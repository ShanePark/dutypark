import { describe, expect, it } from 'vitest'
import kanbanCard from './KanbanCard.vue?raw'

describe('KanbanCard', () => {
  it('keeps status controls out of list cards because the column already communicates status', () => {
    expect(kanbanCard).not.toContain('TodoStatusPicker')
    expect(kanbanCard).not.toContain('statusChangePending')
    expect(kanbanCard).not.toContain("(e: 'status-change'")
    expect(kanbanCard).not.toContain('status-change')
    expect(kanbanCard).not.toContain('kanban-card-status-row')
    expect(kanbanCard).not.toContain('todo-status-picker')
  })

  it('keeps the card attachment affordance in the header', () => {
    expect(kanbanCard).toContain('Paperclip')
    expect(kanbanCard).toContain('kanban-card-attachment-icon')
  })
})
