import { describe, expect, it } from 'vitest'
import todoDetailModal from './TodoDetailModal.vue?raw'
import dutyView from '@/views/duty/DutyView.vue?raw'
import todoBoardView from '@/views/todo/TodoBoardView.vue?raw'

describe('TodoDetailModal status changes', () => {
  it('does not offer status-changing actions in the detail modal', () => {
    expect(todoDetailModal).not.toContain("emit('complete'")
    expect(todoDetailModal).not.toContain("emit('reopen'")
    expect(todoDetailModal).not.toContain('statusOptions')
    expect(todoDetailModal).not.toContain('editStatus')
  })

  it('preserves the existing status when saving non-status edits', () => {
    expect(todoDetailModal).toContain('status: props.todo.status')
  })

  it('keeps the non-status actions available', () => {
    expect(todoDetailModal).toContain("emit('untagSelf'")
    expect(todoDetailModal).toContain('enterEditMode')
    expect(todoDetailModal).toContain("emit('delete'")
  })

  it('expands the remaining detail actions across the mobile footer', () => {
    expect(todoDetailModal).toMatch(/v-if="showBackToList"[\s\S]*?class="flex flex-1 sm:flex-none min-h-11/)
    expect(todoDetailModal).toMatch(/class="flex flex-1 sm:flex-none flex-wrap justify-end gap-2"/)
    expect(todoDetailModal).toMatch(/emit\('untagSelf'[\s\S]*?class="flex-1 sm:flex-none flex min-h-11/)
    expect(todoDetailModal).toMatch(/@click="enterEditMode"[\s\S]*?class="flex-1 sm:flex-none flex min-h-11/)
    expect(todoDetailModal).toMatch(/emit\('delete'[\s\S]*?class="flex-1 sm:flex-none flex min-h-11/)
  })

  it('does not connect status actions from detail modal consumers', () => {
    for (const view of [dutyView, todoBoardView]) {
      expect(view).not.toContain('@complete=')
      expect(view).not.toContain('@reopen=')
    }
  })
})
