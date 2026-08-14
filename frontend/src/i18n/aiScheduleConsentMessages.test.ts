import { describe, expect, it } from 'vitest'
import en from './messages/en'
import ko from './messages/ko'

describe('AI schedule parsing consent messages', () => {
  it.each([
    ['ko', ko, '외부 AI 처리 서비스'],
    ['en', en, 'external AI processing service'],
  ])('provides complete, provider-neutral disclosure copy for %s', (_locale, messages, externalServiceLabel) => {
    const consent = messages.aiScheduleConsent
    const exposedCopy = JSON.stringify(consent)

    expect(consent.settingsTitle).toBeTruthy()
    expect(consent.dataFlowTitle).toBeTruthy()
    expect(consent.dataFlow).toContain(externalServiceLabel)
    expect(exposedCopy).not.toMatch(/Google|Generative Language API/i)
    expect(consent.optionalDescription).toBeTruthy()
    expect(consent.consentAcknowledgement).toBeTruthy()
    expect(consent.consentAction).toBeTruthy()
    expect(consent.consentSaving).toBeTruthy()
    expect(consent.viewPolicy).toBeTruthy()
    expect(consent.messages.granted).toBeTruthy()
    expect(consent.messages.revoked).toBeTruthy()
  })
})
