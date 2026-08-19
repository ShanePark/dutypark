import { computed, onScopeDispose, readonly, ref } from 'vue'
import { useDragClickGuard } from '@/composables/useDragClickGuard'

/** How far the finger has to travel sideways before lifting it changes the month. */
export const MONTH_SWIPE_THRESHOLD = 56

/**
 * A vertical scroll drifts sideways as the thumb rolls, so the horizontal travel has
 * to beat the vertical travel by this much before the drag counts as a month swipe.
 */
export const MONTH_SWIPE_VERTICAL_TOLERANCE = 28

/**
 * The furthest the calendar follows the finger. A drag that turns out to be a scroll
 * therefore never pulls the calendar meaningfully off its column.
 */
export const MONTH_SWIPE_MAX_FOLLOW = 72

export const MONTH_SLIDE_OUT_MS = 160
export const MONTH_SLIDE_IN_MS = 220

/**
 * The month offset a finished drag asks for: -1 for the previous month when the finger
 * travelled left to right, 1 for the next month, and 0 when the drag was too short or
 * too vertical to be a month swipe.
 */
export function resolveMonthSwipe(deltaX: number, deltaY: number): -1 | 0 | 1 {
  const horizontal = Math.abs(deltaX)
  if (horizontal < MONTH_SWIPE_THRESHOLD) return 0
  if (horizontal <= Math.abs(deltaY) + MONTH_SWIPE_VERTICAL_TOLERANCE) return 0
  return deltaX > 0 ? -1 : 1
}

/**
 * How far the calendar sits from its column while the finger is down. The travel is
 * rubber-banded towards MONTH_SWIPE_MAX_FOLLOW: the first few pixels follow the finger
 * almost exactly, and a long drag stops well before the calendar leaves.
 */
export function monthSwipeFollowOffset(deltaX: number, deltaY: number): number {
  if (Math.abs(deltaX) <= Math.abs(deltaY)) return 0
  const magnitude = MONTH_SWIPE_MAX_FOLLOW * (1 - Math.exp(-Math.abs(deltaX) / MONTH_SWIPE_MAX_FOLLOW))
  return deltaX < 0 ? -magnitude : magnitude
}

interface CalendarMonthSwipeOptions {
  onPrevMonth: () => void
  onNextMonth: () => void
  /** Width of the swiped calendar, used as the distance it slides out and back in. */
  getWidth: () => number
}

/**
 * Moves a calendar a month at a time when it is swiped sideways, so changing month does
 * not have to go through the small chevrons in the header.
 *
 * The calendar is a scrollable surface full of tappable days, so the gesture stays a
 * passenger: touch listeners are passive and `touch-action: pan-y` leaves the vertical
 * scroll to the browser, only a clearly sideways drag commits, and the click the browser
 * emits after the swipe is swallowed so a day modal never opens behind the new month.
 */
