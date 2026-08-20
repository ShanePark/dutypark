import { describe, expect, it } from 'vitest'
import {
  POPOVER_ANCHOR_GAP,
  POPOVER_VIEWPORT_MARGIN,
  addDaysIso,
  addMonthsIso,
  buildMonthGrid,
  buildWeekdayLabels,
  clampIsoToRange,
  countDaysInclusive,
  endOfWeekIso,
  formatDayLabel,
  formatFieldValue,
  formatMonthLabel,
  isDateDisabled,
  isIsoDate,
  maxPopoverWidth,
  resolveInitialMonth,
  resolvePopoverPosition,
  resolveRangeDayState,
  resolveRangeMin,
  startOfWeekIso,
} from './datePickerGrid'

describe('isIsoDate', () => {
  it('accepts a real calendar date', () => {
    expect(isIsoDate('2026-08-20')).toBe(true)
  })

  it('rejects an empty value, a wrong shape, and a day the month does not have', () => {
    expect(isIsoDate('')).toBe(false)
    expect(isIsoDate('2026-8-20')).toBe(false)
    expect(isIsoDate('2026-08-20T00:00')).toBe(false)
    // A plain regex would pass this; only a round trip through the calendar catches it.
    expect(isIsoDate('2026-02-30')).toBe(false)
    expect(isIsoDate('2026-13-01')).toBe(false)
  })
})

describe('buildMonthGrid', () => {
  it('always fills six Sunday-first weeks so the popover never changes height', () => {
    for (const [year, month] of [[2026, 2], [2026, 8], [2024, 2], [2027, 5]] as const) {
      const grid = buildMonthGrid(year, month)
      expect(grid, `${year}-${month}`).toHaveLength(42)
    }
  })

  it('starts on the Sunday on or before the first of the month', () => {
    // 2026-08-01 is a Saturday, so the grid opens on 2026-07-26.
    const grid = buildMonthGrid(2026, 8)
    expect(grid[0]).toEqual({ date: '2026-07-26', day: 26, isCurrentMonth: false })
    expect(grid[6]).toEqual({ date: '2026-08-01', day: 1, isCurrentMonth: true })
    expect(grid[41]).toEqual({ date: '2026-09-05', day: 5, isCurrentMonth: false })
  })

  it('opens on the first itself when the month already starts on a Sunday', () => {
    // 2026-02-01 is a Sunday.
    const grid = buildMonthGrid(2026, 2)
    expect(grid[0]).toEqual({ date: '2026-02-01', day: 1, isCurrentMonth: true })
  })

  it('marks exactly the days that belong to the month', () => {
    const grid = buildMonthGrid(2024, 2)
    expect(grid.filter((cell) => cell.isCurrentMonth)).toHaveLength(29)
  })

  it('walks consecutive days with no gap across a year boundary', () => {
    const grid = buildMonthGrid(2025, 12)
    for (let index = 1; index < grid.length; index += 1) {
      expect(grid[index]!.date).toBe(addDaysIso(grid[index - 1]!.date, 1))
    }
    expect(grid.some((cell) => cell.date.startsWith('2026-01'))).toBe(true)
  })
})

describe('addDaysIso', () => {
  it('crosses month and year boundaries', () => {
    expect(addDaysIso('2026-08-20', 1)).toBe('2026-08-21')
    expect(addDaysIso('2026-08-31', 1)).toBe('2026-09-01')
    expect(addDaysIso('2026-01-01', -1)).toBe('2025-12-31')
    expect(addDaysIso('2026-08-20', 7)).toBe('2026-08-27')
  })

  it('crosses a spring-forward DST boundary without losing a day', () => {
    // Local-time arithmetic on a UTC-based value drifts here in DST timezones.
    expect(addDaysIso('2026-03-08', 1)).toBe('2026-03-09')
    expect(addDaysIso('2026-11-01', 1)).toBe('2026-11-02')
  })
})

