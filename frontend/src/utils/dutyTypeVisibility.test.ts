import { describe, expect, it } from 'vitest'
import {
  groupDutyTypesForManagement,
  findVisibleDutyTypeNeighbor,
} from './dutyTypeVisibility'

const off = { id: null, hidden: false }

describe('duty type visibility helpers', () => {
  it('keeps visible duty types first and groups hidden types at the end without changing order', () => {
    const types = [
      { id: 1, name: '주간', hidden: false },
      { id: 2, name: '예전', hidden: true },
      { id: 3, name: '야간', hidden: false },
      { id: 4, name: '중단', hidden: true },
    ]

    expect(groupDutyTypesForManagement(types).map(type => type.id)).toEqual([1, 3, 2, 4])
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

  it('never treats the default off row or hidden types as reorder targets', () => {
    const types = [
      off,
      { id: 1, hidden: true },
      { id: 2, hidden: false },
      { id: 3, hidden: true },
    ]

    expect(findVisibleDutyTypeNeighbor(types, 2, -1)).toBeNull()
    expect(findVisibleDutyTypeNeighbor(types, 2, 1)).toBeNull()
  })

  it('handles empty arrays and boundary indexes without leaking an invalid index', () => {
    expect(findVisibleDutyTypeNeighbor([], 0, 1)).toBeNull()
    expect(findVisibleDutyTypeNeighbor([off], 0, -1)).toBeNull()
    expect(findVisibleDutyTypeNeighbor([off], 0, 1)).toBeNull()
  })
})
