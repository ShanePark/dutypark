import { describe, expect, it } from 'vitest'
import type { MyDutyPatternDto } from '@/types'
import {
  createDutyPatternFormState,
  DEFAULT_DUTY_PATTERN_WEEKDAYS,
  toggleDutyPatternWeekday,
} from './dutyPatternForm'

function response(overrides: Partial<MyDutyPatternDto> = {}): MyDutyPatternDto {
  return {
    configurable: true,
    reason: null,
    pattern: null,
    dutyType: { id: 1, name: '근무', color: '#123456' },
    ...overrides,
  }
}

describe('duty pattern form state', () => {
  it('preselects weekdays and holiday off without applying an unsaved pattern', () => {
    const state = createDutyPatternFormState(response())

    expect(state).toEqual({
      selectedWeekdays: ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY'],
      holidayOff: true,
    })
  })

  it('keeps a paused pattern visible instead of replacing it with defaults', () => {
    const state = createDutyPatternFormState(response({
      configurable: false,
      reason: 'SINGLE_DUTY_TYPE_REQUIRED',
      dutyType: null,
      pattern: {
        weekdays: ['FRIDAY', 'SATURDAY', 'SUNDAY'],
        holidayOff: false,
        effectiveFrom: '2026-07-11',
      },
    }))

    expect(state.selectedWeekdays).toEqual(['FRIDAY', 'SATURDAY', 'SUNDAY'])
    expect(state.holidayOff).toBe(false)
  })

  it('copies API and default arrays so form edits cannot mutate shared state', () => {
    const apiWeekdays = ['WEDNESDAY', 'THURSDAY'] as const
    const data = response({
      pattern: {
        weekdays: [...apiWeekdays],
        holidayOff: true,
        effectiveFrom: '2026-07-11',
      },
    })

    const stored = createDutyPatternFormState(data)
    stored.selectedWeekdays.push('SUNDAY')
    const freshDefault = createDutyPatternFormState(response())
    freshDefault.selectedWeekdays.pop()

    expect(data.pattern?.weekdays).toEqual(apiWeekdays)
    expect(DEFAULT_DUTY_PATTERN_WEEKDAYS).toEqual([
      'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY',
    ])
  })

  it('adds weekdays in calendar order and removes only the selected weekday', () => {
    expect(toggleDutyPatternWeekday(['FRIDAY', 'SUNDAY'], 'MONDAY')).toEqual([
      'MONDAY', 'FRIDAY', 'SUNDAY',
    ])
    expect(toggleDutyPatternWeekday(['MONDAY', 'FRIDAY', 'SUNDAY'], 'FRIDAY')).toEqual([
      'MONDAY', 'SUNDAY',
    ])
    expect(toggleDutyPatternWeekday(['MONDAY'], 'MONDAY')).toEqual([])
  })
})
