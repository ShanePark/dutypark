import { describe, expect, it } from 'vitest'
import { formatDateOnly, parseDateOnly } from './date'

describe('date utils', () => {
  it('formats local dates as YYYY-MM-DD without UTC conversion', () => {
    const date = new Date(2026, 3, 6, 8, 30)

    expect(formatDateOnly(date)).toBe('2026-04-06')
  })

  it('parses date-only strings at local midnight', () => {
    const date = parseDateOnly('2026-04-06')

    expect(date.getFullYear()).toBe(2026)
    expect(date.getMonth()).toBe(3)
    expect(date.getDate()).toBe(6)
    expect(date.getHours()).toBe(0)
    expect(date.getMinutes()).toBe(0)
  })
})
