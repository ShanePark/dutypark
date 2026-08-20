import { formatDateOnly, parseDateOnly } from '@/utils/date'

/** One cell of the popover's month grid. */
export interface DatePickerDay {
  /** ISO `YYYY-MM-DD`. */
  date: string
  day: number
  isCurrentMonth: boolean
}

export interface DatePickerMonth {
  year: number
  /** 1-12. */
  month: number
}

/** Every grid is six Sunday-first weeks, so the popover keeps one height all year. */
export const WEEKS_PER_GRID = 6
export const DAYS_PER_WEEK = 7

/** Breathing room between the popover and the edge of the viewport. */
export const POPOVER_VIEWPORT_MARGIN = 8
/** Gap between the field and the popover hanging off it. */
export const POPOVER_ANCHOR_GAP = 6

const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/

/**
 * True only for a `YYYY-MM-DD` string that names a real day. The round trip through the
 * calendar is what rejects overflow dates such as `2026-02-30`, which the pattern accepts.
 */
export function isIsoDate(value: string | null | undefined): value is string {
  if (!value || !ISO_DATE_PATTERN.test(value)) {
    return false
  }
  return formatDateOnly(parseDateOnly(value)) === value
}

/** Adds days without UTC or DST drift by staying in local calendar time. */
export function addDaysIso(iso: string, amount: number): string {
  const date = parseDateOnly(iso)
  date.setDate(date.getDate() + amount)
  return formatDateOnly(date)
}

/** Adds months, clamping the day to the last day of a shorter target month. */
export function addMonthsIso(iso: string, amount: number): string {
  const date = parseDateOnly(iso)
  const day = date.getDate()
  date.setDate(1)
  date.setMonth(date.getMonth() + amount)
  date.setDate(Math.min(day, daysInMonth(date.getFullYear(), date.getMonth() + 1)))
  return formatDateOnly(date)
}

export function startOfWeekIso(iso: string): string {
  return addDaysIso(iso, -parseDateOnly(iso).getDay())
}

export function endOfWeekIso(iso: string): string {
  return addDaysIso(iso, DAYS_PER_WEEK - 1 - parseDateOnly(iso).getDay())
}

export function daysInMonth(year: number, month: number): number {
  return new Date(year, month, 0).getDate()
}

export function toMonth(iso: string): DatePickerMonth {
  const date = parseDateOnly(iso)
  return { year: date.getFullYear(), month: date.getMonth() + 1 }
}

export function buildMonthGrid(year: number, month: number): DatePickerDay[] {
  const firstOfMonth = new Date(year, month - 1, 1)
  const gridStart = addDaysIso(formatDateOnly(firstOfMonth), -firstOfMonth.getDay())

  return Array.from({ length: WEEKS_PER_GRID * DAYS_PER_WEEK }, (_, index) => {
    const date = addDaysIso(gridStart, index)
    const parsed = parseDateOnly(date)
    return {
      date,
      day: parsed.getDate(),
      isCurrentMonth: parsed.getFullYear() === year && parsed.getMonth() + 1 === month,
    }
  })
}

/** ISO dates sort lexicographically, so the bounds compare as plain strings. */
export function isDateDisabled(iso: string, min?: string, max?: string): boolean {
  if (isIsoDate(min) && iso < min) {
    return true
  }
  return isIsoDate(max) && iso > max
}

export function clampIsoToRange(iso: string, min?: string, max?: string): string {
  if (isIsoDate(min) && iso < min) {
    return min
  }
  if (isIsoDate(max) && iso > max) {
    return max
  }
  return iso
}

/** How one day sits inside the previewed span; drives the continuous hotel-style block. */
export type RangeDayState = 'none' | 'start' | 'middle' | 'end' | 'single'

/**
 * The floor of a range-mode grid: the anchor the range is measured from, or the caller's `min`
 * when that is even later. Feeding it to `isDateDisabled` is what makes every day before the
 * anchor unclickable and unreachable by keyboard rather than merely invalid on submit.
 * An unusable bound normalises to `undefined` so callers can keep testing with `isIsoDate`.
 */
export function resolveRangeMin(
  min: string | undefined,
  rangeStart: string | undefined,
): string | undefined {
  const floor = isIsoDate(min) ? min : undefined
  if (!isIsoDate(rangeStart)) {
    return floor
  }
  return floor !== undefined && floor > rangeStart ? floor : rangeStart
}

/**
 * Where `date` falls in the span between the anchor and the day being previewed. The ends are
 * ordered defensively so a caller that hands over an end before the anchor still paints a span
 * rather than nothing.
 */
export function resolveRangeDayState(date: string, anchor: string, end: string): RangeDayState {
  if (!isIsoDate(anchor) || !isIsoDate(end)) {
    return 'none'
  }
  const from = anchor <= end ? anchor : end
  const to = anchor <= end ? end : anchor
  if (date < from || date > to) {
    return 'none'
  }
  if (from === to) {
    return 'single'
  }
  if (date === from) {
    return 'start'
  }
  return date === to ? 'end' : 'middle'
}

