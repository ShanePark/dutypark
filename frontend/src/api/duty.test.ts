import { beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('./client', () => ({
  default: {
    get: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
}))

import apiClient from './client'
import { dutyApi } from './duty'

describe('duty pattern API contract', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('sends null dutyTypeId as an explicit manual off override', async () => {
    vi.mocked(apiClient.put).mockResolvedValue({ data: true })

    await dutyApi.updateDuty(11, 2026, 8, 15, null)

    expect(apiClient.put).toHaveBeenCalledWith('/duty/change', {
      memberId: 11,
      year: 2026,
      month: 8,
      day: 15,
      dutyTypeId: null,
    })
  })

  it('deletes only the dated override when restoring pattern inheritance', async () => {
    vi.mocked(apiClient.delete).mockResolvedValue({ data: undefined })

    await dutyApi.deleteDutyOverride(11, '2026-08-15')

    expect(apiClient.delete).toHaveBeenCalledWith('/duty/override', {
      params: { memberId: 11, date: '2026-08-15' },
    })
  })

  it('updates weekday-specific duty types and holiday policy', async () => {
    const updated = {
      configurable: true,
      reason: null,
      pattern: {
        days: [
          { weekday: 'FRIDAY' as const, dutyType: { id: 7, name: '주간', color: null } },
          { weekday: 'SATURDAY' as const, dutyType: { id: 8, name: '야간', color: null } },
        ],
        holidayOff: false,
        effectiveFrom: '2026-07-11',
      },
      dutyTypes: [
        { id: 7, name: '주간', color: null },
        { id: 8, name: '야간', color: null },
      ],
    }
    vi.mocked(apiClient.put).mockResolvedValue({ data: updated })

    const result = await dutyApi.updateMyPattern({
      days: [
        { weekday: 'FRIDAY', dutyTypeId: 7 },
        { weekday: 'SATURDAY', dutyTypeId: 8 },
      ],
      holidayOff: false,
    })

    expect(apiClient.put).toHaveBeenCalledWith('/duty/pattern/me', {
      days: [
        { weekday: 'FRIDAY', dutyTypeId: 7 },
        { weekday: 'SATURDAY', dutyTypeId: 8 },
      ],
      holidayOff: false,
    })
    expect(result).toBe(updated)
  })

  it('uses separate endpoints for reading and deleting the current member pattern', async () => {
    const current = {
      configurable: false,
      reason: 'DUTY_TYPE_REQUIRED',
      pattern: null,
      dutyTypes: [],
    }
    vi.mocked(apiClient.get).mockResolvedValue({ data: current })
    vi.mocked(apiClient.delete).mockResolvedValue({ data: undefined })

    await expect(dutyApi.getMyPattern()).resolves.toBe(current)
    await dutyApi.deleteMyPattern()

    expect(apiClient.get).toHaveBeenCalledWith('/duty/pattern/me')
    expect(apiClient.delete).toHaveBeenCalledWith('/duty/pattern/me')
  })
})
