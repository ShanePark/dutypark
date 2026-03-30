import type { NotificationDto, NotificationPayloadVersion, NotificationType } from '@/types'

export type NotificationTranslateParams = Record<string, string | number>

export type NotificationTranslate = (
  key: string,
  params?: NotificationTranslateParams,
) => string

export type NotificationRenderer = (
  notification: NotificationDto,
  t: NotificationTranslate,
) => string

export type NotificationRendererRegistry = Record<
  NotificationType,
  Partial<Record<NotificationPayloadVersion, NotificationRenderer>>
>
