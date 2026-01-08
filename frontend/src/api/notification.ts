import apiClient from './client'
import type { NotificationDto, NotificationCountDto, Page } from '@/types'

export const notificationApi = {
  /**
   * Get paginated notifications
   */
  getNotifications: async (page: number = 0, size: number = 20): Promise<Page<NotificationDto>> => {
    const response = await apiClient.get<Page<NotificationDto>>('/notifications', {
      params: { page, size }
    })
    return response.data
  },

  /**
   * Get unread notifications (max 10)
   */
  getUnreadNotifications: async (): Promise<NotificationDto[]> => {
    const response = await apiClient.get<NotificationDto[]>('/notifications/unread')
    return response.data
  },

  /**
   * Get notification counts (unread, total)
   */
  getCount: async (): Promise<NotificationCountDto> => {
    const response = await apiClient.get<NotificationCountDto>('/notifications/count')
    return response.data
  },

  /**
   * Get friend request count only
   */
  getFriendRequestCount: async (): Promise<number> => {
    const response = await apiClient.get<{ count: number }>('/notifications/friend-request-count')
    return response.data.count
  },

  /**
   * Mark a notification as read
   */
  markAsRead: async (id: string): Promise<NotificationDto> => {
    const response = await apiClient.patch<NotificationDto>(`/notifications/${id}/read`)
    return response.data
  },

  /**
   * Mark all notifications as read
   */
  markAllAsRead: async (): Promise<{ count: number }> => {
    const response = await apiClient.patch<{ count: number }>('/notifications/read-all')
    return response.data
  },

  /**
   * Delete a notification
   */
  deleteNotification: async (id: string): Promise<void> => {
    await apiClient.delete(`/notifications/${id}`)
  },

  /**
   * Delete all read notifications
   */
  deleteAllRead: async (): Promise<{ count: number }> => {
    const response = await apiClient.delete<{ count: number }>('/notifications/read')
    return response.data
  },
}
