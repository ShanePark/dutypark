import { describe, expect, it } from 'vitest'
import { getCalendarDayDifference } from './adminMemberDetailRelativeTime'

describe('AdminMemberDetailModal relative dates', () => {
  it('treats timestamps on the same local calendar date as today', () => {
    const referenceDate = new Date(2026, 8, 3, 23, 59)

    expect(getCalendarDayDifference('2026-09-03T00:01:00', referenceDate)).toBe(0)
  })

  it('counts the previous calendar date even when less than 24 hours have elapsed', () => {
    const referenceDate = new Date(2026, 8, 4, 0, 1)

    expect(getCalendarDayDifference('2026-09-03T23:39:00', referenceDate)).toBe(1)
  })
})
