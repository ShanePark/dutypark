import type {
  NotificationActorSnapshot,
  NotificationDto,
  NotificationPayload,
} from '@/types'
import { notificationRendererRegistry } from '@/notifications/renderers'
import type { NotificationTranslate } from '@/notifications/renderers/types'
export type { NotificationTranslate } from '@/notifications/renderers/types'

function getPayloadActor(payload: NotificationPayload): NotificationActorSnapshot | null {
  if ('actor' in payload) {
    return payload.actor
  }
  return null
}

export function getNotificationActor(notification: NotificationDto): NotificationActorSnapshot | null {
  return getPayloadActor(notification.payload)
}

export function formatNotificationMessage(
  notification: NotificationDto,
  t: NotificationTranslate,
): string {
  const versionRenderer = notificationRendererRegistry[notification.type]?.[notification.payload.version]
  if (!versionRenderer) {
    return t('notifications.items.generic')
  }
  return versionRenderer(notification, t)
}
