import { describe, expect, it } from 'vitest'
import en from './messages/en'
import ko from './messages/ko'

describe('AI schedule parsing consent messages', () => {
  it.each([
    ['ko', ko],
    ['en', en],
  ])('provides complete, localized disclosure copy for %s', (_locale, messages) => {
    const consent = messages.aiScheduleConsent

    expect(consent.settingsTitle).toBeTruthy()
    expect(consent.dataFlowTitle).toBeTruthy()
    expect(consent.dataFlow).toContain('Google')
    expect(consent.optionalDescription).toBeTruthy()
    expect(consent.consentAcknowledgement).toBeTruthy()
    expect(consent.consentAction).toBeTruthy()
    expect(consent.consentSaving).toBeTruthy()
    expect(consent.viewPolicy).toBeTruthy()
    expect(consent.messages.granted).toBeTruthy()
    expect(consent.messages.revoked).toBeTruthy()
  })
})
