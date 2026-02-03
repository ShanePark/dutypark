// Service Worker for Push Notifications

// Activate new service worker immediately without waiting
self.addEventListener('install', () => {
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(clients.claim())
})

self.addEventListener('push', (event) => {
  if (!event.data) {
    return
  }

  const data = event.data.json()

  const options = {
    body: data.body,
    icon: data.icon || '/android-chrome-192x192.png',
    badge: data.badge || '/android-chrome-192x192.png',
    tag: data.tag || 'dutypark-notification',
    renotify: true,
    data: {
      url: data.url || '/',
      notificationId: data.notificationId || null
    }
  }

  // iOS PWA automatically appends "from [app name]" to notifications.
  // Using empty string for title shows only the app name, avoiding "Dutypark from Dutypark".
  const title = data.title || ''

  // Set app icon badge for iOS PWA (requires iOS 16.4+)
  if ('setAppBadge' in navigator && typeof data.unreadCount === 'number') {
    if (data.unreadCount > 0) {
      navigator.setAppBadge(data.unreadCount)
    } else {
      navigator.clearAppBadge()
    }
  }

  event.waitUntil(
    self.registration.showNotification(title, options)
  )
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
