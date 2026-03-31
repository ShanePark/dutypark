import { createStaticNotificationTranslate } from '@/notifications/staticTranslate'
import type { NotificationDto, PushNotificationPayload } from '@/types'
import { formatNotificationMessage } from '@/utils/notificationFormatter'

function isNotificationDto(value: unknown): value is NotificationDto {
  if (value == null || typeof value !== 'object') {
    return false
  }

  const candidate = value as Partial<NotificationDto>
  return typeof candidate.id === 'string'
    && typeof candidate.type === 'string'
    && candidate.payload != null
    && typeof candidate.payload === 'object'
}

export function resolvePushNotificationBody(
  payload: PushNotificationPayload,
  locale: string | null | undefined,
): string {
  if (isNotificationDto(payload.notification)) {
    return formatNotificationMessage(
      payload.notification,
      createStaticNotificationTranslate(locale),
    )
  }

  return createStaticNotificationTranslate(locale)('notifications.items.generic')
}

export function resolvePushNotificationId(payload: PushNotificationPayload): string | null {
  return payload.notificationId
    ?? (isNotificationDto(payload.notification) ? payload.notification.id : null)
}
