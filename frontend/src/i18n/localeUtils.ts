export const SUPPORTED_LOCALES = ['ko', 'en', 'ja'] as const
export type SupportedLocale = (typeof SUPPORTED_LOCALES)[number]
export const LOCALE_NATIVE_LABELS: Record<SupportedLocale, string> = {
  ko: '한국어',
  en: 'English',
  ja: '日本語',
}

export const DEFAULT_LOCALE: SupportedLocale = 'ko'

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

export function detectBrowserLocale(): SupportedLocale {
  if (typeof navigator === 'undefined') {
    return DEFAULT_LOCALE
  }
  return normalizeLocale(navigator.language)
}
