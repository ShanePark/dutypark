import { describe, expect, it } from 'vitest'
import type { NotificationDto } from '@/types'
import { notificationRendererRegistry } from '@/notifications/renderers'
import {
  formatNotificationMessage,
  getNotificationActor,
  type NotificationTranslate,
} from './notificationFormatter'

const templates: Record<string, string> = {
  'notifications.items.generic': '새 알림이 도착했습니다.',
  'notifications.items.friendRequestReceived.v1': '{actorName}님이 친구 요청을 보냈습니다.',
  'notifications.items.friendRequestReceivedFallback.v1': '친구 요청이 도착했습니다.',
  'notifications.items.friendRequestAccepted.v1': '{actorName}님이 친구 요청을 수락했습니다.',
  'notifications.items.friendRequestAcceptedFallback.v1': '친구 요청이 수락되었습니다.',
  'notifications.items.familyRequestReceived.v1': '{actorName}님이 가족 요청을 보냈습니다.',
  'notifications.items.familyRequestReceivedFallback.v1': '가족 요청이 도착했습니다.',
  'notifications.items.familyRequestAccepted.v1': '{actorName}님이 가족 요청을 수락했습니다.',
  'notifications.items.familyRequestAcceptedFallback.v1': '가족 요청이 수락되었습니다.',
  'notifications.items.scheduleTagged.v1': '{actorName}님의 [{scheduleTitle}] 일정에 태그되었습니다.',
  'notifications.items.scheduleTaggedFallback.v1': '[{scheduleTitle}] 일정에 태그되었습니다.',
  'notifications.items.todoTagged.v1': '{actorName}님의 [{todoTitle}] TODO에 태그되었습니다.',
  'notifications.items.todoTaggedFallback.v1': '[{todoTitle}] TODO에 태그되었습니다.',
  'notifications.items.todoStatusTodo.v1': '{actorName}님이 [{todoTitle}] TODO를 할 일로 변경했습니다.',
  'notifications.items.todoStatusTodoFallback.v1': '[{todoTitle}] TODO가 할 일로 변경되었습니다.',
  'notifications.items.todoStatusInProgress.v1': '{actorName}님이 [{todoTitle}] TODO를 진행중으로 변경했습니다.',
  'notifications.items.todoStatusInProgressFallback.v1': '[{todoTitle}] TODO가 진행중으로 변경되었습니다.',
  'notifications.items.todoStatusDone.v1': '{actorName}님이 [{todoTitle}] TODO를 완료 처리했습니다.',
  'notifications.items.todoStatusDoneFallback.v1': '[{todoTitle}] TODO가 완료 처리되었습니다.',
}

const t: NotificationTranslate = (key, params = {}) => {
  const template = templates[key] ?? key
  return Object.entries(params).reduce((message, [paramKey, value]) => {
    return message.split(`{${paramKey}}`).join(String(value))
  }, template)
}

function createNotification(
  overrides: Partial<Omit<NotificationDto, 'type' | 'payload'>> & {
    type?: NotificationDto['type']
    payload?: NotificationDto['payload']
  },
): NotificationDto {
  return {
    id: 'notification-id',
    type: 'FRIEND_REQUEST_RECEIVED',
    referenceType: 'FRIEND_REQUEST',
    referenceId: '1',
    actorId: 1,
    payload: {
      version: 1,
      actor: {
        name: 'Shane',
        hasProfilePhoto: true,
        profilePhotoVersion: 4,
      },
    },
    isRead: false,
    createdAt: '2026-03-30T00:00:00',
    ...overrides,
  } as NotificationDto
}

const supportedTypes: NotificationDto['type'][] = [
  'FRIEND_REQUEST_RECEIVED',
  'FRIEND_REQUEST_ACCEPTED',
  'FAMILY_REQUEST_RECEIVED',
  'FAMILY_REQUEST_ACCEPTED',
  'SCHEDULE_TAGGED',
  'TODO_TAGGED',
  'TODO_STATUS_TODO',
  'TODO_STATUS_IN_PROGRESS',
  'TODO_STATUS_DONE',
]

