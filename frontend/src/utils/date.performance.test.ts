import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createHash } from 'node:crypto'

const locale = vi.hoisted(() => ({ value: 'ko' }))
vi.mock('@/i18n', () => ({ getCurrentLocale: () => locale.value }))

import { formatDateKorean, formatDateRange, formatDateTime } from './date'

const nativeDateTimeFormat = Intl.DateTimeFormat
const dateTimeOptions = {
  year: 'numeric', month: '2-digit', day: '2-digit',
  hour: '2-digit', minute: '2-digit', hour12: false,
} as const
const originalTimezone = process.env.TZ

beforeEach(async () => {
  await Promise.resolve()
  locale.value = 'ko'
})

afterEach(() => {
  vi.restoreAllMocks()
  if (originalTimezone === undefined) delete process.env.TZ
  else process.env.TZ = originalTimezone
})

describe('date formatter reuse', () => {
  it('reuses formatters within one rendering batch', () => {
    const constructor = vi.spyOn(Intl, 'DateTimeFormat')
    for (let index = 0; index < 30; index++) {
      expect(formatDateRange('2026-09-12T09:30', '2026-09-12T17:45')).toContain('2026')
    }

    expect(constructor).toHaveBeenCalledTimes(2)
  })

  it('keeps all date styles and locale changes equivalent to native Intl formatting', () => {
    const input = '2026-09-12T09:30'
    const date = new Date(input)
    for (const language of ['ko', 'en', 'ko']) {
      locale.value = language
      const expected = new nativeDateTimeFormat(language, dateTimeOptions).format(date)
      expect(formatDateTime(input)).toBe(expected)
      expect(formatDateKorean(input)).toBe(new nativeDateTimeFormat(language, {
        year: 'numeric', month: 'long', day: 'numeric',
        hour: '2-digit', minute: '2-digit', hour12: false,
      }).format(date))
      expect(formatDateKorean('2026-09-12')).toBe(new nativeDateTimeFormat(language, {
        year: 'numeric', month: 'long', day: 'numeric',
      }).format(new Date(2026, 8, 12)))
      expect(formatDateRange('2026-09-12T00:00', '2026-09-13T00:00')).toBe(
        [12, 13].map(day => new nativeDateTimeFormat(language, {
          year: 'numeric', month: '2-digit', day: '2-digit',
        }).format(new Date(2026, 8, day))).join(' ~ '),
      )
    }
  })

  it('refreshes the default timezone after the current rendering batch', async () => {
    const constructor = vi.spyOn(Intl, 'DateTimeFormat')
    const input = '2026-09-12T00:30Z'
    process.env.TZ = 'Asia/Seoul'
    expect(formatDateTime(input)).toBe(new nativeDateTimeFormat('ko', dateTimeOptions).format(new Date(input)))
    await Promise.resolve()
    process.env.TZ = 'America/Los_Angeles'
    expect(formatDateTime(input)).toBe(new nativeDateTimeFormat('ko', dateTimeOptions).format(new Date(input)))
    expect(constructor).toHaveBeenCalledTimes(2)
  })

  it('still rejects invalid dates', () => {
    expect(() => formatDateTime('invalid')).toThrow(RangeError)
    expect(() => formatDateKorean('invalid')).toThrow(RangeError)
  })
})

it.skipIf(!process.env.DUTYPARK_PERFORMANCE_BENCHMARK)('measures the same 200 schedule rows', async () => {
  const rows = Array.from({ length: 200 }, (_, index) => {
    const day = String(index % 28 + 1).padStart(2, '0')
    return [`2026-09-${day}T09:30`, `2026-09-${day}T17:45`] as const
  })
  const renderRows = () => rows.map(([start, end]) => formatDateRange(start, end)).join('\n')
  const expected = rows.map(([start, end]) => `${
    new nativeDateTimeFormat('ko', dateTimeOptions).format(new Date(start))
  } ~ ${new nativeDateTimeFormat('ko', {
    hour: '2-digit', minute: '2-digit', hour12: false,
  }).format(new Date(end))}`).join('\n')

  await Promise.resolve()
  const constructor = vi.spyOn(Intl, 'DateTimeFormat')
  expect(renderRows()).toBe(expected)
  const constructorsPerBatch = constructor.mock.calls.length
  constructor.mockRestore()

  const samples: number[] = []
  for (let sample = 0; sample < 12; sample++) {
    await Promise.resolve()
    const start = performance.now()
    const output = renderRows()
    const elapsed = performance.now() - start
    expect(output).toBe(expected)
    if (sample >= 3) samples.push(elapsed)
  }
  samples.sort((a, b) => a - b)
  console.log(JSON.stringify({
    benchmark: 'date-formatting', rows: rows.length,
    outputSha256: createHash('sha256').update(expected).digest('hex'),
    constructorsPerBatch, samplesMs: samples, medianMs: samples[Math.floor(samples.length / 2)],
  }))
})