describe('addMonthsIso', () => {
  it('keeps the day of month when the target month is long enough', () => {
    expect(addMonthsIso('2026-08-20', 1)).toBe('2026-09-20')
    expect(addMonthsIso('2026-08-20', -1)).toBe('2026-07-20')
    expect(addMonthsIso('2026-12-20', 1)).toBe('2027-01-20')
  })

  it('clamps to the last day when the target month is shorter', () => {
    expect(addMonthsIso('2026-01-31', 1)).toBe('2026-02-28')
    expect(addMonthsIso('2024-01-31', 1)).toBe('2024-02-29')
    expect(addMonthsIso('2026-03-31', -1)).toBe('2026-02-28')
  })
})

describe('startOfWeekIso / endOfWeekIso', () => {
  it('snaps to the Sunday and Saturday of the same displayed week', () => {
    // 2026-08-20 is a Thursday.
    expect(startOfWeekIso('2026-08-20')).toBe('2026-08-16')
    expect(endOfWeekIso('2026-08-20')).toBe('2026-08-22')
    expect(startOfWeekIso('2026-08-16')).toBe('2026-08-16')
    expect(endOfWeekIso('2026-08-22')).toBe('2026-08-22')
  })
})

describe('isDateDisabled', () => {
  it('treats min and max as inclusive bounds', () => {
    expect(isDateDisabled('2026-08-20', '2026-08-20', '2026-08-20')).toBe(false)
    expect(isDateDisabled('2026-08-19', '2026-08-20', undefined)).toBe(true)
    expect(isDateDisabled('2026-08-21', undefined, '2026-08-20')).toBe(true)
  })

  it('ignores bounds that are absent or not real dates', () => {
    expect(isDateDisabled('2026-08-20')).toBe(false)
    expect(isDateDisabled('2026-08-20', '', '')).toBe(false)
    expect(isDateDisabled('2026-08-20', 'nonsense', 'nonsense')).toBe(false)
  })
})

describe('clampIsoToRange', () => {
  it('pulls a value inside the bounds and leaves an in-range value alone', () => {
    expect(clampIsoToRange('2026-01-01', '2026-08-01', '2026-08-31')).toBe('2026-08-01')
    expect(clampIsoToRange('2026-12-31', '2026-08-01', '2026-08-31')).toBe('2026-08-31')
    expect(clampIsoToRange('2026-08-20', '2026-08-01', '2026-08-31')).toBe('2026-08-20')
    expect(clampIsoToRange('2026-08-20')).toBe('2026-08-20')
  })
})

describe('resolveInitialMonth', () => {
  it('opens on the selected value when there is one', () => {
    expect(resolveInitialMonth('2026-03-14', undefined, undefined, '2026-08-20')).toEqual({
      year: 2026,
      month: 3,
    })
  })

  it('opens on today when the field is empty', () => {
    expect(resolveInitialMonth('', undefined, undefined, '2026-08-20')).toEqual({
      year: 2026,
      month: 8,
    })
  })

  it('opens on a reachable month when today falls outside the bounds', () => {
    expect(resolveInitialMonth('', '2027-01-10', undefined, '2026-08-20')).toEqual({
      year: 2027,
      month: 1,
    })
    expect(resolveInitialMonth('', undefined, '2025-04-02', '2026-08-20')).toEqual({
      year: 2025,
      month: 4,
    })
  })
})

