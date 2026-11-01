import { describe, expect, it } from 'vitest'
import { orderForCalendarCell } from './calendarScheduleOrder'

function item(id: string, daysFromStart: number | null, totalDays: number | null) {
  return { id, daysFromStart, totalDays }
}

describe('orderForCalendarCell', () => {
  it('lists multi-day schedules first, earliest start then latest end, then single-day ones in incoming order', () => {
    const items = [
      item('single-a', 1, 1),
      item('span-starts-today-short', 1, 2),
      item('single-b', null, null),
      item('span-started-2-days-ago', 3, 4),
      item('span-starts-today-long', 1, 5),
      item('span-started-yesterday', 2, 2),
    ]

    expect(orderForCalendarCell(items).map(entry => entry.id)).toEqual([
      'span-started-2-days-ago',
      'span-started-yesterday',
      'span-starts-today-long',
      'span-starts-today-short',
      'single-a',
      'single-b',
    ])
  })

  it('keeps incoming order for multi-day schedules with the same start and end', () => {
    const items = [item('first', 2, 3), item('second', 2, 3), item('third', 2, 3)]

    expect(orderForCalendarCell(items).map(entry => entry.id)).toEqual(['first', 'second', 'third'])
  })

  it('does not reorder the incoming array', () => {
    const items = [item('single', 1, 1), item('span', 1, 2)]

    orderForCalendarCell(items)

    expect(items.map(entry => entry.id)).toEqual(['single', 'span'])
  })
})
