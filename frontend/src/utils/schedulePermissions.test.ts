import { describe, expect, it } from 'vitest'
import {
  canEditCalendarSchedule,
  isOwnedCalendarSchedule,
} from './schedulePermissions'

describe('schedule permissions', () => {
  it('hides edit actions from a regular visitor', () => {
    expect(canEditCalendarSchedule(false, false)).toBe(false)
  })

  it('shows edit actions to the calendar owner or a registered manager', () => {
    expect(canEditCalendarSchedule(true, false)).toBe(true)
  })

  it('does not allow editing a schedule tagged by another owner', () => {
    expect(canEditCalendarSchedule(true, true)).toBe(false)
  })

  it('marks only untagged schedules on my calendar as owned', () => {
    expect(isOwnedCalendarSchedule(true, false)).toBe(true)
    expect(isOwnedCalendarSchedule(false, false)).toBe(false)
    expect(isOwnedCalendarSchedule(true, true)).toBe(false)
  })
})
