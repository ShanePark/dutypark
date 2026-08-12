import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

vi.mock('@/api/consent', () => ({
  aiScheduleParsingConsentApi: {
    getCurrent: vi.fn(),
    grant: vi.fn(),
    revoke: vi.fn(),
  },
}))

import { aiScheduleParsingConsentApi } from '@/api/consent'
import { useAiScheduleConsentStore } from './aiScheduleConsent'

function dto(consented = false, needsRenewal = false) {
  return {
    consented,
    currentPolicyVersion: 'v2',
    consentVersion: consented ? 'v2' : null,
    needsRenewal,
    consentedAt: consented ? '2026-08-13T00:00:00Z' : null,
    revokedAt: null,
    policy: {
      policyType: 'AI_SCHEDULE_PARSING' as const,
      version: 'v2',
      content: 'policy',
      effectiveDate: '2026-08-13',
    },
  }
}

describe('AI schedule parsing consent store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  it('loads current state and grants the current policy', async () => {
    vi.mocked(aiScheduleParsingConsentApi.getCurrent).mockResolvedValue(dto())
    vi.mocked(aiScheduleParsingConsentApi.grant).mockResolvedValue(dto(true))
    const store = useAiScheduleConsentStore()

    await store.loadForMember(7)
    await store.grant(7)

    expect(aiScheduleParsingConsentApi.grant).toHaveBeenCalledWith('v2')
    expect(store.isCurrent).toBe(true)
  })

  it('revokes the current account', async () => {
    vi.mocked(aiScheduleParsingConsentApi.getCurrent).mockResolvedValue(dto(true))
    vi.mocked(aiScheduleParsingConsentApi.revoke).mockResolvedValue(dto(false))
    const store = useAiScheduleConsentStore()

    await store.loadForMember(7)
    await store.revoke(7)

    expect(aiScheduleParsingConsentApi.revoke).toHaveBeenCalledOnce()
    expect(store.isCurrent).toBe(false)
  })

  it('clears the previous response before loading a switched account', async () => {
    vi.mocked(aiScheduleParsingConsentApi.getCurrent)
      .mockResolvedValueOnce(dto(true))
      .mockResolvedValueOnce(dto(false))
    const store = useAiScheduleConsentStore()

    await store.loadForMember(7)
    const pending = store.loadForMember(9)

    expect(store.memberId).toBe(9)
    expect(store.consent).toBeNull()
    await pending
    expect(store.isCurrent).toBe(false)
  })
})
