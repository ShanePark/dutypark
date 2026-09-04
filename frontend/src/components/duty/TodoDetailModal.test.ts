import { describe, expect, it } from 'vitest'
import todoDetailModal from './TodoDetailModal.vue?raw'
import todoStatusPicker from '@/components/todo/TodoStatusPicker.vue?raw'
import dutyView from '@/views/duty/DutyView.vue?raw'
import todoBoardView from '@/views/todo/TodoBoardView.vue?raw'

describe('TodoDetailModal status changes', () => {
  it('gives the dialog an accessible title and labels the close action', () => {
    expect(todoDetailModal).toContain('aria-labelledby="todo-detail-modal-title"')
    expect(todoDetailModal).toContain('<h2 id="todo-detail-modal-title"')
    expect(todoDetailModal).toMatch(
      /<button[\s\S]*?@click="handleClose"[\s\S]*?:aria-label="t\('common\.actions\.close'\)"[\s\S]*?:title="t\('common\.actions\.close'\)"/,
    )
  })

  it('keeps the status control in the footer instead of beside the title', () => {
    expect(todoDetailModal).toContain('TodoStatusPicker')
    expect(todoDetailModal).toContain('canChangeStatus')
    expect(todoDetailModal).toContain("emit('status-change', $event)")
    expect(todoDetailModal).toContain(':footer="true"')
    const headerBlock = todoDetailModal.match(/<div class="modal-header">[\s\S]*?<\/div>\s*<div class="modal-body-form-compact">/)?.[0] ?? ''
    expect(headerBlock).not.toContain('TodoStatusPicker')
    expect(headerBlock).not.toContain('getStatusLabel(todo.status)')
    expect(todoDetailModal).not.toContain('editStatus')
  })

  it('disables conflicting detail mutations while a status change is pending', () => {
    expect(todoDetailModal).toMatch(/@click="enterEditMode"[\s\S]*?:disabled="statusChangePending"/)
    expect(todoDetailModal).toMatch(/@click="emit\('delete', \{ id: todo\.id, title: todo\.title \}\)"[\s\S]*?:disabled="statusChangePending"/)
    expect(todoDetailModal).toMatch(/v-if="isTaggedTodo"[\s\S]*?:disabled="statusChangePending"/)
    expect(todoDetailModal).toContain('if (props.statusChangePending) return')
  })

  it('preserves the existing status when saving non-status edits', () => {
    expect(todoDetailModal).toContain('status: props.todo.status')
  })

  it('keeps the non-status actions available', () => {
    expect(todoDetailModal).toContain("emit('untagSelf'")
    expect(todoDetailModal).toContain('enterEditMode')
    expect(todoDetailModal).toContain("emit('delete'")
  })

  it('exposes status, edit, and delete as direct owner actions', () => {
    expect(todoDetailModal).toMatch(/<TodoStatusPicker[\s\S]*?:footer="true"[\s\S]*?class="todo-detail-primary-action min-w-0"/)
    expect(todoDetailModal).toMatch(/@click="enterEditMode"[\s\S]*?class="todo-detail-primary-action flex min-h-11/)
    expect(todoDetailModal).toMatch(/@click="emit\('delete', \{ id: todo\.id, title: todo\.title \}\)"[\s\S]*?class="todo-detail-primary-action flex min-h-11/)
  })

  it('keeps tagged todo removal visible beside the status action', () => {
    expect(todoDetailModal).toMatch(/<TodoStatusPicker[\s\S]*?v-if="canChangeStatus && !isEditMode"/)
    expect(todoDetailModal).toMatch(/@click="emit\('untagSelf', \{ id: todo\.id, title: todo\.title \}\)"[\s\S]*?class="todo-detail-primary-action flex min-h-11/)
    expect(todoDetailModal).toContain('<OverflowMenu\n                v-if="canReport"')
    expect(todoDetailModal).not.toMatch(/<OverflowMenu[\s\S]*?emit\('untagSelf'/)
  })

  it('keeps primary footer actions equal-width while reserving report for its own trigger', () => {
    expect(todoDetailModal).toContain('todo-detail-footer-actions')
    expect(todoDetailModal).toContain('todo-detail-primary-actions')
    expect(todoDetailModal).toContain("isTaggedTodo ? 'grid-cols-2' : 'grid-cols-3'")
    expect(todoDetailModal).toContain('todo-detail-report-trigger')
  })

  it('does not ellipsize the footer status label on narrow mobile widths', () => {
    expect(todoStatusPicker).toContain('.todo-status-picker-trigger--footer .todo-status-picker-label')
    expect(todoStatusPicker).toContain('white-space: normal')
    expect(todoStatusPicker).toContain('text-overflow: clip')
    expect(todoStatusPicker).toContain('overflow-wrap: anywhere')
  })

  it('keeps the footer visible while long content scrolls in the body', () => {
    expect(todoDetailModal).toContain("'modal-footer-safe'")
    expect(todoDetailModal).toContain('flex-shrink-0 border-t border-dp-border-primary')
    expect(todoDetailModal).toContain('class="modal-body-form-compact"')
  })

  it('expands the remaining detail actions across the mobile footer', () => {
    expect(todoDetailModal).toMatch(/v-if="showBackToList"[\s\S]*?class="flex min-h-11 w-full items-center justify-center gap-1 px-3 py-2 text-sm rounded-lg transition btn-outline cursor-pointer sm:w-auto sm:flex-none"/)
    expect(todoDetailModal).toMatch(/class="todo-detail-footer-actions flex min-w-0 w-full items-stretch justify-end gap-2 sm:w-auto sm:flex-none"/)
    expect(todoDetailModal).toMatch(/@click="enterEditMode"[\s\S]*?class="todo-detail-primary-action flex min-h-11/)
    expect(todoDetailModal).toMatch(/emit\('delete'[\s\S]*?class="todo-detail-primary-action flex min-h-11/)
  })

  it('gives the back link and primary actions separate full-width rows on narrow screens', () => {
    const backLinkIndex = todoDetailModal.indexOf('v-if="showBackToList"')
    const actionRowIndex = todoDetailModal.indexOf('todo-detail-footer-actions')

    expect(backLinkIndex).toBeGreaterThan(-1)
    expect(actionRowIndex).toBeGreaterThan(backLinkIndex)
    expect(todoDetailModal).toMatch(/class="flex min-h-11 w-full[\s\S]*?sm:w-auto sm:flex-none/)
    expect(todoDetailModal).toMatch(/class="todo-detail-footer-actions flex min-w-0 w-full[\s\S]*?sm:w-auto sm:flex-none"/)
  })

  it('allows the tagged todo action label to wrap beside the report trigger', () => {
    const removeTagStart = todoDetailModal.indexOf('emit(\'untagSelf\'')
    const removeTagEnd = todoDetailModal.indexOf('</button>', removeTagStart)
    const removeTagBlock = todoDetailModal.slice(removeTagStart, removeTagEnd)

    expect(removeTagStart).toBeGreaterThan(-1)
    expect(removeTagEnd).toBeGreaterThan(removeTagStart)
    expect(removeTagBlock).toContain('min-w-0 whitespace-normal')
    expect(removeTagBlock).not.toContain('whitespace-nowrap')
  })

  it('does not reintroduce the legacy complete/reopen events', () => {
    for (const view of [dutyView, todoBoardView]) {
      expect(view).not.toContain('@complete=')
      expect(view).not.toContain('@reopen=')
    }
  })
})

describe('TodoDetailModal due date field', () => {
  it('edits the due date with the shared date picker instead of a native date input', () => {
    expect(todoDetailModal).toContain('DatePickerField')
    expect(todoDetailModal).toMatch(/<DatePickerField[\s\S]*?v-model="editDueDate"/)
    expect(todoDetailModal).not.toContain('type="date"')
  })
})
