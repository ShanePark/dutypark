import type { TodoStatus } from '@/types'
import type { CalendarVisibility } from '@/utils/visibility'

export interface TodoDismissalDraft {
  title: string
  content: string
  status: TodoStatus
  dueDate: string
  tagFriendIds: readonly number[]
}

export interface ScheduleDismissalDraft {
  content: string
  description: string
  startDateTime: string
  endDateTime: string
  visibility: CalendarVisibility
  tagFriendIds: readonly number[]
}

function sameValuesAsSet<T>(left: readonly T[], right: readonly T[]): boolean {
  return left.length === right.length && left.every((value) => right.includes(value))
}

function sameSequence<T>(left: readonly T[], right: readonly T[]): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index])
}

export function hasUnsavedTodoChanges(
  initialDraft: TodoDismissalDraft,
  draft: TodoDismissalDraft,
  initialAttachmentIds: readonly string[],
  attachmentIds: readonly string[],
  hasAttachmentSession: boolean,
): boolean {
  return initialDraft.title !== draft.title
    || initialDraft.content !== draft.content
    || initialDraft.status !== draft.status
    || initialDraft.dueDate !== draft.dueDate
    || !sameValuesAsSet(initialDraft.tagFriendIds, draft.tagFriendIds)
    || !sameSequence(initialAttachmentIds, attachmentIds)
    || hasAttachmentSession
}

export function hasUnsavedScheduleChanges(
  initialDraft: ScheduleDismissalDraft,
  draft: ScheduleDismissalDraft,
  initialAttachmentIds: readonly string[],
  attachmentIds: readonly string[],
  hasAttachmentSession: boolean,
): boolean {
  return initialDraft.content !== draft.content
    || initialDraft.description !== draft.description
    || initialDraft.startDateTime !== draft.startDateTime
    || initialDraft.endDateTime !== draft.endDateTime
    || initialDraft.visibility !== draft.visibility
    || !sameValuesAsSet(initialDraft.tagFriendIds, draft.tagFriendIds)
    || !sameSequence(initialAttachmentIds, attachmentIds)
    || hasAttachmentSession
}
