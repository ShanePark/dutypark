import { describe, expect, it, vi } from 'vitest'
import { h, nextTick } from 'vue'
import { createHostWrapper, findHostNodes, hostText, mountHost, type HostNode } from '@/test/hostRenderer'
import type { HolidayDto } from '@/types'

vi.mock('vue-i18n', () => ({ useI18n: () => ({ locale: { value: 'ko' }, t: (key: string) => key }) }))
const { default: CalendarGrid } = await import('./CalendarGrid.vue')

function weekdayHeaders(root: HostNode) {
  return findHostNodes(root, node => node.type === 'div' && hasClass(node, 'calendar-weekday'))
}

function dayCells(root: HostNode) {
  return findHostNodes(root, node => node.type === 'div' && hasClass(node, 'calendar-day'))
}

function hasClass(node: HostNode, className: string) {
  return String(node.props.class ?? '').split(/\s+/).includes(className)
}

// Sunday 2026-11-01 starts the month, so the grid is 35 cells from 2026-11-01.
function novemberDays(today: { month: number; day: number } | null) {
  return Array.from({ length: 35 }, (_, index) => {
    const date = new Date(2026, 10, 1 + index)
    const month = date.getMonth() + 1
    return {
      year: 2026, month, day: date.getDate(), isCurrentMonth: month === 11,
      isToday: today !== null && today.month === month && today.day === date.getDate(),
    }
  })
}

describe('CalendarGrid duty palette readability', () => {
  it.each([
    { color: '#F6D365', sunday: '#991B1B', saturday: '#1E40AF' },
    // Any duty fill looks the same in both themes, so its weekend ink is fixed too.
    { color: '#FFFFFF', sunday: '#991B1B', saturday: '#1E40AF' },
    { color: '#123456', sunday: '#FCA5A5', saturday: '#93C5FD' },
    { color: null, sunday: 'var(--dp-sunday)', saturday: 'var(--dp-saturday)' },
  ])('renders weekday dates and holidays for $color', async ({ color, sunday, saturday }) => {
    const days = Array.from({ length: 7 }, (_, index) => ({ year: 2026, month: 9, day: index + 20, isCurrentMonth: true }))
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days, currentYear: 2026, currentMonth: 9, getDutyColor: () => color,
      holidays: [[{ localDate: '2026-09-20', dateName: '공휴일', isHoliday: true } as HolidayDto]],
    })))
    await nextTick()
    const spans = findHostNodes(mounted.root, node => node.type === 'span')
    expect(spans.find(node => hostText(node) === '20')?.props.style).toMatchObject({ color: sunday })
    expect(spans.find(node => hostText(node) === '26')?.props.style).toMatchObject({ color: saturday })
    const holiday = findHostNodes(mounted.root, node => node.type === 'div' && node.props.title === '공휴일')[0]
    expect(holiday?.props.style).toMatchObject({ color: sunday })
    const headers = weekdayHeaders(mounted.root)
    expect(headers[0]?.props.style).toMatchObject({ color: 'var(--dp-sunday)' })
    expect(headers[6]?.props.style).toMatchObject({ color: 'var(--dp-saturday)' })
  })
})

