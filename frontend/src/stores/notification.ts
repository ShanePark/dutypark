import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { NotificationDto } from '@/types'
import { notificationApi } from '@/api/notification'

const MAX_BACKOFF_MS = 5 * 60 * 1000 // 5 minutes
const BASE_INTERVAL_MS = 10000 // 10 seconds

export const useNotificationStore = defineStore('notification', () => {
  const unreadNotifications = ref<NotificationDto[]>([])
  const recentNotifications = ref<NotificationDto[]>([])
  const unreadCount = ref(0)
  const friendRequestCount = ref(0)
  const isLoading = ref(false)
  const pollingIntervalId = ref<number | null>(null)
  const consecutiveFailures = ref(0)
  const isPollingPaused = ref(false)
  const friendsRefreshTrigger = ref(0)

  // Getters
  const hasUnread = computed(() => unreadCount.value > 0)
  const hasFriendRequests = computed(() => friendRequestCount.value > 0)
  const unreadCountDisplay = computed(() =>
    unreadCount.value > 99 ? '99+' : String(unreadCount.value)
  )
  const friendRequestCountDisplay = computed(() =>
    friendRequestCount.value > 99 ? '99+' : String(friendRequestCount.value)
  )

  /**
   * Fetch only unread count (lightweight for polling)
   * Does NOT update friendRequestCount - that's only updated on specific events
   */
  async function fetchUnreadCount(): Promise<void> {
    try {
      const prevUnreadCount = unreadCount.value
      const countData = await notificationApi.getCount()
      unreadCount.value = countData.unreadCount
      consecutiveFailures.value = 0

      // If new notifications arrived, check if any are friend requests
      if (countData.unreadCount > prevUnreadCount) {
        checkForNewFriendRequests()
      }
    } catch (error) {
      consecutiveFailures.value++
      console.warn('Failed to fetch notification count:', error)
    }
  }

  /**
   * Fetch friend request count (called on app start and when friend-related notifications arrive)
   */
  async function fetchFriendRequestCount(): Promise<void> {
    try {
      friendRequestCount.value = await notificationApi.getFriendRequestCount()
    } catch (error) {
      console.warn('Failed to fetch friend request count:', error)
    }
  }

  /**
   * Check if new notifications include friend requests
   */
  async function checkForNewFriendRequests(): Promise<void> {
    try {
      const notifications = await notificationApi.getUnreadNotifications()
      const hasFriendRequestNotification = notifications.some(n =>
        n.type === 'FRIEND_REQUEST_RECEIVED' || n.type === 'FAMILY_REQUEST_RECEIVED'
      )
      if (hasFriendRequestNotification) {
        await fetchFriendRequestCount()
      }
    } catch (error) {
      console.warn('Failed to check for friend request notifications:', error)
    }
  }

  /**
   * Fetch unread notifications list
   */
  async function fetchUnreadNotifications(): Promise<void> {
    isLoading.value = true
    try {
      unreadNotifications.value = await notificationApi.getUnreadNotifications()
      unreadCount.value = unreadNotifications.value.length
      consecutiveFailures.value = 0
    } catch (error) {
      consecutiveFailures.value++
      console.warn('Failed to fetch unread notifications:', error)
    } finally {
      isLoading.value = false
    }
  }

  /**
   * Fetch recent notifications (read + unread) for dropdown
   */
  async function fetchRecentNotifications(): Promise<void> {
    isLoading.value = true
    try {
      const page = await notificationApi.getNotifications(0, 10)
      recentNotifications.value = page.content
      consecutiveFailures.value = 0
    } catch (error) {
      consecutiveFailures.value++
      console.warn('Failed to fetch recent notifications:', error)
    } finally {
      isLoading.value = false
    }
  }

  /**
   * Mark a single notification as read
   */
  async function markAsRead(id: string): Promise<void> {
    try {
      await notificationApi.markAsRead(id)
      // Update local state - unread list
      const unreadIndex = unreadNotifications.value.findIndex(n => n.id === id)
      if (unreadIndex !== -1) {
        unreadNotifications.value.splice(unreadIndex, 1)
        unreadCount.value = Math.max(0, unreadCount.value - 1)
      }
      // Update local state - recent list
      const recentNotification = recentNotifications.value.find(n => n.id === id)
      if (recentNotification) {
        // Decrease count if unread and not already handled above
        if (!recentNotification.isRead && unreadIndex === -1) {
          unreadCount.value = Math.max(0, unreadCount.value - 1)
        }
        recentNotification.isRead = true
      }
    } catch (error) {
      console.error('Failed to mark notification as read:', error)
      throw error
    }
  }

  /**
   * Mark all notifications as read
   */
  async function markAllAsRead(): Promise<void> {
    try {
      await notificationApi.markAllAsRead()
      // Clear unread list
      unreadNotifications.value = []
      unreadCount.value = 0
      // Update recent list - mark all as read
      recentNotifications.value.forEach(n => {
        n.isRead = true
      })
    } catch (error) {
      console.error('Failed to mark all notifications as read:', error)
      throw error
    }
  }

  /**
   * Calculate polling interval with exponential backoff
   */
  function getPollingInterval(): number {
    if (consecutiveFailures.value === 0) {
      return BASE_INTERVAL_MS
    }
    const backoffMs = Math.min(
      BASE_INTERVAL_MS * Math.pow(2, consecutiveFailures.value),
      MAX_BACKOFF_MS
    )
    return backoffMs
  }

  /**
   * Handle visibility change for efficient polling
   */
  function handleVisibilityChange(): void {
    if (document.visibilityState === 'visible') {
      isPollingPaused.value = false
      // Immediate fetch when tab becomes visible
      fetchUnreadCount()
    } else {
      isPollingPaused.value = true
    }
  }

  /**
   * Start polling for notification count
   */
  function startPolling(intervalMs: number = BASE_INTERVAL_MS): void {
    // Stop any existing polling
    stopPolling()

    // Initial fetch - includes friend request count on app start
    fetchUnreadCount()
    fetchFriendRequestCount()

    // Add visibility change listener
    document.addEventListener('visibilitychange', handleVisibilityChange)

    // Start polling interval
    const poll = () => {
      if (!isPollingPaused.value) {
        fetchUnreadCount()
      }
      // Schedule next poll with potentially adjusted interval
      pollingIntervalId.value = window.setTimeout(poll, getPollingInterval())
    }

    pollingIntervalId.value = window.setTimeout(poll, intervalMs)
  }

  /**
   * Stop polling
   */
  function stopPolling(): void {
    if (pollingIntervalId.value !== null) {
      clearTimeout(pollingIntervalId.value)
      pollingIntervalId.value = null
    }
    document.removeEventListener('visibilitychange', handleVisibilityChange)
    isPollingPaused.value = false
  }

  /**
   * Reset store state
   */
  function $reset(): void {
    stopPolling()
    unreadNotifications.value = []
    recentNotifications.value = []
    unreadCount.value = 0
    friendRequestCount.value = 0
    isLoading.value = false
    consecutiveFailures.value = 0
  }

  /**
   * Trigger friends page to refresh data
   */
  function triggerFriendsRefresh(): void {
    friendsRefreshTrigger.value++
  }

  return {
    // State
    unreadNotifications,
    recentNotifications,
    unreadCount,
    friendRequestCount,
    isLoading,
    friendsRefreshTrigger,
    // Getters
    hasUnread,
    hasFriendRequests,
    unreadCountDisplay,
    friendRequestCountDisplay,
    // Actions
    fetchUnreadCount,
    fetchFriendRequestCount,
    fetchUnreadNotifications,
    fetchRecentNotifications,
    markAsRead,
    markAllAsRead,
    startPolling,
    stopPolling,
    triggerFriendsRefresh,
    $reset,
  }
})
