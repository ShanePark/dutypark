import { describe, it, expect } from 'vitest'
import {
  defaultEndDateTime,
  defaultStartTime,
  effectiveEndDateTime,
  extractDate,
  extractEndTime,
  extractTime,
  isRangeInvalid,
  joinDateTime,
} from './scheduleDateTime'

describe('scheduleDateTime', () => {
  it('treats midnight as no time', () => {
    expect(extractTime('2026-08-19T00:00')).toBeNull()
    expect(extractTime('2026-08-19T00:00:00')).toBeNull()
    expect(extractTime('2026-08-19T09:30')).toBe('09:30')
  })

  it('folds a missing time back to midnight', () => {
    expect(joinDateTime('2026-08-19', null)).toBe('2026-08-19T00:00')
    expect(joinDateTime('2026-08-19', '09:30')).toBe('2026-08-19T09:30')
  })

  it('reads an end equal to the start as no end time', () => {
    expect(extractEndTime('2026-08-19T09:00', '2026-08-19T09:00')).toBeNull()
    expect(extractEndTime('2026-08-19T18:00', '2026-08-19T09:00')).toBe('18:00')
    expect(extractEndTime('2026-08-21T00:00', '2026-08-19T09:00')).toBeNull()
  })

  it('collapses a same-day end without a time onto the start', () => {
    expect(effectiveEndDateTime('2026-08-19T22:00', '2026-08-19T00:00')).toBe('2026-08-19T22:00')
    expect(effectiveEndDateTime('2026-08-19T22:00', '2026-08-21T00:00')).toBe('2026-08-21T00:00')
    expect(effectiveEndDateTime('2026-08-19T22:00', '2026-08-19T23:30')).toBe('2026-08-19T23:30')
    expect(effectiveEndDateTime('2026-08-19T00:00', '2026-08-19T00:00')).toBe('2026-08-19T00:00')
  })

  it('keeps a start time with no end time valid, and an earlier end date invalid', () => {
    expect(isRangeInvalid('2026-08-19T22:00', '2026-08-19T00:00')).toBe(false)
    expect(isRangeInvalid('2026-08-19T22:00', '2026-08-18T00:00')).toBe(true)
    expect(isRangeInvalid('2026-08-19T22:00', '2026-08-19T21:00')).toBe(true)
  })

  it('never defaults a start time to midnight', () => {
    expect(defaultStartTime(new Date(2026, 7, 19, 9, 15))).toBe('10:00')
    expect(defaultStartTime(new Date(2026, 7, 19, 23, 40))).toBe('09:00')
  })

  it('always defaults the end to a visible time after the start', () => {
    expect(defaultEndDateTime('2026-08-19T10:00', '2026-08-19')).toBe('2026-08-19T11:00')
    // An hour later would cross midnight, which reads back as no time at all.
    expect(defaultEndDateTime('2026-08-19T23:00', '2026-08-19')).toBe('2026-08-19T23:59')
    expect(defaultEndDateTime('2026-08-19T23:30', '2026-08-20')).toBe('2026-08-20T23:59')
    // Nothing later is left on the start's own day, so the end rolls over.
    expect(defaultEndDateTime('2026-08-19T23:59', '2026-08-19')).toBe('2026-08-20T00:59')
    expect(defaultEndDateTime('2026-08-31T23:59', '2026-08-31')).toBe('2026-09-01T00:59')
  })

  it('shows an end time whenever one is added right after a start time', () => {
    const missing: string[] = []
    for (let hour = 0; hour < 24; hour++) {
      const form = { startDateTime: '2026-08-19T00:00', endDateTime: '2026-08-19T00:00' }
      form.startDateTime = joinDateTime('2026-08-19', defaultStartTime(new Date(2026, 7, 19, hour, 15)))
      form.endDateTime = defaultEndDateTime(form.startDateTime, extractDate(form.endDateTime))
      if (extractEndTime(form.endDateTime, form.startDateTime) === null) {
        missing.push(`${hour}:15 -> ${form.startDateTime} / ${form.endDateTime}`)
      }
    }
    expect(missing).toEqual([])
  })
})
