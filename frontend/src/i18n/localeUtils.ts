export const SUPPORTED_LOCALES = ['ko', 'en'] as const
export type SupportedLocale = (typeof SUPPORTED_LOCALES)[number]
export const LOCALE_NATIVE_LABELS: Record<SupportedLocale, string> = {
  ko: '한국어',
  en: 'English',
}

export const DEFAULT_LOCALE: SupportedLocale = 'ko'

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
  return 'en'
}

export function detectBrowserLocale(): SupportedLocale {
  if (typeof navigator === 'undefined') {
    return DEFAULT_LOCALE
  }
  return normalizeLocale(navigator.language)
}
