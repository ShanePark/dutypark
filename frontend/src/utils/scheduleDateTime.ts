/**
 * A schedule has no "has a time" flag: midnight means it carries no time at all.
 * The editor therefore edits a date and an *optional* time separately, and only folds
 * them back into the `YYYY-MM-DDTHH:mm` value the API expects.
 */

const MIDNIGHT = '00:00'

export function extractDate(dateTime: string): string {
  return dateTime.split('T')[0] ?? ''
}

/** `null` for a stored value that means "no time", so the field can stay empty. */
export function extractTime(dateTime: string): string | null {
  const time = (dateTime.split('T')[1] ?? '').slice(0, 5)
  return !time || time === MIDNIGHT ? null : time
}

export function joinDateTime(date: string, time: string | null): string {
  return `${date}T${time ?? MIDNIGHT}`
}

/**
 * An end equal to the start is how a schedule with a start time but no end time is stored —
 * the API rejects an end before the start — so it reads back as no end time.
 */
export function extractEndTime(endDateTime: string, startDateTime: string): string | null {
  return endDateTime === startDateTime ? null : extractTime(endDateTime)
}

/**
 * Without an end time the end means that whole day, but the API rejects an end before the
 * start, so a same-day end collapses onto the start — which is exactly how the schedule list
 * already renders it, as a single time.
 */
export function effectiveEndDateTime(startDateTime: string, endDateTime: string): string {
  if (extractTime(endDateTime) !== null) return endDateTime
  return extractDate(endDateTime) === extractDate(startDateTime) ? startDateTime : endDateTime
}

export function isRangeInvalid(startDateTime: string, endDateTime: string): boolean {
  if (!startDateTime || !endDateTime) return false
  return effectiveEndDateTime(startDateTime, endDateTime) < startDateTime
}

/**
 * The next full hour, so adding a time lands on something usable — and never on midnight,
 * which would be read back as no time at all.
 */
export function defaultStartTime(now: Date): string {
  const nextHour = now.getHours() + 1
  return `${String(nextHour > 23 ? 9 : nextHour).padStart(2, '0')}:00`
}

const LAST_MINUTE = '23:59'

function nextDay(date: string): string {
  const day = new Date(`${date}T00:00:00`)
  day.setDate(day.getDate() + 1)
  const month = String(day.getMonth() + 1).padStart(2, '0')
  return `${day.getFullYear()}-${month}-${String(day.getDate()).padStart(2, '0')}`
}

/**
 * An hour after the start. An added end time has to stay visible, so it can be neither midnight
 * — which reads back as no time at all — nor equal to the start, which reads back as no end
 * time: it falls back to the last minute of the chosen end date, and rolls a day forward only
 * when the start already sits on that minute.
 */
export function defaultEndDateTime(startDateTime: string, endDate: string): string {
  const [hour = '0', minute = '00'] = (extractTime(startDateTime) ?? MIDNIGHT).split(':')
  const nextHour = Number(hour) + 1
  if (nextHour <= 23) return `${endDate}T${String(nextHour).padStart(2, '0')}:${minute}`
  if (`${endDate}T${LAST_MINUTE}` > startDateTime) return `${endDate}T${LAST_MINUTE}`
  return `${nextDay(endDate)}T00:${minute}`
}
