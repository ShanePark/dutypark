import { beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('./client', () => ({
  default: { get: vi.fn(), put: vi.fn() },
}))

import apiClient from './client'
import { aiScheduleParsingConsentApi } from './consent'

const response = {
  consented: false,
  previouslyConsentedToCurrentPolicy: false,
  currentPolicyVersion: '2026-08-13',
  consentVersion: null,
  needsRenewal: false,
  consentedAt: null,
  revokedAt: null,
  policy: {
    policyType: 'AI_SCHEDULE_PARSING' as const,
    version: '2026-08-13',
    content: '# AI schedule parsing',
    effectiveDate: '2026-08-13',
  },
}

describe('AI schedule parsing consent API', () => {
  beforeEach(() => vi.clearAllMocks())

  it('reads the current account consent', async () => {
    vi.mocked(apiClient.get).mockResolvedValue({ data: response })
    await expect(aiScheduleParsingConsentApi.getCurrent()).resolves.toBe(response)
    expect(apiClient.get).toHaveBeenCalledWith('/consents/ai-schedule-parsing')
    expect(response.previouslyConsentedToCurrentPolicy).toBe(false)
  })

  it('grants only the displayed policy version', async () => {
    vi.mocked(apiClient.put).mockResolvedValue({ data: { ...response, consented: true } })
    await aiScheduleParsingConsentApi.grant('2026-08-13')
    expect(apiClient.put).toHaveBeenCalledWith('/consents/ai-schedule-parsing', {
      consented: true,
      policyVersion: '2026-08-13',
    })
  })

  it('revokes without inventing a policy version', async () => {
    vi.mocked(apiClient.put).mockResolvedValue({ data: response })
    await aiScheduleParsingConsentApi.revoke()
    expect(apiClient.put).toHaveBeenCalledWith('/consents/ai-schedule-parsing', {
      consented: false,
    })
  })
})
