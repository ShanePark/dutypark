"""One-time, idempotent integration for PR #422; removed before handoff."""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
assert subprocess.check_output(['git', 'branch', '--show-current'], cwd=ROOT, text=True).strip() == 'feat/visibility-audience-preview'
assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip(), 'Refuse a dirty checkout'


def replace_once(text, before, after):
    assert text.count(before) == 1, f'Expected exactly one integration anchor: {before[:100]!r}'
    return text.replace(before, after, 1)


path = ROOT / 'frontend/src/views/settings/SettingsView.vue'
text = path.read_text()
if 'import CalendarVisibilityModal ' not in text:
    text = replace_once(text, "import { friendApi, memberApi }", "import { memberApi }")
    text = replace_once(text, 'CalendarVisibility, FriendDto', 'CalendarVisibility')
    text = replace_once(text, "import BaseModal from '@/components/common/BaseModal.vue'", "import CalendarVisibilityModal from '@/components/common/CalendarVisibilityModal.vue'")
    text = replace_once(text, "import ProfileAvatar from '@/components/common/ProfileAvatar.vue'\n", '')
    text = replace_once(text, '  Check,\n  X,\n', '')
    text = replace_once(text, "const memberModalPanelStyle = { backgroundColor: 'var(--dp-bg-card)' }\n", '')
    start = text.index('interface VisibilityAudience {')
    end = text.index('const visibilityColorClass', start)
    text = text[:start] + '''function openVisibilityModal() {
  showVisibilityModal.value = true
}

let visibilitySaveGeneration = 0
watch(() => authStore.user?.id, () => {
  visibilitySaveGeneration++
  savingVisibility.value = false
  showVisibilityModal.value = false
}, { flush: 'sync' })

''' + text[end:]
    start = text.index('async function setVisibility(')
    end = text.index('async function fetchCalendarVisibility()', start)
    text = text[:start] + '''async function setVisibility(value: CalendarVisibility) {
  const ownerId = authStore.user?.id
  if (!ownerId || savingVisibility.value || calendarVisibility.value === value) return
  const generation = ++visibilitySaveGeneration
  const isCurrent = () => generation === visibilitySaveGeneration && authStore.user?.id === ownerId
  savingVisibility.value = true
  try {
    await memberApi.updateVisibility(ownerId, value)
    if (!isCurrent()) return
    calendarVisibility.value = value
    showVisibilityModal.value = false
  } catch (error) {
    if (!isCurrent()) return
    console.error('Failed to update visibility:', error)
    showError(t('member.visibility.updateFailed'))
  } finally {
    if (isCurrent()) savingVisibility.value = false
  }
}

''' + text[end:]
    start = text.index('    <!-- Visibility Modal -->')
    end = text.index('    </BaseModal>', start) + len('    </BaseModal>')
    text = text[:start] + '''    <CalendarVisibilityModal
      :key="authStore.user?.id"
      :is-open="showVisibilityModal"
      :value="calendarVisibility"
      :saving="savingVisibility"
      @close="showVisibilityModal = false"
      @save="setVisibility"
    />''' + text[end:]
    start = text.index('\n.audience-avatar + .audience-avatar')
    end = text.index('</style>', start)
    text = text[:start] + text[end:]
    path.write_text(text)

path = ROOT / 'frontend/src/components/duty/ScheduleForm.vue'
text = path.read_text()
if 'import VisibilityAudiencePreview ' not in text:
    text = replace_once(text, "import FriendTagSelector from '@/components/common/FriendTagSelector.vue'", "import FriendTagSelector from '@/components/common/FriendTagSelector.vue'\nimport VisibilityAudiencePreview from '@/components/common/VisibilityAudiencePreview.vue'")
    text = replace_once(text, '@click="form.visibility = option.value"', '@click="form.visibility = option.value"\n          :aria-pressed="form.visibility === option.value"')
    before = '''        </button>
      </div>
    </div>

    <!-- Attachment Upload Area -->'''
    after = '''        </button>
        <VisibilityAudiencePreview
          v-if="canTagFriends"
          :visibility="form.visibility"
          scope="schedule"
          class="col-span-4 mt-1"
        />
      </div>
    </div>

    <!-- Attachment Upload Area -->'''
    text = replace_once(text, before, after)
    path.write_text(text)

path = ROOT / 'src/main/resources/public-content/release-notes.json'
text = path.read_text()
original = json.loads(text)
entry_id = 'pr-422'
if not any(item['id'] == entry_id for item in original['items']):
    # The PR was created on 2026-09-15 in Asia/Seoul, not the runner's UTC date.
    version = '2026.09.15'
    used = {item['version'] for item in original['items']}
    suffix = 2
    while version in used:
        version = f'2026.09.15.{suffix:02d}'
        suffix += 1
    item = {
        'id': entry_id, 'version': version, 'date': '2026-09-15', 'pr': 422,
        'url': 'https://github.com/ShanePark/dutypark/pull/422',
        'category': 'feature', 'areas': ['calendar', 'friends', 'profile', 'schedule', 'ui'],
    }
    copies = {
        'ko': {
            'title': '친구·가족 공개 대상 확인',
            'summary': '공개 범위를 바꾸기 전에 친구와 가족의 전체 명단을 확인할 수 있습니다.',
            'changes': [
                '친구공개·가족공개에서 전체 명단과 가족 표시, 이름 검색을 제공하고 조회 실패 시 다시 시도할 수 있습니다.',
                '캘린더 공개 설정은 선택 후 명단을 확인하고 저장하는 방식으로 바뀌어, 확인 중 실수로 설정이 변경되지 않습니다.',
                '내 일정 작성 화면에서도 공개 대상을 확인할 수 있으며 캘린더 공개 제한과 태그·위임 등 별도 접근 권한을 안내합니다.',
            ],
        },
        'en': {
            'title': 'Inspect Friends and Family audiences',
            'summary': 'Check the full list of friends and family before changing visibility.',
            'changes': [
                'View the full audience with family badges, name search, and recoverable loading errors.',
                'Calendar visibility now uses an explicit select, inspect, and save flow to avoid accidental changes.',
                'Check the audience while editing your own schedules, with calendar restrictions and separate tagged or delegated access explained.',
            ],
        },
    }
    item_json = json.dumps(item, ensure_ascii=False, indent=2)
    item_json = '\n'.join('    ' + line for line in item_json.splitlines())
    text = replace_once(text, '  "items": [', '  "items": [\n' + item_json + ',')
    for locale, copy in copies.items():
        locale_start = text.index('    "' + locale + '": {')
        position = text.index('      "entries": {', locale_start) + len('      "entries": {')
        serialized = json.dumps({entry_id: copy}, ensure_ascii=False, indent=2)
        inner = serialized.splitlines()[1:-1]
        inserted = '\n'.join('      ' + line for line in inner)
        text = text[:position] + '\n' + inserted + ',' + text[position:]
    updated = json.loads(text)
    restored = json.loads(text)
    restored['items'] = [entry for entry in restored['items'] if entry['id'] != entry_id]
    for locale in copies:
        restored['locales'][locale]['entries'].pop(entry_id)
    assert restored == original, 'Release note integration changed existing data'
    assert sum(entry['id'] == entry_id for entry in updated['items']) == 1
    path.write_text(text)

subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
print('Scoped web integrations and canonical bilingual PR #422 release note are ready.')
