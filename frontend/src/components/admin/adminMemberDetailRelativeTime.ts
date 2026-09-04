const MILLISECONDS_PER_DAY = 86_400_000

function localCalendarDayTimestamp(date: Date): number {
  return Date.UTC(date.getFullYear(), date.getMonth(), date.getDate())
}

/**
 * Returns the number of local calendar dates between a timestamp and the reference date.
 * A timestamp later today is clamped to zero to preserve the existing relative-label behavior.
 */
export function getCalendarDayDifference(value: string, referenceDate = new Date()): number {
  const valueDate = new Date(value)
  const difference = localCalendarDayTimestamp(referenceDate) - localCalendarDayTimestamp(valueDate)

  return Math.max(0, Math.floor(difference / MILLISECONDS_PER_DAY))
}
