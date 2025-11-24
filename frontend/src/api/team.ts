import apiClient from './client'
import type {
  MyTeamSummary,
  TeamDto,
  DutyByShift,
  TeamScheduleDto,
  TeamScheduleSaveDto,
  PageResponse,
  MemberDto,
  DutyTypeCreateDto,
  DutyTypeUpdateDto,
  DutyBatchTemplateDto,
  DutyBatchTeamResult,
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

  // ========== Team Management APIs ==========

  /**
   * Get team details for management (includes members and duty types)
   */
  getTeamForManage(teamId: number) {
    return apiClient.get<TeamDto>(`/teams/manage/${teamId}`)
  },

  /**
   * Change team admin
   */
  changeAdmin(teamId: number, memberId: number | null) {
    return apiClient.put(`/teams/manage/${teamId}/admin`, null, {
      params: { memberId },
    })
  },

  /**
   * Update batch template
   */
  updateBatchTemplate(teamId: number, templateName: string | null) {
    return apiClient.patch(`/teams/manage/${teamId}/batch-template`, null, {
      params: { templateName },
    })
  },

  /**
   * Update work type
   */
  updateWorkType(teamId: number, workType: string) {
    return apiClient.patch(`/teams/manage/${teamId}/work-type`, null, {
      params: { workType },
    })
  },

  /**
   * Upload duty batch file
   */
  uploadDutyBatch(teamId: number, file: File, year: number, month: number) {
    const formData = new FormData()
    formData.append('file', file)
    formData.append('year', year.toString())
    formData.append('month', month.toString())
    return apiClient.post<DutyBatchTeamResult>(`/teams/manage/${teamId}/duty`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
  },

  /**
   * Update default duty (off duty)
   */
  updateDefaultDuty(teamId: number, name: string, color: string) {
    return apiClient.patch(`/teams/manage/${teamId}/default-duty`, null, {
      params: { name, color },
    })
  },

  /**
   * Add member to team
   */
  addMember(teamId: number, memberId: number) {
    return apiClient.post(`/teams/manage/${teamId}/members`, null, {
      params: { memberId },
    })
  },

  /**
   * Remove member from team
   */
  removeMember(teamId: number, memberId: number) {
    return apiClient.delete(`/teams/manage/${teamId}/members`, {
      params: { memberId },
    })
  },

  /**
   * Search members to invite to team
   */
  searchMembersToInvite(keyword: string, page: number = 0, size: number = 10) {
    return apiClient.get<PageResponse<MemberDto>>('/teams/manage/members', {
      params: { keyword, page, size },
    })
  },

  /**
   * Add manager role to member
   */
  addManager(teamId: number, memberId: number) {
    return apiClient.post(`/teams/manage/${teamId}/manager`, null, {
      params: { memberId },
    })
  },

  /**
   * Remove manager role from member
   */
  removeManager(teamId: number, memberId: number) {
    return apiClient.delete(`/teams/manage/${teamId}/manager`, {
      params: { memberId },
    })
  },

  // ========== Duty Type APIs ==========

  /**
   * Add duty type
   */
  addDutyType(teamId: number, dto: DutyTypeCreateDto) {
    return apiClient.post(`/teams/manage/${teamId}/duty-types`, dto)
  },

  /**
   * Update duty type
   */
  updateDutyType(teamId: number, dto: DutyTypeUpdateDto) {
    return apiClient.patch(`/teams/manage/${teamId}/duty-types`, dto)
  },

  /**
   * Swap duty type positions
   */
  swapDutyTypePosition(teamId: number, id1: number, id2: number) {
    return apiClient.patch(`/teams/manage/${teamId}/duty-types/swap-position`, null, {
      params: { id1, id2 },
    })
  },

  /**
   * Delete duty type
   */
  deleteDutyType(teamId: number, dutyTypeId: number) {
    return apiClient.delete(`/teams/manage/${teamId}/duty-types/${dutyTypeId}`)
  },

  /**
   * Get duty batch templates
   */
  getDutyBatchTemplates() {
    return apiClient.get<DutyBatchTemplateDto[]>('/duty_batch/templates')
  },
}

export default teamApi
