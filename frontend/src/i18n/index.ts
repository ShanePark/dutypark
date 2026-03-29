import { createI18n } from 'vue-i18n'
import en from './messages/en'
import ja from './messages/ja'
import ko from './messages/ko'

export const SUPPORTED_LOCALES = ['ko', 'en', 'ja'] as const
export type SupportedLocale = (typeof SUPPORTED_LOCALES)[number]
export const LOCALE_NATIVE_LABELS: Record<SupportedLocale, string> = {
  ko: '한국어',
  en: 'English',
  ja: '日本語',
}

export const DEFAULT_LOCALE: SupportedLocale = 'ko'
export const LOCALE_STORAGE_KEY = 'dp-locale'
export const LOCALE_SUGGESTION_STORAGE_KEY = 'dp-locale-suggestion'

const messages = {
  ko,
  en,
  ja,
}

export function isSupportedLocale(value: string | null | undefined): value is SupportedLocale {
  return value === 'ko' || value === 'en' || value === 'ja'
}

export function normalizeLocale(value: string | null | undefined): SupportedLocale {
  const normalized = value?.toLowerCase()
  if (!normalized) {
    return DEFAULT_LOCALE
  }
  if (normalized.startsWith('en')) {
    return 'en'
  }
  if (normalized.startsWith('ja')) {
    return 'ja'
  }
  if (normalized.startsWith('ko')) {
    return 'ko'
  }
  return DEFAULT_LOCALE
}

export function getLocaleNativeLabel(locale: SupportedLocale): string {
  return LOCALE_NATIVE_LABELS[locale]
}

export function detectBrowserLocale(): SupportedLocale {
  if (typeof navigator === 'undefined') {
    return DEFAULT_LOCALE
  }
  return normalizeLocale(navigator.language)
}

export function readStoredLocalePreference(): SupportedLocale | null {
  if (typeof window === 'undefined') {
    return null
  }

  const stored = window.localStorage.getItem(LOCALE_STORAGE_KEY)
  if (isSupportedLocale(stored)) {
    return stored
  }

  return null
}

export function writeStoredLocalePreference(locale: SupportedLocale) {
  if (typeof window === 'undefined') {
    return
  }
  window.localStorage.setItem(LOCALE_STORAGE_KEY, locale)
}

export function clearStoredLocalePreference() {
  if (typeof window === 'undefined') {
    return
  }
  window.localStorage.removeItem(LOCALE_STORAGE_KEY)
}

export function readHandledLocaleSuggestion(): SupportedLocale | null {
  if (typeof window === 'undefined') {
    return null
  }

  const stored = window.localStorage.getItem(LOCALE_SUGGESTION_STORAGE_KEY)
  return isSupportedLocale(stored) ? stored : null
}

export function markLocaleSuggestionHandled(locale: SupportedLocale) {
  if (typeof window === 'undefined') {
    return
  }
  window.localStorage.setItem(LOCALE_SUGGESTION_STORAGE_KEY, locale)
}

export function clearHandledLocaleSuggestion() {
  if (typeof window === 'undefined') {
    return
  }
  window.localStorage.removeItem(LOCALE_SUGGESTION_STORAGE_KEY)
}

export function readStoredLocale(): SupportedLocale {
  return readStoredLocalePreference() ?? detectBrowserLocale()
}

export const i18n = createI18n({
  legacy: false,
  locale: readStoredLocale(),
  fallbackLocale: {
    ja: ['en', 'ko'],
    en: ['ko'],
    default: ['ko'],
  },
  messages,
})

export function setI18nLanguage(
  locale: SupportedLocale,
  options: { persist?: boolean } = {},
): SupportedLocale {
  i18n.global.locale.value = locale

  if (typeof document !== 'undefined') {
    document.documentElement.lang = locale
  }

  if (options.persist && typeof window !== 'undefined') {
    writeStoredLocalePreference(locale)
  }

  return locale
}

export function getCurrentLocale(): SupportedLocale {
  const locale = i18n.global.locale.value
  return isSupportedLocale(locale) ? locale : readStoredLocale()
}

export function translateGlobal(key: string, values?: Record<string, unknown>): string {
  return String(i18n.global.t(key, values ?? {}))
}