describe('resolveRangeMin', () => {
  it('makes the anchor the floor when there is no other bound', () => {
    expect(resolveRangeMin(undefined, '2026-08-20')).toBe('2026-08-20')
  })

  it('keeps whichever of the anchor and min is later, so neither bound can be escaped', () => {
    expect(resolveRangeMin('2026-08-01', '2026-08-20')).toBe('2026-08-20')
    expect(resolveRangeMin('2026-09-01', '2026-08-20')).toBe('2026-09-01')
    expect(resolveRangeMin('2026-08-20', '2026-08-20')).toBe('2026-08-20')
  })

  it('falls back to the plain min when the anchor is missing or not a real date', () => {
    expect(resolveRangeMin('2026-08-01', undefined)).toBe('2026-08-01')
    expect(resolveRangeMin('2026-08-01', '')).toBe('2026-08-01')
    expect(resolveRangeMin('2026-08-01', '2026-02-30')).toBe('2026-08-01')
  })

  it('normalises an unusable bound to undefined so callers can test it with isIsoDate', () => {
    expect(resolveRangeMin(undefined, undefined)).toBeUndefined()
    expect(resolveRangeMin('nonsense', 'nonsense')).toBeUndefined()
    expect(resolveRangeMin('nonsense', '2026-08-20')).toBe('2026-08-20')
  })

  it('hard-disables every day before the anchor once fed to isDateDisabled', () => {
    const min = resolveRangeMin(undefined, '2026-08-20')
    expect(isDateDisabled('2026-08-19', min, undefined)).toBe(true)
    expect(isDateDisabled('2026-01-01', min, undefined)).toBe(true)
    expect(isDateDisabled('2026-08-20', min, undefined)).toBe(false)
    expect(isDateDisabled('2026-12-31', min, undefined)).toBe(false)
  })
})

describe('resolveRangeDayState', () => {
  const anchor = '2026-08-20'

  it('paints the span as one block: rounded ends with filled days between', () => {
    expect(resolveRangeDayState(anchor, anchor, '2026-08-24')).toBe('start')
    expect(resolveRangeDayState('2026-08-21', anchor, '2026-08-24')).toBe('middle')
    expect(resolveRangeDayState('2026-08-23', anchor, '2026-08-24')).toBe('middle')
    expect(resolveRangeDayState('2026-08-24', anchor, '2026-08-24')).toBe('end')
  })

  it('leaves everything outside the span unpainted', () => {
    expect(resolveRangeDayState('2026-08-19', anchor, '2026-08-24')).toBe('none')
    expect(resolveRangeDayState('2026-08-25', anchor, '2026-08-24')).toBe('none')
  })

  it('collapses to a single rounded cell when the span is one day', () => {
    expect(resolveRangeDayState(anchor, anchor, anchor)).toBe('single')
  })

  it('spans months and years without a gap', () => {
    expect(resolveRangeDayState('2026-08-31', anchor, '2026-09-02')).toBe('middle')
    expect(resolveRangeDayState('2026-09-01', anchor, '2026-09-02')).toBe('middle')
    expect(resolveRangeDayState('2026-12-31', '2026-12-30', '2027-01-02')).toBe('middle')
  })

  it('paints nothing while there is no anchor or no end to preview', () => {
    expect(resolveRangeDayState(anchor, '', '2026-08-24')).toBe('none')
    expect(resolveRangeDayState(anchor, anchor, '')).toBe('none')
    expect(resolveRangeDayState(anchor, 'nonsense', 'nonsense')).toBe('none')
  })

  it('still reads left to right if an end somehow lands before the anchor', () => {
    expect(resolveRangeDayState('2026-08-18', anchor, '2026-08-18')).toBe('start')
    expect(resolveRangeDayState('2026-08-19', anchor, '2026-08-18')).toBe('middle')
    expect(resolveRangeDayState(anchor, anchor, '2026-08-18')).toBe('end')
  })
})

describe('countDaysInclusive', () => {
  it('counts both ends of the span', () => {
    expect(countDaysInclusive('2026-08-20', '2026-08-20')).toBe(1)
    expect(countDaysInclusive('2026-08-20', '2026-08-21')).toBe(2)
    expect(countDaysInclusive('2026-08-20', '2026-08-24')).toBe(5)
  })

  it('counts across months, years, and leap days', () => {
    expect(countDaysInclusive('2026-08-01', '2026-09-01')).toBe(32)
    expect(countDaysInclusive('2025-12-31', '2026-01-01')).toBe(2)
    expect(countDaysInclusive('2024-02-01', '2024-03-01')).toBe(30)
  })

  it('is unaffected by DST, where a naive millisecond division is off by a day', () => {
    expect(countDaysInclusive('2026-03-07', '2026-03-09')).toBe(3)
    expect(countDaysInclusive('2026-10-31', '2026-11-02')).toBe(3)
  })

  it('is order independent and zero when either end is unusable', () => {
    expect(countDaysInclusive('2026-08-24', '2026-08-20')).toBe(5)
    expect(countDaysInclusive('', '2026-08-20')).toBe(0)
    expect(countDaysInclusive('2026-08-20', 'nonsense')).toBe(0)
  })
})

