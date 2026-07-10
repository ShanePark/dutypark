import { describe, expect, it } from 'vitest'
import {
  countVisibleDutyTypes,
  findVisibleDutyTypeNeighbor,
  leavesSingleVisibleDutyType,
} from './dutyTypeVisibility'

const off = { id: null, hidden: false }

describe('duty type visibility helpers', () => {
  it('does not count the default off row or hidden duty types', () => {
    expect(countVisibleDutyTypes([
      off,
      { id: 1, hidden: false },
      { id: 2, hidden: true },
    ])).toBe(1)
  })

  it('detects only transitions away from exactly one visible duty type', () => {
    expect(leavesSingleVisibleDutyType(1, 0)).toBe(true)
    expect(leavesSingleVisibleDutyType(1, 2)).toBe(true)
    expect(leavesSingleVisibleDutyType(0, 1)).toBe(false)
    expect(leavesSingleVisibleDutyType(2, 1)).toBe(false)
  })

  it('finds the next visible duty type across hidden rows', () => {
    const types = [
      off,
      { id: 1, hidden: false },
      { id: 2, hidden: true },
      { id: 3, hidden: false },
    ]

    expect(findVisibleDutyTypeNeighbor(types, 1, 1)).toBe(3)
    expect(findVisibleDutyTypeNeighbor(types, 3, -1)).toBe(1)
    expect(findVisibleDutyTypeNeighbor(types, 1, -1)).toBeNull()
  })
})
