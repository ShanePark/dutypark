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
    // Duty tiles look the same in light and dark, so the fade is a fixed hex with fixed ink.
    expect(outside.props.style).toEqual({ backgroundColor: '#c4e9eb' })
    expect(hasClass(outside, 'calendar-day--on-light')).toBe(true)
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
