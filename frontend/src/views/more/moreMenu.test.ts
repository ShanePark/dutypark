import { describe, expect, it } from 'vitest'
import { MORE_MENU_PATHS, MORE_PROFILE_PATH, buildMoreMenuGroups } from './moreMenu'
import friendsView from '../member/FriendsView.vue?raw'
import memberView from '../member/MemberView.vue?raw'
import notificationListView from '../notification/NotificationListView.vue?raw'
import settingsView from '../settings/SettingsView.vue?raw'
import supportView from '../support/SupportView.vue?raw'

function itemIds(isAdmin: boolean) {
  return buildMoreMenuGroups({ isAdmin }).flat().map((item) => item.id)
}

/** More destinations whose header comes from PageHeader, so back is a shared prop. */
const PAGE_HEADER_VIEWS: Record<string, string> = {
  '/member': memberView,
  '/friends': friendsView,
  '/notifications': notificationListView,
  '/settings': settingsView,
  '/support': supportView,
}

/** These render bespoke headers instead of PageHeader and have no back button yet. */
const BESPOKE_HEADER_PATHS = ['/admin', '/guide']

function pageHeaderTag(source: string): string {
  return source.match(/<PageHeader\b[^>]*>/)?.[0] ?? ''
}

describe('buildMoreMenuGroups', () => {
  it('lists the destinations that are not already in the dock', () => {
    expect(itemIds(false)).toEqual(['friends', 'notifications', 'guide', 'support', 'settings'])
  })

  it('adds the admin entry only for admins', () => {
    expect(itemIds(true)).toEqual(['friends', 'notifications', 'admin', 'guide', 'support', 'settings'])
  })

  it('groups social entries apart from app entries', () => {
    const groups = buildMoreMenuGroups({ isAdmin: false })

    expect(groups).toHaveLength(2)
    expect(groups[0]?.map((item) => item.id)).toEqual(['friends', 'notifications'])
    expect(groups[1]?.map((item) => item.id)).toEqual(['guide', 'support', 'settings'])
  })

  it('marks only the friends entry with the friend request badge', () => {
    const badged = buildMoreMenuGroups({ isAdmin: true })
      .flat()
      .filter((item) => item.showsFriendRequestBadge)

    expect(badged.map((item) => item.id)).toEqual(['friends'])
  })

  it('points the settings entry at the app preference page', () => {
    const settings = buildMoreMenuGroups({ isAdmin: false })
      .flat()
      .find((item) => item.id === 'settings')

    expect(settings?.path).toBe('/settings')
  })

  it('keeps the account page out of the list because the profile card links to it', () => {
    expect(MORE_PROFILE_PATH).toBe('/member')
    expect(buildMoreMenuGroups({ isAdmin: true }).flat().map((item) => item.path))
      .not.toContain(MORE_PROFILE_PATH)
  })

  it('exposes every more destination for the footer active state', () => {
    expect(MORE_MENU_PATHS).toEqual([
      '/member',
      '/friends',
      '/notifications',
      '/admin',
      '/guide',
      '/support',
      '/settings',
    ])
  })
})

describe('more sub-page back navigation', () => {
  it('accounts for every more destination', () => {
    expect([...Object.keys(PAGE_HEADER_VIEWS), ...BESPOKE_HEADER_PATHS].sort())
      .toEqual([...MORE_MENU_PATHS].sort())
  })

  it('sends back to the more tab when the page was entered directly', () => {
    for (const [path, source] of Object.entries(PAGE_HEADER_VIEWS)) {
      const header = pageHeaderTag(source)
      expect(header, path).toContain('show-back')
      expect(header, path).toContain('back-fallback="/more"')
    }
  })
})
