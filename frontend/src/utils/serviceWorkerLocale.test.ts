import { beforeEach, describe, expect, it, vi } from 'vitest'
import { syncServiceWorkerLocale } from './serviceWorkerLocale'

function createWorker() {
  return {
    postMessage: vi.fn(),
  } as unknown as ServiceWorker
}

describe('syncServiceWorkerLocale', () => {
  beforeEach(() => {
    Object.defineProperty(globalThis, 'window', {
      value: {},
      configurable: true,
    })
  })

  it('posts locale updates to all known worker targets', async () => {
    const active = createWorker()
    const waiting = createWorker()
    const installing = createWorker()
    const controller = createWorker()

    Object.defineProperty(globalThis, 'navigator', {
      value: {
        serviceWorker: {
          controller,
        },
      },
      configurable: true,
    })

    await syncServiceWorkerLocale('ja', {
      active,
      waiting,
      installing,
    } as unknown as ServiceWorkerRegistration)

    for (const target of [active, waiting, installing, controller]) {
      expect(target.postMessage).toHaveBeenCalledWith({
        type: 'DUTYPARK_SET_LOCALE',
        locale: 'ja',
      })
    }
  })

  it('falls back to navigator service worker registration lookup when registration is omitted', async () => {
    const active = createWorker()
    const registration = { active } as unknown as ServiceWorkerRegistration
    const getRegistration = vi.fn().mockResolvedValue(registration)

    Object.defineProperty(globalThis, 'navigator', {
      value: {
        serviceWorker: {
          getRegistration,
          ready: Promise.resolve(null),
          controller: null,
        },
      },
      configurable: true,
    })

    await syncServiceWorkerLocale('en')

    expect(getRegistration).toHaveBeenCalled()
    expect(active.postMessage).toHaveBeenCalledWith({
      type: 'DUTYPARK_SET_LOCALE',
      locale: 'en',
    })
  })

  it('falls back to navigator service worker ready when registration lookup returns null', async () => {
    const active = createWorker()
    const getRegistration = vi.fn().mockResolvedValue(null)

    Object.defineProperty(globalThis, 'navigator', {
      value: {
        serviceWorker: {
          getRegistration,
          ready: Promise.resolve({ active } as unknown as ServiceWorkerRegistration),
          controller: null,
        },
      },
      configurable: true,
    })

    await syncServiceWorkerLocale('ko')

    expect(getRegistration).toHaveBeenCalled()
    expect(active.postMessage).toHaveBeenCalledWith({
      type: 'DUTYPARK_SET_LOCALE',
      locale: 'ko',
    })
  })

  it('silently exits when no registration can be resolved', async () => {
    Object.defineProperty(globalThis, 'navigator', {
      value: {
        serviceWorker: {
          getRegistration: vi.fn().mockResolvedValue(null),
          ready: Promise.reject(new Error('not ready')),
          controller: null,
        },
      },
      configurable: true,
    })

    await expect(syncServiceWorkerLocale('en')).resolves.toBeUndefined()
  })
})
