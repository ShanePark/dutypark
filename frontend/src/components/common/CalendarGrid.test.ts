import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { h, nextTick, ref } from 'vue'
import { createHostWrapper, findHostNodes, hostText, mountHost, triggerHost, type HostNode } from '@/test/hostRenderer'
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
  function cellsWithBorder(cell: HostNode, className: string) {
    return findHostNodes(cell, node => node.type === 'span' && hasClass(node, className))
  }

  // Today is marked by a red date strip, not a ring: only a plain white numeral
  // sits in the date row, whatever the weekday ink would be. Screen readers get
  // today from aria-current instead of a visible word.
  it('marks today with the date strip instead of a ring or a date circle', async () => {
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays({ month: 11, day: 1 }), currentYear: 2026, currentMonth: 11,
    })))
    await nextTick()
    const today = dayCells(mounted.root)[0]!
    expect(hasClass(today, 'calendar-day--today')).toBe(true)
    expect(today.props['aria-current']).toBe('date')
    expect(cellsWithBorder(today, 'calendar-day-today-border')).toHaveLength(0)
    expect(findHostNodes(today, node => hasClass(node, 'calendar-day-today-circle'))).toHaveLength(0)
    const number = findHostNodes(today, node => hasClass(node, 'calendar-day-number'))[0]!
    // Sunday ink would vanish on the red strip, so today's numeral takes the strip's ink.
    expect(number.props.style).toMatchObject({ color: 'var(--calendar-ink)' })
    expect(hostText(number)).toBe('1')
    expect(findHostNodes(today, node => hasClass(node, 'calendar-day-today-label'))).toHaveLength(0)
  })

  it('redraws the selection border above the strip when today is selected', async () => {
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays({ month: 11, day: 1 }), currentYear: 2026, currentMonth: 11,
      selectedDay: { year: 2026, month: 11, day: 1 },
    })))
    await nextTick()
    const today = dayCells(mounted.root)[0]!
    expect(hasClass(today, 'ring-dp-accent')).toBe(true)
    expect(hasClass(today, 'calendar-day--today')).toBe(true)
    expect(cellsWithBorder(today, 'calendar-day-selection-border')).toHaveLength(1)
  })

  it('leaves other selected days to the plain inset ring', async () => {
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays({ month: 11, day: 1 }), currentYear: 2026, currentMonth: 11,
      selectedDay: { year: 2026, month: 11, day: 5 },
    })))
    await nextTick()
    const cells = dayCells(mounted.root)
    expect(hasClass(cells[0]!, 'ring-dp-accent')).toBe(false)
    expect(cellsWithBorder(cells[0]!, 'calendar-day-selection-border')).toHaveLength(0)
    expect(hasClass(cells[4]!, 'ring-dp-accent')).toBe(true)
    expect(cellsWithBorder(cells[4]!, 'calendar-day-selection-border')).toHaveLength(0)
  })

  it('spotlights today without the selection border, then restores it', async () => {
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays({ month: 11, day: 1 }), currentYear: 2026, currentMonth: 11,
      highlightDay: { year: 2026, month: 11, day: 1 },
      selectedDay: { year: 2026, month: 11, day: 1 },
    })))
    await nextTick()
    const today = () => dayCells(mounted.root)[0]!
    const spotlight = findHostNodes(mounted.root, node => hasClass(node, 'calendar-grid-spotlight'))
    expect(spotlight).toHaveLength(1)
    expect(hasClass(today(), 'calendar-day--highlighted')).toBe(true)
    expect(cellsWithBorder(today(), 'calendar-day-selection-border')).toHaveLength(0)

    triggerHost(spotlight[0]!, 'onAnimationend')
    await nextTick()
    expect(hasClass(today(), 'calendar-day--highlighted')).toBe(false)
    expect(cellsWithBorder(today(), 'calendar-day-selection-border')).toHaveLength(1)
  })

  // The pin label must be a direct child of the date row so it shares today's
  // strip, right of the date.
  it('renders the day-header slot as a direct child of the date row', async () => {
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays({ month: 11, day: 1 }), currentYear: 2026, currentMonth: 11,
    }, {
      'day-header': () => h('span', { class: 'calendar-pin-label' }, 'D-3'),
    })))
    await nextTick()
    const top = findHostNodes(dayCells(mounted.root)[0]!, node => hasClass(node, 'calendar-day-top'))[0]!
    expect(top.children.filter(node => node.type === 'span').map(node => String(node.props.class)))
      .toEqual(['calendar-day-number', 'calendar-pin-label'])
  })
})

