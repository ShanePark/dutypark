import type { NotificationDtoForTypeAndVersion } from '@/types'
import type { NotificationTranslate } from './types'

function messageKey(key: string): string {
  return `notifications.items.${key}.v1`
}

function resolveActorName<T extends { payload: { actor: { name: string | null } } }>(
  notification: T,
): string | null {
  const name = notification.payload.actor.name?.trim()
  return name ? name : null
}

export const notificationRenderersV1 = {
  FRIEND_REQUEST_RECEIVED: (
    notification: NotificationDtoForTypeAndVersion<'FRIEND_REQUEST_RECEIVED', 1>,
    t: NotificationTranslate,
  ) => {
    const actorName = resolveActorName(notification)
    return actorName
      ? t(messageKey('friendRequestReceived'), { actorName })
      : t(messageKey('friendRequestReceivedFallback'))
  },
  FRIEND_REQUEST_ACCEPTED: (
    notification: NotificationDtoForTypeAndVersion<'FRIEND_REQUEST_ACCEPTED', 1>,
    t: NotificationTranslate,
  ) => {
    const actorName = resolveActorName(notification)
    return actorName
      ? t(messageKey('friendRequestAccepted'), { actorName })
      : t(messageKey('friendRequestAcceptedFallback'))
  },
  FAMILY_REQUEST_RECEIVED: (
    notification: NotificationDtoForTypeAndVersion<'FAMILY_REQUEST_RECEIVED', 1>,
    t: NotificationTranslate,
  ) => {
    const actorName = resolveActorName(notification)
    return actorName
      ? t(messageKey('familyRequestReceived'), { actorName })
      : t(messageKey('familyRequestReceivedFallback'))
  },
  FAMILY_REQUEST_ACCEPTED: (
    notification: NotificationDtoForTypeAndVersion<'FAMILY_REQUEST_ACCEPTED', 1>,
    t: NotificationTranslate,
  ) => {
    const actorName = resolveActorName(notification)
    return actorName
      ? t(messageKey('familyRequestAccepted'), { actorName })
      : t(messageKey('familyRequestAcceptedFallback'))
  },
  SCHEDULE_TAGGED: (
    notification: NotificationDtoForTypeAndVersion<'SCHEDULE_TAGGED', 1>,
    t: NotificationTranslate,
  ) => {
    const actorName = resolveActorName(notification)
    return actorName
      ? t(messageKey('scheduleTagged'), {
        actorName,
        scheduleTitle: notification.payload.scheduleTitle,
      })
      : t(messageKey('scheduleTaggedFallback'), {
        scheduleTitle: notification.payload.scheduleTitle,
      })
  },
  TODO_TAGGED: (
    notification: NotificationDtoForTypeAndVersion<'TODO_TAGGED', 1>,
    t: NotificationTranslate,
  ) => {
    const actorName = resolveActorName(notification)
    return actorName
      ? t(messageKey('todoTagged'), {
        actorName,
        todoTitle: notification.payload.todoTitle,
      })
      : t(messageKey('todoTaggedFallback'), {
        todoTitle: notification.payload.todoTitle,
      })
  },
  TODO_STATUS_TODO: (
    notification: NotificationDtoForTypeAndVersion<'TODO_STATUS_TODO', 1>,
    t: NotificationTranslate,
  ) => {
    const actorName = resolveActorName(notification)
    return actorName
      ? t(messageKey('todoStatusTodo'), {
        actorName,
        todoTitle: notification.payload.todoTitle,
      })
      : t(messageKey('todoStatusTodoFallback'), {
        todoTitle: notification.payload.todoTitle,
      })
  },
  TODO_STATUS_IN_PROGRESS: (
    notification: NotificationDtoForTypeAndVersion<'TODO_STATUS_IN_PROGRESS', 1>,
    t: NotificationTranslate,
  ) => {
    const actorName = resolveActorName(notification)
    return actorName
      ? t(messageKey('todoStatusInProgress'), {
        actorName,
        todoTitle: notification.payload.todoTitle,
      })
      : t(messageKey('todoStatusInProgressFallback'), {
        todoTitle: notification.payload.todoTitle,
      })
  },
  TODO_STATUS_DONE: (
    notification: NotificationDtoForTypeAndVersion<'TODO_STATUS_DONE', 1>,
    t: NotificationTranslate,
  ) => {
    const actorName = resolveActorName(notification)
    return actorName
      ? t(messageKey('todoStatusDone'), {
        actorName,
        todoTitle: notification.payload.todoTitle,
      })
      : t(messageKey('todoStatusDoneFallback'), {
        todoTitle: notification.payload.todoTitle,
      })
  },
} as const
