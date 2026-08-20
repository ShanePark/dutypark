import type { TaggableFriend } from '@/types'

/** A selected friend that is no longer taggable (unfriended, deactivated) but must stay removable. */
export type SelectedFriendEntry = TaggableFriend & {
  isUnavailable?: boolean
}

export function sortTaggableFriends(friends: TaggableFriend[], locale: string): TaggableFriend[] {
  return [...friends].sort((a, b) => {
    const aPinned = a.pinOrder == null ? 1 : 0
    const bPinned = b.pinOrder == null ? 1 : 0
    if (aPinned !== bPinned) {
      return aPinned - bPinned
    }

    if (a.pinOrder != null && b.pinOrder != null && a.pinOrder !== b.pinOrder) {
      return a.pinOrder - b.pinOrder
    }

    const aFamily = a.isFamily ? 0 : 1
    const bFamily = b.isFamily ? 0 : 1
    if (aFamily !== bFamily) {
      return aFamily - bFamily
    }

    return a.name.localeCompare(b.name, locale)
  })
}

export function matchesFriendQuery(friend: TaggableFriend, query: string): boolean {
  const normalizedQuery = query.trim().toLowerCase()
  if (!normalizedQuery) {
    return true
  }

  return `${friend.name} ${friend.team ?? ''}`.toLowerCase().includes(normalizedQuery)
}

export function filterTaggableFriends(friends: TaggableFriend[], query: string): TaggableFriend[] {
  return friends.filter((friend) => matchesFriendQuery(friend, query))
}

/**
 * Selected friends in the shared sort order, followed by picks that are no longer taggable.
 * The rail lists only taggable friends, so an unavailable pick is reachable through its chip alone.
 */
export function buildSelectedEntries(options: {
  sortedFriends: TaggableFriend[]
  selectedIds: number[]
  resolveUnavailableName: (id: number) => string
}): SelectedFriendEntry[] {
  const { sortedFriends, selectedIds, resolveUnavailableName } = options
  const selectedIdSet = new Set(selectedIds)
  const availableIdSet = new Set(sortedFriends.map((friend) => friend.id))

  const available = sortedFriends.filter((friend) => selectedIdSet.has(friend.id))
  const unavailable = selectedIds
    .filter((id) => !availableIdSet.has(id))
    .map<SelectedFriendEntry>((id) => ({
      id,
      name: resolveUnavailableName(id),
      teamId: null,
      team: null,
      hasProfilePhoto: false,
      profilePhotoVersion: 0,
      isFamily: false,
      pinOrder: null,
      isUnavailable: true,
    }))

  return [...available, ...unavailable]
}