export function useCalendarMonthSwipe(options: CalendarMonthSwipeOptions) {
  const dragClickGuard = useDragClickGuard({ resetDelay: 250 })
  const offset = ref(0)
  const isSliding = ref(false)
  const isAnimating = ref(false)

  let startX = 0
  let startY = 0
  let lastX = 0
  let lastY = 0
  let isTouching = false
  let hasFollowedFinger = false
  let slideTimer: ReturnType<typeof setTimeout> | null = null
  let frameHandle: number | null = null

  // An idle calendar carries no transform at all: a permanent one would turn the
  // calendar into the containing block of anything fixed inside a day cell.
  const trackStyle = computed(() => {
    if (offset.value === 0 && !isAnimating.value) return {}
    const duration = isSliding.value ? MONTH_SLIDE_OUT_MS : MONTH_SLIDE_IN_MS
    return {
      transform: `translate3d(${offset.value}px, 0, 0)`,
      transition: isAnimating.value ? `transform ${duration}ms ease-out` : 'none',
    }
  })

  function clearSlideTimer() {
    if (slideTimer !== null) {
      clearTimeout(slideTimer)
      slideTimer = null
    }
    if (frameHandle !== null) {
      cancelAnimationFrame(frameHandle)
      frameHandle = null
    }
  }

  function resetTouch() {
    hasFollowedFinger = false
    startX = 0
    startY = 0
    lastX = 0
    lastY = 0
    isTouching = false
  }

  function settle() {
    isAnimating.value = true
    isSliding.value = false
    offset.value = 0
  }

  function handleTouchStart(event: TouchEvent) {
    if (isSliding.value) return
    const touch = event.touches[0]
    if (!touch) return

    startX = touch.clientX
    startY = touch.clientY
    lastX = touch.clientX
    lastY = touch.clientY
    isTouching = true
    hasFollowedFinger = false
    isAnimating.value = false
  }

  function handleTouchMove(event: TouchEvent) {
    if (!isTouching) return
    const touch = event.touches[0]
    if (!touch) return

    lastX = touch.clientX
    lastY = touch.clientY
    offset.value = monthSwipeFollowOffset(lastX - startX, lastY - startY)
    if (offset.value !== 0) {
      hasFollowedFinger = true
      dragClickGuard.startDrag()
    }
  }

  function handleTouchEnd(event: TouchEvent) {
    if (!isTouching) return

    const touch = event.changedTouches[0]
    const deltaX = (touch?.clientX ?? lastX) - startX
    const deltaY = (touch?.clientY ?? lastY) - startY
    const direction = resolveMonthSwipe(deltaX, deltaY)
    // A finger that pulled the calendar sideways was swiping, not tapping, even when
    // it gave up short of the next month, so its click never reaches a day.
    const wasSwiping = hasFollowedFinger

    resetTouch()

    if (direction === 0) {
      if (wasSwiping) dragClickGuard.endDrag()
      else dragClickGuard.cancelDrag()
      settle()
      return
    }

    event.stopPropagation()
    dragClickGuard.endDrag()
    slideToMonth(direction)
  }

  function handleTouchCancel() {
    if (!isTouching) return
    const wasSwiping = hasFollowedFinger
    resetTouch()
    if (wasSwiping) {
      dragClickGuard.endDrag()
      settle()
      return
    }
    dragClickGuard.cancelDrag()
    settle()
  }

  /**
   * The month changes now and its days arrive later, so the calendar slides out,
   * reappears on the far side and slides back in without waiting for the response; a
   * slow month lands its days in a calendar that is already home.
   */
  function slideToMonth(direction: -1 | 1) {
    const travel = Math.max(options.getWidth(), MONTH_SWIPE_MAX_FOLLOW)
    clearSlideTimer()
    isSliding.value = true
    isAnimating.value = true
    offset.value = direction > 0 ? -travel : travel

    slideTimer = setTimeout(() => {
      slideTimer = null
      if (direction > 0) options.onNextMonth()
      else options.onPrevMonth()

      // The far side has to be painted before the slide back in, or the browser
      // collapses the two transforms into one and nothing slides in at all.
      isAnimating.value = false
      offset.value = direction > 0 ? travel : -travel
      frameHandle = requestAnimationFrame(() => {
        frameHandle = requestAnimationFrame(() => {
          frameHandle = null
          settle()
          slideTimer = setTimeout(() => {
            isAnimating.value = false
            slideTimer = null
          }, MONTH_SLIDE_IN_MS)
        })
      })
    }, MONTH_SLIDE_OUT_MS)
  }

  onScopeDispose(() => {
    clearSlideTimer()
    resetTouch()
    isSliding.value = false
    isAnimating.value = false
  })

  return {
    dragClickGuard,
    offset: readonly(offset),
    trackStyle,
    handleTouchStart,
    handleTouchMove,
    handleTouchEnd,
    handleTouchCancel,
  }
}
