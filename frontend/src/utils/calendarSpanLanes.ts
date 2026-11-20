interface CalendarSpanOccurrence {
  daysFromStart?: number | null
  totalDays?: number | null
}

// The part of a multi-day schedule that falls inside one week row.
export interface CalendarSpanSegment<T> {
  /** The occurrence on the segment's first day. */
  item: T
  days: number
  /** The segment holds the schedule's first day. */
  isStart: boolean
  /** The segment holds the schedule's last day; otherwise it continues past it. */
  isEnd: boolean
}

export interface CalendarSpanLane<T> {
  segment: CalendarSpanSegment<T>
  isFirstDay: boolean
}

/** One entry per lane, top first; null keeps an empty spacer above a used lane. */
export type CalendarSpanLanes<T> = Array<CalendarSpanLane<T> | null>

interface OpenSegment<T> {
  segment: CalendarSpanSegment<T>
  firstDay: number
  lastDay: number
  trueStart: number
  order: number
}

const WEEK = 7

function isMultiDay(item: CalendarSpanOccurrence): boolean {
  return (item.totalDays ?? 0) > 1
}

// Gives every multi-day schedule one lane per week row, so its days line up as a
// single band. Spans that started earlier, then longer ones, take the lowest
// lane free on all of their days in that row. Grid days are week-aligned.
export function assignCalendarSpanLanes<T extends CalendarSpanOccurrence>(
  itemsByDay: readonly (readonly T[] | null | undefined)[],
  spanKey: (item: T) => string,
): CalendarSpanLanes<T>[] {
  const lanesByDay: CalendarSpanLanes<T>[] = itemsByDay.map(() => [])

  for (let rowStart = 0; rowStart < itemsByDay.length; rowStart += WEEK) {
    const rowEnd = Math.min(rowStart + WEEK, itemsByDay.length)
    const segments: OpenSegment<T>[] = []
    const latestByKey = new Map<string, OpenSegment<T>>()

    for (let day = rowStart; day < rowEnd; day++) {
      const seen = new Set<string>()
      for (const item of itemsByDay[day] ?? []) {
        if (!isMultiDay(item)) continue
        const key = spanKey(item)
        if (seen.has(key)) continue
        seen.add(key)

        const latest = latestByKey.get(key)
        if (latest && latest.lastDay === day - 1) {
          latest.lastDay = day
          latest.segment.days++
          latest.segment.isEnd = item.daysFromStart === item.totalDays
          continue
        }
        const open: OpenSegment<T> = {
          segment: {
            item,
            days: 1,
            isStart: item.daysFromStart === 1,
            isEnd: item.daysFromStart === item.totalDays,
          },
          firstDay: day,
          lastDay: day,
          trueStart: day - ((item.daysFromStart ?? 1) - 1),
          order: segments.length,
        }
        segments.push(open)
        latestByKey.set(key, open)
      }
    }

    segments.sort((a, b) =>
      a.trueStart - b.trueStart ||
      (b.segment.item.totalDays ?? 0) - (a.segment.item.totalDays ?? 0) ||
      a.order - b.order)

    const occupied: boolean[][] = []
    for (const open of segments) {
      let lane = 0
      while (occupied[lane]?.some((taken, day) => taken && day >= open.firstDay && day <= open.lastDay)) lane++
      occupied[lane] ??= []
      for (let day = open.firstDay; day <= open.lastDay; day++) {
        occupied[lane]![day] = true
        const lanes = lanesByDay[day]!
        while (lanes.length < lane) lanes.push(null)
        lanes[lane] = { segment: open.segment, isFirstDay: day === open.firstDay }
      }
    }
  }

  return lanesByDay
}
