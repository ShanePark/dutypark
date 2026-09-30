<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import CalendarGrid from '../../src/components/common/CalendarGrid.vue'
import { dutyCalendarWeekendColor, dutyTypePalette } from '../../src/utils/dutyTypePalette'
import { isLightColor } from '../../src/utils/color'
import { contrastRatio } from './policy'

const { t } = useI18n()
const defaultOffColor = dutyTypePalette.find(option => option.name === 'blush')!.color
const mode = ref<string>('blush')
const selectedColor = ref<string>(defaultOffColor)
const customDraft = ref<string>(defaultOffColor)
const selectedDay = ref({ year: 2025, month: 10, day: 14 })
const previewRoots = reactive<Record<string, HTMLElement | null>>({ light: null, dark: null })
const foreground = computed(() => isLightColor(selectedColor.value) ? '#1F2937' : '#FFFFFF')
const colorName = computed(() => mode.value === 'custom' ? t('team.dutyType.palette.custom') : t(`team.dutyType.palette.${mode.value}`))
const invalidHex = computed(() => mode.value === 'custom' && !/^#[0-9a-f]{6}$/i.test(customDraft.value))
const isOff = computed(() => mode.value === 'blush')
const dates = Array.from({ length: 35 }, (_, index) => {
  const d = new Date(2025, 8, 28 + index)
  return { year: d.getFullYear(), month: d.getMonth() + 1, day: d.getDate(), isCurrentMonth: d.getMonth() === 9, isToday: d.getMonth() === 9 && d.getDate() === 9 }
})
const holidays = dates.map(d => d.month === 10 && [3, 9].includes(d.day)
  ? [{ dateName: d.day === 3 ? '개천절' : '한글날', isHoliday: true, localDate: `2025-10-${String(d.day).padStart(2, '0')}` }]
  : [])
function filled(d: { month: number; day: number }) { return d.month === 10 && ![6, 13, 20, 27].includes(d.day) }
function dayColor(d: { month: number; day: number }) { return filled(d) ? selectedColor.value : null }
function choosePreset(name: string, color: string) {
  mode.value = name
  selectedColor.value = color
  customDraft.value = color
}
function chooseCustom() {
  mode.value = 'custom'
  customDraft.value = selectedColor.value
}
function updateCustom(value: string) {
  customDraft.value = value
  if (/^#[0-9a-f]{6}$/i.test(value)) selectedColor.value = value.toUpperCase()
}
function weekendForeground(theme: string, day: 'sunday' | 'saturday') {
  const color = dutyCalendarWeekendColor(selectedColor.value, day)
  if (color.startsWith('#')) return color
  const root = previewRoots[theme]
  return root ? getComputedStyle(root).getPropertyValue(`--dp-${day}`).trim() : '#FFFFFF'
}
function weekendContrast(theme: string, day: 'sunday' | 'saturday') {
  return contrastRatio(selectedColor.value, weekendForeground(theme, day)).toFixed(2)
}
</script>

<template>
  <main class="review-tool">
    <header class="intro">
      <p class="eyebrow">DUTYPARK · FINAL PALETTE</p>
      <h1>최종 팔레트 미리보기</h1>
      <p>대표색 11개와 커스텀 1칸을 두 열로 배치했습니다. 색을 선택하면 실제 달력의 라이트·다크 모드를 함께 확인할 수 있습니다.</p>
      <p class="muted">신규 팀의 OFF 기본색은 블러시 {{ defaultOffColor }}입니다. 이 화면은 미리보기용이며 서비스 설정을 저장하지 않습니다.</p>
    </header>

    <section class="picker-panel" aria-labelledby="palette-heading">
      <h2 id="palette-heading">근무 색상</h2>
      <div class="palette-grid" role="radiogroup" aria-label="근무 색상 선택">
        <label v-for="option in dutyTypePalette" :key="option.name" class="palette-option" :class="{ chosen: mode === option.name }">
          <input type="radio" name="duty-color" :value="option.name" :checked="mode === option.name" @change="choosePreset(option.name, option.color)">
          <span class="swatch" :style="{ background: option.color }" aria-hidden="true"></span>
          <span class="option-name">{{ t(`team.dutyType.palette.${option.name}`) }}<small v-if="option.name === 'blush'">OFF 기본색</small></span>
          <code>{{ option.color }}</code>
        </label>
        <label class="palette-option custom-option" :class="{ chosen: mode === 'custom' }">
          <input type="radio" name="duty-color" value="custom" :checked="mode === 'custom'" @change="chooseCustom">
          <span class="custom-swatch" aria-hidden="true">＋</span>
          <span class="option-name">{{ t('team.dutyType.palette.custom') }}<small>직접 선택</small></span>
        </label>
      </div>
      <div v-if="mode === 'custom'" class="custom-controls">
        <label class="color-control">색상 선택<input type="color" :value="selectedColor" @input="updateCustom(($event.target as HTMLInputElement).value)"></label>
        <label class="hex-control">HEX<input type="text" :value="customDraft" placeholder="#123456" maxlength="7" spellcheck="false" :aria-invalid="invalidHex" @input="updateCustom(($event.target as HTMLInputElement).value)"></label>
        <p class="muted">커스텀은 자유롭게 선택할 수 있습니다. 아래 대비 수치는 참고 정보입니다.</p>
        <p v-if="invalidHex" class="hex-error" role="status">#과 6자리 HEX를 입력해 주세요. 입력 중에는 마지막 유효 색상을 표시합니다.</p>
      </div>
      <div class="selected-summary" aria-live="polite"><span class="swatch" :style="{ background: selectedColor }"></span><strong>{{ colorName }}</strong><code>{{ selectedColor }}</code><span class="muted">근무 글자 {{ contrastRatio(selectedColor, foreground).toFixed(2) }}:1</span></div>
    </section>

    <section class="previews" aria-label="실제 달력 미리보기">
      <article v-for="theme in ['light', 'dark']" :key="theme" :ref="element => previewRoots[theme] = element as HTMLElement | null" :class="['theme-preview', { dark: theme === 'dark' }]" :style="{ '--review-foreground': foreground }">
        <div class="preview-title"><h2>{{ theme === 'light' ? '라이트' : '다크' }} 모드</h2><code>{{ selectedColor }}</code></div>
        <div class="month-heading"><span>‹</span><h3>2025년 10월</h3><span>›</span></div>
        <CalendarGrid :days="dates" :current-year="2025" :current-month="10" :holidays="holidays" :get-duty-color="dayColor" :selected-day="selectedDay" :use-adaptive-border="true" @day-click="selectedDay = $event">
          <template #day-header="{ day }"><span v-if="filled(day)" class="preview-abbr">{{ isOff ? 'OFF' : ['D', 'E', 'N'][day.day % 3] }}</span></template>
          <template #day-content="{ day }">
            <div v-if="filled(day)" class="preview-duty">{{ isOff ? '휴무' : ['주간', '오후', '야간'][day.day % 3] }}</div>
            <div v-if="day.month === 10 && [3, 9, 14, 18, 22, 29].includes(day.day)" class="preview-event">{{ day.day === 9 ? '가족 식사' : day.day === 14 ? '팀 교육' : day.day === 22 ? '정기 검진' : '친구 약속' }}</div>
          </template>
        </CalendarGrid>
        <p class="preview-note">9일 오늘 · {{ selectedDay.day }}일 선택 · 빈 근무와 앞뒤 달 포함</p>
        <div class="contrast-info"><span>일요일·공휴일 <b>{{ weekendContrast(theme, 'sunday') }}:1</b></span><span>토요일 <b>{{ weekendContrast(theme, 'saturday') }}:1</b></span></div>
      </article>
    </section>
  </main>
</template>

<style>
body { margin:0; background:#f5f6f8; color:#1f2937; font-family:'NexonMaplestory',system-ui,sans-serif }
.review-tool { max-width:1280px; margin:auto; padding:30px 24px 48px }
.review-tool h1 { font-size:30px; font-weight:700; line-height:1.35; margin:6px 0 12px }
.review-tool h2 { font-size:19px; font-weight:700; margin:0 0 12px }
.review-tool p { line-height:1.6; margin:6px 0 }
.review-tool code { font:13px ui-monospace,monospace; font-weight:400 }
.review-tool :focus-visible { outline:3px solid #3b82f6; outline-offset:3px }
.eyebrow { color:#64748b; font-size:12px; letter-spacing:.06em }
.muted { color:#64748b; font-size:13px }
.picker-panel { background:white; border:1px solid #e2e8f0; border-radius:12px; padding:20px; margin:22px 0 18px }
.palette-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:10px; max-width:800px }
.palette-option { display:flex; align-items:center; gap:10px; min-height:66px; padding:10px 14px; border:1px solid #cbd5e1; border-radius:9px; cursor:pointer; transition:background .15s; min-width:0 }
.palette-option:hover { background:#f8fafc }.palette-option.chosen { border-color:#3b82f6; background:#eff6ff }.palette-option input { width:16px; height:16px; accent-color:#2563eb; flex-shrink:0 }
.swatch { width:30px; height:30px; border:1px solid #0002; border-radius:6px; flex-shrink:0 }
.custom-swatch { display:flex; align-items:center; justify-content:center; width:30px; height:30px; border-radius:6px; background:conic-gradient(#ffb3c1,#ffe38c,#b9dfac,#a5d9e2,#d6b8ea,#ffb3c1); color:#1f2937; font-size:20px; flex-shrink:0 }
.option-name { font-size:15px; font-weight:700 }.option-name small { display:block; font-size:10px; font-weight:400; color:#64748b; margin-top:4px }.palette-option code { margin-left:auto; color:#64748b }
.custom-controls { display:flex; align-items:center; flex-wrap:wrap; gap:14px; margin:16px 0; padding:16px; background:#f8fafc; border-radius:8px }.custom-controls label { font-size:13px; display:flex; flex-direction:column; gap:7px }.custom-controls input { border:1px solid #cbd5e1; border-radius:6px; background:white; color:#1f2937; font:14px ui-monospace,monospace; min-height:42px }.color-control input { width:70px; padding:3px; cursor:pointer }.hex-control input { width:130px; padding:10px }.custom-controls .hex-error { width:100%; font-size:12px; color:#991b1b }
.selected-summary { display:flex; align-items:center; flex-wrap:wrap; gap:10px; border-top:1px solid #e2e8f0; padding-top:16px; margin-top:16px }.selected-summary strong { font-size:16px }.selected-summary .muted { margin-left:auto }
.previews { display:grid; grid-template-columns:1fr 1fr; gap:18px }.theme-preview { --color-dp-bg-card:var(--dp-bg-card); --color-dp-border-secondary:var(--dp-border-secondary); --color-dp-accent:var(--dp-accent); background:var(--dp-bg-secondary); color:var(--dp-text-primary); padding:16px; border:1px solid var(--dp-border-secondary); border-radius:12px; min-width:0 }.preview-title { display:flex; justify-content:space-between; align-items:center }.preview-title code { color:var(--dp-text-muted); font-size:12px }.month-heading { display:flex; align-items:center; justify-content:space-between; margin:10px 0 15px }.month-heading h3 { font-size:20px; font-weight:700 }.month-heading > span { font-size:25px; color:var(--dp-text-muted) }.preview-abbr,.preview-duty { color:var(--review-foreground); font-size:13px; font-weight:700; line-height:1.3 }.preview-abbr { font-size:10px }.preview-duty { text-align:center; margin:4px 0 }.preview-event { color:var(--review-foreground); font-size:11px; border-top:2px dashed var(--dp-border-on-light); margin-top:5px; overflow-wrap:anywhere }.preview-note { color:var(--dp-text-muted); font-size:12px }.contrast-info { display:flex; flex-wrap:wrap; gap:8px 16px; color:var(--dp-text-secondary); font-size:12px; margin-top:10px }
@media(max-width:800px) { .previews { grid-template-columns:1fr } }
@media(max-width:450px) { .review-tool { padding:20px 12px }.review-tool h1 { font-size:25px }.picker-panel { padding:14px }.palette-grid { gap:8px }.palette-option { padding:10px 8px; gap:6px; min-height:67px; flex-wrap:wrap }.palette-option .swatch,.palette-option .custom-swatch { width:24px;height:24px }.option-name { font-size:13px }.palette-option code { font-size:11px; width:100%; margin-left:22px }.theme-preview { padding:10px }.preview-event { font-size:10px }.preview-duty { font-size:11px }.selected-summary .muted { width:100%;margin-left:0 }.custom-controls { padding:12px;gap:10px } }
</style>
