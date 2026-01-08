import { useRouter } from 'vue-router'
import { scheduleApi } from '@/api/schedule'
import type { NotificationDto, NotificationReferenceType } from '@/types'

export function useNotificationNavigation() {
  const router = useRouter()

  function getNavigationPath(notification: NotificationDto): string | null {
    const { referenceType, referenceId } = notification

    if (!referenceType) return null

    // SCHEDULE type is handled separately in navigateToNotification
    if (referenceType === 'SCHEDULE') return null

    const typeRoutes: Record<NotificationReferenceType, string | null> = {
      FRIEND_REQUEST: '/friends',
      SCHEDULE: null,
      MEMBER: referenceId ? `/duty/${referenceId}` : null,
    }

    return typeRoutes[referenceType] || null
  }

  async function navigateToNotification(
    notification: NotificationDto,
    options?: {
      onScheduleError?: (error: unknown) => void
      onSamePage?: () => void
    }
  ): Promise<boolean> {
    // Handle SCHEDULE type - fetch schedule info and navigate to own calendar with date params
    if (notification.referenceType === 'SCHEDULE' && notification.referenceId) {
      try {
        const scheduleInfo = await scheduleApi.getScheduleById(notification.referenceId)
        const date = new Date(scheduleInfo.startDateTime)
        const year = date.getFullYear()
        const month = date.getMonth() + 1
        const day = date.getDate()
        router.push({
          path: '/duty/me',
          query: { year: String(year), month: String(month), day: String(day) }
        })
        return true
      } catch (error) {
        console.error('Failed to fetch schedule info:', error)
        options?.onScheduleError?.(error)
        return false
      }
    }

    const path = getNavigationPath(notification)
    if (path) {
      // Check if already on the same page
      if (router.currentRoute.value.path === path) {
        options?.onSamePage?.()
      } else {
        router.push(path)
      }
      return true
    }

    return false
  }

  return {
    getNavigationPath,
    navigateToNotification,
  }
}
