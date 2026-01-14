// Service Worker for Push Notifications

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

  event.waitUntil(
    self.registration.showNotification(data.title || 'Dutypark', options)
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
