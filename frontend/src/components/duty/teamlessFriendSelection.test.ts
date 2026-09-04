import { describe, expect, it } from 'vitest'
import en from '@/i18n/messages/en'
import ko from '@/i18n/messages/ko'
import otherDutiesModal from './OtherDutiesModal.vue?raw'

const template = otherDutiesModal.match(/<template>([\s\S]*?)<\/template>/)?.[1] ?? ''

function friendOptionOpening() {
  return template.match(
    /<button\s+v-for="friend in friends"[\s\S]*?(?=\s*<ProfileAvatar)/,
  )?.[0] ?? ''
}

describe('teamless friends in the shared duty selector', () => {
  it('keeps teamless friends visible but disables selecting them with an explanation', () => {
    const option = friendOptionOpening()

    expect(option).toContain(':disabled="!isSelected(friend.id) && (isTeamless(friend) || !canSelectMore)"')
    expect(option).toContain('isTeamless(friend) || !canSelectMore')
    expect(template).toContain('v-if="isTeamless(friend)"')
    expect(template).toContain("t('duty.otherDuties.noTeam')")
    expect(otherDutiesModal).toMatch(
      /function isTeamless\(friend: TaggableFriend\)\s*\{\s*return friend\.teamId == null\s*\}/,
    )
    expect(otherDutiesModal).toMatch(
      /if \(friend && isTeamless\(friend\) && !isSelected\(friendId\)\) \{\s*return/,
    )
  })

  it('treats a null teamId as teamless even when the team label is stale', () => {
    expect(otherDutiesModal).toMatch(
      /function isTeamless\(friend: TaggableFriend\)\s*\{\s*return friend\.teamId == null\s*\}/,
    )
    expect(otherDutiesModal).not.toMatch(/friend\.teamId == null && !friend\.team\?\.trim\(\)/)
  })

  it('keeps the no-team explanation localized in both supported languages', () => {
    expect(en.duty.otherDuties.noTeam).toBe('No team')
    expect(ko.duty.otherDuties.noTeam).toBe('소속 팀 없음')
  })
})
