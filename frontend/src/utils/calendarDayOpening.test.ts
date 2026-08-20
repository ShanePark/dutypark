import { describe, expect, it } from 'vitest'
import { canOpenCalendarDay } from './calendarDayOpening'

describe('opening a calendar day', () => {
  it('opens every day where I can edit, since that is how I add a schedule', () => {
    expect(canOpenCalendarDay(true, 0)).toBe(true)
    expect(canOpenCalendarDay(true, 2)).toBe(true)
  })

  it('leaves a day with no schedule shut where I cannot edit', () => {
    expect(canOpenCalendarDay(false, 0)).toBe(false)
  })

  it('opens a read-only day as soon as it holds a schedule', () => {
    expect(canOpenCalendarDay(false, 1)).toBe(true)
  })
})
