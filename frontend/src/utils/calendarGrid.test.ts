import { describe, expect, it } from 'vitest'
import { getCalendarGridSlice } from './calendarGrid'

describe('calendar grid rows', () => {
  function makeDays(startYear: number, startMonth: number, startDay: number, length = 42) {
    return Array.from({ length }, (_, index) => {
      const date = new Date(startYear, startMonth - 1, startDay + index)
      return {
        year: date.getFullYear(),
        month: date.getMonth() + 1,
        day: date.getDate(),
      }
    })
  }

  it('trims trailing weeks that contain no days from the selected month', () => {
    const result = getCalendarGridSlice(makeDays(2026, 8, 30), 2026, 9)

    expect(result.startIndex).toBe(0)
    expect(result.days).toHaveLength(35)
    expect(result.days.at(-1)).toEqual({ year: 2026, month: 10, day: 3 })
  })

  it('drops the extra leading week returned for a month that starts on Sunday', () => {
    const result = getCalendarGridSlice(makeDays(2026, 1, 25), 2026, 2)

    expect(result.startIndex).toBe(7)
    expect(result.days).toHaveLength(28)
    expect(result.days[0]).toEqual({ year: 2026, month: 2, day: 1 })
    expect(result.days.at(-1)).toEqual({ year: 2026, month: 2, day: 28 })
  })

  it('keeps six rows when the month spans six weeks', () => {
    const result = getCalendarGridSlice(makeDays(2026, 7, 26), 2026, 8)

    expect(result.startIndex).toBe(0)
    expect(result.days).toHaveLength(42)
  })

  it('does not add days when the supplied month data is shorter than the grid', () => {
    const result = getCalendarGridSlice(makeDays(2026, 8, 30, 20), 2026, 9)

    expect(result.startIndex).toBe(0)
    expect(result.days).toHaveLength(20)
  })

  it('keeps the source index when a leading week is removed', () => {
    const days = makeDays(2026, 1, 25)
    const result = getCalendarGridSlice(days, 2026, 2)

    expect(result.days[0]).toBe(days[result.startIndex])
    expect(result.startIndex + result.days.length).toBe(35)
  })
})
