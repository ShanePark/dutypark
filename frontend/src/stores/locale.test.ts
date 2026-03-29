import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

vi.mock('@/api/member', () => ({
  memberApi: {
    getPreferredLocale: vi.fn(),
    updatePreferredLocale: vi.fn(),
  },
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
  })

  it('keeps the local locale when the server preference response is empty', async () => {
    storage.set('dp-locale', 'en')

    const { memberApi } = await import('@/api/member')
    vi.mocked(memberApi.getPreferredLocale).mockResolvedValue({
      data: '',
    } as never)

    const { useLocaleStore } = await import('./locale')
    const store = useLocaleStore()

    store.initializeLocale()
    await store.syncWithServerPreference()

    expect(store.locale).toBe('en')
    expect(document.documentElement.lang).toBe('en')
  })
})
