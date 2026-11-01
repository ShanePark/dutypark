import { effectScope } from 'vue'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import {
  MONTH_SLIDE_OUT_MS,
  MONTH_SWIPE_MAX_FOLLOW,
  MONTH_SWIPE_THRESHOLD,
  monthSwipeFollowOffset,
  resolveMonthSwipe,
  useCalendarMonthSwipe,
} from './useCalendarMonthSwipe'
import dutyCalendarContent from '@/components/duty/DutyCalendarContent.vue?raw'
import dutyView from '@/views/duty/DutyView.vue?raw'
import teamView from '@/views/team/TeamView.vue?raw'

function touchEvent(x: number, y: number) {
  const touch = { clientX: x, clientY: y }
  return {
    touches: [touch],
    changedTouches: [touch],
    stopPropagation: vi.fn(),
  } as unknown as TouchEvent
}

describe('resolveMonthSwipe', () => {
  it('reads a left-to-right swipe as the previous month and the reverse as the next one', () => {
    expect(resolveMonthSwipe(MONTH_SWIPE_THRESHOLD, 0)).toBe(-1)
    expect(resolveMonthSwipe(-MONTH_SWIPE_THRESHOLD, 0)).toBe(1)
  })

  it('keeps the month for a drag that is too short', () => {
    expect(resolveMonthSwipe(MONTH_SWIPE_THRESHOLD - 1, 0)).toBe(0)
    expect(resolveMonthSwipe(0, 0)).toBe(0)
  })

  it('keeps the month for a vertical scroll that drifts sideways', () => {
    const travel = MONTH_SWIPE_THRESHOLD + 20
    expect(resolveMonthSwipe(travel, travel)).toBe(0)
    expect(resolveMonthSwipe(-travel, travel)).toBe(0)
  })
})

describe('monthSwipeFollowOffset', () => {
  it('damps the travel and never passes the follow limit', () => {
    expect(monthSwipeFollowOffset(0, 0)).toBe(0)

    const short = monthSwipeFollowOffset(10, 0)
    expect(short).toBeGreaterThan(0)
    expect(short).toBeLessThan(10)

    const long = monthSwipeFollowOffset(1000, 0)
    expect(long).toBeLessThanOrEqual(MONTH_SWIPE_MAX_FOLLOW)
    expect(long).toBeGreaterThan(MONTH_SWIPE_MAX_FOLLOW * 0.9)
    expect(monthSwipeFollowOffset(-1000, 0)).toBeCloseTo(-long)
  })

  it('leaves the calendar in place while the drag is mostly vertical', () => {
    expect(monthSwipeFollowOffset(20, 40)).toBe(0)
  })
})

