import apiClient from './client'
import type {
  CalendarVisibility,
  DashboardScheduleDto,
  Page,
} from '@/types'

// Schedule DTO matching backend ScheduleDto
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

// Save DTO matching backend ScheduleSaveDto
export interface ScheduleSaveDto {
  id?: string
  memberId: number
  content: string
  description?: string
  visibility?: CalendarVisibility
  startDateTime: string
  endDateTime: string
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}

// Search result DTO
export interface ScheduleSearchResult {
  id: string
  content: string
  description: string
  startDateTime: string
  endDateTime: string
  hasAttachments: boolean
}

// Basic info response for schedule lookup
export interface ScheduleBasicInfo {
  id: string
  memberId: number
  memberName: string
  startDateTime: string
  content: string
}

export const scheduleApi = {
  /**
   * Get basic schedule info by ID
   * Used for notification navigation to schedule
   */
  getScheduleById: async (scheduleId: string): Promise<ScheduleBasicInfo> => {
    const response = await apiClient.get<ScheduleBasicInfo>(`/schedules/${scheduleId}`)
    return response.data
  },

  /**
   * Get schedules for a member for a specific month
   * Returns array indexed by day of month (0-based, matching calendar view)
   */
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

  /**
   * Search schedules for a member
   */
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

  /**
   * Create or update a schedule
   */
  saveSchedule: async (schedule: ScheduleSaveDto): Promise<{ id: string }> => {
    const response = await apiClient.post<{ id: string }>('/schedules', schedule)
    return response.data
  },

  /**
   * Delete a schedule
   */
  deleteSchedule: async (scheduleId: string): Promise<void> => {
    await apiClient.delete(`/schedules/${scheduleId}`)
  },

  /**
   * Reorder schedule positions (for drag and drop)
   */
  reorderSchedulePositions: async (scheduleIds: string[]): Promise<void> => {
    await apiClient.patch('/schedules/positions', scheduleIds)
  },

  /**
   * Tag a friend to a schedule
   */
  tagFriend: async (scheduleId: string, friendId: number): Promise<void> => {
    await apiClient.post(`/schedules/${scheduleId}/tags/${friendId}`)
  },

  /**
   * Untag a friend from a schedule
   */
  untagFriend: async (scheduleId: string, friendId: number): Promise<void> => {
    await apiClient.delete(`/schedules/${scheduleId}/tags/${friendId}`)
  },

  /**
   * Untag self from a schedule
   */
  untagSelf: async (scheduleId: string): Promise<void> => {
    await apiClient.delete(`/schedules/${scheduleId}/tags`)
  },
}
