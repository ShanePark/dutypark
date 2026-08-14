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

function dto(
  consented = false,
  needsRenewal = false,
  previouslyConsentedToCurrentPolicy = consented,
) {
  return {
    consented,
    previouslyConsentedToCurrentPolicy,
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
    vi.mocked(aiScheduleParsingConsentApi.revoke).mockResolvedValue(dto(false, false, true))
    const store = useAiScheduleConsentStore()

    await store.loadForMember(7)
    await store.revoke(7)

    expect(aiScheduleParsingConsentApi.revoke).toHaveBeenCalledOnce()
    expect(store.isCurrent).toBe(false)
    expect(store.consent?.previouslyConsentedToCurrentPolicy).toBe(true)
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

  it('force refreshes an already loaded account', async () => {
    vi.mocked(aiScheduleParsingConsentApi.getCurrent)
      .mockResolvedValueOnce(dto(true))
      .mockResolvedValueOnce({
        ...dto(false),
        revokedAt: '2026-08-13T01:00:00Z',
      })
    const store = useAiScheduleConsentStore()

    await store.loadForMember(7)
    await store.loadForMember(7, true)

    expect(aiScheduleParsingConsentApi.getCurrent).toHaveBeenCalledTimes(2)
    expect(store.consent?.revokedAt).toBe('2026-08-13T01:00:00Z')
    expect(store.isCurrent).toBe(false)
  })

  it('merges overlapping stale refreshes for the same member', async () => {
    let resolveRequest!: (value: ReturnType<typeof dto>) => void
    vi.mocked(aiScheduleParsingConsentApi.getCurrent).mockReturnValue(new Promise((resolve) => {
      resolveRequest = resolve
    }))
    const store = useAiScheduleConsentStore()

    const first = store.refreshIfStaleForMember(7, 30_000)
    const second = store.refreshIfStaleForMember(7, 30_000)

    expect(aiScheduleParsingConsentApi.getCurrent).toHaveBeenCalledOnce()
    resolveRequest(dto())
    await Promise.all([first, second])
  })

  it('uses a fresh cached result and refreshes it once after it becomes stale', async () => {
    let now = 1_000
    const nowSpy = vi.spyOn(Date, 'now').mockImplementation(() => now)
    vi.mocked(aiScheduleParsingConsentApi.getCurrent).mockResolvedValue(dto())
    const store = useAiScheduleConsentStore()

    await store.loadForMember(7)
    await store.refreshIfStaleForMember(7, 30_000)
    await store.refreshIfStaleForMember(7, 30_000)
    expect(aiScheduleParsingConsentApi.getCurrent).toHaveBeenCalledOnce()

    now += 30_001
    await store.refreshIfStaleForMember(7, 30_000)
    expect(aiScheduleParsingConsentApi.getCurrent).toHaveBeenCalledTimes(2)
    nowSpy.mockRestore()
  })

  it('treats successful grants and revocations as fresh', async () => {
    let now = 1_000
    const nowSpy = vi.spyOn(Date, 'now').mockImplementation(() => now)
    vi.mocked(aiScheduleParsingConsentApi.getCurrent).mockResolvedValue(dto())
    vi.mocked(aiScheduleParsingConsentApi.grant).mockResolvedValue(dto(true))
    vi.mocked(aiScheduleParsingConsentApi.revoke).mockResolvedValue(dto(false, false, true))
    const store = useAiScheduleConsentStore()

    await store.loadForMember(7)
    now += 30_001
    await store.grant(7)
    await store.refreshIfStaleForMember(7, 30_000)
    now += 30_001
    await store.revoke(7)
    await store.refreshIfStaleForMember(7, 30_000)

    expect(aiScheduleParsingConsentApi.getCurrent).toHaveBeenCalledOnce()
    nowSpy.mockRestore()
  })

  it('keeps the cached value when a stale refresh fails', async () => {
    let now = 1_000
    const nowSpy = vi.spyOn(Date, 'now').mockImplementation(() => now)
    vi.mocked(aiScheduleParsingConsentApi.getCurrent)
      .mockResolvedValueOnce(dto(true))
      .mockRejectedValueOnce(new Error('network'))
      .mockResolvedValueOnce(dto(true))
    const store = useAiScheduleConsentStore()

    await store.loadForMember(7)
    now += 30_001
    await expect(store.refreshIfStaleForMember(7, 30_000)).rejects.toThrow('network')

    expect(store.isCurrent).toBe(true)
    expect(store.loadFailed).toBe(true)
    await store.refreshIfStaleForMember(7, 30_000)
    expect(aiScheduleParsingConsentApi.getCurrent).toHaveBeenCalledTimes(3)
    nowSpy.mockRestore()
  })
})
