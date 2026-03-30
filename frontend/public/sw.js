// Service Worker for Push Notifications

const LOCALE_CACHE_NAME = 'dutypark-sw-settings-v1'
const LOCALE_CACHE_KEY = 'https://dutypark.local/__settings/locale'
const DEFAULT_LOCALE = 'ko'

const PUSH_MESSAGES = {
  ko: {
    FRIEND_REQUEST_RECEIVED: '친구추가 요청이 왔습니다.',
    FRIEND_REQUEST_ACCEPTED: '친구추가 요청이 수락되었습니다.',
    FAMILY_REQUEST_RECEIVED: '가족 요청이 왔습니다.',
    FAMILY_REQUEST_ACCEPTED: '가족 요청이 수락되었습니다.',
    SCHEDULE_TAGGED: '일정에 태그되었습니다.',
    TODO_TAGGED: '할 일에 태그되었습니다.',
    TODO_STATUS_TODO: '할 일 상태가 변경되었습니다.',
    TODO_STATUS_IN_PROGRESS: '할 일 상태가 변경되었습니다.',
    TODO_STATUS_DONE: '할 일이 완료 처리되었습니다.',
    DEFAULT: '새 알림이 도착했습니다.'
  },
  en: {
    FRIEND_REQUEST_RECEIVED: 'You have a new friend request.',
    FRIEND_REQUEST_ACCEPTED: 'Your friend request was accepted.',
    FAMILY_REQUEST_RECEIVED: 'You have a new family request.',
    FAMILY_REQUEST_ACCEPTED: 'Your family request was accepted.',
    SCHEDULE_TAGGED: 'You were tagged in a schedule.',
    TODO_TAGGED: 'You were tagged in a task.',
    TODO_STATUS_TODO: 'A task status changed.',
    TODO_STATUS_IN_PROGRESS: 'A task status changed.',
    TODO_STATUS_DONE: 'A task was marked as done.',
    DEFAULT: 'You have a new notification.'
  },
  ja: {
    FRIEND_REQUEST_RECEIVED: '友だちリクエストが届きました。',
    FRIEND_REQUEST_ACCEPTED: '友だちリクエストが承認されました。',
    FAMILY_REQUEST_RECEIVED: '家族リクエストが届きました。',
    FAMILY_REQUEST_ACCEPTED: '家族リクエストが承認されました。',
    SCHEDULE_TAGGED: '予定にタグ付けされました。',
    TODO_TAGGED: 'タスクにタグ付けされました。',
    TODO_STATUS_TODO: 'タスクの状態が変更されました。',
    TODO_STATUS_IN_PROGRESS: 'タスクの状態が変更されました。',
    TODO_STATUS_DONE: 'タスクが完了に変更されました。',
    DEFAULT: '新しい通知があります。'
  }
}

function normalizeLocale(locale) {
  if (!locale || typeof locale !== 'string') {
    return DEFAULT_LOCALE
  }

  const normalized = locale.trim().toLowerCase()
  if (normalized.startsWith('en')) {
    return 'en'
  }
  if (normalized.startsWith('ja')) {
    return 'ja'
  }
  return 'ko'
}

async function readStoredLocale(fallbackLocale) {
  const cache = await caches.open(LOCALE_CACHE_NAME)
  const response = await cache.match(LOCALE_CACHE_KEY)
  const cachedLocale = response ? await response.text() : null
  return normalizeLocale(cachedLocale || fallbackLocale || self.navigator?.language)
}

async function storeLocale(locale) {
  const cache = await caches.open(LOCALE_CACHE_NAME)
  await cache.put(
    LOCALE_CACHE_KEY,
    new Response(normalizeLocale(locale), {
      headers: {
        'Content-Type': 'text/plain',
      },
    })
  )
}

function resolvePushBody(type, locale) {
  const messages = PUSH_MESSAGES[normalizeLocale(locale)] || PUSH_MESSAGES[DEFAULT_LOCALE]
  return messages[type] || messages.DEFAULT
}

// Activate new service worker immediately without waiting
self.addEventListener('install', () => {
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(clients.claim())
})

self.addEventListener('message', (event) => {
  if (event.data?.type !== 'DUTYPARK_SET_LOCALE') {
    return
  }

  event.waitUntil(storeLocale(event.data.locale))
})

self.addEventListener('push', (event) => {
  if (!event.data) {
    return
  }

  event.waitUntil((async () => {
    const data = event.data.json()
    const locale = await readStoredLocale()

    const options = {
      body: resolvePushBody(data.type, locale),
      icon: data.icon || '/android-chrome-192x192.png',
      badge: data.badge || '/android-chrome-192x192.png',
      tag: data.tag || data.type || 'dutypark-notification',
      renotify: true,
      data: {
        url: data.url || '/',
        notificationId: data.notificationId || null
      }
    }

    // iOS PWA automatically appends "from [app name]" to notifications.
    // Using empty string for title shows only the app name, avoiding "Dutypark from Dutypark".
    const title = ''

    // Set app icon badge for iOS PWA (requires iOS 16.4+)
    if ('setAppBadge' in navigator && typeof data.unreadCount === 'number') {
      if (data.unreadCount > 0) {
        navigator.setAppBadge(data.unreadCount)
      } else {
        navigator.clearAppBadge()
      }
    }

    await self.registration.showNotification(title, options)
  })())
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()

  const notificationId = event.notification.data?.notificationId
  const urlToOpen = notificationId
    ? `/notifications?pushId=${encodeURIComponent(notificationId)}`
    : (event.notification.data?.url || '/')

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // Focus existing window if available
        for (const client of clientList) {
          if (client.url.includes(self.location.origin) && 'focus' in client) {
            client.navigate(urlToOpen)
            return client.focus()
          }
        }
        // Open new window
        if (clients.openWindow) {
          return clients.openWindow(urlToOpen)
        }
      })
  )
})
