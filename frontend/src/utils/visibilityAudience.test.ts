import { describe, expect, it } from 'vitest'
import { isRestrictedAudience, resolveVisibilityAudience, searchVisibilityAudience, type AudienceContext } from './visibilityAudience'

const friends = [
  { id: 1, name: 'Owner', isFamily: false },
  { id: 2, name: 'Friend', isFamily: false },
  { id: 3, name: 'Family', isFamily: true },
  { id: null, name: 'Unavailable', isFamily: true },
]
const context: AudienceContext = { ownerId: 1, visibility: 'FRIENDS', scope: 'calendar', calendarVisibility: 'PRIVATE' }
const ids = (value: ReturnType<typeof resolveVisibilityAudience>) => value.map(member => member.id)

describe('visibility audience', () => {
  it('includes family in Friends and excludes the owner and missing identities', () => {
    expect(ids(resolveVisibilityAudience(friends, context))).toEqual([2, 3])
  })
  it('includes only accepted family relations in Family', () => {
    expect(ids(resolveVisibilityAudience(friends, { ...context, visibility: 'FAMILY' }))).toEqual([3])
  })
  it('previews the selected calendar visibility rather than the previously saved one', () => {
    expect(ids(resolveVisibilityAudience(friends, context))).toEqual([2, 3])
  })
  it('deduplicates identities without changing the input', () => {
    const source = [...friends, friends[1]!]
    expect(ids(resolveVisibilityAudience(source, context))).toEqual([2, 3])
    expect(source).toHaveLength(5)
  })
  it.each(['PUBLIC', 'PRIVATE'] as const)('does not enumerate a %s audience', visibility => {
    expect(resolveVisibilityAudience(friends, { ...context, visibility })).toEqual([])
    expect(isRestrictedAudience(visibility)).toBe(false)
  })
  it('applies both the calendar gate and the individual schedule visibility', () => {
    expect(resolveVisibilityAudience(friends, { ...context, scope: 'schedule' })).toEqual([])
    expect(ids(resolveVisibilityAudience(friends, { ...context, scope: 'schedule', calendarVisibility: 'FAMILY' }))).toEqual([3])
    expect(ids(resolveVisibilityAudience(friends, { ...context, scope: 'schedule', calendarVisibility: 'PUBLIC', visibility: 'FAMILY' }))).toEqual([3])
    expect(ids(resolveVisibilityAudience(friends, { ...context, scope: 'schedule', calendarVisibility: 'FRIENDS' }))).toEqual([2, 3])
  })
  it('fails closed for an unknown calendar visibility', () => {
    expect(resolveVisibilityAudience(friends, { ...context, scope: 'schedule', calendarVisibility: 'UNKNOWN' as AudienceContext['calendarVisibility'] })).toEqual([])
  })
  it('handles an empty audience without inventing viewers', () => {
    expect(resolveVisibilityAudience([], context)).toEqual([])
  })
  it('supports trimmed, case-insensitive name searches and keeps the source order', () => {
    expect(ids(searchVisibilityAudience(friends, '  FAMILY ', 'en'))).toEqual([3])
    expect(searchVisibilityAudience(friends, 'no match', 'ko')).toEqual([])
    expect(friends[0]!.name).toBe('Owner')
  })
  it('normalizes Korean Unicode names for search', () => {
    const members = [{ id: 4, name: '가족', isFamily: true }]
    expect(searchVisibilityAudience(members, '가족'.normalize('NFD'), 'ko')).toEqual(members)
  })
})
