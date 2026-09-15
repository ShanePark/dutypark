export type AudienceVisibility = 'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE'
export type AudienceScope = 'calendar' | 'schedule'

export interface AudienceFriend {
  id: number | null
  name: string
  isFamily: boolean
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
}

export interface AudienceContext {
  ownerId: number
  visibility: AudienceVisibility
  scope: AudienceScope
  calendarVisibility: AudienceVisibility
}

export function isRestrictedAudience(visibility: string): visibility is 'FRIENDS' | 'FAMILY' {
  return visibility === 'FRIENDS' || visibility === 'FAMILY'
}

/** Relationship-based viewers only. Tags and privileged access are disclosed separately. */
export function resolveVisibilityAudience<T extends AudienceFriend>(
  friends: readonly T[],
  context: AudienceContext,
): T[] {
  if (!isRestrictedAudience(context.visibility)) return []
  const unique = new Map<number, T>()
  for (const friend of friends) {
    if (friend.id === null || friend.id === context.ownerId || unique.has(friend.id)) continue
    if (context.visibility === 'FAMILY' && !friend.isFamily) continue
    if (context.scope === 'schedule') {
      if (!['PUBLIC', 'FRIENDS', 'FAMILY'].includes(context.calendarVisibility)) continue
      if (context.calendarVisibility === 'FAMILY' && !friend.isFamily) continue
    }
    unique.set(friend.id, friend)
  }
  return [...unique.values()]
}

export function searchVisibilityAudience<T extends AudienceFriend>(
  members: readonly T[], query: string, locale: string,
): T[] {
  const normalizedQuery = query.trim().normalize('NFKC').toLocaleLowerCase(locale)
  const collator = new Intl.Collator(locale, { sensitivity: 'base', numeric: true })
  return members
    .filter(member => member.name.normalize('NFKC').toLocaleLowerCase(locale).includes(normalizedQuery))
    .sort((left, right) => collator.compare(left.name, right.name) || (left.id ?? 0) - (right.id ?? 0))
}
