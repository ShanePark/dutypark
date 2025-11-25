import apiClient from './client'
import type { DashboardMyDetail, DashboardFriendInfo } from '@/types'

export const dashboardApi = {
  /**
   * Get my dashboard data (duty, schedules for today)
   */
  getMyDashboard: async (): Promise<DashboardMyDetail> => {
    const response = await apiClient.get<DashboardMyDetail>('/dashboard/my')
    return response.data
  },

  /**
   * Get friends dashboard data (friends list, pending requests)
   */
  getFriendsDashboard: async (): Promise<DashboardFriendInfo> => {
    const response = await apiClient.get<DashboardFriendInfo>('/dashboard/friends')
    return response.data
  },
}
