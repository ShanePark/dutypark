import { describe, expect, it } from 'vitest'
import en from './messages/en'
import es from './messages/es'
import ja from './messages/ja'
import ko from './messages/ko'
import zh from './messages/zh'

describe('AI schedule parsing consent messages', () => {
  it.each([
    ['ko', ko],
    ['en', en],
    ['ja', ja],
    ['zh', zh],
    ['es', es],
  ])('provides complete, localized disclosure copy for %s', (_locale, messages) => {
    const consent = messages.aiScheduleConsent

    expect(consent.settingsTitle).toBeTruthy()
    expect(consent.dataFlow).toContain('Google')
    expect(consent.optionalDescription).toBeTruthy()
    expect(consent.confirmDescription).toContain('Google')
    expect(consent.viewPolicy).toBeTruthy()
    expect(consent.messages.granted).toBeTruthy()
    expect(consent.messages.revoked).toBeTruthy()
  })
})
