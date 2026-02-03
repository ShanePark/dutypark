import type { CalendarVisibility } from '@/types'

export interface LocalTodo {
  id: string
  title: string
  content: string
  status: 'TODO' | 'IN_PROGRESS' | 'DONE'
  createdDate: string
  completedDate?: string
  dueDate?: string
  isOverdue?: boolean
  hasAttachments: boolean
  attachments: Array<{
    id: string
    name: string
    originalFilename: string
    size: number
    contentType: string
    isImage: boolean
    hasThumbnail: boolean
    thumbnailUrl?: string
    downloadUrl: string
  }>
}

export type TodoDueItem = Pick<LocalTodo, 'id' | 'title' | 'status'>

export interface DutyType {
  id: number | null
  name: string
  color: string | null
}

export interface DutyTypeWithCount extends DutyType {
  cnt: number
}

export interface Schedule {
  id: string
  content: string
  contentWithoutTime?: string
  description?: string
  startDateTime: string
  endDateTime: string
  visibility: CalendarVisibility
  isMine: boolean
  isTagged: boolean
  owner?: string
  taggedBy?: string
  attachments?: Array<{
    id: string
    originalFilename: string
    contentType: string
    size: number
    thumbnailUrl?: string
    hasThumbnail: boolean
  }>
  tags?: Array<{ id: number; name: string }>
  daysFromStart: number
  totalDays: number
}

export interface LocalDDay {
  id: number
  title: string
  date: string
  isPrivate: boolean
  calc: number
  dDayText: string
}

export interface Friend {
  id: number
  name: string
}

export interface CalendarDay {
  year: number
  month: number
  day: number
  isCurrentMonth?: boolean
  isPrev?: boolean
  isNext?: boolean
  isToday?: boolean
}

export interface DutyDay {
  dutyType: string
  dutyColor: string
  dutyTypeId: number | null
}

export interface OtherDuty {
  memberId: number
  memberName: string
  duties: Array<{
    dutyType: string
    dutyColor: string
  }>
}
