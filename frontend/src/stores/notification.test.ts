import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { notificationApi } from '@/api/notification'
import type { NotificationDto } from '@/types'

vi.mock('@/api/notification', () => ({
  notificationApi: {
    markAsRead: vi.fn(),
  },
}))

function createNotification(id: string, isRead = false): NotificationDto {
  return {
    id,
    type: 'FRIEND_REQUEST_RECEIVED',
    referenceType: 'FRIEND_REQUEST',
    referenceId: 'friend-request-id',
    actorId: 1,
    payload: {
      version: 1,
      actor: {
        name: 'Tester',
        hasProfilePhoto: false,
        profilePhotoVersion: 0,
      },
    },
    isRead,
    createdAt: '2026-05-10T00:00:00Z',
  }
}

describe('notification store', async () => {
  const { useNotificationStore } = await import('./notification')
  const markAsRead = vi.mocked(notificationApi.markAsRead)

  beforeEach(() => {
    Object.defineProperty(globalThis, 'navigator', {
      value: {},
      configurable: true,
    })
    setActivePinia(createPinia())
    markAsRead.mockReset()
  })

  it('marks the only unread notification as read', async () => {
    const unreadNotification = createNotification('notification-1')
    const readNotification = createNotification('notification-2', true)
    const store = useNotificationStore()
    store.unreadCount = 1
    store.recentNotifications = [unreadNotification, readNotification]
    markAsRead.mockResolvedValue({ ...unreadNotification, isRead: true })

    await store.markSingleUnreadAsRead()

    expect(markAsRead).toHaveBeenCalledWith('notification-1')
    expect(store.unreadCount).toBe(0)
    expect(store.recentNotifications[0]?.isRead).toBe(true)
  })

  it('does not mark a different single unread notification than the one captured on open', async () => {
    const store = useNotificationStore()
    store.unreadCount = 1
    store.recentNotifications = [createNotification('notification-2')]

    await store.markSingleUnreadAsRead('notification-1')

    expect(markAsRead).not.toHaveBeenCalled()
    expect(store.unreadCount).toBe(1)
  })

  it('does not auto-read when multiple notifications are unread', async () => {
    const store = useNotificationStore()
    store.unreadCount = 2
    store.recentNotifications = [
      createNotification('notification-1'),
      createNotification('notification-2'),
    ]

    await store.markSingleUnreadAsRead()

    expect(markAsRead).not.toHaveBeenCalled()
    expect(store.unreadCount).toBe(2)
  })
})
