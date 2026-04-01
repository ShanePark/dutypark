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
    vi.mocked(syncServiceWorkerLocale).mockClear()
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

  it('supports japanese browser locales', async () => {
    setNavigatorLanguage('ja-JP')

    const { useLocaleStore } = await import('./locale')
    const store = useLocaleStore()

    store.initializeLocale()

    expect(store.locale).toBe('ja')
    expect(localStorageMock.setItem).not.toHaveBeenCalledWith('dp-locale', 'ja')
    expect(store.explicitLocale).toBeNull()
    expect(store.detectedLocale).toBe('ja')
    expect(store.shouldSuggestLocale).toBe(true)
    expect(document.documentElement.lang).toBe('ja')
    expect(syncServiceWorkerLocale).toHaveBeenCalledWith('ja')
  })

  it('supports chinese browser locales', async () => {
    setNavigatorLanguage('zh-CN')

    const { useLocaleStore } = await import('./locale')
    const store = useLocaleStore()

    store.initializeLocale()

    expect(store.locale).toBe('zh')
    expect(localStorageMock.setItem).not.toHaveBeenCalledWith('dp-locale', 'zh')
    expect(store.explicitLocale).toBeNull()
    expect(store.detectedLocale).toBe('zh')
    expect(store.shouldSuggestLocale).toBe(true)
    expect(document.documentElement.lang).toBe('zh')
    expect(syncServiceWorkerLocale).toHaveBeenCalledWith('zh')
  })

  it('supports spanish browser locales', async () => {
    setNavigatorLanguage('es-ES')

    const { useLocaleStore } = await import('./locale')
    const store = useLocaleStore()

    store.initializeLocale()

    expect(store.locale).toBe('es')
    expect(localStorageMock.setItem).not.toHaveBeenCalledWith('dp-locale', 'es')
    expect(store.explicitLocale).toBeNull()
    expect(store.detectedLocale).toBe('es')
    expect(store.shouldSuggestLocale).toBe(true)
    expect(document.documentElement.lang).toBe('es')
    expect(syncServiceWorkerLocale).toHaveBeenCalledWith('es')
  })

  it('falls back to korean when the browser locale is unsupported', async () => {
    setNavigatorLanguage('fr-FR')

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

    await store.setLocale('ja')

    expect(store.locale).toBe('ja')
    expect(localStorageMock.setItem).toHaveBeenCalledWith('dp-locale', 'ja')
    expect(store.explicitLocale).toBe('ja')
    expect(document.documentElement.lang).toBe('ja')
    expect(syncServiceWorkerLocale).toHaveBeenCalledWith('ja')
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

  it('keeps the explicit locale after initialization without server sync', async () => {
    storage.set('dp-locale', 'en')

    const { useLocaleStore } = await import('./locale')
    const store = useLocaleStore()

    store.initializeLocale()

    expect(store.locale).toBe('en')
    expect(document.documentElement.lang).toBe('en')
  })

  it('persists chinese locale changes', async () => {
    const { useLocaleStore } = await import('./locale')
    const store = useLocaleStore()

    await store.setLocale('zh')

    expect(store.locale).toBe('zh')
    expect(localStorageMock.setItem).toHaveBeenCalledWith('dp-locale', 'zh')
    expect(store.explicitLocale).toBe('zh')
    expect(document.documentElement.lang).toBe('zh')
    expect(syncServiceWorkerLocale).toHaveBeenCalledWith('zh')
  })
})
