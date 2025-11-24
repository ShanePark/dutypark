import apiClient from './client'
import type {
  MyTeamSummary,
  TeamDto,
  DutyByShift,
  TeamScheduleDto,
  TeamScheduleSaveDto,
} from '@/types'

/**
 * Team API Client
 */
export const teamApi = {
  /**
   * Get team by ID
   */
  getTeam(teamId: number) {
    return apiClient.get<TeamDto>(`/teams/${teamId}`)
  },

  /**
   * Get my team summary with calendar data
   */
  getMyTeamSummary(year: number, month: number) {
    return apiClient.get<MyTeamSummary>('/teams/my', {
      params: { year, month },
    })
  },

  /**
   * Get shift data for a specific day
   */
  getShift(year: number, month: number, day: number) {
    return apiClient.get<DutyByShift[]>('/teams/shift', {
      params: { year, month, day },
    })
  },

  /**
   * Get team schedules for a month
   */
  getTeamSchedules(teamId: number, year: number, month: number) {
    return apiClient.get<TeamScheduleDto[][]>('/teams/schedules', {
      params: { teamId, year, month },
    })
  },

  /**
   * Save team schedule (create or update)
   */
  saveTeamSchedule(saveDto: TeamScheduleSaveDto) {
    return apiClient.post<TeamScheduleDto>('/teams/schedules', saveDto)
  },

  /**
   * Delete team schedule
   */
  deleteTeamSchedule(scheduleId: string) {
    return apiClient.delete(`/teams/schedules/${scheduleId}`)
  },
}

export default teamApi
