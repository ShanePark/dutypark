import { describe, expect, it } from 'vitest'
import {
  findVisibleDutyTypeNeighbor,
} from './dutyTypeVisibility'

const off = { id: null, hidden: false }

describe('duty type visibility helpers', () => {
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
