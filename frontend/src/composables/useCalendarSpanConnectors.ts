import { onMounted, onUnmounted, onUpdated, ref, useId, type Ref } from 'vue'
import { buildCalendarSpanPaths, type CalendarSpanUnderline, type CalendarSpanPath } from '@/utils/calendarSpanConnectors'

// Keep content flow intact and draw each weekly underline run as one SVG path.
export function useCalendarSpanConnectors(grid: Ref<HTMLElement | null>) {
  const gradientPrefix = `calendar-span-${useId().replace(/[^a-zA-Z0-9-]/g, '')}`
  const paths = ref<CalendarSpanPath[]>([])
  let resizeObserver: ResizeObserver | undefined
  let themeObserver: MutationObserver | undefined
  let frame: number | undefined
  let observedItems = new Set<HTMLElement>()
  let lastGeometry = ''

  function measure() {
    frame = undefined
    const root = grid.value
    // The lightweight unit-test renderer has no browser layout API.
    if (!root?.querySelectorAll) return
    const svg = root.querySelector<SVGSVGElement>('.calendar-span-connectors')
    if (!svg) return
    const matrix = svg.getScreenCTM()
    if (!matrix) return
    // Screen CTM includes fractional borders, browser/CSS zoom, and the month
    // swipe transform; clientLeft/clientTop round fractional border widths.
    const localX = (x: number) => (x - matrix.e) / matrix.a
    const localY = (y: number) => (y - matrix.f) / matrix.d
    const items: HTMLElement[] = []
    const anchors: CalendarSpanUnderline[] = []
    const cells = root.querySelectorAll<HTMLElement>('.calendar-day')
    cells.forEach((cell, day) => {
      const cellRect = cell.getBoundingClientRect()
      const cellStyle = getComputedStyle(cell)
      cell.querySelectorAll<HTMLElement>('.calendar-item--span[data-calendar-span-key]').forEach(item => {
        const itemRect = item.getBoundingClientRect()
        const itemStyle = getComputedStyle(item)
        const line = getComputedStyle(item, '::after')
        const thickness = Number.parseFloat(line.height)
        if (!itemRect.width || !Number.isFinite(thickness)) return
        items.push(item)
        anchors.push({
          day, key: item.dataset.calendarSpanKey!, part: Number(item.dataset.calendarSpanPart),
          left: localX(cellRect.left), right: localX(cellRect.right),
          barLeft: localX(itemRect.left) + (Number.parseFloat(itemStyle.borderLeftWidth) || 0) + Number.parseFloat(line.left),
          barRight: localX(itemRect.right) - (Number.parseFloat(itemStyle.borderRightWidth) || 0) - Number.parseFloat(line.right),
          y: localY(itemRect.bottom) - (Number.parseFloat(itemStyle.borderBottomWidth) || 0)
            - (Number.parseFloat(line.bottom) || 0) - thickness / 2,
          starts: item.classList.contains('calendar-item--span-start'),
          ends: item.classList.contains('calendar-item--span-end'),
          color: line.backgroundColor, thickness,
          paddingLeft: Number.parseFloat(cellStyle.paddingLeft) || 0,
          paddingRight: Number.parseFloat(cellStyle.paddingRight) || 0,
        })
      })
    })
    const next = buildCalendarSpanPaths(anchors)
    for (const item of observedItems) {
      if (!items.includes(item)) item.style.removeProperty('--calendar-span-visibility')
    }
    for (const item of items) item.style.setProperty('--calendar-span-visibility', 'hidden')
    if (resizeObserver) {
      for (const item of observedItems) if (!items.includes(item)) resizeObserver.unobserve(item)
      for (const item of items) if (!observedItems.has(item)) resizeObserver.observe(item)
    }
    observedItems = new Set(items)
    const geometry = JSON.stringify(next)
    // SVG updates run this component's update hook too.
    if (geometry !== lastGeometry) {
      lastGeometry = geometry
      paths.value = next
    }
  }

  function scheduleMeasure() {
    if (frame === undefined && typeof requestAnimationFrame !== 'undefined') frame = requestAnimationFrame(measure)
  }

  onMounted(() => {
    if (!grid.value?.querySelectorAll) return
    if (typeof ResizeObserver !== 'undefined') {
      resizeObserver = new ResizeObserver(scheduleMeasure)
      resizeObserver.observe(grid.value)
    }
    // Theme changes may alter resolved ink without resizing the calendar.
    if (typeof MutationObserver !== 'undefined') {
      themeObserver = new MutationObserver(scheduleMeasure)
      themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['class', 'style'] })
    }
    scheduleMeasure()
  })
  onUpdated(scheduleMeasure)
  onUnmounted(() => {
    resizeObserver?.disconnect()
    themeObserver?.disconnect()
    if (frame !== undefined) cancelAnimationFrame(frame)
  })
  return { paths, gradientPrefix }
}
