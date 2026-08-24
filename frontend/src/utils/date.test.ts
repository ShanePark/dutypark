import { describe, expect, it, vi } from 'vitest'
import {
  formatDateNumeric,
  formatDateOnly,
  formatDateRange,
  formatDateTime,
  parseDateOnly,
} from './date'

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

  it('formats date-only strings without UTC drift in numeric form', () => {
    expect(formatDateNumeric('2026-04-06')).toBe('2026/4/6')
  })

  it('omits midnight from date-only schedule ranges', () => {
    const formatted = formatDateRange('2026-08-22T00:00', '2026-08-22T00:00')

    expect(formatted).not.toContain('00:00')
    expect(formatted).toContain('2026')
  })

  it('keeps a specified start time in schedule ranges', () => {
    const start = '2026-08-22T09:30'
    const formatted = formatDateRange(start, '2026-08-22T00:00')

    expect(formatted).toBe(formatDateTime(start))
  })

  it('treats an input midnight as midnight when Intl formats it as 24:00', () => {
    const nativeDateTimeFormat = Intl.DateTimeFormat
    const dateTimeFormat = vi.spyOn(Intl, 'DateTimeFormat')

    dateTimeFormat.mockImplementation(function (locales, options) {
      if (options?.hour === '2-digit' && options.minute === '2-digit' && !options.year) {
        return { format: () => '24:00' } as unknown as Intl.DateTimeFormat
      }

      return new nativeDateTimeFormat(locales, options)
    } as typeof Intl.DateTimeFormat)

    try {
      const start = '2026-08-22T09:30'

      expect(formatDateRange(start, '2026-08-22T00:00')).toBe(formatDateTime(start))
    } finally {
      dateTimeFormat.mockRestore()
    }
  })
})
