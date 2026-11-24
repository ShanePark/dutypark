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
  const onLight = 'var(--dp-text-on-light)'
  const onDark = 'var(--dp-text-on-dark)'
  const step = (days: number) => `(100% + var(--calendar-span-start) + var(--calendar-span-end) + var(--calendar-gap)) / ${days}`
  // Seams sit in the middle of the gutter before day n; dividers cover that gutter.
  const seam = (days: number) => (n: number) => `calc(${n} * ${step(days)} - var(--calendar-span-start) - var(--calendar-gap) / 2)`
  const gutter = (days: number, n: number) => `calc(${n} * ${step(days)} - var(--calendar-span-start) - var(--calendar-gap))`
  const outline = (ink: string) => `color-mix(in srgb, ${ink} var(--calendar-span-outline-strength), transparent)`

  function bands() {
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays(null), currentYear: 2026, currentMonth: 11, spanLanes,
      getDutyColor: (day: { month: number; day: number }) => (day.month === 11 ? fills[day.day] ?? null : null),
    })))
    return findHostNodes(mounted.root, node => hasClass(node, 'calendar-span'))
  }

  function dividers(band: HostNode) {
    return findHostNodes(band, node => node.type === 'span' && hasClass(node, 'calendar-span__divider'))
  }

  // The band is opaque glass over each covered day's own tile, and each day's
  // stretch meets the next in the middle of the gutter between them. Empty
  // tiles take a theme tint (--calendar-span-empty-*), since white glass would
  // vanish on a white tile. Its rim takes the ink of the day it runs over.
  it('paints each covered day as glass over its own fill, rimmed in that day\'s ink', async () => {
    await nextTick()
    const [trip] = bands()
    const empty = 'color-mix(in srgb, var(--calendar-span-empty-tint) var(--calendar-span-empty-glass), var(--dp-calendar-cell-bg))'
    const at = seam(3)
    const stops = (colors: string[]) => `linear-gradient(to right, ${colors[0]} 0 ${at(1)}, ${colors[1]} ${at(1)} ${at(2)}, ${colors[2]} ${at(2)} 100%)`
    expect(trip!.props.style).toEqual({
      '--calendar-span-days': 3,
      '--calendar-span-fill': stops([light, dark, empty]),
      '--calendar-span-outline': stops([outline(onLight), outline(onDark), outline('var(--dp-text-primary)')]),
      // Each tag takes the ink and ring of the day it sits over; the end time
      // and chevron sit on the last day.
      '--calendar-span-ink-0': onLight,
      '--calendar-span-ink-1': onDark,
      '--calendar-span-ink-2': 'var(--dp-text-primary)',
      '--calendar-span-glass-0': light,
      '--calendar-span-glass-1': dark,
      '--calendar-span-glass-2': empty,
      // The same glass over the gutter: what a light-theme divider shows.
      '--calendar-span-gutter-glass-0': 'color-mix(in srgb, #fff 45%, var(--calendar-gutter))',
      '--calendar-span-gutter-glass-1': 'color-mix(in srgb, #fff 10%, var(--calendar-gutter))',
      '--calendar-span-gutter-glass-2': 'color-mix(in srgb, var(--calendar-span-empty-tint) var(--calendar-span-empty-glass), var(--calendar-gutter))',
      '--calendar-span-end-ink': 'var(--dp-text-primary)',
      '--calendar-span-ring': empty,
    })
  })

  it('writes the end of a dark-to-light ribbon in the light tile ink', async () => {
    await nextTick()
    const at = seam(2)
    expect(bands()[1]!.props.style).toEqual({
      '--calendar-span-days': 2,
      '--calendar-span-fill': `linear-gradient(to right, ${dark} 0 ${at(1)}, ${light} ${at(1)} 100%)`,
      '--calendar-span-outline': `linear-gradient(to right, ${outline(onDark)} 0 ${at(1)}, ${outline(onLight)} ${at(1)} 100%)`,
      '--calendar-span-ink-0': onDark,
      '--calendar-span-ink-1': onLight,
      '--calendar-span-glass-0': dark,
      '--calendar-span-glass-1': light,
      '--calendar-span-gutter-glass-0': 'color-mix(in srgb, #fff 10%, var(--calendar-gutter))',
      '--calendar-span-gutter-glass-1': 'color-mix(in srgb, #fff 45%, var(--calendar-gutter))',
      '--calendar-span-end-ink': onLight,
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

  // Each gutter the band crosses gets a divider over exactly that gutter, split
  // at the seam into each side's glass and ink (dark theme) or each side's
  // glass over the gutter (light theme).
  it('draws a divider over each gutter the band crosses', async () => {
    await nextTick()
    const [trip, mixedBand, next] = bands()
    expect(dividers(trip!).map(divider => divider.props.style)).toEqual([1, 2].map(n => ({
      left: gutter(3, n),
      '--calendar-span-before-ink': `var(--calendar-span-ink-${n - 1})`,
      '--calendar-span-before-glass': `var(--calendar-span-glass-${n - 1})`,
      '--calendar-span-after-ink': `var(--calendar-span-ink-${n})`,
      '--calendar-span-after-glass': `var(--calendar-span-glass-${n})`,
      '--calendar-span-before-gutter': `var(--calendar-span-gutter-glass-${n - 1})`,
      '--calendar-span-after-gutter': `var(--calendar-span-gutter-glass-${n})`,
    })))
    expect(dividers(trip!).every(divider => divider.props['aria-hidden'] === 'true')).toBe(true)
    expect(dividers(mixedBand!)).toHaveLength(1)
    expect(dividers(next!)).toHaveLength(0)
  })

  // Resolves a band offset as the browser would, for a band whose first cell
  // starts at 0 in a grid of equal fractional tracks.
  function resolve(expr: string, band: { width: number; start: number; end: number; gap: number }) {
    const js = expr
      .replaceAll('calc(', '(')
      .replaceAll('100%', String(band.width))
      .replaceAll('var(--calendar-span-start)', String(band.start))
      .replaceAll('var(--calendar-span-end)', String(band.end))
      .replaceAll('var(--calendar-gap)', String(band.gap))
    return Function(`return ${js}`)() as number
  }

  it.each([
    { track: 101.857142, gap: 2, start: 4, end: 4, days: 4 },
    { track: 49.6428571, gap: 2, start: 2, end: 0, days: 6 },
    { track: 177.3333, gap: 2, start: 0, end: 0, days: 7 },
  ])('lines dividers and seams up with the grid gutters ($days days over $track px tracks)', ({ track, gap, start, end, days }) => {
    // The band starts `start` into its first cell and spans its days and the gutters between them.
    const band = { width: days * track + (days - 1) * gap - start - end, start, end, gap }
    for (let n = 1; n < days; n++) {
      const gutterLeft = n * track + (n - 1) * gap
      expect(start + resolve(gutter(days, n), band)).toBeCloseTo(gutterLeft, 9)
      expect(start + resolve(seam(days)(n), band)).toBeCloseTo(gutterLeft + gap / 2, 9)
    }
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

describe('CalendarGrid pinned day content', () => {
  it('renders pinned content in the week-shared header row, above the multi-day lanes', async () => {
    const spanLanes = Array.from({ length: 35 }, (_, index) =>
      index === 1 ? [{ segment: { item: 'trip', days: 1, isStart: true, isEnd: true }, isFirstDay: true }] : [])
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays(null), currentYear: 2026, currentMonth: 11, spanLanes,
    }, {
      'day-pinned': ({ index }: { index: number }) => h('div', { class: 'pinned' }, `pinned ${index}`),
    })))
    await nextTick()
    const cell = dayCells(mounted.root)[1]!
    // The cell stays two subgrid rows: the header row and the body row.
    const rows = cell.children.filter(node => node.type === 'div')
    expect(rows.map(node => String(node.props.class))).toEqual(['calendar-day-head', 'calendar-day-body'])
    const [head, body] = rows as [HostNode, HostNode]
    expect(head.children.filter(node => node.type === 'div').map(node => String(node.props.class)))
      .toEqual(['calendar-day-top', 'pinned'])
    expect(hostText(head)).toContain('pinned 1')
    expect(findHostNodes(body, node => hasClass(node, 'pinned'))).toHaveLength(0)
    expect(findHostNodes(body, node => hasClass(node, 'calendar-span-lanes'))).toHaveLength(1)
  })
})
