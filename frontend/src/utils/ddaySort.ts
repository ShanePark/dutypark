interface SortableDDay {
  date: string
  calc: number
}

// Upcoming (calc >= 0) nearest first, then past most recent first.
export function compareDDays(a: SortableDDay, b: SortableDDay): number {
  const aPast = a.calc < 0
  const bPast = b.calc < 0
  if (aPast !== bPast) return aPast ? 1 : -1
  return aPast ? b.date.localeCompare(a.date) : a.date.localeCompare(b.date)
}
