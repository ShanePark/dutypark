import apiClient from './client'
import type {
  DutyCalendarDay,
  DutyCalendarResponse,
  OtherDutyResponse,
  TeamDto,
  HolidayDto,
} from '@/types'

export const dutyApi = {
  /**
   * Get duties for a member for a specific month
   */
  getDuties: async (
    memberId: number,
    year: number,
    month: number
  ): Promise<DutyCalendarDay[]> => {
    const response = await apiClient.get<DutyCalendarDay[]>('/duty', {
      params: { memberId, year, month },
    })
    return response.data
  },

  /**
   * Get duties for other members (friends) - for "view together" feature
   */
  getOtherDuties: async (
    memberIds: number[],
    year: number,
    month: number
  ): Promise<OtherDutyResponse[]> => {
    const response = await apiClient.get<OtherDutyResponse[]>('/duty/others', {
      params: {
        memberIds: memberIds.join(','),
        year,
        month,
      },
    })
    return response.data
  },

  /**
   * Update a single duty
   */
  updateDuty: async (
    memberId: number,
    year: number,
    month: number,
    day: number,
    dutyTypeId: number | null
  ): Promise<boolean> => {
    const response = await apiClient.put<boolean>('/duty/change', {
      memberId,
      year,
      month,
      day,
      dutyTypeId,
    })
    return response.data
  },

  /**
   * Batch update duties for entire month
   */
  batchUpdateDuty: async (
    memberId: number,
    year: number,
    month: number,
    dutyTypeId: number | null
  ): Promise<boolean> => {
    const response = await apiClient.put<boolean>('/duty/batch', {
      memberId,
      year,
      month,
      dutyTypeId,
    })
    return response.data
  },

  /**
   * Get team info with duty types
   */
  getTeam: async (teamId: number): Promise<TeamDto> => {
    const response = await apiClient.get<TeamDto>(`/teams/${teamId}`)
    return response.data
  },

  /**
   * Get calendar structure for a month
   */
  getCalendar: async (
    year: number,
    month: number
  ): Promise<DutyCalendarResponse[][]> => {
    const response = await apiClient.get<DutyCalendarResponse[][]>('/calendar', {
      params: { year, month },
    })
    return response.data
  },

  /**
   * Check if current user can manage the target member's duties
   */
  canManage: async (memberId: number): Promise<boolean> => {
    const response = await apiClient.get<boolean>(`/members/${memberId}/canManage`)
    return response.data
  },

  /**
   * Get holidays for a month (returns Array<List<HolidayDto>> - one list per day index)
   */
  getHolidays: async (year: number, month: number): Promise<HolidayDto[][]> => {
    const response = await apiClient.get<HolidayDto[][]>('/holidays', {
      params: { year, month },
    })
    return response.data
  },
}
