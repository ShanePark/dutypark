import { describe, expect, it } from 'vitest'
import { compareDDays } from './ddaySort'

describe('compareDDays', () => {
  it('lists upcoming D-Days nearest first, then past D-Days most recent first', () => {
    const dDays = [
      { title: 'past-old', date: '2025-01-01', calc: -305 },
      { title: 'future-far', date: '2026-12-25', calc: 54 },
      { title: 'past-recent', date: '2026-10-30', calc: -3 },
      { title: 'today', date: '2026-11-01', calc: 0 },
      { title: 'future-near', date: '2026-11-02', calc: 1 },
    ]

    expect([...dDays].sort(compareDDays).map(dday => dday.title)).toEqual([
      'today',
      'future-near',
      'future-far',
      'past-recent',
      'past-old',
    ])
  })
})
