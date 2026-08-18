import { describe, expect, it } from 'vitest'
import { createI18n } from 'vue-i18n'
import en from './messages/en'
import ko from './messages/ko'

const locales = { ko, en }

// vue-i18n reserves `@` for linked messages and `{`/`}` for interpolation, so a literal
// `@` in a message throws at translation time and takes the whole view down.
// Compiling every message here catches those escapes before they reach a route.
function collectKeys(messages: object, prefix = ''): string[] {
  return Object.entries(messages).flatMap(([key, value]) => {
    const path = prefix ? `${prefix}.${key}` : key
    if (typeof value === 'object' && value !== null) {
      return collectKeys(value, path)
    }
    return [path]
  })
}

describe('message compilation', () => {
  it.each(Object.entries(locales))('%s compiles every message', (locale, messages) => {
    const i18n = createI18n({ legacy: false, locale, messages: { [locale]: messages } })
    const failures: string[] = []

    for (const key of collectKeys(messages)) {
      try {
        i18n.global.t(key)
      } catch (error) {
        failures.push(`${key}: ${(error as Error).message}`)
      }
    }

    expect(failures).toEqual([])
  })
})

describe('support form placeholder', () => {
  it.each(Object.entries(locales))('%s renders a literal e-mail address', (locale, messages) => {
    const i18n = createI18n({ legacy: false, locale, messages: { [locale]: messages } })
    expect(i18n.global.t('support.form.emailPlaceholder')).toBe('you@example.com')
  })
})
