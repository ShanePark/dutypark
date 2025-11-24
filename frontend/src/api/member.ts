import apiClient from './client'
import type {
  MemberDto,
  FriendDto,
  DDayDto,
  DDaySaveDto,
  RefreshTokenDto,
  CalendarVisibility,
  Page,
} from '@/types'

/**
 * Member API Client
 */
export const memberApi = {
  /**
   * Get my member info
   */
  getMyInfo() {
    return apiClient.get<MemberDto>('/members/me')
  },

  /**
   * Get member info by ID (requires visibility permission)
   */
  getMemberById(memberId: number) {
    return apiClient.get<MemberDto>(`/members/${memberId}`)
  },

  /**
   * Update calendar visibility
   */
  updateVisibility(memberId: number, visibility: CalendarVisibility) {
    return apiClient.put(`/members/${memberId}/visibility`, { visibility })
  },

  /**
   * Assign a manager to manage my schedule
   */
  assignManager(managerId: number) {
    return apiClient.post(`/members/manager/${managerId}`)
  },

  /**
   * Unassign a manager
   */
  unassignManager(managerId: number) {
    return apiClient.delete(`/members/manager/${managerId}`)
  },

  /**
   * Get family members
   */
  getFamilyMembers() {
    return apiClient.get<FriendDto[]>('/members/family')
  },

  /**
   * Get all managers of current user
   */
  getManagers() {
    return apiClient.get<MemberDto[]>('/members/managers')
  },

  /**
   * Check if current user can manage the target member
   */
  canManage(memberId: number) {
    return apiClient.get<boolean>(`/members/${memberId}/canManage`)
  },
}

/**
 * Friend API Client
 */
export const friendApi = {
  /**
   * Get all friends
   */
  getFriends() {
    return apiClient.get<FriendDto[]>('/friends')
  },

  /**
   * Search possible friends to add
   */
  searchPossibleFriends(keyword: string, page = 0, size = 10) {
    return apiClient.get<Page<FriendDto>>('/friends/search', {
      params: { keyword, page, size },
    })
  },

  /**
   * Send friend request
   */
  sendFriendRequest(toMemberId: number) {
    return apiClient.post(`/friends/request/send/${toMemberId}`)
  },

  /**
   * Cancel friend request
   */
  cancelFriendRequest(toMemberId: number) {
    return apiClient.delete(`/friends/request/cancel/${toMemberId}`)
  },

  /**
   * Accept friend request
   */
  acceptFriendRequest(fromMemberId: number) {
    return apiClient.post(`/friends/request/accept/${fromMemberId}`)
  },

  /**
   * Reject friend request
   */
  rejectFriendRequest(fromMemberId: number) {
    return apiClient.post(`/friends/request/reject/${fromMemberId}`)
  },

  /**
   * Send family request (upgrade friend to family)
   */
  sendFamilyRequest(toMemberId: number) {
    return apiClient.put(`/friends/family/${toMemberId}`)
  },

  /**
   * Unfriend
   */
  unfriend(deleteMemberId: number) {
    return apiClient.delete(`/friends/${deleteMemberId}`)
  },

  /**
   * Pin a friend
   */
  pinFriend(friendId: number) {
    return apiClient.patch(`/friends/pin/${friendId}`)
  },

  /**
   * Unpin a friend
   */
  unpinFriend(friendId: number) {
    return apiClient.patch(`/friends/unpin/${friendId}`)
  },

  /**
   * Update friends pin order
   */
  updateFriendsPinOrder(order: number[]) {
    return apiClient.patch('/friends/pin/order', order)
  },
}

/**
 * D-Day API Client
 */
export const ddayApi = {
  /**
   * Get my D-Days
   */
  getMyDDays() {
    return apiClient.get<DDayDto[]>('/dday')
  },

  /**
   * Get D-Days by member ID
   */
  getDDaysByMemberId(memberId: number) {
    return apiClient.get<DDayDto[]>(`/dday/${memberId}`)
  },

  /**
   * Save D-Day (create or update)
   */
  saveDDay(saveDto: DDaySaveDto) {
    return apiClient.post<DDayDto>('/dday', saveDto)
  },

  /**
   * Delete D-Day
   */
  deleteDDay(id: number) {
    return apiClient.delete(`/dday/${id}`)
  },
}

/**
 * Refresh Token API Client
 */
export const refreshTokenApi = {
  /**
   * Get all refresh tokens (sessions)
   */
  getRefreshTokens(validOnly = true) {
    return apiClient.get<RefreshTokenDto[]>('/refresh-tokens', {
      params: { validOnly },
    })
  },

  /**
   * Delete a refresh token (logout from device)
   */
  deleteRefreshToken(id: number) {
    return apiClient.delete(`/refresh-tokens/${id}`)
  },
}

export default {
  member: memberApi,
  friend: friendApi,
  dday: ddayApi,
  refreshToken: refreshTokenApi,
}
