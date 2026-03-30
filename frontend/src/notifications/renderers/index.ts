import type {
  NotificationDtoForTypeAndVersion,
  NotificationType,
} from '@/types'
import type { NotificationRenderer, NotificationRendererRegistry, NotificationTranslate } from './types'
import { notificationRenderersV1 } from './v1'

function rendererV1<T extends NotificationType>(
  render: (notification: NotificationDtoForTypeAndVersion<T, 1>, t: NotificationTranslate) => string,
): NotificationRenderer {
  return (notification, t) => render(notification as NotificationDtoForTypeAndVersion<T, 1>, t)
}

export const notificationRendererRegistry: NotificationRendererRegistry = {
  FRIEND_REQUEST_RECEIVED: {
    1: rendererV1<'FRIEND_REQUEST_RECEIVED'>(notificationRenderersV1.FRIEND_REQUEST_RECEIVED),
  },
  FRIEND_REQUEST_ACCEPTED: {
    1: rendererV1<'FRIEND_REQUEST_ACCEPTED'>(notificationRenderersV1.FRIEND_REQUEST_ACCEPTED),
  },
  FAMILY_REQUEST_RECEIVED: {
    1: rendererV1<'FAMILY_REQUEST_RECEIVED'>(notificationRenderersV1.FAMILY_REQUEST_RECEIVED),
  },
  FAMILY_REQUEST_ACCEPTED: {
    1: rendererV1<'FAMILY_REQUEST_ACCEPTED'>(notificationRenderersV1.FAMILY_REQUEST_ACCEPTED),
  },
  SCHEDULE_TAGGED: {
    1: rendererV1<'SCHEDULE_TAGGED'>(notificationRenderersV1.SCHEDULE_TAGGED),
  },
  TODO_TAGGED: {
    1: rendererV1<'TODO_TAGGED'>(notificationRenderersV1.TODO_TAGGED),
  },
  TODO_STATUS_TODO: {
    1: rendererV1<'TODO_STATUS_TODO'>(notificationRenderersV1.TODO_STATUS_TODO),
  },
  TODO_STATUS_IN_PROGRESS: {
    1: rendererV1<'TODO_STATUS_IN_PROGRESS'>(notificationRenderersV1.TODO_STATUS_IN_PROGRESS),
  },
  TODO_STATUS_DONE: {
    1: rendererV1<'TODO_STATUS_DONE'>(notificationRenderersV1.TODO_STATUS_DONE),
  },
}
