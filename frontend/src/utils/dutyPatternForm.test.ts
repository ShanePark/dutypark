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
    dutyTypes: [
      { id: 1, name: '주간', color: '#123456' },
      { id: 2, name: '야간', color: '#654321' },
    ],
    ...overrides,
  }
}

describe('duty pattern form state', () => {
  it('preselects weekdays and holiday off without applying an unsaved pattern', () => {
    const state = createDutyPatternFormState(response())

    expect(state).toEqual({
      assignments: [
        { weekday: 'MONDAY', dutyTypeId: 1 },
        { weekday: 'TUESDAY', dutyTypeId: 1 },
        { weekday: 'WEDNESDAY', dutyTypeId: 1 },
        { weekday: 'THURSDAY', dutyTypeId: 1 },
        { weekday: 'FRIDAY', dutyTypeId: 1 },
      ],
      holidayOff: true,
    })
  })

  it('keeps a paused pattern visible instead of replacing it with defaults', () => {
    const state = createDutyPatternFormState(response({
      configurable: true,
      pattern: {
        days: [
          { weekday: 'FRIDAY', dutyType: { id: 1, name: '주간', color: '#123456' } },
          { weekday: 'SATURDAY', dutyType: { id: 2, name: '야간', color: '#654321' } },
          { weekday: 'SUNDAY', dutyType: { id: 2, name: '야간', color: '#654321' } },
        ],
        holidayOff: false,
        effectiveFrom: '2026-07-11',
      },
    }))

    expect(state.assignments).toEqual([
      { weekday: 'FRIDAY', dutyTypeId: 1 },
      { weekday: 'SATURDAY', dutyTypeId: 2 },
      { weekday: 'SUNDAY', dutyTypeId: 2 },
    ])
    expect(state.holidayOff).toBe(false)
  })

  it('copies API and default arrays so form edits cannot mutate shared state', () => {
    const data = response({
      pattern: {
        days: [
          { weekday: 'WEDNESDAY', dutyType: { id: 1, name: '주간', color: '#123456' } },
          { weekday: 'THURSDAY', dutyType: { id: 2, name: '야간', color: '#654321' } },
        ],
        holidayOff: true,
        effectiveFrom: '2026-07-11',
      },
    })

    const stored = createDutyPatternFormState(data)
    stored.assignments.push({ weekday: 'SUNDAY', dutyTypeId: 1 })
    const freshDefault = createDutyPatternFormState(response())
    freshDefault.assignments.pop()

    expect(data.pattern?.days.map((day) => day.weekday)).toEqual(['WEDNESDAY', 'THURSDAY'])
    expect(DEFAULT_DUTY_PATTERN_WEEKDAYS).toEqual([
      'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY',
    ])
  })

  it('adds weekdays in calendar order and removes only the selected weekday', () => {
    expect(toggleDutyPatternWeekday([
      { weekday: 'FRIDAY', dutyTypeId: 2 },
      { weekday: 'SUNDAY', dutyTypeId: 2 },
    ], 'MONDAY', 1)).toEqual([
      { weekday: 'MONDAY', dutyTypeId: 1 },
      { weekday: 'FRIDAY', dutyTypeId: 2 },
      { weekday: 'SUNDAY', dutyTypeId: 2 },
    ])
    expect(toggleDutyPatternWeekday([
      { weekday: 'MONDAY', dutyTypeId: 1 },
      { weekday: 'FRIDAY', dutyTypeId: 2 },
      { weekday: 'SUNDAY', dutyTypeId: 2 },
    ], 'FRIDAY', 1)).toEqual([
      { weekday: 'MONDAY', dutyTypeId: 1 },
      { weekday: 'SUNDAY', dutyTypeId: 2 },
    ])
    expect(toggleDutyPatternWeekday([{ weekday: 'MONDAY', dutyTypeId: 1 }], 'MONDAY', 1)).toEqual([])
  })
})
