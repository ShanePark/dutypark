import { describe, expect, it } from 'vitest'
import { assignCalendarSpanLanes, type CalendarSpanLanes } from './calendarSpanLanes'

interface Item {
  id: string
  daysFromStart: number | null
  totalDays: number | null
}

// Lays a schedule over consecutive grid days, the way the API repeats one
// occurrence per day with its day counter.
function place(byDay: Item[][], id: string, firstDay: number, totalDays: number, fromDay = 1) {
  for (let offset = 0; fromDay + offset <= totalDays && firstDay + offset < byDay.length; offset++) {
    byDay[firstDay + offset]!.push({ id, daysFromStart: fromDay + offset, totalDays })
  }
}

function grid(days = 14): Item[][] {
  return Array.from({ length: days }, () => [])
}

// One letter per lane: the schedule id where a band starts, '-' where a band
// passes through, '.' for an empty spacer.
function picture(lanes: CalendarSpanLanes<Item>[]): string[] {
  return lanes.map(day => day.map(lane => (lane ? (lane.isFirstDay ? lane.segment.item.id : '-') : '.')).join(''))
}

describe('assignCalendarSpanLanes', () => {
  it('ignores single-day schedules and leaves days without spans empty', () => {
    const byDay = grid(7)
    byDay[2]!.push({ id: 'single', daysFromStart: 1, totalDays: 1 }, { id: 'legacy', daysFromStart: null, totalDays: null })

    expect(assignCalendarSpanLanes(byDay, item => item.id)).toEqual(Array.from({ length: 7 }, () => []))
  })

  it('draws one segment per week row with its length, true start and true end', () => {
    const byDay = grid()
    place(byDay, 'trip', 5, 4)

    const lanes = assignCalendarSpanLanes(byDay, item => item.id)

    expect(picture(lanes).slice(4, 10)).toEqual(['', 'trip', '-', 'trip', '-', ''])
    const first = lanes[5]![0]!.segment
    const second = lanes[7]![0]!.segment
    expect(first).toMatchObject({ days: 2, isStart: true, isEnd: false })
    expect(first.item.daysFromStart).toBe(1)
    expect(second).toMatchObject({ days: 2, isStart: false, isEnd: true })
    expect(second.item.daysFromStart).toBe(3)
    expect(lanes[6]![0]!.segment).toBe(first)
  })

  it('keeps each span on one lane across the row and fills the lowest free lane', () => {
    const byDay = grid(7)
    place(byDay, 'a', 0, 3)
    place(byDay, 'b', 1, 3)
    place(byDay, 'c', 3, 2)

    // 'c' starts after 'a' ends, so it reuses lane 0 while 'b' still holds lane 1.
    expect(picture(assignCalendarSpanLanes(byDay, item => item.id))).toEqual([
      'a', '-b', '--', 'c-', '-', '', '',
    ])
  })

  it('orders by true start, then longer spans, then incoming order', () => {
    const byDay = grid()
    place(byDay, 's', 8, 2)
    place(byDay, 'l', 8, 4)
    place(byDay, 'a', 10, 2)
    place(byDay, 'b', 10, 2)
    // Continues from the previous week, so it started first though it is listed last.
    place(byDay, 'e', 7, 5, 3)

    expect(picture(assignCalendarSpanLanes(byDay, item => item.id)).slice(7)).toEqual([
      'e', '-ls', '---', 'a-b', '---', '', '',
    ])
  })

  it('keeps an empty spacer under a later used lane but no trailing spacers', () => {
    const byDay = grid(7)
    place(byDay, 'a', 0, 2)
    place(byDay, 'b', 0, 4)

    const lanes = assignCalendarSpanLanes(byDay, item => item.id)

    // 'b' is longer, so it takes lane 0; day 2 keeps 'b' only and day 4 has nothing.
    expect(picture(lanes)).toEqual(['ba', '--', '-', '-', '', '', ''])
    const sparse = grid(7)
    place(sparse, 't', 0, 2)
    place(sparse, 'l', 1, 3)
    expect(picture(assignCalendarSpanLanes(sparse, item => item.id))).toEqual(['t', '-l', '.-', '.-', '', '', ''])
  })

  it('splits a span when a day in between does not carry it and skips duplicate occurrences', () => {
    const byDay = grid(7)
    place(byDay, 'g', 0, 4)
    byDay[2] = []
    byDay[0]!.push({ id: 'g', daysFromStart: 1, totalDays: 4 })

    const lanes = assignCalendarSpanLanes(byDay, item => item.id)

    expect(picture(lanes)).toEqual(['g', '-', '', 'g', '', '', ''])
    expect(lanes[0]![0]!.segment).toMatchObject({ days: 2, isStart: true, isEnd: false })
    expect(lanes[3]![0]!.segment).toMatchObject({ days: 1, isStart: false, isEnd: true })
  })

  it('uses the caller key, so separate occurrences of one id stay separate spans', () => {
    type Keyed = Item & { start: string }
    const byDay: Keyed[][] = Array.from({ length: 7 }, () => [])
    byDay[0]!.push({ id: 'x', start: 'mon', daysFromStart: 1, totalDays: 2 })
    byDay[1]!.push({ id: 'x', start: 'mon', daysFromStart: 2, totalDays: 2 })
    byDay[1]!.push({ id: 'x', start: 'tue', daysFromStart: 1, totalDays: 2 })
    byDay[2]!.push({ id: 'x', start: 'tue', daysFromStart: 2, totalDays: 2 })

    const lanes = assignCalendarSpanLanes(byDay, item => `${item.id}@${item.start}`)

    expect(lanes.slice(0, 3).map(day => day.length)).toEqual([1, 2, 2])
    expect(lanes[1]![1]!.segment.item.start).toBe('tue')
  })
})
