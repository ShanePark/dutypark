import { ref, computed } from 'vue'
import { pushApi } from '@/api/push'
import { useLocaleStore } from '@/stores/locale'
import { buildPushSubscriptionRequest } from '@/utils/pushSubscription'
import { syncServiceWorkerLocale } from '@/utils/serviceWorkerLocale'

const SERVICE_WORKER_VERSION = 'push-detail-v4'
const SERVICE_WORKER_URL = import.meta.env.DEV
  ? `/sw.js?v=${SERVICE_WORKER_VERSION}`
  : `/sw-runtime.js?v=${SERVICE_WORKER_VERSION}`
const SERVICE_WORKER_ACTIVATION_TIMEOUT_MS = 5000
const SERVICE_WORKER_ACTIVATION_POLL_INTERVAL_MS = 100

const isSupported = ref(false)
const isEnabled = ref(false)
const permission = ref<NotificationPermission>('default')
const isSubscribed = ref(false)
const isLoading = ref(false)

function wait(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms)
  })
}

async function updateRegistrationIfPossible(
  registration: ServiceWorkerRegistration,
): Promise<void> {
  if (typeof registration.update !== 'function') {
    return
  }

  try {
    await registration.update()
  } catch {
    // Ignore best-effort update failures while polling activation.
  }
}

async function getRegistrationsIfPossible(): Promise<ServiceWorkerRegistration[]> {
  if (typeof navigator.serviceWorker.getRegistrations !== 'function') {
    return []
  }

  try {
    return Array.from(await navigator.serviceWorker.getRegistrations())
  } catch {
    return []
  }
}

async function getCandidateRegistrations(): Promise<ServiceWorkerRegistration[]> {
  const registrations = await getRegistrationsIfPossible()
  const currentRegistration = await navigator.serviceWorker.getRegistration().catch(() => null)

  return Array.from(
    new Set(
      [...registrations, currentRegistration].filter(
        (value): value is ServiceWorkerRegistration => value != null,
      ),
    ),
  )
}

async function unregisterRegistrations(
  registrations: ServiceWorkerRegistration[],
): Promise<void> {
  await Promise.all(
    registrations.map(async (registration) => {
      if (typeof registration.unregister !== 'function') {
        return false
      }

      try {
        return await registration.unregister()
      } catch {
        return false
      }
    }),
  )
}

function isCurrentServiceWorker(
  serviceWorker: ServiceWorker | null | undefined,
): boolean {
  return typeof serviceWorker?.scriptURL === 'string'
    && serviceWorker.scriptURL.includes(SERVICE_WORKER_VERSION)
}

function isCurrentServiceWorkerRegistration(
  registration: ServiceWorkerRegistration | null | undefined,
): boolean {
  if (!registration) {
    return false
  }

  const scriptUrls = [
    registration.active?.scriptURL,
    registration.waiting?.scriptURL,
    registration.installing?.scriptURL,
  ].filter((value): value is string => typeof value === 'string' && value.length > 0)

  return scriptUrls.some((scriptURL) => scriptURL.includes(SERVICE_WORKER_VERSION))
}

export function usePushNotification() {
  const localeStore = useLocaleStore()

  const waitForCurrentServiceWorker = async (
    registration: ServiceWorkerRegistration,
    timeoutMs = SERVICE_WORKER_ACTIVATION_TIMEOUT_MS,
  ): Promise<ServiceWorkerRegistration | null> => {
    if (isCurrentServiceWorker(registration.active)) {
      return registration
    }

    const deadline = Date.now() + timeoutMs

    while (Date.now() < deadline) {
      if (isCurrentServiceWorker(registration.active)) {
        return registration
      }

      const hasPendingCurrentWorker = isCurrentServiceWorker(registration.waiting)
        || isCurrentServiceWorker(registration.installing)
      if (!hasPendingCurrentWorker) {
        return null
      }

      await updateRegistrationIfPossible(registration)
      await wait(SERVICE_WORKER_ACTIVATION_POLL_INTERVAL_MS)
    }

    console.error('Current Service Worker did not activate in time:', {
      active: registration.active?.scriptURL,
      waiting: registration.waiting?.scriptURL,
      installing: registration.installing?.scriptURL,
    })
    return null
  }

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
      const registration = await navigator.serviceWorker.register(SERVICE_WORKER_URL, {
        type: 'module',
      })
      const currentRegistration = await waitForCurrentServiceWorker(registration)
      if (!currentRegistration) {
        return null
      }
      await syncServiceWorkerLocale(localeStore.locale, currentRegistration)
      return currentRegistration
    } catch (error) {
      console.error('Service Worker registration failed:', error)
      return null
    }
  }

  const ensureServiceWorker = async (): Promise<ServiceWorkerRegistration | null> => {
    if (!isSupported.value) return null

    const registration = await registerServiceWorker()
    if (isCurrentServiceWorkerRegistration(registration)) {
      return registration
    }

    const currentRegistrations = (await getCandidateRegistrations())
      .filter(isCurrentServiceWorkerRegistration)
    for (const currentRegistration of currentRegistrations) {
      const resolvedRegistration = await waitForCurrentServiceWorker(currentRegistration)
      if (resolvedRegistration) {
        return resolvedRegistration
      }
    }

    const staleRegistrations = (await getCandidateRegistrations())
      .filter((candidate) => !isCurrentServiceWorkerRegistration(candidate))
    if (staleRegistrations.length === 0) {
      return null
    }

    await unregisterRegistrations(staleRegistrations)

    const retriedRegistration = await registerServiceWorker()
    if (isCurrentServiceWorkerRegistration(retriedRegistration)) {
      return retriedRegistration
    }

    return null
  }

  const getReadyRegistration = async (): Promise<ServiceWorkerRegistration | null> => {
    const registration = await ensureServiceWorker()
    if (!registration) return null
    if (isCurrentServiceWorker(registration.active)) {
      return registration
    }
    try {
      const readyRegistration = await navigator.serviceWorker.ready
      return isCurrentServiceWorker(readyRegistration.active)
        ? readyRegistration
        : null
    } catch {
      return isCurrentServiceWorker(registration.active) ? registration : null
    }
  }

  const prepareServiceWorker = async (): Promise<ServiceWorkerRegistration | null> => {
    checkSupport()
    if (!isSupported.value) {
      return null
    }

    return ensureServiceWorker()
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
      await syncServiceWorkerLocale(localeStore.locale, registration)

      const existingSubscription = await registration.pushManager.getSubscription()
      const subscription = existingSubscription ?? await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidPublicKey) as BufferSource
      })

      const success = await pushApi.subscribe(buildPushSubscriptionRequest(subscription))

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
    prepareServiceWorker,
    requestPermission,
    subscribe,
    unsubscribe
  }
}

// Utility functions
function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = '='.repeat((4 - base64String.length % 4) % 4)
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
  const rawData = window.atob(base64)
  return Uint8Array.from(rawData, char => char.charCodeAt(0))
}
