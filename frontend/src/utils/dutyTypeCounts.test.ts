import { describe, expect, it } from 'vitest'
import type { DutyCalendarDay } from '@/types'
import { buildDutyTypeCounts } from './dutyTypeCounts'

const selectableTypes = [
  { id: null, name: '휴무', color: null },
  { id: 1, name: '주간', color: '#ffffff' },
]

function duty(overrides: Partial<DutyCalendarDay> = {}): DutyCalendarDay {
  return {
    year: 2026,
    month: 8,
    day: 1,
    dutyTypeId: null,
    dutyType: null,
    dutyColor: null,
    isOff: true,
    source: 'DEFAULT_OFF',
    ...overrides,
  }
}

describe('duty type month counts', () => {
  it('counts visible work and all remaining calendar dates as off', () => {
    const result = buildDutyTypeCounts(selectableTypes, [
      duty({ day: 1, dutyTypeId: 1, dutyType: '주간', isOff: false }),
      duty({ day: 2, source: 'OVERRIDE' }),
    ], 2026, 8)

    expect(result).toEqual([
      { id: null, name: '휴무', color: null, cnt: 30 },
      { id: 1, name: '주간', color: '#ffffff', cnt: 1 },
    ])
  })

  it('keeps hidden historical duty types in the read-only month summary', () => {
    const result = buildDutyTypeCounts(selectableTypes, [
      duty({
        day: 3,
        dutyTypeId: 9,
        dutyType: '숨긴 야간',
        dutyColor: '#123456',
        isOff: false,
        source: 'OVERRIDE',
      }),
    ], 2026, 8)

    expect(result).toContainEqual({
      id: 9,
      name: '숨긴 야간',
      color: '#123456',
      cnt: 1,
    })
    expect(result[0]?.cnt).toBe(30)
  })

  it('ignores adjacent-month rows and de-duplicates malformed repeated dates', () => {
    const result = buildDutyTypeCounts(selectableTypes, [
      duty({ year: 2026, month: 7, day: 31, dutyTypeId: 1, dutyType: '주간', isOff: false }),
      duty({ day: 1, dutyTypeId: 1, dutyType: '주간', isOff: false }),
      duty({ day: 1, dutyTypeId: 1, dutyType: '주간', isOff: false }),
      duty({ day: 32, dutyTypeId: 1, dutyType: '주간', isOff: false }),
    ], 2026, 8)

    expect(result[0]?.cnt).toBe(30)
    expect(result[1]?.cnt).toBe(1)
  })

  it('returns no legend when the team exposes no selectable rows at all', () => {
    expect(buildDutyTypeCounts([], [duty()], 2026, 8)).toEqual([])
  })
})
