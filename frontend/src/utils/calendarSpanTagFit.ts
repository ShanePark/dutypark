export type CalendarSpanTagScale = 'pc' | 'mobile'

/**
 * Richest first: name chips, an avatar stack, one pill with the first avatar
 * and "+N", or the first avatar alone with a tiny "+N" badge on it. 'none'
 * means no tags or no room at all.
 */
export type CalendarSpanTagLevel = 'chips' | 'avatars' | 'compact' | 'lone' | 'none'

export interface CalendarSpanTagFitInput {
  /** Width the title and the tag cluster share once the times, chevron and gaps are placed. */
  available: number
  /** Width the title keeps before any tag but the lone avatar is shown. */
  titleMin: number
  /** Measured name-chip widths in display order; one per tag. */
  chipWidths: readonly number[]
  avatarSize: number
  /** Distance from one stacked avatar to the next: its size minus the overlap. */
  avatarStep: number
  /** Width of the "+N" pill, measured for the largest N. */
  moreWidth: number
  /** Width of the compact pill: the first member's avatar and "+N" for the rest. */
  compactWidth: number
  /** Width of the lone avatar, with the overhang of its "+N" badge when there is one. */
  loneWidth: number
  /** Space between items inside the cluster. */
  gap: number
  scale: CalendarSpanTagScale
}

export interface CalendarSpanTagFit {
  level: CalendarSpanTagLevel
  /** Chips or avatars drawn; the rest go into "+N". */
  shown: number
}

export const CALENDAR_SPAN_TITLE_MIN_CHARS: Record<CalendarSpanTagScale, number> = { pc: 4, mobile: 2 }
// The shortest the title is drawn beside tags: its first few characters, not
// counting whitespace, plus the ellipsis it is cut with, or all of it if shorter.
export function calendarSpanTitleFloor(title: string, scale: CalendarSpanTagScale): string {
  const chars = Array.from(title.trim())
  let counted = 0
  for (let index = 0; index < chars.length; index++) {
    if (/\s/.test(chars[index]!)) continue
    counted++
    if (counted === CALENDAR_SPAN_TITLE_MIN_CHARS[scale] && index < chars.length - 1) {
      return `${chars.slice(0, index + 1).join('')}…`
    }
  }
  return chars.join('')
}

/** The "+N" beside the compact pill's avatar; empty for a lone member. */
export function calendarSpanCompactMore(total: number): string {
  return total > 1 ? `+${total - 1}` : ''
}

export interface CalendarSpanBand {
  width: number
  /** Insets at the band's rounded start and end. */
  start: number
  end: number
  /** Gutter between days. */
  gap: number
  days: number
}

// The covered day under a point `x` px from the band's left edge. A gutter
// counts as the day before it, as the band paints it (CalendarGrid getSpanStyle).
export function calendarSpanDayAt(x: number, band: CalendarSpanBand): number {
  const step = (band.width + band.start + band.end + band.gap) / band.days
  return Math.min(band.days - 1, Math.max(0, Math.floor((x + band.start) / step)))
}

const MAX_STACKED_AVATARS: Record<CalendarSpanTagScale, number> = { pc: 3, mobile: 2 }

// Picks the richest tag level that fits beside the title's minimum width.
export function fitCalendarSpanTags(input: CalendarSpanTagFitInput): CalendarSpanTagFit {
  const { chipWidths, gap } = input
  const total = chipWidths.length
  const space = input.available - input.titleMin
  if (total === 0) return { level: 'none', shown: 0 }

  const withMore = (width: number, shown: number) => (shown < total ? width + gap + input.moreWidth : width)

  // Any count short of the total also needs a "+N" pill, so keep the largest count that fits.
  let chipsShown = 0
  let chipsWidth = 0
  for (let shown = 1; shown <= total; shown++) {
    chipsWidth += chipWidths[shown - 1]! + (shown > 1 ? gap : 0)
    if (withMore(chipsWidth, shown) <= space) chipsShown = shown
  }
  if (chipsShown > 0) return { level: 'chips', shown: chipsShown }

  for (let shown = Math.min(MAX_STACKED_AVATARS[input.scale], total); shown >= 1; shown--) {
    if (withMore(input.avatarSize + (shown - 1) * input.avatarStep, shown) <= space) {
      return { level: 'avatars', shown }
    }
  }

  if (input.compactWidth <= space) return { level: 'compact', shown: 1 }
  // A tagged schedule always shows one face: below the floor the title is cut
  // further, to one character and then to just its ellipsis.
  return input.loneWidth <= input.available ? { level: 'lone', shown: 1 } : { level: 'none', shown: 0 }
}
