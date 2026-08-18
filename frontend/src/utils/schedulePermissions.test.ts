import { describe, expect, it } from 'vitest'
import {
  canReportCalendarSchedule,
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

  it('reports only schedules owned by another member', () => {
    expect(canReportCalendarSchedule(true, 1, 2)).toBe(true)
    expect(canReportCalendarSchedule(true, 1, 1)).toBe(false)
    expect(canReportCalendarSchedule(false, 1, 2)).toBe(false)
    expect(canReportCalendarSchedule(true, null, 2)).toBe(false)
    expect(canReportCalendarSchedule(true, 1, null)).toBe(false)
  })
})
