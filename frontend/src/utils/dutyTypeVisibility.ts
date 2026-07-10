export interface DutyTypeVisibilityItem {
  id: number | null
  hidden: boolean
}

export function findVisibleDutyTypeNeighbor(
  types: DutyTypeVisibilityItem[],
  index: number,
  direction: -1 | 1
): number | null {
  for (let next = index + direction; next >= 0 && next < types.length; next += direction) {
    const type = types[next]
    if (type?.id !== null && !type?.hidden) return next
  }
  return null
}
