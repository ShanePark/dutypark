import { describe, expect, it } from 'vitest'
import type { AiScheduleParsingConsentDto } from '@/api/consent'
import {
  canReenableAiScheduleConsentWithoutPrompt,
  getAiScheduleConsentAction,
  isAiTimeParsingCandidate,
} from './aiScheduleConsentFlow'

function consentDto(
  overrides: Partial<AiScheduleParsingConsentDto> = {},
): AiScheduleParsingConsentDto {
  return {
    consented: false,
    previouslyConsentedToCurrentPolicy: false,
    currentPolicyVersion: 'v2',
    consentVersion: null,
    needsRenewal: false,
    consentedAt: null,
    revokedAt: null,
    policy: {
      policyType: 'AI_SCHEDULE_PARSING',
      version: 'v2',
      content: 'policy',
      effectiveDate: '2026-08-13',
    },
    ...overrides,
  }
}

describe('AI schedule consent flow', () => {
  it('re-enables without prompting only after prior consent to the current policy', () => {
    expect(canReenableAiScheduleConsentWithoutPrompt(consentDto({
      previouslyConsentedToCurrentPolicy: true,
      revokedAt: '2026-08-13T00:00:00Z',
    }))).toBe(true)
    expect(canReenableAiScheduleConsentWithoutPrompt(consentDto())).toBe(false)
    expect(canReenableAiScheduleConsentWithoutPrompt({} as AiScheduleParsingConsentDto)).toBe(false)
    expect(canReenableAiScheduleConsentWithoutPrompt(null)).toBe(false)
  })

  it('treats an all-day midnight range as an AI parsing candidate', () => {
    expect(isAiTimeParsingCandidate('2026-08-13T00:00:00', '2026-08-13T00:00:00')).toBe(true)
    expect(isAiTimeParsingCandidate('2026-08-13T00:00', '2026-08-14T00:00')).toBe(true)
    expect(isAiTimeParsingCandidate('2026-08-13T09:00:00', '2026-08-13T10:00:00')).toBe(false)
  })

  it('requests AI without prompting only for current consent', () => {
    expect(getAiScheduleConsentAction(consentDto({ consented: true }))).toBe('request-ai')
  })

  it('prompts for a first decision and renewed consent', () => {
    expect(getAiScheduleConsentAction(consentDto())).toBe('prompt')
    expect(getAiScheduleConsentAction(consentDto({
      consented: true,
      needsRenewal: true,
      consentVersion: 'v1',
    }))).toBe('prompt')
  })

  it('does not repeatedly prompt after revocation', () => {
    expect(getAiScheduleConsentAction(consentDto({
      revokedAt: '2026-08-13T00:00:00Z',
    }))).toBe('without-ai')
  })
})