describe('notificationFormatter', () => {
  it('keeps a version 1 renderer for every supported notification type', () => {
    supportedTypes.forEach((type) => {
      expect(notificationRendererRegistry[type]?.[1]).toBeTypeOf('function')
    })
  })

  it('formats actor-based notifications from payload snapshots', () => {
    const notification = createNotification({
      type: 'FRIEND_REQUEST_RECEIVED',
    })

    expect(formatNotificationMessage(notification, t)).toBe('Shane님이 친구 요청을 보냈습니다.')
  })

  it('formats schedule notifications using the payload title', () => {
    const notification = createNotification({
      type: 'SCHEDULE_TAGGED',
      referenceType: 'SCHEDULE',
      payload: {
        version: 1,
        actor: {
          name: 'Shane',
          hasProfilePhoto: false,
          profilePhotoVersion: 0,
        },
        scheduleTitle: '팀 회의',
      },
    })

    expect(formatNotificationMessage(notification, t)).toBe('Shane님의 [팀 회의] 일정에 태그되었습니다.')
  })

  it('uses fallback copy when actor name is missing', () => {
    const notification = createNotification({
      type: 'TODO_STATUS_DONE',
      referenceType: 'TODO',
      payload: {
        version: 1,
        actor: {
          name: null,
          hasProfilePhoto: false,
          profilePhotoVersion: 0,
        },
        todoTitle: '보고서 정리',
      },
    })

    expect(formatNotificationMessage(notification, t)).toBe('[보고서 정리] TODO가 완료 처리되었습니다.')
  })

  it('returns actor snapshot data for avatar rendering', () => {
    const notification = createNotification({})

    expect(getNotificationActor(notification)).toEqual({
      name: 'Shane',
      hasProfilePhoto: true,
      profilePhotoVersion: 4,
    })
  })

  it('returns null actor for generic fallback payloads', () => {
    const notification = createNotification({
      payload: {
        version: 0,
      },
    })

    expect(getNotificationActor(notification)).toBeNull()
    expect(formatNotificationMessage(notification, t)).toBe('새 알림이 도착했습니다.')
  })

  it('falls back to a generic message for unsupported payload versions', () => {
    const notification = createNotification({
      payload: {
        version: 99,
        actor: {
          name: 'Shane',
          hasProfilePhoto: false,
          profilePhotoVersion: 0,
        },
      } as unknown as NotificationDto['payload'],
    })

    expect(formatNotificationMessage(notification, t)).toBe('새 알림이 도착했습니다.')
  })

  it('renders every version 1 notification type with dedicated copy', () => {
    const cases: Array<{ notification: NotificationDto; expected: string }> = [
      {
        notification: createNotification({ type: 'FRIEND_REQUEST_RECEIVED' }),
        expected: 'Shane님이 친구 요청을 보냈습니다.',
      },
      {
        notification: createNotification({ type: 'FRIEND_REQUEST_ACCEPTED' }),
        expected: 'Shane님이 친구 요청을 수락했습니다.',
      },
      {
        notification: createNotification({ type: 'FAMILY_REQUEST_RECEIVED' }),
        expected: 'Shane님이 가족 요청을 보냈습니다.',
      },
      {
        notification: createNotification({ type: 'FAMILY_REQUEST_ACCEPTED' }),
        expected: 'Shane님이 가족 요청을 수락했습니다.',
      },
      {
        notification: createNotification({
          type: 'SCHEDULE_TAGGED',
          referenceType: 'SCHEDULE',
          payload: {
            version: 1,
            actor: {
              name: 'Shane',
              hasProfilePhoto: false,
              profilePhotoVersion: 0,
            },
            scheduleTitle: '팀 회의',
          },
        }),
        expected: 'Shane님의 [팀 회의] 일정에 태그되었습니다.',
      },
      {
        notification: createNotification({
          type: 'TODO_TAGGED',
          referenceType: 'TODO',
          payload: {
            version: 1,
            actor: {
              name: 'Shane',
              hasProfilePhoto: false,
              profilePhotoVersion: 0,
            },
            todoTitle: '보고서 정리',
          },
        }),
        expected: 'Shane님의 [보고서 정리] TODO에 태그되었습니다.',
      },
      {
        notification: createNotification({
          type: 'TODO_STATUS_TODO',
          referenceType: 'TODO',
          payload: {
            version: 1,
            actor: {
              name: 'Shane',
              hasProfilePhoto: false,
              profilePhotoVersion: 0,
            },
            todoTitle: '보고서 정리',
          },
        }),
        expected: 'Shane님이 [보고서 정리] TODO를 할 일로 변경했습니다.',
      },
      {
        notification: createNotification({
          type: 'TODO_STATUS_IN_PROGRESS',
          referenceType: 'TODO',
          payload: {
            version: 1,
            actor: {
              name: 'Shane',
              hasProfilePhoto: false,
              profilePhotoVersion: 0,
            },
            todoTitle: '보고서 정리',
          },
        }),
        expected: 'Shane님이 [보고서 정리] TODO를 진행중으로 변경했습니다.',
      },
      {
        notification: createNotification({
          type: 'TODO_STATUS_DONE',
          referenceType: 'TODO',
          payload: {
            version: 1,
            actor: {
              name: 'Shane',
              hasProfilePhoto: false,
              profilePhotoVersion: 0,
            },
            todoTitle: '보고서 정리',
          },
        }),
        expected: 'Shane님이 [보고서 정리] TODO를 완료 처리했습니다.',
      },
    ]

    cases.forEach(({ notification, expected }) => {
      expect(formatNotificationMessage(notification, t)).toBe(expected)
    })
  })

  it('uses fallback copy when actor name is blank', () => {
    const notification = createNotification({
      type: 'FRIEND_REQUEST_ACCEPTED',
      payload: {
        version: 1,
        actor: {
          name: '   ',
          hasProfilePhoto: false,
          profilePhotoVersion: 0,
        },
      },
    })

    expect(formatNotificationMessage(notification, t)).toBe('친구 요청이 수락되었습니다.')
  })

  it('returns null when payload does not carry actor snapshot data', () => {
    const notification = createNotification({
      payload: {
        version: 1,
      } as unknown as NotificationDto['payload'],
    })

    expect(getNotificationActor(notification)).toBeNull()
  })
})
