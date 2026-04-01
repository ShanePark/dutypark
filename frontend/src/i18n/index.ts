import { createI18n } from 'vue-i18n'
import en from './messages/en'
import es from './messages/es'
import ja from './messages/ja'
import ko from './messages/ko'
import zh from './messages/zh'
import {
  DEFAULT_LOCALE,
  LOCALE_NATIVE_LABELS,
  SUPPORTED_LOCALES,
  detectBrowserLocale,
  isSupportedLocale,
  normalizeLocale,
  type SupportedLocale,
} from './localeUtils'

export const LOCALE_STORAGE_KEY = 'dp-locale'
export const LOCALE_SUGGESTION_STORAGE_KEY = 'dp-locale-suggestion'

const messages = {
  ko,
  en,
  ja,
  zh,
  es,
}

export function getLocaleNativeLabel(locale: SupportedLocale): string {
  return LOCALE_NATIVE_LABELS[locale]
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
    zh: ['en', 'ko'],
    es: ['en', 'ko'],
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

export {
  DEFAULT_LOCALE,
  LOCALE_NATIVE_LABELS,
  SUPPORTED_LOCALES,
  detectBrowserLocale,
  isSupportedLocale,
  normalizeLocale,
}
export type { SupportedLocale }
