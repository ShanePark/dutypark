import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { syncServiceWorkerLocale } from '@/utils/serviceWorkerLocale'

vi.mock('@/utils/serviceWorkerLocale', () => ({
  syncServiceWorkerLocale: vi.fn(),
}))

const storage = new Map<string, string>()

const localStorageMock = {
  getItem: vi.fn((key: string) => storage.get(key) ?? null),
  setItem: vi.fn((key: string, value: string) => {
    storage.set(key, value)
  }),
  removeItem: vi.fn((key: string) => {
    storage.delete(key)
  }),
}

Object.defineProperty(globalThis, 'localStorage', {
  value: localStorageMock,
  configurable: true,
})

Object.defineProperty(globalThis, 'window', {
  value: {
    localStorage: localStorageMock,
  },
  configurable: true,
})

Object.defineProperty(globalThis, 'document', {
  value: {
    documentElement: {
      lang: '',
    },
  },
  configurable: true,
})

function setNavigatorLanguage(language: string) {
  Object.defineProperty(globalThis, 'navigator', {
    value: {
      language,
    },
    configurable: true,
  })
}

describe('locale store', () => {
  beforeEach(() => {
    storage.clear()
    localStorageMock.getItem.mockClear()
    localStorageMock.setItem.mockClear()
    localStorageMock.removeItem.mockClear()
    vi.mocked(syncServiceWorkerLocale).mockReset().mockResolvedValue(undefined)
    document.documentElement.lang = ''
    setNavigatorLanguage('ko-KR')
    vi.resetModules()
    setActivePinia(createPinia())
  })

  it('initializes from the stored locale first', async () => {
    storage.set('dp-locale', 'en')

    const { useLocaleStore } = await import('./locale')
    const store = useLocaleStore()

    store.initializeLocale()

    expect(store.locale).toBe('en')
    expect(store.explicitLocale).toBe('en')
    expect(store.shouldSuggestLocale).toBe(false)
    expect(document.documentElement.lang).toBe('en')
    expect(syncServiceWorkerLocale).toHaveBeenCalledWith('en')
  })

  it('falls back to the browser locale when supported', async () => {
    setNavigatorLanguage('en-US')

    const { useLocaleStore } = await import('./locale')
    const store = useLocaleStore()

    store.initializeLocale()

    expect(store.locale).toBe('en')
    expect(localStorageMock.setItem).not.toHaveBeenCalledWith('dp-locale', 'en')
    expect(store.explicitLocale).toBeNull()
    expect(store.detectedLocale).toBe('en')
    expect(store.shouldSuggestLocale).toBe(true)
  })

  it('falls back to English when the browser locale is unsupported', async () => {
    setNavigatorLanguage('fr-FR')

    const { useLocaleStore } = await import('./locale')
    const store = useLocaleStore()

    store.initializeLocale()

    expect(store.locale).toBe('en')
    expect(store.explicitLocale).toBeNull()
    expect(store.detectedLocale).toBe('en')
    expect(store.shouldSuggestLocale).toBe(true)
    expect(document.documentElement.lang).toBe('en')
    expect(syncServiceWorkerLocale).toHaveBeenCalledWith('en')
  })

  it.each(['ja', 'zh', 'es'])('ignores the stored %s locale after support is removed', async (storedLocale) => {
    storage.set('dp-locale', storedLocale)
    setNavigatorLanguage('ko-KR')

    const { useLocaleStore } = await import('./locale')
    const store = useLocaleStore()

    store.initializeLocale()

    expect(store.locale).toBe('ko')
    expect(store.explicitLocale).toBeNull()
    expect(store.detectedLocale).toBe('ko')
    expect(store.shouldSuggestLocale).toBe(false)
    expect(document.documentElement.lang).toBe('ko')
  })

  it('persists locale changes', async () => {
    const { useLocaleStore } = await import('./locale')
    const store = useLocaleStore()

    await store.setLocale('en')

    expect(store.locale).toBe('en')
    expect(localStorageMock.setItem).toHaveBeenCalledWith('dp-locale', 'en')
    expect(store.explicitLocale).toBe('en')
    expect(document.documentElement.lang).toBe('en')
    expect(syncServiceWorkerLocale).toHaveBeenCalledWith('en')
  })

  it('marks the detected locale as handled when the suggestion is dismissed', async () => {
    setNavigatorLanguage('en-US')

    const { useLocaleStore } = await import('./locale')
    const store = useLocaleStore()

    store.initializeLocale()
    store.dismissLocaleSuggestion()

    expect(localStorageMock.setItem).toHaveBeenCalledWith('dp-locale-suggestion', 'en')
    expect(store.shouldSuggestLocale).toBe(false)
  })

  it('allows confirming the detected locale as an explicit choice', async () => {
    setNavigatorLanguage('en-US')

    const { useLocaleStore } = await import('./locale')
    const store = useLocaleStore()

    store.initializeLocale()
    await store.confirmDetectedLocale()

    expect(store.locale).toBe('en')
    expect(store.explicitLocale).toBe('en')
    expect(store.shouldSuggestLocale).toBe(false)
    expect(localStorageMock.setItem).toHaveBeenCalledWith('dp-locale', 'en')
    expect(syncServiceWorkerLocale).toHaveBeenCalledWith('en')
  })

  it('does not wait for a service worker sync that never settles', async () => {
    // `navigator.serviceWorker.ready` stays pending until push notifications register a worker.
    vi.mocked(syncServiceWorkerLocale).mockImplementation(() => new Promise(() => {}))
    setNavigatorLanguage('en-US')
    const { useLocaleStore } = await import('./locale')
    const store = useLocaleStore()
    store.initializeLocale()
    const pending = Symbol('pending')
    const settled = (result: unknown) =>
      Promise.race([Promise.resolve(result), new Promise(resolve => setTimeout(() => resolve(pending), 0))])

    expect(await settled(store.confirmDetectedLocale())).not.toBe(pending)
    expect(store.locale).toBe('en')
    expect(await settled(store.setLocale('ko'))).not.toBe(pending)
    expect(store.locale).toBe('ko')
    expect(await settled(store.setLocale('en'))).not.toBe(pending)
    expect(store.locale).toBe('en')
  })

  it('applies the locale and swallows a failed service worker sync', async () => {
    // A mocked sync would not do: Vitest's spy observes every promise a mock returns, so a
    // rejection from it is never unhandled. Use the real sync with a failing registration lookup.
    vi.doUnmock('@/utils/serviceWorkerLocale')
    Object.defineProperty(globalThis, 'navigator', {
      value: {
        language: 'en-US',
        serviceWorker: {
          getRegistration: () => Promise.reject(new Error('getRegistration failed')),
        },
      },
      configurable: true,
    })
    const unhandled = vi.fn()
    process.on('unhandledRejection', unhandled)
    try {
      const { useLocaleStore } = await import('./locale')
      const store = useLocaleStore()
      store.initializeLocale()
      store.confirmDetectedLocale()
      expect(store.locale).toBe('en')
      store.setLocale('ko')
      expect(store.locale).toBe('ko')
      await new Promise(resolve => setTimeout(resolve, 0))

      expect(unhandled).not.toHaveBeenCalled()
    } finally {
      process.off('unhandledRejection', unhandled)
      vi.doMock('@/utils/serviceWorkerLocale', () => ({ syncServiceWorkerLocale }))
    }
  })

  it('keeps the explicit locale after initialization without server sync', async () => {
    storage.set('dp-locale', 'en')

    const { useLocaleStore } = await import('./locale')
    const store = useLocaleStore()

    store.initializeLocale()

    expect(store.locale).toBe('en')
    expect(document.documentElement.lang).toBe('en')
  })

})
