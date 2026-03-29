import { createI18n } from 'vue-i18n'
import en from './messages/en'
import ko from './messages/ko'

export const SUPPORTED_LOCALES = ['ko', 'en'] as const
export type SupportedLocale = (typeof SUPPORTED_LOCALES)[number]

export const DEFAULT_LOCALE: SupportedLocale = 'ko'
export const LOCALE_STORAGE_KEY = 'dp-locale'

const messages = {
  ko,
  en,
}

export function isSupportedLocale(value: string | null | undefined): value is SupportedLocale {
  return value === 'ko' || value === 'en'
}

export function normalizeLocale(value: string | null | undefined): SupportedLocale {
  const normalized = value?.toLowerCase()
  if (!normalized) {
    return DEFAULT_LOCALE
  }
  if (normalized.startsWith('en')) {
    return 'en'
  }
  if (normalized.startsWith('ko')) {
    return 'ko'
  }
  return DEFAULT_LOCALE
}

export function detectBrowserLocale(): SupportedLocale {
  if (typeof navigator === 'undefined') {
    return DEFAULT_LOCALE
  }
  return normalizeLocale(navigator.language)
}

export function readStoredLocale(): SupportedLocale {
  if (typeof window === 'undefined') {
    return DEFAULT_LOCALE
  }

  const stored = window.localStorage.getItem(LOCALE_STORAGE_KEY)
  if (isSupportedLocale(stored)) {
    return stored
  }

  return detectBrowserLocale()
}

export const i18n = createI18n({
  legacy: false,
  locale: readStoredLocale(),
  fallbackLocale: DEFAULT_LOCALE,
  messages,
})

export function setI18nLanguage(locale: SupportedLocale): SupportedLocale {
  i18n.global.locale.value = locale

  if (typeof document !== 'undefined') {
    document.documentElement.lang = locale
  }

  if (typeof window !== 'undefined') {
    window.localStorage.setItem(LOCALE_STORAGE_KEY, locale)
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
