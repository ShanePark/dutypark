import { describe, expect, it } from 'vitest'
import guideView from './GuideView.vue?raw'
import ko from '@/i18n/messages/ko'
import en from '@/i18n/messages/en'

/**
 * The guide and the release notes share one page, switched by two tabs at the top, the same way
 * the iOS guide uses a segmented picker.
 */
describe('guide page tabs', () => {
  it('switches between the guide and the release notes with a tab strip at the top', () => {
    const tablist = guideView.indexOf('role="tablist"')
    const firstSection = guideView.indexOf('v-for="section in guideSections"')

    expect(tablist).toBeGreaterThan(-1)
    expect(tablist).toBeLessThan(firstSection)
    expect(guideView).toContain(':aria-selected="activeTab === tab.value"')
    expect(guideView).toContain("'bg-dp-accent-soft text-dp-accent font-bold shadow-sm ring-1 ring-dp-accent-border'")
    expect(guideView).toContain("v-if=\"activeTab === 'guide'\"")
    expect(guideView).toContain("activeTab === 'releaseNotes'")
  })

  it('no longer folds the release notes into a collapsible section', () => {
    expect(guideView).not.toContain('isReleaseNotesOpen')
    expect(guideView).not.toContain('toggleReleaseNotes')
    expect(guideView).toContain('loadMoreReleaseNotes')
  })

  it('labels the tabs like the iOS guide picker', () => {
    expect(ko.guide.tabs).toEqual({ guide: '이용 안내', releaseNotes: '업데이트 내역' })
    expect(en.guide.tabs).toEqual({ guide: 'Guide', releaseNotes: 'Release notes' })
  })
})
