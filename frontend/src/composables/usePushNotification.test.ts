import { beforeEach, describe, expect, it, vi } from 'vitest'

const mocks = vi.hoisted(() => ({
  pushApi: {
    isEnabled: vi.fn(),
    getVapidPublicKey: vi.fn(),
    subscribe: vi.fn(),
    unsubscribe: vi.fn(),
  },
  buildPushSubscriptionRequest: vi.fn(),
  syncServiceWorkerLocale: vi.fn(),
  localeStore: {
    locale: 'ja',
  },
}))

vi.mock('@/api/push', () => ({
  pushApi: mocks.pushApi,
}))

vi.mock('@/utils/pushSubscription', () => ({
  buildPushSubscriptionRequest: mocks.buildPushSubscriptionRequest,
}))

vi.mock('@/utils/serviceWorkerLocale', () => ({
  syncServiceWorkerLocale: mocks.syncServiceWorkerLocale,
}))

vi.mock('@/stores/locale', () => ({
  useLocaleStore: () => mocks.localeStore,
}))

describe('usePushNotification', () => {
  beforeEach(() => {
    vi.resetModules()
    mocks.pushApi.isEnabled.mockReset()
    mocks.pushApi.getVapidPublicKey.mockReset()
    mocks.pushApi.subscribe.mockReset()
    mocks.pushApi.unsubscribe.mockReset()
    mocks.buildPushSubscriptionRequest.mockReset()
    mocks.syncServiceWorkerLocale.mockReset()
    mocks.localeStore.locale = 'ja'

    const notificationApi = {
      permission: 'granted' as NotificationPermission,
      requestPermission: vi.fn().mockResolvedValue('granted' as NotificationPermission),
    }

    Object.defineProperty(globalThis, 'Notification', {
      value: notificationApi,
      configurable: true,
    })

    Object.defineProperty(globalThis, 'window', {
      value: {
        Notification: notificationApi,
        PushManager: function PushManager() {},
        atob: (value: string) => Buffer.from(value, 'base64').toString('binary'),
      },
      configurable: true,
    })
  })

  it('syncs locale before sending an existing subscription to the server', async () => {
    const existingSubscription = {
      endpoint: 'https://push.example/subscription',
    } as PushSubscription
    const registration = {
      pushManager: {
        getSubscription: vi.fn().mockResolvedValue(existingSubscription),
        subscribe: vi.fn(),
      },
    } as unknown as ServiceWorkerRegistration

    Object.defineProperty(globalThis, 'navigator', {
      value: {
        serviceWorker: {
          getRegistration: vi.fn().mockResolvedValue(registration),
          ready: Promise.resolve(registration),
          register: vi.fn(),
        },
      },
      configurable: true,
    })

    mocks.pushApi.isEnabled.mockResolvedValue(true)
    mocks.pushApi.getVapidPublicKey.mockResolvedValue('dGVzdA')
    mocks.buildPushSubscriptionRequest.mockReturnValue({
      endpoint: 'https://push.example/subscription',
      keys: {
        p256dh: 'p256dh',
        auth: 'auth',
      },
    })
    mocks.pushApi.subscribe.mockResolvedValue(true)

    const { usePushNotification } = await import('./usePushNotification')
    const pushNotification = usePushNotification()
    pushNotification.checkSupport()

    const result = await pushNotification.subscribe()

    expect(result).toBe(true)
    expect(mocks.syncServiceWorkerLocale).toHaveBeenCalledWith('ja', registration)
    expect(mocks.buildPushSubscriptionRequest).toHaveBeenCalledWith(existingSubscription)
    expect(registration.pushManager.subscribe).not.toHaveBeenCalled()
    const syncOrder = mocks.syncServiceWorkerLocale.mock.invocationCallOrder[0]
    const subscribeOrder = mocks.pushApi.subscribe.mock.invocationCallOrder[0]
    expect(syncOrder).toBeDefined()
    expect(subscribeOrder).toBeDefined()
    expect(syncOrder!).toBeLessThan(subscribeOrder!)
  })

  it('does not call server subscribe when vapid public key is unavailable', async () => {
    Object.defineProperty(globalThis, 'navigator', {
      value: {
        serviceWorker: {
          getRegistration: vi.fn().mockResolvedValue(null),
          ready: Promise.resolve(null),
          register: vi.fn(),
        },
      },
      configurable: true,
    })

    mocks.pushApi.isEnabled.mockResolvedValue(true)
    mocks.pushApi.getVapidPublicKey.mockResolvedValue('')

    const { usePushNotification } = await import('./usePushNotification')
    const pushNotification = usePushNotification()
    pushNotification.checkSupport()

    const result = await pushNotification.subscribe()

    expect(result).toBe(false)
    expect(mocks.pushApi.subscribe).not.toHaveBeenCalled()
    expect(mocks.syncServiceWorkerLocale).not.toHaveBeenCalled()
  })

  it('stops before server subscribe when permission is denied', async () => {
    const deniedNotificationApi = {
      permission: 'default' as NotificationPermission,
      requestPermission: vi.fn().mockResolvedValue('denied' as NotificationPermission),
    }
    Object.defineProperty(globalThis, 'Notification', {
      value: deniedNotificationApi,
      configurable: true,
    })
    Object.defineProperty(globalThis, 'window', {
      value: {
        Notification: deniedNotificationApi,
        PushManager: function PushManager() {},
        atob: (value: string) => Buffer.from(value, 'base64').toString('binary'),
      },
      configurable: true,
    })
    Object.defineProperty(globalThis, 'navigator', {
      value: {
        serviceWorker: {
          getRegistration: vi.fn(),
          ready: Promise.resolve(null),
          register: vi.fn(),
        },
      },
      configurable: true,
    })

    mocks.pushApi.isEnabled.mockResolvedValue(true)

    const { usePushNotification } = await import('./usePushNotification')
    const pushNotification = usePushNotification()
    pushNotification.checkSupport()

    const result = await pushNotification.subscribe()

    expect(result).toBe(false)
    expect(deniedNotificationApi.requestPermission).toHaveBeenCalled()
    expect(mocks.pushApi.getVapidPublicKey).not.toHaveBeenCalled()
    expect(mocks.pushApi.subscribe).not.toHaveBeenCalled()
  })
})
