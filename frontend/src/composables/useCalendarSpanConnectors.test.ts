import { afterEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h, nextTick, ref, shallowRef } from 'vue'
import { mountHost } from '@/test/hostRenderer'
import { useCalendarSpanConnectors } from './useCalendarSpanConnectors'

const apps: Array<ReturnType<typeof mountHost>['app']> = []
afterEach(() => {
  apps.splice(0).forEach(app => app.unmount())
  vi.unstubAllGlobals()
})

function fixture() {
  let queued: FrameRequestCallback | undefined
  let resized = () => {}
  let themeChanged = () => {}
  let bottom = 70
  let color = '#123456'
  let borderBottom = '0px'
  let matrix = { a: 1, d: 1, e: 0, f: 0 }
  let secondDayVisible = true
  const disconnectResize = vi.fn()
  const disconnectTheme = vi.fn()
  const cancel = vi.fn()
  vi.stubGlobal('requestAnimationFrame', vi.fn((callback: FrameRequestCallback) => { queued = callback; return 1 }))
  vi.stubGlobal('cancelAnimationFrame', cancel)
  vi.stubGlobal('ResizeObserver', class {
    constructor(callback: () => void) { resized = callback }
    observe() {}
    unobserve() {}
    disconnect = disconnectResize
  })
  vi.stubGlobal('MutationObserver', class {
    constructor(callback: () => void) { themeChanged = callback }
    observe() {}
    disconnect = disconnectTheme
  })
  vi.stubGlobal('document', { documentElement: {} })
  vi.stubGlobal('getComputedStyle', (_target: unknown, pseudo?: string) => pseudo
    ? { height: '3px', backgroundColor: color, left: '-8px', right: '-8px', bottom: '0px' }
    : { paddingLeft: '8px', paddingRight: '8px', borderBottomWidth: borderBottom, borderLeftWidth: '0px', borderRightWidth: '0px' })
  const items = [0, 1].map(index => ({
    classList: { contains: () => false },
    dataset: { calendarSpanKey: 'schedule', calendarSpanPart: String(index + 1) },
    style: { setProperty: vi.fn(), removeProperty: vi.fn() },
    getBoundingClientRect: () => ({ width: 84, left: index * 102 + 8, right: index * 102 + 92, bottom: index ? bottom : 50 }),
  }))
  const cells = items.map((item, index) => ({
    getBoundingClientRect: () => ({ left: index * 102, right: index * 102 + 100 }),
    querySelectorAll: () => index && !secondDayVisible ? [] : [item],
  }))
  const grid = {
    clientLeft: 0, clientTop: 0,
    getBoundingClientRect: () => ({ left: 0, top: 0 }),
    querySelectorAll: () => cells,
    querySelector: () => ({ getScreenCTM: () => matrix }),
  } as unknown as HTMLElement
  const tick = ref(0)
  let result!: ReturnType<typeof useCalendarSpanConnectors>
  const app = mountHost(defineComponent({ setup() {
    result = useCalendarSpanConnectors(shallowRef(grid))
    return () => h('div', { 'data-path': result.paths.value[0]?.path, 'data-tick': tick.value })
  } }))
  apps.push(app.app)
  return {
    result, items, tick, cancel, disconnectResize, disconnectTheme,
    resize: () => resized(), theme: () => themeChanged(),
    setBorderBottom: (value: string) => { borderBottom = value },
    setMatrix: (value: typeof matrix) => { matrix = value },
    setBottom: (value: number) => { bottom = value },
    setColor: (value: string) => { color = value },
    hideSecondDay: () => { secondDayVisible = false },
    flush: () => { const callback = queued; queued = undefined; callback?.(0) },
    hasQueuedFrame: () => !!queued,
  }
}

describe('calendar span connector lifecycle', () => {
  it('uses the SVG fractional screen transform and the pseudo padding-box bottom', async () => {
    const f = fixture()
    f.setBorderBottom('1px')
    f.setMatrix({ a: 1.25, d: 1.25, e: 0.375, f: 0.625 })
    f.flush()
    await nextTick()
    // The CSS line sits inside the border; SVG coordinates undo zoom/translation.
    expect(f.result.paths.value[0]?.path).toContain('37')
    expect(f.result.paths.value[0]?.path).toContain('53')
  })

  it('remeasures wrapped contents and theme colors without continually updating SVG state', async () => {
    const f = fixture()
    f.flush()
    await nextTick()
    const first = f.result.paths.value
    expect(first[0]?.path).toContain('48.5')
    expect(first[0]?.path).toContain('68.5')
    f.flush()
    await nextTick()
    expect(f.result.paths.value).toBe(first)
    expect(f.hasQueuedFrame()).toBe(false)

    f.setBottom(100)
    f.resize()
    f.flush()
    await nextTick()
    expect(f.result.paths.value[0]?.path).toContain('98.5')
    f.setColor('#ffffff')
    f.theme()
    f.flush()
    await nextTick()
    expect(f.result.paths.value[0]?.stops.at(-1)?.color).toBe('#ffffff')
    expect(f.items[0]?.style.setProperty).toHaveBeenCalledWith('--calendar-span-visibility', 'hidden')
  })

  it('removes stale endpoint insets after content updates and disconnects observers on unmount', async () => {
    const f = fixture()
    f.flush()
    await nextTick()
    f.hideSecondDay()
    f.tick.value++
    await nextTick()
    f.flush()
    await nextTick()
    expect(f.result.paths.value).toHaveLength(1)
    expect(f.items[1]?.style.removeProperty).toHaveBeenCalledWith('--calendar-span-visibility')
    apps.pop()!.unmount()
    expect(f.disconnectResize).toHaveBeenCalledOnce()
    expect(f.disconnectTheme).toHaveBeenCalledOnce()
    expect(f.cancel).toHaveBeenCalled()
  })
})
