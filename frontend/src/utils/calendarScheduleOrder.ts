interface CalendarCellSchedule {
  daysFromStart?: number | null
  totalDays?: number | null
}

function isMultiDay(schedule: CalendarCellSchedule): boolean {
  return (schedule.totalDays ?? 0) > 1
}

// Multi-day schedules lead a calendar cell, the one that started earliest
// first and then the one that ends latest, so a run keeps its place across
// neighbouring days. Ties and single-day schedules keep their incoming order.
export function compareForCalendarCell(a: CalendarCellSchedule, b: CalendarCellSchedule): number {
  const aSpan = isMultiDay(a)
  const bSpan = isMultiDay(b)
  if (aSpan !== bSpan) return aSpan ? -1 : 1
  if (!aSpan) return 0
  const aStart = a.daysFromStart ?? 1
  const bStart = b.daysFromStart ?? 1
  if (aStart !== bStart) return bStart - aStart
  return (b.totalDays! - bStart) - (a.totalDays! - aStart)
}

export function orderForCalendarCell<T extends CalendarCellSchedule>(schedules: readonly T[]): T[] {
  return [...schedules].sort(compareForCalendarCell)
}
