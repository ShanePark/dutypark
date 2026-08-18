import axios from 'axios'
import type {
  PageResponse,
  SimpleTeam,
  TeamCreateDto,
  TeamDto,
  TeamNameCheckResult,
  AdminMemberDto,
  AdminMemberDetailDto,
  RefreshTokenDto,
} from '@/types'
import type {
  AdminInquiryDto,
  AdminReportDetailDto,
  AdminReportSummaryDto,
  InquiryStatusFilter,
  ReportStatusFilter,
  UpdateInquiryStatusRequest,
  UpdateReportStatusRequest,
} from '@/types/adminModeration'

// Separate axios instance for admin API (different base path)
// Cookies are sent automatically via withCredentials
const adminClient = axios.create({
  baseURL: '/admin/api',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true,
})

/**
 * Admin API Client
 */
export const adminApi = {
  // ========== Member Management ==========

  /**
   * Get members with pagination
   */
  getMembers(keyword: string = '', page: number = 0, size: number = 10) {
    return adminClient.get<PageResponse<AdminMemberDto>>('/members', {
      params: { keyword: keyword || undefined, page, size },
    })
  },

  /**
   * Get detailed member stats for admin modal
   */
  getMemberDetail(memberId: number) {
    return adminClient.get<AdminMemberDetailDto>(`/members/${memberId}`)
  },

  /**
   * Get all refresh tokens (sessions)
   */
  getAllRefreshTokens() {
    return adminClient.get<RefreshTokenDto[]>('/refresh-tokens')
  },

  /**
   * Suspend a member: sign-in is refused and every existing session is revoked.
   * Idempotent when the member is already suspended.
   */
  suspendMember(memberId: number) {
    return adminClient.post(`/members/${memberId}/suspension`)
  },

  /**
   * Lift a member suspension. Idempotent when the member is not suspended.
   */
  unsuspendMember(memberId: number) {
    return adminClient.delete(`/members/${memberId}/suspension`)
  },

  // ========== Team Management ==========

  /**
   * Get all teams with pagination
   */
  getTeams(keyword: string = '', page: number = 0, size: number = 10) {
    return adminClient.get<PageResponse<SimpleTeam>>('/teams', {
      params: { keyword, page, size },
    })
  },

  /**
   * Create a new team
   */
  createTeam(dto: TeamCreateDto) {
    return adminClient.post<TeamDto>('/teams', dto)
  },

  /**
   * Check team name availability
   */
  checkTeamName(name: string) {
    return adminClient.post<TeamNameCheckResult>('/teams/check', { name })
  },

  /**
   * Delete a team
   */
  deleteTeam(teamId: number) {
    return adminClient.delete(`/teams/${teamId}`)
  },

  // ========== Report Management ==========

  /**
   * Get content reports with pagination. `ALL` drops the status filter.
   */
  getReports(status: ReportStatusFilter = 'OPEN', page: number = 0, size: number = 10) {
    return adminClient.get<PageResponse<AdminReportSummaryDto>>('/reports', {
      params: { status: status === 'ALL' ? undefined : status, page, size },
    })
  },

  /**
   * Get a single report with its snapshot and moderation state
   */
  getReport(reportId: string) {
    return adminClient.get<AdminReportDetailDto>(`/reports/${reportId}`)
  },

  /**
   * Resolve or dismiss a report, optionally recording an admin memo
   */
  updateReportStatus(reportId: string, request: UpdateReportStatusRequest) {
    return adminClient.patch<AdminReportDetailDto>(`/reports/${reportId}/status`, request)
  },

  /**
   * Delete the reported content. Member targets are not deletable.
   */
  deleteReportTarget(reportId: string) {
    return adminClient.delete<AdminReportDetailDto>(`/reports/${reportId}/target`)
  },

  // ========== Inquiry Management ==========

  /**
   * Get inquiries with pagination. `ALL` drops the status filter.
   */
  getInquiries(status: InquiryStatusFilter = 'OPEN', page: number = 0, size: number = 10) {
    return adminClient.get<PageResponse<AdminInquiryDto>>('/inquiries', {
      params: { status: status === 'ALL' ? undefined : status, page, size },
    })
  },

  /**
   * Get a single inquiry
   */
  getInquiry(inquiryId: string) {
    return adminClient.get<AdminInquiryDto>(`/inquiries/${inquiryId}`)
  },

  /**
   * Change an inquiry status, optionally recording an admin memo
   */
  updateInquiryStatus(inquiryId: string, request: UpdateInquiryStatusRequest) {
    return adminClient.patch<AdminInquiryDto>(`/inquiries/${inquiryId}/status`, request)
  },
}

export default adminApi
