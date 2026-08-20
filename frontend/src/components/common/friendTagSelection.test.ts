import { describe, expect, it } from 'vitest'
import type { TaggableFriend } from '@/types'
import {
  buildSelectedEntries,
  filterTaggableFriends,
  sortTaggableFriends,
} from './friendTagSelection'

function friend(overrides: Partial<TaggableFriend> & Pick<TaggableFriend, 'id' | 'name'>): TaggableFriend {
  return {
    teamId: null,
    team: null,
    hasProfilePhoto: false,
    profilePhotoVersion: 0,
    isFamily: false,
    pinOrder: null,
    ...overrides,
  }
}

describe('sortTaggableFriends', () => {
  it('orders pinned friends first, then family, then by name', () => {
    const friends = [
      friend({ id: 1, name: 'Zoe' }),
      friend({ id: 2, name: 'Amy' }),
      friend({ id: 3, name: 'Family', isFamily: true }),
      friend({ id: 4, name: 'Pinned second', pinOrder: 2 }),
      friend({ id: 5, name: 'Pinned first', pinOrder: 1 }),
    ]

    expect(sortTaggableFriends(friends, 'ko').map((entry) => entry.id)).toEqual([5, 4, 3, 2, 1])
  })

  it('leaves the source array untouched', () => {
    const friends = [friend({ id: 2, name: 'Bee' }), friend({ id: 1, name: 'Ant' })]

    sortTaggableFriends(friends, 'ko')

    expect(friends.map((entry) => entry.id)).toEqual([2, 1])
  })
})

describe('filterTaggableFriends', () => {
  const friends = [
    friend({ id: 1, name: 'Alice', team: 'Emergency' }),
    friend({ id: 2, name: 'Bob', team: 'Emergency' }),
    friend({ id: 3, name: 'Carol', team: 'Ward' }),
  ]

  it('matches on name and team', () => {
    expect(filterTaggableFriends(friends, 'emerg').map((entry) => entry.id)).toEqual([1, 2])
    expect(filterTaggableFriends(friends, 'carol').map((entry) => entry.id)).toEqual([3])
  })

  it('keeps the whole rail browsable for a blank query', () => {
    expect(filterTaggableFriends(friends, '   ').map((entry) => entry.id)).toEqual([1, 2, 3])
  })
})

describe('buildSelectedEntries', () => {
  const sortedFriends = [
    friend({ id: 1, name: 'Alice' }),
    friend({ id: 2, name: 'Bob' }),
  ]

  it('lists selected friends in the rail order', () => {
    const entries = buildSelectedEntries({
      sortedFriends,
      selectedIds: [2, 1],
      resolveUnavailableName: () => 'unused',
    })

    expect(entries.map((entry) => entry.id)).toEqual([1, 2])
    expect(entries.every((entry) => entry.isUnavailable !== true)).toBe(true)
  })

  it('appends picks that are no longer taggable so they stay removable', () => {
    const entries = buildSelectedEntries({
      sortedFriends,
      selectedIds: [1, 99],
      resolveUnavailableName: (id) => `Friend #${id}`,
    })

    expect(entries.map((entry) => entry.id)).toEqual([1, 99])
    expect(entries[1]).toMatchObject({ name: 'Friend #99', isUnavailable: true })
  })

  it('returns nothing when no friend is selected', () => {
    expect(buildSelectedEntries({
      sortedFriends,
      selectedIds: [],
      resolveUnavailableName: () => 'unused',
    })).toEqual([])
  })
})