describe('CalendarGrid flat month layout', () => {
  it('fills the weekday header of today only while the current month is shown', async () => {
    const thursday12 = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays({ month: 11, day: 12 }), currentYear: 2026, currentMonth: 11,
    })))
    await nextTick()
    const headers = weekdayHeaders(thursday12.root)
    expect(headers.map(header => hasClass(header, 'calendar-weekday--today'))).toEqual([false, false, false, false, true, false, false])

    const spillover = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays({ month: 12, day: 2 }), currentYear: 2026, currentMonth: 11,
    })))
    await nextTick()
    expect(weekdayHeaders(spillover.root).some(header => hasClass(header, 'calendar-weekday--today'))).toBe(false)
    expect(dayCells(spillover.root).find(cell => cell.props['aria-current'] === 'date')).toBeDefined()
  })

  it('fills in-month days with the raw duty colour and outside days with a theme-independent faded duty', async () => {
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays(null), currentYear: 2026, currentMonth: 11, getDutyColor: () => '#9DDBDE',
    })))
    await nextTick()
    const cells = dayCells(mounted.root)
    const inside = cells[0]!
    const outside = cells[34]!
    expect(inside.props.style).toMatchObject({ backgroundColor: '#9DDBDE' })
    expect(inside.props.style).not.toHaveProperty('opacity')
    expect(hasClass(outside, 'calendar-day--outside')).toBe(true)
    expect(outside.props.style).not.toMatchObject({ backgroundColor: '#9DDBDE' })
    expect(outside.props.style).not.toHaveProperty('opacity')
    // Duty tiles look the same in light and dark, so the fade is a fixed hex with fixed ink,
    // and its time chip is a tone-on-tone shade of that fade.
    expect(outside.props.style).toEqual({
      backgroundColor: '#c4e9eb', '--calendar-time-bg': '#a3d1d3', '--calendar-time-ink': '#104649',
    })
    expect(hasClass(outside, 'calendar-day--on-light')).toBe(true)
  })

  it('leaves the neutral time chip to tiles without a fill or with a fill too dark for the tone-on-tone pair', async () => {
    const empty = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays(null), currentYear: 2026, currentMonth: 11,
    })))
    const dark = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays(null), currentYear: 2026, currentMonth: 11, getDutyColor: () => '#334155',
    })))
    await nextTick()
    expect(dayCells(empty.root)[0]!.props.style).toEqual({ backgroundColor: 'var(--dp-calendar-cell-bg)' })
    expect(dayCells(dark.root)[0]!.props.style).toEqual({ backgroundColor: '#334155' })
  })
})

describe('CalendarGrid multi-day ribbons', () => {
  // A ribbon from Monday 2 Nov over a light duty, a dark duty and an empty tile,
  // one from Tuesday 10 Nov from a dark duty onto a light one, and a one-day
  // ribbon on an empty December tile.
  const fills: Record<number, string> = { 2: '#9DDBDE', 3: '#334155', 10: '#334155', 11: '#9DDBDE' }
  const segment = { item: 'trip', days: 3, isStart: true, isEnd: true }
  const mixed = { item: 'mixed', days: 2, isStart: true, isEnd: true }
  const spanLanes = Array.from({ length: 35 }, (_, index) => {
    if (index >= 1 && index <= 3) return [{ segment, isFirstDay: index === 1 }]
    if (index === 9 || index === 10) return [{ segment: mixed, isFirstDay: index === 9 }]
    if (index === 34) return [{ segment: { item: 'next', days: 1, isStart: true, isEnd: true }, isFirstDay: true }]
    return []
  })
  const light = 'color-mix(in srgb, #fff 45%, #9DDBDE)'
  const dark = 'color-mix(in srgb, #fff 10%, #334155)'
  const band = (days: number) => {
    const day = `(100% + var(--calendar-span-start) + var(--calendar-span-end) + var(--calendar-gap)) / ${days}`
    return (n: number) => `calc(${n} * ${day} - var(--calendar-span-start))`
  }

  function bands() {
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays(null), currentYear: 2026, currentMonth: 11, spanLanes,
      getDutyColor: (day: { month: number; day: number }) => (day.month === 11 ? fills[day.day] ?? null : null),
    })))
    return findHostNodes(mounted.root, node => hasClass(node, 'calendar-span'))
  }

  // The band is opaque: each day's stretch is the glass composited over that
  // day's own tile, and the gutter after a day takes that day's colour, so the
  // gutters never show through as lines. Empty tiles take a theme tint
  // (--calendar-span-empty-*), since white glass would vanish on a white tile.
  it('paints each covered day as glass over its own fill, gutters included', async () => {
    await nextTick()
    const [trip] = bands()
    const empty = 'color-mix(in srgb, var(--calendar-span-empty-tint) var(--calendar-span-empty-glass), var(--dp-calendar-cell-bg))'
    const edge = band(3)
    expect(trip!.props.style).toEqual({
      '--calendar-span-days': 3,
      '--calendar-span-fill': `linear-gradient(to right, ${light} 0 ${edge(1)}, ${dark} ${edge(1)} ${edge(2)}, ${empty} ${edge(2)} 100%)`,
      // Each tag takes the ink and ring of the day it sits over; the end time
      // and chevron sit on the last day.
      '--calendar-span-ink-0': 'var(--dp-text-on-light)',
      '--calendar-span-ink-1': 'var(--dp-text-on-dark)',
      '--calendar-span-ink-2': 'var(--dp-text-primary)',
      '--calendar-span-glass-0': light,
      '--calendar-span-glass-1': dark,
      '--calendar-span-glass-2': empty,
      '--calendar-span-end-ink': 'var(--dp-text-primary)',
      '--calendar-span-ring': empty,
    })
  })

  it('writes the end of a dark-to-light ribbon in the light tile ink', async () => {
    await nextTick()
    const edge = band(2)
    expect(bands()[1]!.props.style).toEqual({
      '--calendar-span-days': 2,
      '--calendar-span-fill': `linear-gradient(to right, ${dark} 0 ${edge(1)}, ${light} ${edge(1)} 100%)`,
      '--calendar-span-ink-0': 'var(--dp-text-on-dark)',
      '--calendar-span-ink-1': 'var(--dp-text-on-light)',
      '--calendar-span-glass-0': dark,
      '--calendar-span-glass-1': light,
      '--calendar-span-end-ink': 'var(--dp-text-on-light)',
      '--calendar-span-ring': light,
    })
  })

  it('uses the outside-month surface under an empty tile of another month', async () => {
    await nextTick()
    const next = bands()[2]!
    const outside = 'color-mix(in srgb, var(--calendar-span-empty-tint) var(--calendar-span-empty-glass), var(--calendar-surface))'
    expect(next.props.style).toMatchObject({
      '--calendar-span-fill': `linear-gradient(to right, ${outside} 0 100%)`,
      '--calendar-span-ring': outside,
    })
  })
})

