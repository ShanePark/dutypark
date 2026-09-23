import { describe, expect, it } from 'vitest'
import { hasUnsavedScheduleChanges, hasUnsavedTodoChanges } from './formDismissal'

const todoDraft = {
  title: 'Plan the week',
  content: 'Review priorities',
  status: 'TODO' as const,
  dueDate: '',
  tagFriendIds: [2, 5],
}

const scheduleDraft = {
  content: 'Team meeting',
  description: 'Discuss the launch',
  startDateTime: '2026-09-23T09:00',
  endDateTime: '2026-09-23T10:00',
  visibility: 'FAMILY' as const,
  tagFriendIds: [2, 5],
}

describe('todo form dismissal', () => {
  it('allows dismissal when the draft and attachments match their baseline', () => {
    expect(hasUnsavedTodoChanges(todoDraft, { ...todoDraft, tagFriendIds: [5, 2] }, ['a'], ['a'], false)).toBe(false)
  })

  it('protects changes to fields, tags, attachments, or an attachment session', () => {
    expect(hasUnsavedTodoChanges(todoDraft, { ...todoDraft, title: 'Updated title' }, ['a'], ['a'], false)).toBe(true)
    expect(hasUnsavedTodoChanges(todoDraft, { ...todoDraft, content: 'New notes' }, ['a'], ['a'], false)).toBe(true)
    expect(hasUnsavedTodoChanges(todoDraft, { ...todoDraft, status: 'DONE' }, ['a'], ['a'], false)).toBe(true)
    expect(hasUnsavedTodoChanges(todoDraft, { ...todoDraft, dueDate: '2026-09-30' }, ['a'], ['a'], false)).toBe(true)
    expect(hasUnsavedTodoChanges(todoDraft, { ...todoDraft, tagFriendIds: [2] }, ['a'], ['a'], false)).toBe(true)
    expect(hasUnsavedTodoChanges(todoDraft, todoDraft, ['a'], ['b'], false)).toBe(true)
    expect(hasUnsavedTodoChanges(todoDraft, todoDraft, [], [], true)).toBe(true)
  })
})

describe('schedule form dismissal', () => {
  it('allows dismissal when the draft and attachments match their baseline', () => {
    expect(hasUnsavedScheduleChanges(scheduleDraft, { ...scheduleDraft, tagFriendIds: [5, 2] }, ['a'], ['a'], false)).toBe(false)
  })

  it('protects changes to schedule fields, tags, attachment order, or an attachment session', () => {
    expect(hasUnsavedScheduleChanges(scheduleDraft, { ...scheduleDraft, content: 'New title' }, ['a'], ['a'], false)).toBe(true)
    expect(hasUnsavedScheduleChanges(scheduleDraft, { ...scheduleDraft, description: 'New description' }, ['a'], ['a'], false)).toBe(true)
    expect(hasUnsavedScheduleChanges(scheduleDraft, { ...scheduleDraft, startDateTime: '2026-09-23T08:00' }, ['a'], ['a'], false)).toBe(true)
    expect(hasUnsavedScheduleChanges(scheduleDraft, { ...scheduleDraft, endDateTime: '2026-09-23T11:00' }, ['a'], ['a'], false)).toBe(true)
    expect(hasUnsavedScheduleChanges(scheduleDraft, { ...scheduleDraft, visibility: 'PRIVATE' }, ['a'], ['a'], false)).toBe(true)
    expect(hasUnsavedScheduleChanges(scheduleDraft, { ...scheduleDraft, tagFriendIds: [2] }, ['a'], ['a'], false)).toBe(true)
    expect(hasUnsavedScheduleChanges(scheduleDraft, scheduleDraft, ['a', 'b'], ['b', 'a'], false)).toBe(true)
    expect(hasUnsavedScheduleChanges(scheduleDraft, scheduleDraft, [], [], true)).toBe(true)
  })
})
