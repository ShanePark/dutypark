import { defineStore } from 'pinia'
import { ref, computed, watch } from 'vue'
import type { NotificationDto } from '@/types'
import { notificationApi } from '@/api/notification'

const MAX_BACKOFF_MS = 5 * 60 * 1000 // 5 minutes
const BASE_INTERVAL_MS = 10000 // 10 seconds
const RESUME_SYNC_DEBOUNCE_MS = 500

type NavigatorBadgeApi = Navigator & {
  setAppBadge?: (count?: number) => Promise<void>
  clearAppBadge?: () => Promise<void>
}

type ServiceWorkerRegistrationBadgeApi = ServiceWorkerRegistration & {
  setAppBadge?: (count?: number) => Promise<void>
  clearAppBadge?: () => Promise<void>
}

/**
 * Update app icon badge for iOS PWA (requires iOS 16.4+)
 */
function updateAppBadge(count: number): void {
  const navBadge = navigator as NavigatorBadgeApi
  const fallbackOnServiceWorker = () => {
    if (!('serviceWorker' in navigator)) return
    void navigator.serviceWorker.getRegistration()
      .then((registration) => {
        if (!registration) return
        const registrationBadge = registration as ServiceWorkerRegistrationBadgeApi
        if (count > 0) {
          if (registrationBadge.setAppBadge) {
            return registrationBadge.setAppBadge(count)
          }
          return undefined
        }

        if (registrationBadge.clearAppBadge) {
          return registrationBadge.clearAppBadge()
        }
        if (registrationBadge.setAppBadge) {
          return registrationBadge.setAppBadge(0)
        }
        return undefined
      })
      .catch(() => undefined)
  }

  if (count > 0) {
    if (navBadge.setAppBadge) {
      void navBadge.setAppBadge(count).catch(() => {
        fallbackOnServiceWorker()
      })
      return
    }
    fallbackOnServiceWorker()
    return
  }

  if (navBadge.clearAppBadge) {
    void navBadge.clearAppBadge().catch(() => {
      fallbackOnServiceWorker()
    })
    return
  }
  if (navBadge.setAppBadge) {
    void navBadge.setAppBadge(0).catch(() => {
      fallbackOnServiceWorker()
    })
    return
  }
  fallbackOnServiceWorker()
}

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
  const isFetchingUnreadCount = ref(false)
  const lastResumeSyncAt = ref(0)

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
    if (isFetchingUnreadCount.value) {
      return
    }

    isFetchingUnreadCount.value = true
    try {
      const prevUnreadCount = unreadCount.value
      const countData = await notificationApi.getCount()
      unreadCount.value = countData.unreadCount
      updateAppBadge(countData.unreadCount)
      consecutiveFailures.value = 0

      // If new notifications arrived, check if any are friend requests
      if (countData.unreadCount > prevUnreadCount) {
        checkForNewFriendRequests()
      }
    } catch (error) {
      consecutiveFailures.value++
      console.warn('Failed to fetch notification count:', error)
    } finally {
      isFetchingUnreadCount.value = false
    }
  }

  async function fetchFriendRequestCount(): Promise<void> {
    try {
      friendRequestCount.value = await notificationApi.getFriendRequestCount()
    } catch (error) {
      console.warn('Failed to fetch friend request count:', error)
    }
  }

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

  async function fetchRecentNotifications(): Promise<boolean> {
    isLoading.value = true
    try {
      const page = await notificationApi.getNotifications(0, 10)
      recentNotifications.value = page.content
      consecutiveFailures.value = 0
      return true
    } catch (error) {
      consecutiveFailures.value++
      console.warn('Failed to fetch recent notifications:', error)
      return false
    } finally {
      isLoading.value = false
    }
  }

  async function markAsRead(id: string): Promise<void> {
    try {
      await notificationApi.markAsRead(id)
      const unreadIndex = unreadNotifications.value.findIndex(n => n.id === id)
      if (unreadIndex !== -1) {
        unreadNotifications.value.splice(unreadIndex, 1)
        unreadCount.value = Math.max(0, unreadCount.value - 1)
      }
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

  async function markAllAsRead(): Promise<void> {
    try {
      await notificationApi.markAllAsRead()
      unreadNotifications.value = []
      unreadCount.value = 0
      recentNotifications.value.forEach(n => {
        n.isRead = true
      })
    } catch (error) {
      console.error('Failed to mark all notifications as read:', error)
      throw error
    }
  }

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

  function handleVisibilityChange(): void {
    if (document.visibilityState === 'visible') {
      handleAppResume()
    } else {
      isPollingPaused.value = true
    }
  }

  /**
   * Handle app resume for mobile PWA environments where visibility events can be inconsistent
   */
  function handleAppResume(): void {
    const now = Date.now()
    if (now - lastResumeSyncAt.value < RESUME_SYNC_DEBOUNCE_MS) {
      return
    }
    lastResumeSyncAt.value = now
    isPollingPaused.value = false
    fetchUnreadCount()
  }

  function startPolling(intervalMs: number = BASE_INTERVAL_MS): void {
    stopPolling()

    fetchUnreadCount()
    fetchFriendRequestCount()

    document.addEventListener('visibilitychange', handleVisibilityChange)
    window.addEventListener('focus', handleAppResume)
    window.addEventListener('pageshow', handleAppResume)

    const poll = () => {
      if (!isPollingPaused.value) {
        fetchUnreadCount()
      }
      pollingIntervalId.value = window.setTimeout(poll, getPollingInterval())
    }

    pollingIntervalId.value = window.setTimeout(poll, intervalMs)
  }

  function stopPolling(): void {
    if (pollingIntervalId.value !== null) {
      clearTimeout(pollingIntervalId.value)
      pollingIntervalId.value = null
    }
    document.removeEventListener('visibilitychange', handleVisibilityChange)
    window.removeEventListener('focus', handleAppResume)
    window.removeEventListener('pageshow', handleAppResume)
    isPollingPaused.value = false
  }

  function triggerFriendsRefresh(): void {
    friendsRefreshTrigger.value++
  }

  // Update app icon badge when unread count changes (iOS PWA)
  watch(unreadCount, (count) => {
    updateAppBadge(count)
  })

  return {
    unreadNotifications,
    recentNotifications,
    unreadCount,
    isLoading,
    friendsRefreshTrigger,
    hasUnread,
    hasFriendRequests,
    unreadCountDisplay,
    friendRequestCountDisplay,
    fetchUnreadCount,
    fetchFriendRequestCount,
    fetchRecentNotifications,
    markAsRead,
    markAllAsRead,
    startPolling,
    stopPolling,
    triggerFriendsRefresh,
  }
})
