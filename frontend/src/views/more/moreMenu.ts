import type { Component } from 'vue'
import { Bell, BookOpen, Settings, Shield, UserPlus } from 'lucide-vue-next'

export type MoreMenuItem = {
  id: string
  path: string
  labelKey: string
  icon: Component
  showsFriendRequestBadge?: boolean
}

export function buildMoreMenuGroups(options: { isAdmin: boolean }): MoreMenuItem[][] {
  const socialGroup: MoreMenuItem[] = [
    {
      id: 'friends',
      path: '/friends',
      labelKey: 'header.menu.friends',
      icon: UserPlus,
      showsFriendRequestBadge: true,
    },
    { id: 'notifications', path: '/notifications', labelKey: 'header.menu.notifications', icon: Bell },
  ]

  const appGroup: MoreMenuItem[] = []

  if (options.isAdmin) {
    appGroup.push({ id: 'admin', path: '/admin', labelKey: 'header.menu.admin', icon: Shield })
  }

  appGroup.push(
    { id: 'guide', path: '/guide', labelKey: 'header.menu.guide', icon: BookOpen },
    { id: 'settings', path: '/settings', labelKey: 'header.menu.settings', icon: Settings }
  )

  return [socialGroup, appGroup]
}

/** The profile card at the top of the more page is the entry point to the account page. */
export const MORE_PROFILE_PATH = '/member'

/**
 * Destinations reachable from the more page. The footer keeps its more tab active
 * while the user is on any of them, so both stay in sync from this single list.
 */
export const MORE_MENU_PATHS: string[] = [
  MORE_PROFILE_PATH,
  ...buildMoreMenuGroups({ isAdmin: true })
    .flat()
    .map((item) => item.path),
]
