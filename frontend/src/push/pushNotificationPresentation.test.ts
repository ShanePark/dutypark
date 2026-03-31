import { describe, expect, it } from 'vitest'
import type { NotificationDto, PushNotificationPayload } from '@/types'
import {
  resolvePushNotificationBody,
  resolvePushNotificationId,
} from './pushNotificationPresentation'

function createNotification(
  overrides: Partial<NotificationDto> = {},
): NotificationDto {
  return {
    id: 'notification-id',
    type: 'SCHEDULE_TAGGED',
    referenceType: 'SCHEDULE',
    referenceId: 'schedule-id',
    actorId: 1,
    payload: {
      version: 1,
      actor: {
        name: 'Shane',
        hasProfilePhoto: true,
        profilePhotoVersion: 3,
      },
      scheduleTitle: '팀 회의',
    },
    isRead: false,
    createdAt: '2026-03-31T12:00:00',
    ...overrides,
  } as NotificationDto
}

function createPayload(overrides: Partial<PushNotificationPayload> = {}): PushNotificationPayload {
  return {
    type: 'SCHEDULE_TAGGED',
    url: '/duty/1',
    notificationId: 'notification-id',
    unreadCount: 2,
    notification: createNotification(),
    ...overrides,
  }
}

describe('pushNotificationPresentation', () => {
  it('renders detailed notification copy with the worker locale', () => {
    expect(resolvePushNotificationBody(createPayload(), 'en-US')).toBe('Shane tagged you in [팀 회의].')
  })

  it('falls back to a generic message when notification details are missing', () => {
    expect(resolvePushNotificationBody(createPayload({ notification: null }), 'ja-JP')).toBe('新しい通知があります。')
  })

  it('falls back to the embedded notification id when top-level id is absent', () => {
    expect(resolvePushNotificationId(createPayload({ notificationId: null }))).toBe('notification-id')
  })
})
