import { describe, expect, it } from 'vitest'
import {
  CALENDAR_SPAN_TITLE_MIN_CHARS,
  calendarSpanCompactMore,
  calendarSpanDayAt,
  calendarSpanTitleFloor,
  fitCalendarSpanTags,
  type CalendarSpanTagFitInput,
} from './calendarSpanTagFit'

// Seven 50px chips, 18px avatars overlapping by 5px, a 24px "+N" pill, a 30px
// compact pill and a 22px lone avatar whose "+N" badge overhangs it by 4px,
// 2px apart. Only `available` changes between most cases.
function input(overrides: Partial<CalendarSpanTagFitInput> = {}): CalendarSpanTagFitInput {
  return {
    available: 1000,
    titleMin: 40,
    chipWidths: Array.from({ length: 7 }, () => 50),
    avatarSize: 18,
    avatarStep: 13,
    moreWidth: 24,
    compactWidth: 30,
    loneWidth: 22,
    gap: 2,
    scale: 'pc',
    ...overrides,
  }
}

describe('fitCalendarSpanTags', () => {
  it('shows nothing for a schedule without display tags', () => {
    expect(fitCalendarSpanTags(input({ chipWidths: [] }))).toEqual({ level: 'none', shown: 0 })
  })

  it('shows every name chip when they all fit next to the title minimum', () => {
    // 7 chips + 6 gaps = 362, plus the 40px title minimum.
    expect(fitCalendarSpanTags(input({ available: 402 }))).toEqual({ level: 'chips', shown: 7 })
  })

  it('shows as many name chips as fit, then a "+N" pill for the rest', () => {
    // 7 chips need 402; 3 chips + "+4" need 3*50 + 2*2 + 2 + 24 = 180 (+40 title).
    expect(fitCalendarSpanTags(input({ available: 401 }))).toEqual({ level: 'chips', shown: 6 })
    expect(fitCalendarSpanTags(input({ available: 220 }))).toEqual({ level: 'chips', shown: 3 })
    expect(fitCalendarSpanTags(input({ available: 219 }))).toEqual({ level: 'chips', shown: 2 })
  })

  it('keeps the title minimum out of the tag space', () => {
    expect(fitCalendarSpanTags(input({ available: 402, titleMin: 41 }))).toEqual({ level: 'chips', shown: 6 })
  })

  it('falls back to an avatar stack capped at 3 on PC and 2 on mobile', () => {
    // 1 chip + "+6" needs 50 + 2 + 24 = 76; 3 avatars + "+4" need 18 + 2*13 + 2 + 24 = 70.
    expect(fitCalendarSpanTags(input({ available: 40 + 75 }))).toEqual({ level: 'avatars', shown: 3 })
    expect(fitCalendarSpanTags(input({ available: 40 + 75, scale: 'mobile' }))).toEqual({ level: 'avatars', shown: 2 })
  })

  it('drops avatars before giving up on the stack', () => {
    // 2 avatars + "+5" need 18 + 13 + 2 + 24 = 57; 1 avatar + "+6" needs 44.
    expect(fitCalendarSpanTags(input({ available: 40 + 69 }))).toEqual({ level: 'avatars', shown: 2 })
    expect(fitCalendarSpanTags(input({ available: 40 + 44 }))).toEqual({ level: 'avatars', shown: 1 })
  })

  it('shows the compact pill when not even one avatar and its "+N" fit', () => {
    expect(fitCalendarSpanTags(input({ available: 40 + 43 }))).toEqual({ level: 'compact', shown: 1 })
    expect(fitCalendarSpanTags(input({ available: 40 + 30 }))).toEqual({ level: 'compact', shown: 1 })
  })

  // A tagged schedule always shows at least one face.
  it('shows the first avatar alone when not even the compact pill fits beside the title floor', () => {
    expect(fitCalendarSpanTags(input({ available: 40 + 29 }))).toEqual({ level: 'lone', shown: 1 })
    expect(fitCalendarSpanTags(input({ available: 40 + 18 }))).toEqual({ level: 'lone', shown: 1 })
  })

  // Below the title floor the avatar wins: the title is cut to fewer
  // characters, down to one character and then to just its ellipsis.
  it('keeps the lone avatar while the title gives way below its floor', () => {
    expect(fitCalendarSpanTags(input({ available: 40 + 17 }))).toEqual({ level: 'lone', shown: 1 })
    expect(fitCalendarSpanTags(input({ available: 10 + 18, titleMin: 40 }))).toEqual({ level: 'lone', shown: 1 })
    expect(fitCalendarSpanTags(input({ available: 22 }))).toEqual({ level: 'lone', shown: 1 })
  })

  // The lone avatar's "+N" badge overhangs it, and that overhang needs room too.
  it('counts the lone badge overhang in the lone width', () => {
    expect(fitCalendarSpanTags(input({ available: 21 }))).toEqual({ level: 'none', shown: 0 })
    expect(fitCalendarSpanTags(input({ available: 18, chipWidths: [50], loneWidth: 18 })))
      .toEqual({ level: 'lone', shown: 1 })
  })

  it('hides the tags only when the band cannot hold even one avatar', () => {
    expect(fitCalendarSpanTags(input({ available: 17 }))).toEqual({ level: 'none', shown: 0 })
    expect(fitCalendarSpanTags(input({ available: 17, chipWidths: [50], loneWidth: 18 })))
      .toEqual({ level: 'none', shown: 0 })
  })

  it('needs no "+N" pill when every tag is shown', () => {
    // One 50px chip fits without a pill; its avatar alone fits in 18.
    expect(fitCalendarSpanTags(input({ chipWidths: [50], available: 40 + 50 }))).toEqual({ level: 'chips', shown: 1 })
    expect(fitCalendarSpanTags(input({ chipWidths: [50], available: 40 + 18 }))).toEqual({ level: 'avatars', shown: 1 })
    // Two avatars without a pill: 18 + 13.
    expect(fitCalendarSpanTags(input({ chipWidths: [50, 50], available: 40 + 31, scale: 'mobile' })))
      .toEqual({ level: 'avatars', shown: 2 })
  })

  it('uses each chip at its own measured width', () => {
    expect(fitCalendarSpanTags(input({ chipWidths: [30, 80, 30], available: 40 + 30 + 2 + 24 })))
      .toEqual({ level: 'chips', shown: 1 })
    expect(fitCalendarSpanTags(input({ chipWidths: [30, 80, 30], available: 40 + 144 })))
      .toEqual({ level: 'chips', shown: 3 })
  })

  it('keeps about four title characters on PC and two on mobile', () => {
    expect(CALENDAR_SPAN_TITLE_MIN_CHARS).toEqual({ pc: 4, mobile: 2 })
  })
})

