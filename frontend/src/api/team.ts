import apiClient from './client'
import type {
  MyTeamSummary,
  TeamDto,
  DutyByShift,
  TeamScheduleDto,
  TeamScheduleSaveDto,
  PageResponse,
  MemberInviteCandidateDto,
  DutyTypeCreateDto,
  DutyTypeUpdateDto,
  DutyBatchTemplateDto,
  DutyBatchTeamResult,
} from '@/types'

export const teamApi = {
  getMyTeamSummary(year: number, month: number) {
    return apiClient.get<MyTeamSummary>('/teams/my', {
      params: { year, month },
    })
  },

  getShift(year: number, month: number, day: number) {
    return apiClient.get<DutyByShift[]>('/teams/shift', {
      params: { year, month, day },
    })
  },

  getTeamSchedules(teamId: number, year: number, month: number) {
    return apiClient.get<TeamScheduleDto[][]>('/teams/schedules', {
      params: { teamId, year, month },
    })
  },

  saveTeamSchedule(saveDto: TeamScheduleSaveDto) {
    return apiClient.post<TeamScheduleDto>('/teams/schedules', saveDto)
  },

  deleteTeamSchedule(scheduleId: string) {
    return apiClient.delete(`/teams/schedules/${scheduleId}`)
  },

  getTeamForManage(teamId: number) {
    return apiClient.get<TeamDto>(`/teams/manage/${teamId}`)
  },

  changeAdmin(teamId: number, memberId: number | null) {
    return apiClient.put(`/teams/manage/${teamId}/admin`, null, {
      params: { memberId },
    })
  },

  updateBatchTemplate(teamId: number, templateName: string | null) {
    return apiClient.patch(`/teams/manage/${teamId}/batch-template`, null, {
      params: { templateName },
    })
  },

  uploadDutyBatch(teamId: number, file: File, year: number, month: number) {
    const formData = new FormData()
    formData.append('file', file)
    formData.append('year', year.toString())
    formData.append('month', month.toString())
    return apiClient.post<DutyBatchTeamResult>(`/teams/manage/${teamId}/duty`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
  },

  updateDefaultDuty(teamId: number, name: string, color: string) {
    return apiClient.patch(`/teams/manage/${teamId}/default-duty`, null, {
      params: { name, color },
    })
  },

  addMember(teamId: number, memberId: number) {
    return apiClient.post(`/teams/manage/${teamId}/members`, null, {
      params: { memberId },
    })
  },

  removeMember(teamId: number, memberId: number) {
    return apiClient.delete(`/teams/manage/${teamId}/members`, {
      params: { memberId },
    })
  },

  searchMembersToInvite(teamId: number, keyword: string, page: number = 0, size: number = 10) {
    return apiClient.get<PageResponse<MemberInviteCandidateDto>>('/teams/manage/members', {
      params: { teamId, keyword, page, size },
    })
  },

  addManager(teamId: number, memberId: number) {
    return apiClient.post(`/teams/manage/${teamId}/manager`, null, {
      params: { memberId },
    })
  },

  removeManager(teamId: number, memberId: number) {
    return apiClient.delete(`/teams/manage/${teamId}/manager`, {
      params: { memberId },
    })
  },

  addDutyType(teamId: number, dto: DutyTypeCreateDto) {
    return apiClient.post(`/teams/manage/${teamId}/duty-types`, dto)
  },

  updateDutyType(teamId: number, dto: DutyTypeUpdateDto) {
    return apiClient.patch(`/teams/manage/${teamId}/duty-types`, dto)
  },

  swapDutyTypePosition(teamId: number, id1: number, id2: number) {
    return apiClient.patch(`/teams/manage/${teamId}/duty-types/swap-position`, null, {
      params: { id1, id2 },
    })
  },

  // Hiding a duty type preserves its historical records.
  updateDutyTypeVisibility(teamId: number, dutyTypeId: number, hidden: boolean) {
    return apiClient.patch(`/teams/manage/${teamId}/duty-types/${dutyTypeId}/visibility`, {
      hidden,
    })
  },

  getDutyBatchTemplates() {
    return apiClient.get<DutyBatchTemplateDto[]>('/duty_batch/templates')
  },
}
