/// <reference lib="webworker" />

import type { PushNotificationPayload } from '@/types'
import { normalizeLocale } from '@/i18n/localeUtils'
import {
  resolvePushNotificationBody,
  resolvePushNotificationId,
} from './pushNotificationPresentation'

const serviceWorker = self as unknown as ServiceWorkerGlobalScope

const LOCALE_CACHE_NAME = 'dutypark-sw-settings-v1'
const LOCALE_CACHE_KEY = 'https://dutypark.local/__settings/locale'

async function readStoredLocale(fallbackLocale?: string): Promise<string> {
  const cache = await caches.open(LOCALE_CACHE_NAME)
  const response = await cache.match(LOCALE_CACHE_KEY)
  const cachedLocale = response ? await response.text() : null
  return normalizeLocale(cachedLocale || fallbackLocale || serviceWorker.navigator?.language)
}

async function storeLocale(locale: string) {
  const cache = await caches.open(LOCALE_CACHE_NAME)
  await cache.put(
    LOCALE_CACHE_KEY,
    new Response(normalizeLocale(locale), {
      headers: {
        'Content-Type': 'text/plain',
      },
    }),
  )
}

async function updateAppBadgeSafely(unreadCount: number) {
  try {
    if (unreadCount > 0 && typeof serviceWorker.navigator.setAppBadge === 'function') {
      await serviceWorker.navigator.setAppBadge(unreadCount)
      return
    }

    if (unreadCount <= 0 && typeof serviceWorker.navigator.clearAppBadge === 'function') {
      await serviceWorker.navigator.clearAppBadge()
      return
    }

    if (unreadCount <= 0 && typeof serviceWorker.navigator.setAppBadge === 'function') {
      await serviceWorker.navigator.setAppBadge(0)
    }
  } catch (error) {
    console.warn('Failed to update app badge in service worker:', error)
  }
}

async function handlePush(payload: PushNotificationPayload) {
  const locale = await readStoredLocale()
  const notificationId = resolvePushNotificationId(payload)

  const options = {
    body: resolvePushNotificationBody(payload, locale),
    icon: payload.icon || '/android-chrome-192x192.png',
    badge: payload.badge || '/android-chrome-192x192.png',
    tag: payload.tag || notificationId || payload.type || 'dutypark-notification',
    renotify: true,
    data: {
      url: payload.url || '/',
      notificationId,
    },
  } as NotificationOptions

  const title = ''

  if (typeof payload.unreadCount === 'number') {
    await updateAppBadgeSafely(payload.unreadCount)
  }

  await serviceWorker.registration.showNotification(title, options)
}

export function handleInstall() {
  serviceWorker.skipWaiting()
}

export async function handleActivate() {
  await serviceWorker.clients.claim()
}

export async function handleMessage(event: ExtendableMessageEvent) {
  if (event.data?.type !== 'DUTYPARK_SET_LOCALE') {
    return
  }

  await storeLocale(event.data.locale)
}

export async function handlePushEvent(event: PushEvent) {
  if (!event.data) {
    return
  }

  await handlePush(event.data.json() as PushNotificationPayload)
}

export async function handleNotificationClick(event: NotificationEvent) {
  event.notification.close()

  const notificationId = event.notification.data?.notificationId
  const urlToOpen = notificationId
    ? `/notifications?pushId=${encodeURIComponent(notificationId)}`
    : (event.notification.data?.url || '/')

  await serviceWorker.clients.matchAll({ type: 'window', includeUncontrolled: true })
    .then((clientList: readonly WindowClient[]) => {
      for (const client of clientList) {
        if (client.url.includes(serviceWorker.location.origin) && 'focus' in client) {
          client.navigate(urlToOpen)
          return client.focus()
        }
      }

      if (serviceWorker.clients.openWindow) {
        return serviceWorker.clients.openWindow(urlToOpen)
      }

      return undefined
    })
}

serviceWorker.addEventListener('install', () => {
  handleInstall()
})

serviceWorker.addEventListener('activate', (event) => {
  event.waitUntil(handleActivate())
})

serviceWorker.addEventListener('message', (event: ExtendableMessageEvent) => {
  event.waitUntil(handleMessage(event))
})

serviceWorker.addEventListener('push', (event: PushEvent) => {
  event.waitUntil(handlePushEvent(event))
})

serviceWorker.addEventListener('notificationclick', (event: NotificationEvent) => {
  event.waitUntil(handleNotificationClick(event))
})