describe('calendarSpanTitleFloor', () => {
  it('keeps a title no longer than the floor whole', () => {
    expect(calendarSpanTitleFloor('제주', 'mobile')).toBe('제주')
    expect(calendarSpanTitleFloor('제주 여행', 'pc')).toBe('제주 여행')
  })

  // A cut title is drawn with an ellipsis, so the floor must hold one too, or
  // a mobile "제주 2박 3일" would shrink to "제…".
  it('measures a longer title as its first characters plus the ellipsis', () => {
    expect(calendarSpanTitleFloor('제주 2박 3일', 'mobile')).toBe('제주…')
    expect(calendarSpanTitleFloor('아주 긴 제목의 워크숍', 'pc')).toBe('아주 긴 제…')
  })

  it('does not count whitespace toward the floor', () => {
    expect(calendarSpanTitleFloor(' 가 나 다', 'mobile')).toBe('가 나…')
    expect(calendarSpanTitleFloor('가 나 ', 'mobile')).toBe('가 나')
  })
})

describe('calendarSpanDayAt', () => {
  // A 3-day band inset 2px at both ends over 2px gutters: one day plus its
  // gutter is (300 + 2 + 2 + 2) / 3 = 102px, so day 1 starts 100px in.
  const band = { width: 300, start: 2, end: 2, gap: 2, days: 3 }

  it('finds the covered day under a point of the band', () => {
    expect(calendarSpanDayAt(0, band)).toBe(0)
    expect(calendarSpanDayAt(99.9, band)).toBe(0)
    expect(calendarSpanDayAt(100, band)).toBe(1)
    expect(calendarSpanDayAt(299, band)).toBe(2)
  })

  it('keeps points outside the band on its first or last day', () => {
    expect(calendarSpanDayAt(-5, band)).toBe(0)
    expect(calendarSpanDayAt(400, band)).toBe(2)
  })
})

// The compact pill holds the first member's avatar and "+N" for everyone else.
describe('calendarSpanCompactMore', () => {
  it('counts the members behind the first avatar', () => {
    expect(calendarSpanCompactMore(4)).toBe('+3')
    expect(calendarSpanCompactMore(2)).toBe('+1')
  })

  it('leaves a lone member as just the avatar, never "+0"', () => {
    expect(calendarSpanCompactMore(1)).toBe('')
  })
})