describe('CalendarGrid day states', () => {
  function todayBorders(cell: HostNode) {
    return findHostNodes(cell, node => node.type === 'span' && hasClass(node, 'calendar-day-today-border'))
  }

  it('draws the selection border instead of the today border when today is selected', async () => {
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays({ month: 11, day: 1 }), currentYear: 2026, currentMonth: 11,
      selectedDay: { year: 2026, month: 11, day: 1 },
    })))
    await nextTick()
    const today = dayCells(mounted.root)[0]!
    expect(hasClass(today, 'ring-dp-accent')).toBe(true)
    expect(todayBorders(today)).toHaveLength(0)
    // Today stays identifiable by its filled date circle and label.
    expect(findHostNodes(today, node => hasClass(node, 'calendar-day-today-circle'))).toHaveLength(1)
    expect(findHostNodes(today, node => hasClass(node, 'calendar-day-today-label'))).toHaveLength(1)
  })

  it('keeps the today border while another day is selected', async () => {
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays({ month: 11, day: 1 }), currentYear: 2026, currentMonth: 11,
      selectedDay: { year: 2026, month: 11, day: 5 },
    })))
    await nextTick()
    const cells = dayCells(mounted.root)
    expect(todayBorders(cells[0]!)).toHaveLength(1)
    expect(hasClass(cells[0]!, 'ring-dp-accent')).toBe(false)
    expect(hasClass(cells[4]!, 'ring-dp-accent')).toBe(true)
  })

  it('draws the highlight border instead of the today border when today is highlighted', async () => {
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays({ month: 11, day: 1 }), currentYear: 2026, currentMonth: 11,
      highlightDay: { year: 2026, month: 11, day: 1 },
    })))
    await nextTick()
    const today = dayCells(mounted.root)[0]!
    expect(findHostNodes(today, node => hasClass(node, 'calendar-day-highlight-border'))).toHaveLength(1)
    expect(todayBorders(today)).toHaveLength(0)
  })
})
