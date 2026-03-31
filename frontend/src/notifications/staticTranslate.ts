import en from '@/i18n/messages/en'
import ja from '@/i18n/messages/ja'
import ko from '@/i18n/messages/ko'
import {
  DEFAULT_LOCALE,
  normalizeLocale,
  type SupportedLocale,
} from '@/i18n/localeUtils'
import type { NotificationTranslate, NotificationTranslateParams } from './renderers/types'

type LocaleMessages = Record<string, unknown>

const notificationMessagesByLocale: Record<SupportedLocale, LocaleMessages> = {
  ko,
  en,
  ja,
}

const notificationLocaleFallbacks: Record<SupportedLocale, SupportedLocale[]> = {
  ko: ['ko'],
  en: ['en', 'ko'],
  ja: ['ja', 'en', 'ko'],
}

function getNestedMessage(messages: LocaleMessages, key: string): string | null {
  const resolved = key.split('.').reduce<unknown>((current, segment) => {
    if (current == null || typeof current !== 'object') {
      return null
    }
    return (current as LocaleMessages)[segment] ?? null
  }, messages)

  return typeof resolved === 'string' ? resolved : null
}

function interpolateMessage(template: string, params: NotificationTranslateParams = {}): string {
  return Object.entries(params).reduce((message, [key, value]) => {
    return message.split(`{${key}}`).join(String(value))
  }, template)
}

function getMessageForLocale(locale: SupportedLocale, key: string): string | null {
  for (const candidate of notificationLocaleFallbacks[locale]) {
    const message = getNestedMessage(notificationMessagesByLocale[candidate], key)
    if (message) {
      return message
    }
  }
  return null
}

export function createStaticNotificationTranslate(
  locale: string | SupportedLocale | null | undefined,
): NotificationTranslate {
  const resolvedLocale = normalizeLocale(locale ?? DEFAULT_LOCALE)

  return (key, params = {}) => {
    const template = getMessageForLocale(resolvedLocale, key) ?? key
    return interpolateMessage(template, params)
  }
}