describe('locale-aware text', () => {
  it('names the weekdays Sunday first in the active locale', () => {
    expect(buildWeekdayLabels('ko')).toEqual(['일', '월', '화', '수', '목', '금', '토'])
    expect(buildWeekdayLabels('en')).toEqual(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])
  })

  it('titles the month in the active locale', () => {
    expect(formatMonthLabel(2026, 8, 'ko')).toBe('2026년 8월')
    expect(formatMonthLabel(2026, 8, 'en')).toBe('August 2026')
  })

  it('shows the field value in the active locale and nothing at all when empty', () => {
    expect(formatFieldValue('2026-08-20', 'ko')).toBe('2026. 08. 20.')
    expect(formatFieldValue('2026-08-20', 'en')).toBe('08/20/2026')
    expect(formatFieldValue('', 'ko')).toBe('')
    expect(formatFieldValue('not-a-date', 'ko')).toBe('')
  })

  it('gives each day a spoken label that includes its weekday', () => {
    expect(formatDayLabel('2026-08-20', 'en')).toContain('Thursday')
    expect(formatDayLabel('2026-08-20', 'ko')).toContain('목요일')
  })
})

describe('resolvePopoverPosition', () => {
  const popover = { width: 288, height: 320 }

  it('hangs the popover under the field, left edges aligned', () => {
    const position = resolvePopoverPosition(
      { top: 100, bottom: 140, left: 40, width: 200 },
      popover,
      { width: 1280, height: 800 },
    )
    expect(position).toEqual({ top: 140 + POPOVER_ANCHOR_GAP, left: 40, placement: 'below' })
  })

  it('flips above the field when there is no room below but there is above', () => {
    const position = resolvePopoverPosition(
      { top: 500, bottom: 540, left: 40, width: 200 },
      popover,
      { width: 1280, height: 700 },
    )
    expect(position.placement).toBe('above')
    expect(position.top).toBe(500 - POPOVER_ANCHOR_GAP - popover.height)
  })

  it('stays below when neither side fits, clamped inside the viewport', () => {
    const position = resolvePopoverPosition(
      { top: 180, bottom: 220, left: 10, width: 200 },
      popover,
      { width: 375, height: 420 },
    )
    expect(position.placement).toBe('below')
    expect(position.top).toBe(420 - POPOVER_VIEWPORT_MARGIN - popover.height)
    expect(position.top).toBeGreaterThanOrEqual(POPOVER_VIEWPORT_MARGIN)
  })

  it('never lets the popover run off either edge of a 375px viewport', () => {
    const viewport = { width: 375, height: 812 }
    const flushRight = resolvePopoverPosition(
      { top: 200, bottom: 240, left: 300, width: 60 },
      popover,
      viewport,
    )
    expect(flushRight.left).toBe(375 - popover.width - POPOVER_VIEWPORT_MARGIN)
    expect(flushRight.left + popover.width).toBeLessThanOrEqual(375 - POPOVER_VIEWPORT_MARGIN)

    const flushLeft = resolvePopoverPosition(
      { top: 200, bottom: 240, left: -20, width: 60 },
      popover,
      viewport,
    )
    expect(flushLeft.left).toBe(POPOVER_VIEWPORT_MARGIN)
  })

  it('pins to the left margin rather than going negative when the popover is wider than the viewport', () => {
    const position = resolvePopoverPosition(
      { top: 200, bottom: 240, left: 30, width: 60 },
      { width: 400, height: 320 },
      { width: 375, height: 812 },
    )
    expect(position.left).toBe(POPOVER_VIEWPORT_MARGIN)
  })
})

describe('maxPopoverWidth', () => {
  it('leaves a margin on both sides of the viewport', () => {
    expect(maxPopoverWidth(375)).toBe(375 - POPOVER_VIEWPORT_MARGIN * 2)
  })
})