/**
 * Length of a span counting both ends, so a same-day range is 1. Compared in UTC because a span
 * containing a DST switch is not a whole number of 24-hour days in local time.
 */
export function countDaysInclusive(from: string, to: string): number {
  if (!isIsoDate(from) || !isIsoDate(to)) {
    return 0
  }
  const start = parseDateOnly(from)
  const end = parseDateOnly(to)
  const startUtc = Date.UTC(start.getFullYear(), start.getMonth(), start.getDate())
  const endUtc = Date.UTC(end.getFullYear(), end.getMonth(), end.getDate())
  return Math.abs(endUtc - startUtc) / 86_400_000 + 1
}

/**
 * The month the popover opens on: the selected day when there is one, otherwise today
 * pulled inside the bounds so an out-of-range field still opens somewhere selectable.
 */
export function resolveInitialMonth(
  modelValue: string,
  min: string | undefined,
  max: string | undefined,
  todayIso: string,
): DatePickerMonth {
  if (isIsoDate(modelValue)) {
    return toMonth(modelValue)
  }
  return toMonth(clampIsoToRange(todayIso, min, max))
}

// A month grid formats 42 accessible day labels at once, and building an Intl formatter is
// far more expensive than using one, so formatters are kept per locale + option set.
const formatterCache = new Map<string, Intl.DateTimeFormat>()

function getFormatter(locale: string, options: Intl.DateTimeFormatOptions): Intl.DateTimeFormat {
  const key = `${locale}|${JSON.stringify(options)}`
  let formatter = formatterCache.get(key)
  if (!formatter) {
    formatter = new Intl.DateTimeFormat(locale, options)
    formatterCache.set(key, formatter)
  }
  return formatter
}

function formatWith(iso: string, locale: string, options: Intl.DateTimeFormatOptions): string {
  return getFormatter(locale, options).format(parseDateOnly(iso))
}

/** Sunday-first weekday names, matching the app's calendar grid. */
export function buildWeekdayLabels(locale: string): string[] {
  const formatter = getFormatter(locale, { weekday: 'short' })
  // 2024-01-07 is a Sunday.
  return Array.from({ length: DAYS_PER_WEEK }, (_, index) =>
    formatter.format(new Date(2024, 0, 7 + index)),
  )
}

export function formatMonthLabel(year: number, month: number, locale: string): string {
  return getFormatter(locale, { year: 'numeric', month: 'long' }).format(
    new Date(year, month - 1, 1),
  )
}

/** The text on the field itself; empty for an unset or unparseable value. */
export function formatFieldValue(modelValue: string, locale: string): string {
  if (!isIsoDate(modelValue)) {
    return ''
  }
  return formatWith(modelValue, locale, { year: 'numeric', month: '2-digit', day: '2-digit' })
}

/** The accessible name of a day button, so a screen reader reads more than a bare number. */
export function formatDayLabel(iso: string, locale: string): string {
  return formatWith(iso, locale, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    weekday: 'long',
  })
}

export interface AnchorRect {
  top: number
  bottom: number
  left: number
  width: number
}

export interface PopoverSize {
  width: number
  height: number
}

export interface ViewportSize {
  width: number
  height: number
}

export interface PopoverPosition {
  top: number
  left: number
  placement: 'below' | 'above'
}

/** The widest a popover may be before it would touch the viewport edges. */
export function maxPopoverWidth(viewportWidth: number): number {
  return viewportWidth - POPOVER_VIEWPORT_MARGIN * 2
}

/**
 * Places the popover in viewport (fixed) coordinates: hanging under the field by default,
 * flipped above it when the space below is too small, and always clamped horizontally so a
 * field near the right edge of a phone cannot push the popover off screen.
 */
export function resolvePopoverPosition(
  anchor: AnchorRect,
  popover: PopoverSize,
  viewport: ViewportSize,
): PopoverPosition {
  const rightmostLeft = viewport.width - popover.width - POPOVER_VIEWPORT_MARGIN
  const left = Math.max(POPOVER_VIEWPORT_MARGIN, Math.min(anchor.left, rightmostLeft))

  const belowTop = anchor.bottom + POPOVER_ANCHOR_GAP
  const aboveTop = anchor.top - POPOVER_ANCHOR_GAP - popover.height
  const fitsBelow = belowTop + popover.height <= viewport.height - POPOVER_VIEWPORT_MARGIN
  const fitsAbove = aboveTop >= POPOVER_VIEWPORT_MARGIN

  if (!fitsBelow && fitsAbove) {
    return { top: aboveTop, left, placement: 'above' }
  }

  const lowestTop = viewport.height - POPOVER_VIEWPORT_MARGIN - popover.height
  return {
    top: Math.max(POPOVER_VIEWPORT_MARGIN, Math.min(belowTop, lowestTop)),
    left,
    placement: 'below',
  }
}
