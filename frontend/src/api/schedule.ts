import apiClient from './client'
import type {
  CalendarVisibility,
  Page,
} from '@/types'

export interface ScheduleDto {
  id: string
  content: string
  description: string
  position: number
  year: number
  month: number
  dayOfMonth: number
  startDateTime: string
  endDateTime: string
  isTagged: boolean
  owner: string
  taggedByMember?: ScheduleTagMemberDto | null
  tags: ScheduleTagMemberDto[]
  visibility?: CalendarVisibility
  dateToCompare: string
  attachments: ScheduleAttachmentDto[]
  // Computed fields from backend
  startDate: string
  daysFromStart: number
  endDate: string
  totalDays: number
  curDate: string
}

export interface ScheduleTagMemberDto {
  id: number | null
  name: string
  email?: string | null
  teamId?: number | null
  team?: string | null
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
}

export interface ScheduleAttachmentDto {
  id: string
  originalFilename: string
  contentType: string
  size: number
  hasThumbnail: boolean
  thumbnailUrl: string | null
  orderIndex: number
}

export interface ScheduleSaveDto {
  id?: string
  memberId: number
  content: string
  description?: string
  visibility?: CalendarVisibility
  startDateTime: string
  endDateTime: string
  tagFriendIds?: number[]
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
  aiTimeParsingRequested?: boolean
}

export interface ScheduleSearchResult {
  id: string
  content: string
  description: string
  startDateTime: string
  endDateTime: string
  hasAttachments: boolean
}

export interface ScheduleBasicInfo {
  id: string
  memberId: number
  memberName: string
  startDateTime: string
  content: string
}

export const scheduleApi = {
  getScheduleById: async (scheduleId: string): Promise<ScheduleBasicInfo> => {
    const response = await apiClient.get<ScheduleBasicInfo>(`/schedules/${scheduleId}`)
    return response.data
  },

  // The response is indexed by zero-based day of month for the calendar view.
  getSchedules: async (
    memberId: number,
    year: number,
    month: number
  ): Promise<ScheduleDto[][]> => {
    const response = await apiClient.get<ScheduleDto[][]>('/schedules', {
      params: { memberId, year, month },
    })
    return response.data
  },

  searchSchedules: async (
    memberId: number,
    query: string,
    page: number = 0,
    size: number = 10
  ): Promise<Page<ScheduleSearchResult>> => {
    const response = await apiClient.get<Page<ScheduleSearchResult>>(
      `/schedules/${memberId}/search`,
      {
        params: { q: query, page, size },
      }
    )
    return response.data
  },

  saveSchedule: async (schedule: ScheduleSaveDto): Promise<{ id: string }> => {
    const response = await apiClient.post<{ id: string }>('/schedules', schedule)
    return response.data
  },

  deleteSchedule: async (scheduleId: string): Promise<void> => {
    await apiClient.delete(`/schedules/${scheduleId}`)
  },

  reorderSchedulePositions: async (scheduleIds: string[]): Promise<void> => {
    await apiClient.patch('/schedules/positions', scheduleIds)
  },

  untagSelf: async (scheduleId: string): Promise<void> => {
    await apiClient.delete(`/schedules/${scheduleId}/tags`)
  },
}
