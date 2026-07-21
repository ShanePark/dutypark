import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { notificationApi } from '@/api/notification'
import type { NotificationDto } from '@/types'

vi.mock('@/api/notification', () => ({
  notificationApi: {
    markAsRead: vi.fn(),
    markAllAsRead: vi.fn(),
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
  const markAllAsRead = vi.mocked(notificationApi.markAllAsRead)

  beforeEach(() => {
    Object.defineProperty(globalThis, 'navigator', {
      value: {},
      configurable: true,
    })
    setActivePinia(createPinia())
    markAsRead.mockReset()
    markAllAsRead.mockReset()
  })

  it('marks every notification as read', async () => {
    const store = useNotificationStore()
    store.unreadCount = 2
    store.recentNotifications = [
      createNotification('notification-1'),
      createNotification('notification-2', true),
      createNotification('notification-3'),
    ]
    markAllAsRead.mockResolvedValue({ count: 2 })

    await store.markAllAsRead()

    expect(markAllAsRead).toHaveBeenCalledTimes(1)
    expect(store.unreadCount).toBe(0)
    expect(store.recentNotifications.every(n => n.isRead)).toBe(true)
  })
})