describe('useCalendarMonthSwipe', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.stubGlobal('requestAnimationFrame', (callback: FrameRequestCallback) =>
      setTimeout(() => callback(0), 16) as unknown as number
    )
    vi.stubGlobal('cancelAnimationFrame', (handle: number) =>
      clearTimeout(handle as unknown as ReturnType<typeof setTimeout>)
    )
  })

  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  function mountSwipe() {
    const onPrevMonth = vi.fn()
    const onNextMonth = vi.fn()
    const scope = effectScope()
    const swipe = scope.run(() =>
      useCalendarMonthSwipe({ onPrevMonth, onNextMonth, getWidth: () => 360 })
    )!
    return { swipe, scope, onPrevMonth, onNextMonth }
  }

  it('moves to the next month once the calendar has slid out to the left', () => {
    const { swipe, scope, onPrevMonth, onNextMonth } = mountSwipe()

    swipe.handleTouchStart(touchEvent(300, 200))
    swipe.handleTouchMove(touchEvent(240, 205))
    expect(swipe.offset.value).toBeLessThan(0)

    swipe.handleTouchEnd(touchEvent(300 - MONTH_SWIPE_THRESHOLD - 10, 205))
    expect(onNextMonth).not.toHaveBeenCalled()

    vi.advanceTimersByTime(MONTH_SLIDE_OUT_MS)
    expect(onNextMonth).toHaveBeenCalledOnce()
    expect(onPrevMonth).not.toHaveBeenCalled()

    scope.stop()
  })

  it('moves to the previous month when the finger travels the other way', () => {
    const { swipe, scope, onPrevMonth, onNextMonth } = mountSwipe()

    swipe.handleTouchStart(touchEvent(100, 200))
    swipe.handleTouchEnd(touchEvent(100 + MONTH_SWIPE_THRESHOLD + 10, 205))
    vi.advanceTimersByTime(MONTH_SLIDE_OUT_MS)

    expect(onPrevMonth).toHaveBeenCalledOnce()
    expect(onNextMonth).not.toHaveBeenCalled()

    scope.stop()
  })

  it('leaves the month alone for a vertical scroll and puts the calendar back', () => {
    const { swipe, scope, onPrevMonth, onNextMonth } = mountSwipe()

    swipe.handleTouchStart(touchEvent(200, 400))
    swipe.handleTouchMove(touchEvent(215, 250))
    swipe.handleTouchEnd(touchEvent(215, 250))
    vi.advanceTimersByTime(MONTH_SLIDE_OUT_MS)

    expect(onPrevMonth).not.toHaveBeenCalled()
    expect(onNextMonth).not.toHaveBeenCalled()
    expect(swipe.offset.value).toBe(0)

    scope.stop()
  })

  it('swallows the click after a drag that moved the calendar but kept the month', () => {
    const { swipe, scope, onPrevMonth, onNextMonth } = mountSwipe()
    const click = {
      detail: 1,
      preventDefault: vi.fn(),
      stopPropagation: vi.fn(),
      stopImmediatePropagation: vi.fn(),
    }

    swipe.handleTouchStart(touchEvent(200, 300))
    swipe.handleTouchMove(touchEvent(172, 302))
    swipe.handleTouchEnd(touchEvent(172, 302))

    expect(onPrevMonth).not.toHaveBeenCalled()
    expect(onNextMonth).not.toHaveBeenCalled()
    expect(swipe.dragClickGuard.handleClick(click)).toBe(true)

    scope.stop()
  })

  it('leaves a plain tap alone', () => {
    const { swipe, scope } = mountSwipe()
    const click = {
      detail: 1,
      preventDefault: vi.fn(),
      stopPropagation: vi.fn(),
      stopImmediatePropagation: vi.fn(),
    }

    swipe.dragClickGuard.handlePointerDown()
    swipe.handleTouchStart(touchEvent(200, 300))
    swipe.handleTouchMove(touchEvent(201, 301))
    swipe.handleTouchEnd(touchEvent(201, 301))

    expect(swipe.dragClickGuard.handleClick(click)).toBe(false)
    expect(click.preventDefault).not.toHaveBeenCalled()

    scope.stop()
  })

  it('swallows the click the browser emits after a committed swipe', () => {
    const { swipe, scope } = mountSwipe()
    const click = {
      detail: 1,
      preventDefault: vi.fn(),
      stopPropagation: vi.fn(),
      stopImmediatePropagation: vi.fn(),
    }

    swipe.handleTouchStart(touchEvent(300, 200))
    swipe.handleTouchMove(touchEvent(240, 205))
    swipe.handleTouchEnd(touchEvent(300 - MONTH_SWIPE_THRESHOLD - 10, 205))

    expect(swipe.dragClickGuard.handleClick(click)).toBe(true)
    expect(click.preventDefault).toHaveBeenCalledOnce()

    scope.stop()
  })
})

describe('the duty calendar wiring', () => {
  it('swipes the calendar grid itself and hands the month change to the view', () => {
    expect(dutyCalendarContent).toContain('useCalendarMonthSwipe')
    expect(dutyCalendarContent).toContain('@touchstart.passive="monthSwipe.handleTouchStart"')
    expect(dutyCalendarContent).toContain('@click.capture="monthSwipe.dragClickGuard.handleClick"')
    expect(dutyCalendarContent).toContain("(e: 'prev-month'): void")
    expect(dutyCalendarContent).toContain("(e: 'next-month'): void")

    const calendarContentTag = dutyView.slice(
      dutyView.indexOf('<DutyCalendarContent'),
      dutyView.indexOf('</DutyCalendarContent>', dutyView.indexOf('<DutyCalendarContent'))
    )
    expect(calendarContentTag).toContain('@prev-month="prevMonth"')
    expect(calendarContentTag).toContain('@next-month="nextMonth"')
  })
})

describe('the team calendar wiring', () => {
  it('uses the shared month swipe on the calendar without swiping the selected-day details', () => {
    expect(teamView).toContain('const monthSwipe = useCalendarMonthSwipe({')
    expect(teamView).toContain('onPrevMonth: prevMonth')
    expect(teamView).toContain('onNextMonth: nextMonth')
    expect(teamView).toContain('getWidth: () => swipeContainer.value?.clientWidth ?? 0')
    const swipeSurface = teamView.slice(
      teamView.indexOf('ref="swipeContainer"'),
      teamView.indexOf('</CalendarGrid>'),
    )
    expect(swipeSurface).toContain('@touchstart.passive="monthSwipe.handleTouchStart"')
    expect(swipeSurface).toContain('@touchmove.passive="monthSwipe.handleTouchMove"')
    expect(swipeSurface).toContain('@touchend="monthSwipe.handleTouchEnd"')
    expect(swipeSurface).toContain('@touchcancel="monthSwipe.handleTouchCancel"')
    expect(swipeSurface).toContain('@pointerdown.capture="monthSwipe.dragClickGuard.handlePointerDown"')
    expect(swipeSurface).toContain('@click.capture="monthSwipe.dragClickGuard.handleClick"')
    expect(swipeSurface).toContain(':style="monthSwipe.trackStyle.value"')
    expect(teamView).toContain('touch-action: pan-y;')
    expect(teamView).toMatch(/<\/CalendarGrid>\s*<\/div>\s*<\/div>\s*<div class="rounded-lg border shadow-sm/)
  })
})
