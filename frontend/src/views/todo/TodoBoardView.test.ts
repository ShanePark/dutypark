import { describe, expect, it } from 'vitest'
import todoBoardView from './TodoBoardView.vue?raw'

const templateAt = todoBoardView.indexOf('<template>')
const styleAt = todoBoardView.indexOf('<style')
const script = todoBoardView.slice(0, templateAt)
const template = todoBoardView.slice(templateAt, styleAt > -1 ? styleAt : todoBoardView.length)
const style = styleAt > -1 ? todoBoardView.slice(styleAt) : ''
const dragMoveAt = script.indexOf('function handleDragMove')
const dragMoveEndAt = script.indexOf('function collectOrderedIds')
const dragMoveHandler = script.slice(dragMoveAt, dragMoveEndAt)
const dragPointerMoveAt = script.indexOf('function handleDragPointerMove')
const dragPointerMoveEndAt = script.indexOf('function removeDragPointerListeners')
const dragPointerMoveHandler = script.slice(dragPointerMoveAt, dragPointerMoveEndAt)

describe('todo board mobile drag navigation', () => {
  it('tracks the Sortable destination while dragging and follows it horizontally', () => {
    expect(script).toContain('function handleDragMove')
    expect(script).toContain('event.to.getAttribute(\'data-column\')')
    expect(script).toContain('activeStatus.value = toColumn')
    expect(dragMoveHandler).toContain('focusDraggedStatus(toColumn)')
    expect(script).toContain('onMove: handleDragMove')
  })

  it('follows the finger edge while the next column is still off screen', () => {
    expect(script).toContain('function handleDragPointerMove')
    expect(script).toContain("document.addEventListener('pointermove', handleDragPointerMove")
    expect(script).toContain("document.addEventListener('touchmove', handleDragPointerMove")
    expect(script).toContain('dragEdgeStatus')
    expect(script).toContain('focusDraggedStatus(nextStatus)')
  })

  it('captures fallback touch movement before Sortable can consume it', () => {
    expect(script).toContain('forceFallback: true')
    expect(script).toContain('fallbackOnBody: true')
    expect(script).toContain(
      "document.addEventListener('pointermove', handleDragPointerMove, { capture: true })",
    )
    expect(script).toContain(
      "document.addEventListener('touchmove', handleDragPointerMove, { capture: true, passive: false })",
    )
    expect(script).toContain(
      "document.removeEventListener('pointermove', handleDragPointerMove, { capture: true })",
    )
    expect(script).toContain(
      "document.removeEventListener('touchmove', handleDragPointerMove, { capture: true })",
    )
  })

  it('moves the actual board scroller to the edge-selected column after touch handling', () => {
    const focusesDestinationAfterTouchFrame =
      /requestAnimationFrame\([\s\S]*?focusStatus\(nextStatus,\s*['"](?:smooth|instant|auto)['"]\)/
        .test(dragPointerMoveHandler)

    const dragScrollCall = dragPointerMoveHandler.match(
      /(?:focusDraggedStatus|scrollToDraggedStatus|scrollDragStatus)\(nextStatus\)/,
    )
    const dragScrollFunctionName = dragScrollCall?.[0].split('(')[0]
    const dragScrollFunctionAt = dragScrollFunctionName
      ? script.indexOf(`function ${dragScrollFunctionName}`)
      : -1
    const nextFunctionAt = dragScrollFunctionAt >= 0
      ? script.indexOf('\nfunction ', dragScrollFunctionAt + 1)
      : -1
    const dragScrollFunction = dragScrollFunctionAt >= 0
      ? script.slice(dragScrollFunctionAt, nextFunctionAt >= 0 ? nextFunctionAt : undefined)
      : ''
    const dragScrollSetsCalculatedLeft =
      /(?:scrollLeft\s*=\s*left|scrollTo\(\{\s*left(?:,|\s*\}))/s.test(dragScrollFunction)

    expect(
      focusesDestinationAfterTouchFrame || dragScrollSetsCalculatedLeft,
      'edge drag must focus the destination after the touch frame or directly set the board scroll left',
    ).toBe(true)
    expect(dragScrollFunction).toContain('container.scrollWidth - container.clientWidth')
    expect(dragScrollFunction).toContain('Math.min')
  })

  it('moves the board synchronously during the mobile touchmove gesture', () => {
    expect.soft(script).toContain(
      "document.addEventListener('touchmove', handleDragPointerMove, { capture: true, passive: false })",
    )
    expect.soft(dragPointerMoveHandler).toContain('event.preventDefault()')
    expect.soft(dragPointerMoveHandler).toContain('focusDraggedStatus(nextStatus)')

    const focusDraggedStatusAt = script.indexOf('function focusDraggedStatus')
    const cancelDragStatusFocusAt = script.indexOf('function cancelDragStatusFocus')
    const focusDraggedStatusHandler = script.slice(
      focusDraggedStatusAt,
      cancelDragStatusFocusAt > focusDraggedStatusAt ? cancelDragStatusFocusAt : undefined,
    )
    const deferredMoverAt = focusDraggedStatusHandler.indexOf('const moveBoardToDraggedStatus')
    const firstAnimationFrameAt = focusDraggedStatusHandler.indexOf('requestAnimationFrame')
    const synchronousPathEnd = [deferredMoverAt, firstAnimationFrameAt]
      .filter((index) => index >= 0)
      .reduce((earliest, index) => Math.min(earliest, index), focusDraggedStatusHandler.length)
    const synchronousPath = focusDraggedStatusHandler.slice(0, synchronousPathEnd)

    expect.soft(synchronousPath).toContain('boardScroller.value')
    expect.soft(synchronousPath).toMatch(
      /(?:container\.scrollLeft\s*(?:=|\+=)|container\.scrollTo\(\{\s*left)/,
    )
  })

  it('keeps the edge-selected status active while Sortable still reports the source column', () => {
    expect(dragMoveHandler).toContain('toColumn === dragStartStatus')
    expect(dragMoveHandler).toContain('activeDragStatus !== dragStartStatus')
    expect(dragMoveHandler).toContain('return')
    expect(script).toContain('if (dragClickGuard.isDragging.value && activeDragStatus) return')
  })

  it('keeps Sortable touch ordering active inside the destination column', () => {
    expect(script).toContain("draggable: '.kanban-card-wrapper'")
    expect(script).toContain('delayOnTouchOnly: true')
    expect(script).toContain('touchStartThreshold: 4')
    expect(script).toContain('swapThreshold: 0.65')
    expect(style).toContain('.kanban-card-wrapper {')
    expect(style).toContain('touch-action: none')
  })

  it('keeps the destination order API and reload-on-failure recovery unchanged', () => {
    expect(script).toContain('todoApi.changeStatus(todoId, {')
    expect(script).toContain('status: toColumn')
    expect(script).toContain('orderedIds')
    expect(script).toContain("showError(t('todoBoard.messages.changeStatusFailed'))")
    expect(script).toMatch(/showError\(t\('todoBoard\.messages\.changeStatusFailed'\)\)[\s\S]*?await loadBoard\(\)/)
    expect(script).toContain('dragStartStatus = activeStatus.value')
    expect(script).toContain('void handleDragEnd(event, previousActiveStatus)')
    expect(script).toContain('const statusToRestore = previousActiveStatus ?? fromColumn')
    expect(script).toContain('activeStatus.value = statusToRestore')
    expect(script).toContain("focusStatus(statusToRestore, 'smooth')")
  })

  it('keeps the empty column add action visually identifiable', () => {
    expect(style).toContain('border: 2px dashed var(--dp-accent-border);')
  })
})
