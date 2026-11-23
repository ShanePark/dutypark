import { describe, expect, it } from 'vitest'
import type { NotificationDto } from '@/types'
import { createStaticNotificationTranslate } from '@/notifications/staticTranslate'
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
  'notifications.items.inquiryAnswered.v1': '문의 [{subject}]에 답변이 등록되었습니다.',
  'notifications.items.inquiryAnsweredFallback.v1': '문의에 답변이 등록되었습니다.',
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
  'INQUIRY_ANSWERED',
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

  it('names the inquiry in the answered notification', () => {
    const notification = createNotification({
      type: 'INQUIRY_ANSWERED',
      referenceType: 'INQUIRY',
      referenceId: '0f2b6d4c-2d5f-4f4c-9a53-9d0f2b6d4c2d',
      actorId: null,
      payload: {
        version: 1,
        subject: '결제 오류',
      },
    })

    expect(formatNotificationMessage(notification, t)).toBe('문의 [결제 오류]에 답변이 등록되었습니다.')
    expect(getNotificationActor(notification)).toBeNull()
  })

  it.each([null, '   '])('falls back to subject-less inquiry copy for %j', (subject) => {
    const notification = createNotification({
      type: 'INQUIRY_ANSWERED',
      referenceType: 'INQUIRY',
      actorId: null,
      payload: {
        version: 1,
        subject,
      },
    })

    expect(formatNotificationMessage(notification, t)).toBe('문의에 답변이 등록되었습니다.')
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


describe('schedule update messages', () => {
  it('includes only changed field names and the actual actor', () => {
    const notification = createNotification({
      type: 'SCHEDULE_UPDATED', referenceType: 'SCHEDULE',
      payload: { version: 1, actor: { name: 'Manager', hasProfilePhoto: false, profilePhotoVersion: 0 }, scheduleVersion: 3, changedFields: ['TITLE', 'TIME'] },
    })
    const translate: NotificationTranslate = (key, params = {}) => key === 'notifications.items.scheduleUpdated.v1'
      ? `${params.actorName}: ${params.fields}`
      : key
    const message = formatNotificationMessage(notification, translate)
    expect(message).toContain('Manager')
    expect(message).toContain('TITLE')
    expect(message).toContain('TIME')
    expect(message).not.toContain('DESCRIPTION')
  })
})


describe('inline schedule changes', () => {
  it('includes the before and after values in Korean without another view', () => {
    const notification = createNotification({
      type: 'SCHEDULE_UPDATED', referenceType: 'SCHEDULE',
      payload: { version: 1, actor: { name: '박세현', hasProfilePhoto: false, profilePhotoVersion: 0 }, scheduleVersion: 3, changedFields: ['DESCRIPTION'] },
      scheduleChanges: { scheduleId: 's', scheduleVersion: 3, description: { before: '공통 ㄴㄴㄴ 공통', after: '공통 ㅇㅇㅇ 공통' } },
    } as Partial<NotificationDto>)
    expect(formatNotificationMessage(notification, createStaticNotificationTranslate('ko'))).toBe('박세현님이 일정을 수정했습니다.\n‘ㄴㄴㄴ’ → ‘ㅇㅇㅇ’')
  })
})


describe('inline schedule change combinations', () => {
  it('formats all changed fields in English and collapses whitespace', () => {
    const notification = createNotification({
      type: 'SCHEDULE_UPDATED', referenceType: 'SCHEDULE',
      payload: { version: 1, actor: { name: 'Park', hasProfilePhoto: false, profilePhotoVersion: 0 }, scheduleVersion: 3, changedFields: ['TITLE', 'DESCRIPTION', 'TIME'] },
      scheduleChanges: { scheduleId: 's', scheduleVersion: 3, title: { before: 'Old', after: 'New' }, description: { before: 'before\ntext', after: 'after\ttext' }, time: { before: { startDateTime: '2026-11-23T14:00:00', endDateTime: '2026-11-23T15:00:00' }, after: { startDateTime: '2026-11-23T15:00:00', endDateTime: '2026-11-23T16:00:00' } } },
    })
    const message = formatNotificationMessage(notification, createStaticNotificationTranslate('en'))
    expect(message).toContain('Park renamed “Old” to “New”.')
    expect(message).toContain('\n“')
    expect(message).toContain('14:00–15:00 → 15:00–16:00')
    expect(message.split('\n')).toHaveLength(3)
  })
})


it('identifies an unchanged schedule title once in the heading', () => {
  const notification = createNotification({
    type: 'SCHEDULE_UPDATED', referenceType: 'SCHEDULE',
    payload: { version: 1, actor: { name: '부계테스트', hasProfilePhoto: false, profilePhotoVersion: 0 }, scheduleVersion: 3, changedFields: ['DESCRIPTION'] },
    scheduleChanges: { scheduleId: 's', scheduleVersion: 3, scheduleTitle: '알림 확인 · 일정 확정', description: { before: '온라인', after: '대면' } },
  })
  expect(formatNotificationMessage(notification, createStaticNotificationTranslate('ko'))).toBe('부계테스트님이 ‘알림 확인 · 일정 확정’ 일정을 수정했습니다.\n‘온라인’ → ‘대면’')
})


describe('renamed schedule sentence', () => {
  it.each([['최종 회의', '로'], ['모임', '으로'], ['일정', '으로'], ['일', '로'], ['회의 0', '으로'], ['회의 3!', '으로'], ['회의 6   ', '으로'], ['회의 1', '로'], ['회의 2?', '로']])('selects the Korean particle after %s', (after, particle) => {
    const notification = createNotification({
      type: 'SCHEDULE_UPDATED', referenceType: 'SCHEDULE',
      payload: { version: 1, actor: { name: '부계테스트', hasProfilePhoto: false, profilePhotoVersion: 0 }, scheduleVersion: 3, changedFields: ['TITLE'] },
      scheduleChanges: { scheduleId: 's', scheduleVersion: 3, title: { before: '자료 검토', after } },
    })
    expect(formatNotificationMessage(notification, createStaticNotificationTranslate('ko'))).toBe(`부계테스트님이 ‘자료 검토’ 일정을 ‘${after.trim()}’${particle} 변경했습니다.`)
  })
})
