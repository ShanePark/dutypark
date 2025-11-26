import axios from 'axios'
import type {
  PageResponse,
  SimpleTeam,
  TeamCreateDto,
  TeamDto,
  TeamNameCheckResult,
  MemberDto,
  RefreshTokenDto,
} from '@/types'

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
   * Get all members
   */
  getAllMembers() {
    return adminClient.get<MemberDto[]>('/members-all')
  },

  /**
   * Get all refresh tokens (sessions)
   */
  getAllRefreshTokens() {
    return adminClient.get<RefreshTokenDto[]>('/refresh-tokens')
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
}

export default adminApi