describe('CalendarGrid transient date spotlight', () => {
  function gridRoot(root: HostNode) {
    return findHostNodes(root, node => node.type === 'div' && hasClass(node, 'calendar-grid'))[0]!
  }

  // One overlay over the whole grid dims every day; the target is raised above it.
  function spotlights(root: HostNode) {
    return gridRoot(root).children.filter(node => hasClass(node, 'calendar-grid-spotlight'))
  }

  function highlightedCells(root: HostNode) {
    return dayCells(root).filter(cell => hasClass(cell, 'calendar-day--highlighted'))
  }

  async function mountHighlighted() {
    const highlightDay = ref<{ year: number; month: number; day: number } | null>({ year: 2026, month: 11, day: 12 })
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays(null), currentYear: 2026, currentMonth: 11, highlightDay: highlightDay.value,
    })))
    await nextTick()
    return { root: mounted.root, highlightDay }
  }

  it('dims the grid around the highlighted day and leaves nothing behind once the animation ends', async () => {
    const { root } = await mountHighlighted()
    expect(highlightedCells(root).map(cell => hostText(findHostNodes(cell, node => hasClass(node, 'calendar-day-number'))[0]!)))
      .toEqual(['12'])
    expect(spotlights(root)).toHaveLength(1)
    expect(spotlights(root)[0]!.props['aria-hidden']).toBe('true')
    expect(findHostNodes(root, node => hasClass(node, 'calendar-day-highlight-flash'))).toHaveLength(0)
    expect(dayCells(root).some(cell => hasClass(cell, 'highlight-pulse-glow'))).toBe(false)

    triggerHost(spotlights(root)[0]!, 'onAnimationend')
    await nextTick()
    expect(spotlights(root)).toHaveLength(0)
    expect(highlightedCells(root)).toHaveLength(0)
  })

  it('replays the spotlight when the same day is highlighted again', async () => {
    const { root, highlightDay } = await mountHighlighted()
    const first = spotlights(root)[0]!

    // Re-highlighting mid-spotlight restarts the animation on a fresh element.
    highlightDay.value = { year: 2026, month: 11, day: 12 }
    await nextTick()
    const restarted = spotlights(root)
    expect(restarted).toHaveLength(1)
    expect(restarted[0]).not.toBe(first)

    triggerHost(restarted[0]!, 'onAnimationend')
    await nextTick()
    expect(spotlights(root)).toHaveLength(0)

    highlightDay.value = { year: 2026, month: 11, day: 12 }
    await nextTick()
    expect(spotlights(root)).toHaveLength(1)
    expect(highlightedCells(root)).toHaveLength(1)
  })

  it('stops the spotlight at once when the highlight is cleared', async () => {
    const { root, highlightDay } = await mountHighlighted()
    highlightDay.value = null
    await nextTick()
    expect(spotlights(root)).toHaveLength(0)
    expect(highlightedCells(root)).toHaveLength(0)
  })

  it('does not dim the grid when the highlighted day is not on it', async () => {
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days: novemberDays(null), currentYear: 2026, currentMonth: 11, highlightDay: { year: 2027, month: 3, day: 1 },
    })))
    await nextTick()
    expect(spotlights(mounted.root)).toHaveLength(0)
  })

  describe('lighting the day through the dim', () => {
    type Rect = { left: number; top: number; width: number; height: number }

    let observers: Array<{ callback: () => void; observed: unknown[]; disconnect: ReturnType<typeof vi.fn<() => void>> }>

    beforeEach(() => {
      observers = []
      vi.stubGlobal('window', { innerHeight: 800 })
      vi.stubGlobal('ResizeObserver', class {
        record: { callback: () => void; observed: unknown[]; disconnect: ReturnType<typeof vi.fn<() => void>> }
        constructor(callback: () => void) {
          this.record = { callback, observed: [], disconnect: vi.fn<() => void>() }
          observers.push(this.record)
        }
        observe(target: unknown) { this.record.observed.push(target) }
        disconnect() { this.record.disconnect() }
      })
    })

    afterEach(() => {
      vi.unstubAllGlobals()
    })

    function boxOf(rect: Rect) {
      return { ...rect, right: rect.left + rect.width, bottom: rect.top + rect.height }
    }

    // The grid's padding box starts inside its 1px border at (101, 201).
    function startSpotlight(root: HostNode, cellRect: Rect) {
      const cell = { rect: cellRect, getBoundingClientRect: () => boxOf(cell.rect), scrollIntoView: vi.fn() }
      const querySelector = vi.fn(() => cell)
      const grid = { clientLeft: 1, clientTop: 1, getBoundingClientRect: () => boxOf({ left: 100, top: 200, width: 377, height: 500 }), querySelector }
      triggerHost(spotlights(root)[0]!, 'onAnimationstart', { currentTarget: { parentElement: grid } })
      return { cell, grid, querySelector }
    }

    function clipPath(root: HostNode) {
      return (spotlights(root)[0]!.props.style as { clipPath?: string } | undefined)?.clipPath
    }

    it('cuts the highlighted day out of the dim instead of raising it', async () => {
      const { root } = await mountHighlighted()
      expect(clipPath(root)).toBeUndefined()

      const { querySelector } = startSpotlight(root, { left: 154.5, top: 361, width: 53.5, height: 64 })
      await nextTick()
      expect(querySelector).toHaveBeenCalledWith('.calendar-day--highlighted')
      expect(clipPath(root)).toBe(
        'polygon(evenodd, 0 0, 100% 0, 100% 100%, 0 100%, 0 0, '
        + '53.5px 160px, 53.5px 224px, 107px 224px, 107px 160px, 53.5px 160px)',
      )
    })

    it('re-measures the hole when the grid or the day resizes, and stops once the spotlight ends', async () => {
      const { root } = await mountHighlighted()
      const { cell, grid } = startSpotlight(root, { left: 154.5, top: 361, width: 53.5, height: 64 })
      expect(observers).toHaveLength(1)
      expect(observers[0]!.observed).toEqual([grid, cell])

      cell.rect = { left: 201, top: 401, width: 80, height: 90 }
      observers[0]!.callback()
      await nextTick()
      expect(clipPath(root)).toContain('100px 200px, 100px 290px, 180px 290px, 180px 200px, 100px 200px)')

      triggerHost(spotlights(root)[0]!, 'onAnimationend')
      await nextTick()
      expect(observers[0]!.disconnect).toHaveBeenCalled()
      expect(spotlights(root)).toHaveLength(0)
    })

    it('stops tracking the day when the highlight is cleared or replayed', async () => {
      const { root, highlightDay } = await mountHighlighted()
      startSpotlight(root, { left: 154.5, top: 361, width: 53.5, height: 64 })
      highlightDay.value = { year: 2026, month: 11, day: 12 }
      await nextTick()
      expect(observers[0]!.disconnect).toHaveBeenCalled()
      expect(clipPath(root)).toBeUndefined()

      startSpotlight(root, { left: 154.5, top: 361, width: 53.5, height: 64 })
      highlightDay.value = null
      await nextTick()
      expect(observers[1]!.disconnect).toHaveBeenCalled()
    })

    it('scrolls an off-screen highlighted day into view as the dim starts', async () => {
      const { root } = await mountHighlighted()
      const { cell } = startSpotlight(root, { left: 154.5, top: 900, width: 53.5, height: 90 })
      expect(cell.scrollIntoView).toHaveBeenCalledWith({ behavior: 'smooth', block: 'center' })
    })

    it('leaves the page where it is when the highlighted day is already visible', async () => {
      const { root } = await mountHighlighted()
      const { cell } = startSpotlight(root, { left: 154.5, top: 300, width: 53.5, height: 90 })
      expect(cell.scrollIntoView).not.toHaveBeenCalled()
    })
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
