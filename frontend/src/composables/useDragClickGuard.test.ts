import { effectScope } from 'vue'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { useDragClickGuard } from './useDragClickGuard'

function createClickEvent(detail = 1) {
  return {
    detail,
    preventDefault: vi.fn(),
    stopPropagation: vi.fn(),
    stopImmediatePropagation: vi.fn(),
  }
}

describe('useDragClickGuard', () => {
  afterEach(() => {
    vi.useRealTimers()
  })

  it('blocks the pointer click emitted immediately after a drag ends', () => {
    const scope = effectScope()
    const guard = scope.run(() => useDragClickGuard())!
    const event = createClickEvent()

    guard.startDrag()
    expect(guard.isDragging.value).toBe(true)

    guard.endDrag()
    expect(guard.isDragging.value).toBe(false)
    expect(guard.handleClick(event)).toBe(true)
    expect(event.preventDefault).toHaveBeenCalledOnce()
    expect(event.stopPropagation).toHaveBeenCalledOnce()
    expect(event.stopImmediatePropagation).toHaveBeenCalledOnce()

    scope.stop()
  })

  it('allows keyboard-generated clicks while pointer clicks are suppressed', () => {
    const scope = effectScope()
    const guard = scope.run(() => useDragClickGuard())!
    const keyboardEvent = createClickEvent(0)
    const pointerEvent = createClickEvent()

    guard.startDrag()
    guard.endDrag()

    expect(guard.handleClick(keyboardEvent)).toBe(false)
    expect(keyboardEvent.preventDefault).not.toHaveBeenCalled()
    expect(guard.handleClick(pointerEvent)).toBe(true)

    scope.stop()
  })

  it('allows pointer clicks after the suppression window expires', () => {
    vi.useFakeTimers()
    const scope = effectScope()
    const guard = scope.run(() => useDragClickGuard({ resetDelay: 100 }))!
    const event = createClickEvent()

    guard.startDrag()
    guard.endDrag()
    vi.advanceTimersByTime(100)

    expect(guard.handleClick(event)).toBe(false)
    expect(event.preventDefault).not.toHaveBeenCalled()

    scope.stop()
  })

  it('allows a deliberate pointer interaction after a drag when no ghost click occurred', () => {
    const scope = effectScope()
    const guard = scope.run(() => useDragClickGuard())!
    const event = createClickEvent()

    guard.startDrag()
    guard.endDrag()
    guard.handlePointerDown()

    expect(guard.handleClick(event)).toBe(false)
    expect(event.preventDefault).not.toHaveBeenCalled()

    scope.stop()
  })

  it('can suppress the next click for a custom swipe gesture', () => {
    const scope = effectScope()
    const guard = scope.run(() => useDragClickGuard())!
    const event = createClickEvent()

    guard.suppressNextClick()

    expect(guard.handleClick(event)).toBe(true)
    expect(guard.handleClick(createClickEvent())).toBe(false)

    scope.stop()
  })

  it('clears suppression when a gesture is cancelled', () => {
    const scope = effectScope()
    const guard = scope.run(() => useDragClickGuard())!
    const event = createClickEvent()

    guard.startDrag()
    guard.cancelDrag()

    expect(guard.isDragging.value).toBe(false)
    expect(guard.handleClick(event)).toBe(false)

    scope.stop()
  })
})
