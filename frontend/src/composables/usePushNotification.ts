import { ref, computed } from 'vue'
import { pushApi } from '@/api/push'

const isSupported = ref(false)
const isEnabled = ref(false)
const permission = ref<NotificationPermission>('default')
const isSubscribed = ref(false)
const isLoading = ref(false)

export function usePushNotification() {
  // Check browser support
  const checkSupport = () => {
    const notificationSupported = 'Notification' in window
    isSupported.value = 'serviceWorker' in navigator && 'PushManager' in window && notificationSupported
    if (notificationSupported) {
      permission.value = Notification.permission
    } else {
      permission.value = 'denied'
    }
    if (!isSupported.value) {
      isEnabled.value = false
      isSubscribed.value = false
    }
  }

  const checkEnabled = async (): Promise<boolean> => {
    if (!isSupported.value) {
      isEnabled.value = false
      return false
    }

    try {
      isEnabled.value = await pushApi.isEnabled()
      return isEnabled.value
    } catch (error) {
      console.error('Failed to check push availability:', error)
      isEnabled.value = false
      return false
    }
  }

  // Register Service Worker
  const registerServiceWorker = async (): Promise<ServiceWorkerRegistration | null> => {
    if (!isSupported.value) return null

    try {
      const registration = await navigator.serviceWorker.register('/sw.js')
      return registration
    } catch (error) {
      console.error('Service Worker registration failed:', error)
      return null
    }
  }

  const ensureServiceWorker = async (): Promise<ServiceWorkerRegistration | null> => {
    if (!isSupported.value) return null

    const existingRegistration = await navigator.serviceWorker.getRegistration()
    if (existingRegistration) {
      return existingRegistration
    }

    return registerServiceWorker()
  }

  const getReadyRegistration = async (): Promise<ServiceWorkerRegistration | null> => {
    const registration = await ensureServiceWorker()
    if (!registration) return null
    try {
      return await navigator.serviceWorker.ready
    } catch {
      return registration
    }
  }

  // Request notification permission
  const requestPermission = async (): Promise<NotificationPermission> => {
    if (!('Notification' in window)) {
      return 'denied'
    }

    const result = await Notification.requestPermission()
    permission.value = result
    return result
  }

  // Subscribe to push notifications
  const subscribe = async (): Promise<boolean> => {
    if (!isSupported.value || isLoading.value) return false

    isLoading.value = true
    try {
      const enabled = isEnabled.value || await checkEnabled()
      if (!enabled) {
        return false
      }

      // Check permission
      if (permission.value !== 'granted') {
        const result = await requestPermission()
        if (result !== 'granted') {
          return false
        }
      }

      // Get VAPID public key
      const vapidPublicKey = await pushApi.getVapidPublicKey()
      if (!vapidPublicKey) {
        console.error('VAPID public key not available')
        return false
      }

      // Register Service Worker
      const registration = await getReadyRegistration()
      if (!registration) return false

      const existingSubscription = await registration.pushManager.getSubscription()
      const subscription = existingSubscription ?? await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidPublicKey) as BufferSource
      })

      const success = await pushApi.subscribe(buildSubscriptionRequest(subscription))

      isSubscribed.value = success
      return success
    } catch (error) {
      console.error('Push subscription failed:', error)
      return false
    } finally {
      isLoading.value = false
    }
  }

  // Unsubscribe from push notifications
  const unsubscribe = async (): Promise<boolean> => {
    if (!isSupported.value || isLoading.value) return false

    isLoading.value = true
    try {
      const registration = await getReadyRegistration()
      const subscription = registration
        ? await registration.pushManager.getSubscription()
        : null

      let serverSuccess = true
      let browserSuccess = true

      try {
        serverSuccess = await pushApi.unsubscribe()
      } catch (error) {
        console.error('Push server unsubscribe failed:', error)
        serverSuccess = false
      }

      if (subscription) {
        try {
          browserSuccess = await subscription.unsubscribe()
        } catch (error) {
          console.error('Push browser unsubscribe failed:', error)
          browserSuccess = false
        }
      }

      if (browserSuccess) {
        isSubscribed.value = false
      }

      return serverSuccess && browserSuccess
    } catch (error) {
      console.error('Push unsubscription failed:', error)
      return false
    } finally {
      isLoading.value = false
    }
  }

  return {
    isSupported: computed(() => isSupported.value),
    isEnabled: computed(() => isEnabled.value),
    permission: computed(() => permission.value),
    isSubscribed: computed(() => isSubscribed.value),
    isLoading: computed(() => isLoading.value),
    checkSupport,
    checkEnabled,
    registerServiceWorker,
    requestPermission,
    subscribe,
    unsubscribe
  }
}

function buildSubscriptionRequest(subscription: PushSubscription) {
  const p256dh = arrayBufferToBase64(subscription.getKey('p256dh')!)
  const auth = arrayBufferToBase64(subscription.getKey('auth')!)
  return {
    endpoint: subscription.endpoint,
    keys: { p256dh, auth }
  }
}

// Utility functions
function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = '='.repeat((4 - base64String.length % 4) % 4)
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
  const rawData = window.atob(base64)
  return Uint8Array.from(rawData, char => char.charCodeAt(0))
}

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer)
  let binary = ''
  bytes.forEach(b => binary += String.fromCharCode(b))
  return window.btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}
