import { describe, expect, it } from 'vitest'
import memberView from './member/MemberView.vue?raw'
import settingsView from './settings/SettingsView.vue?raw'
import moreView from './more/MoreView.vue?raw'

/**
 * The account page and the app preference page were split out of one oversized view.
 * These markers pin each section to its page so the two never drift back together.
 */

const MEMBER_SECTION_MARKERS = [
  'member.profile.sectionTitle',
  'DutyPatternCard',
  'member.manager.sectionTitle',
  'member.sessions.sectionTitle',
  'member.sso.sectionTitle',
  'member.account.sectionTitle',
  'accountDeletionCompletion',
]

const SETTINGS_SECTION_MARKERS = [
  'member.visibility.sectionTitle',
  'member.theme.sectionTitle',
  'member.push.sectionTitle',
  'aiScheduleConsent.settingsTitle',
]

describe('member and settings page split', () => {
  it('keeps every account section on the member page', () => {
    for (const marker of MEMBER_SECTION_MARKERS) {
      expect(memberView, marker).toContain(marker)
      expect(settingsView, marker).not.toContain(marker)
    }
  })

  it('keeps every app preference section on the settings page', () => {
    for (const marker of SETTINGS_SECTION_MARKERS) {
      expect(settingsView, marker).toContain(marker)
      expect(memberView, marker).not.toContain(marker)
    }
  })

  it('titles each page distinctly', () => {
    expect(memberView).toContain("t('member.pageTitle')")
    expect(settingsView).toContain("t('header.menu.settings')")
  })

  it('leaves logout to the more page alone', () => {
    expect(moreView).toContain("t('member.logout')")
    expect(memberView).not.toContain('member.logout')
    expect(settingsView).not.toContain('member.logout')
  })

  it('does not load account-only data on the settings page', () => {
    for (const accountOnlyCall of [
      'getManagedMembers',
      'getManagers',
      'getFamilyMembers',
      'getRefreshTokens',
    ]) {
      expect(settingsView, accountOnlyCall).not.toContain(accountOnlyCall)
    }
  })

  it('does not load preference-only data on the member page', () => {
    for (const preferenceOnlyCall of ['friendApi', 'usePushNotification', 'useAiScheduleConsentStore']) {
      expect(memberView, preferenceOnlyCall).not.toContain(preferenceOnlyCall)
    }
  })
})
