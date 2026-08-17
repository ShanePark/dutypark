import { describe, expect, it } from 'vitest'
import { MORE_MENU_PATHS, MORE_PROFILE_PATH, buildMoreMenuGroups } from './moreMenu'

function itemIds(isAdmin: boolean) {
  return buildMoreMenuGroups({ isAdmin }).flat().map((item) => item.id)
}

describe('buildMoreMenuGroups', () => {
  it('lists the destinations that are not already in the dock', () => {
    expect(itemIds(false)).toEqual(['friends', 'notifications', 'guide', 'settings'])
  })

  it('adds the admin entry only for admins', () => {
    expect(itemIds(true)).toEqual(['friends', 'notifications', 'admin', 'guide', 'settings'])
  })

  it('groups social entries apart from app entries', () => {
    const groups = buildMoreMenuGroups({ isAdmin: false })

    expect(groups).toHaveLength(2)
    expect(groups[0]?.map((item) => item.id)).toEqual(['friends', 'notifications'])
    expect(groups[1]?.map((item) => item.id)).toEqual(['guide', 'settings'])
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
      '/settings',
    ])
  })
})
