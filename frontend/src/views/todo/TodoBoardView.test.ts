import { describe, expect, it } from 'vitest'
import todoBoardView from './TodoBoardView.vue?raw'
import en from '@/i18n/messages/en'
import ko from '@/i18n/messages/ko'

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
    expect(script).toContain("filter: '.kanban-card-wrapper--status-pending'")
    expect(script).not.toContain('.todo-status-picker')
    expect(script).toContain('preventOnFilter: false')
    expect(script).toContain('delayOnTouchOnly: true')
    expect(script).toContain('touchStartThreshold: 4')
    expect(script).toContain('swapThreshold: 0.65')
    expect(style).toContain('.kanban-card-wrapper {')
    expect(style).toContain('touch-action: manipulation')
    expect(style).not.toContain('touch-action: none')
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

  it('keeps status changes in the detail modal instead of repeating them on list cards', () => {
    expect(template).toContain('<KanbanCard')
    expect(template).not.toContain('@status-change="handleStatusChange(todo, $event)"')
    expect(template).not.toContain(':status-change-pending="pendingStatusTodoIds.has(todo.id)"')
    expect(template).toContain('@status-change="handleSelectedTodoStatusChange"')
    expect(script).toContain('async function handleSelectedTodoStatusChange(status: TodoStatus)')
    expect(script).toContain('todoApi.changeStatus(todo.id, { status })')
    expect(script).toContain("toastSuccess(t('todoBoard.messages.changeStatusSuccess'))")
    expect(script).toContain("showError(t('todoBoard.messages.changeStatusFailed'))")
  })

  it('reconciles the board from the successful status response before refreshing', () => {
    expect(script).toContain('const updatedTodo = await todoApi.changeStatus(todo.id, { status })')
    expect(script).toContain('reconcileTodoStatus(updatedTodo)')
    expect(script).toMatch(
      /const updatedTodo = await todoApi\.changeStatus\(todo\.id, \{ status \}\)[\s\S]*?reconcileTodoStatus\(updatedTodo\)[\s\S]*?await loadBoard\(\)/,
    )
    expect(script).toContain('if (selectedTodo.value?.id === updatedTodo.id)')
  })

  it('keeps the successful local reconciliation when the follow-up refresh fails', () => {
    expect(script).toContain("showError(t('todoBoard.messages.loadFailed'))")
    expect(script).toMatch(
      /reconcileTodoStatus\(updatedTodo\)[\s\S]*?await loadBoard\(\)[\s\S]*?finally[\s\S]*?pendingStatusTodoIds\.value\.delete\(todo\.id\)/,
    )
  })

  it('connects the detail modal status control and keeps the selected todo in sync', () => {
    expect(template).toContain(':can-change-status="true"')
    expect(template).toContain('@status-change="handleSelectedTodoStatusChange"')
    expect(script).toContain('async function handleSelectedTodoStatusChange(status: TodoStatus)')
    expect(script).toContain('selectedTodo.value = updatedTodo')
  })

  it('explains that list cards change status from detail or by dragging', () => {
    expect(ko.todoBoard.help.whatIsKanbanText).toContain('상세 화면에서 상태를 변경')
    expect(ko.todoBoard.help.whatIsKanbanText).toContain('드래그')
    expect(ko.todoBoard.help.whatIsKanbanText).not.toContain('상태 버튼')
    expect(ko.todoBoard.help.tips.drag).toContain('상세 화면에서 상태를 변경')
    expect(ko.todoBoard.help.tips.drag).toContain('드래그')
    expect(ko.todoBoard.help.tips.drag).not.toContain('상태 버튼')

    expect(en.todoBoard.help.whatIsKanbanText).toContain('detail view')
    expect(en.todoBoard.help.whatIsKanbanText).toContain('drag')
    expect(en.todoBoard.help.whatIsKanbanText).not.toContain('status button')
    expect(en.todoBoard.help.tips.drag).toContain('detail view')
    expect(en.todoBoard.help.tips.drag).toContain('drag')
    expect(en.todoBoard.help.tips.drag).not.toContain('status button')
  })

  it('blocks competing status changes for the same todo while its request is pending', () => {
    expect(script).toContain('const pendingStatusTodoIds = ref<Set<string>>(new Set())')
    expect(script).toContain('if (pendingStatusTodoIds.value.has(todo.id)) return')
    expect(script).toContain('pendingStatusTodoIds.value.add(todo.id)')
    expect(script).toContain('pendingStatusTodoIds.value.delete(todo.id)')
    expect(script).toContain('finally')
    expect(template).toContain(':status-change-pending="selectedTodo ? pendingStatusTodoIds.has(selectedTodo.id) : false"')
  })

  it('does not let an earlier status request replace a newly opened detail todo', () => {
    expect(script).toContain('if (selectedTodo.value?.id !== todo.id || !board.value) return')
  })

  it('keeps pending cards out of Sortable and guards drag persistence', () => {
    expect(script).toContain("filter: '.kanban-card-wrapper--status-pending'")
    expect(script).toMatch(/async function handleDragEnd[\s\S]*?if \(pendingStatusTodoIds\.value\.has\(todoId\)\) return/)
    expect(template).toContain(":class=\"{ 'kanban-card-wrapper--status-pending': pendingStatusTodoIds.has(todo.id) }\"")
  })

  it('marks cross-column drag status requests as pending until they settle', () => {
    expect(script).toMatch(/async function handleDragEnd[\s\S]*?pendingStatusTodoIds\.value\.add\(todoId\)/)
    expect(script).toMatch(/pendingStatusTodoIds\.value\.add\(todoId\)[\s\S]*?finally[\s\S]*?pendingStatusTodoIds\.value\.delete\(todoId\)/)
  })

  it('guards detail mutations while the todo status request is pending', () => {
    expect(script).toMatch(/async function handleUpdateTodo[\s\S]*?if \(pendingStatusTodoIds\.value\.has\(data\.id\)\) return/)
    expect(script).toMatch(/async function handleDeleteTodo[\s\S]*?if \(pendingStatusTodoIds\.value\.has\(todo\.id\)\) return/)
    expect(script).toMatch(/async function handleUntagSelf[\s\S]*?if \(pendingStatusTodoIds\.value\.has\(todo\.id\)\) return/)
  })

  it('keeps the report action available for tagged todos in the board detail flow', () => {
    expect(script).toContain("import ReportModal from '@/components/common/ReportModal.vue'")
    expect(script).toContain("import { reportApi } from '@/api/report'")
    expect(script).toContain("import type { ReportSubmission, ReportTarget } from '@/types/report'")
    expect(script).toContain('const reportTarget = ref<ReportTarget | null>(null)')
    expect(script).toContain('const canReportSelectedTodo = computed(')
    expect(template).toContain(':can-report="canReportSelectedTodo"')
    expect(template).toContain('@report="openTodoReport"')
    expect(template).toContain('<ReportModal')
    expect(script).toContain('async function handleReportSubmit(submission: ReportSubmission)')
    expect(script).toContain('await reportApi.createReport({')
  })

  it('serializes tag removal with status and report mutations', () => {
    expect(script).toMatch(/async function handleUntagSelf[\s\S]*?pendingStatusTodoIds\.value\.add\(todo\.id\)/)
    expect(script).toMatch(/async function handleUntagSelf[\s\S]*?finally[\s\S]*?pendingStatusTodoIds\.value\.delete\(todo\.id\)/)
    expect(script).toMatch(/function openTodoReport[\s\S]*?pendingStatusTodoIds\.value\.has\(todo\.id\)/)
  })

  it('serializes save, delete, and report with the same per-todo lock', () => {
    expect(script).toMatch(/async function handleUpdateTodo[\s\S]*?pendingStatusTodoIds\.value\.add\(data\.id\)[\s\S]*?finally[\s\S]*?pendingStatusTodoIds\.value\.delete\(data\.id\)/)
    expect(script).toMatch(/async function handleDeleteTodo[\s\S]*?pendingStatusTodoIds\.value\.add\(todo\.id\)[\s\S]*?finally[\s\S]*?pendingStatusTodoIds\.value\.delete\(todo\.id\)/)
    expect(script).toMatch(/async function handleReportSubmit[\s\S]*?pendingStatusTodoIds\.value\.add\(target\.targetId\)[\s\S]*?finally[\s\S]*?pendingStatusTodoIds\.value\.delete\(target\.targetId\)/)
  })
})
