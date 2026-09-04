import { beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('@/api/admin', () => ({
  adminApi: {
    getReports: vi.fn(),
    getInquiries: vi.fn(),
  },
}))

import { adminApi } from '@/api/admin'
import {
  resetAdminModerationCounts,
  useAdminModerationCounts,
} from './useAdminModerationCounts'

function page(totalElements: number) {
  return { data: { totalElements } }
}

describe('useAdminModerationCounts', () => {
  beforeEach(() => {
    resetAdminModerationCounts()
    vi.clearAllMocks()
  })

  it('shares one in-flight request and publishes both open counts', async () => {
    vi.mocked(adminApi.getReports).mockResolvedValue(page(5) as never)
    vi.mocked(adminApi.getInquiries).mockResolvedValue(page(2) as never)
    const counts = useAdminModerationCounts()

    await Promise.all([counts.load(), counts.load()])

    expect(adminApi.getReports).toHaveBeenCalledOnce()
    expect(adminApi.getReports).toHaveBeenCalledWith('OPEN', 0, 1)
    expect(adminApi.getInquiries).toHaveBeenCalledOnce()
    expect(adminApi.getInquiries).toHaveBeenCalledWith('OPEN', 0, 1)
    expect(counts.openReportCount.value).toBe(5)
    expect(counts.openInquiryCount.value).toBe(2)
  })

  it('uses the shared result for later consumers until explicitly refreshed', async () => {
    vi.mocked(adminApi.getReports).mockResolvedValue(page(5) as never)
    vi.mocked(adminApi.getInquiries).mockResolvedValue(page(2) as never)
    const counts = useAdminModerationCounts()

    await counts.load()
    await counts.load()

    expect(adminApi.getReports).toHaveBeenCalledOnce()
    expect(adminApi.getInquiries).toHaveBeenCalledOnce()
  })

  it('refreshes both counts when requested', async () => {
    vi.mocked(adminApi.getReports)
      .mockResolvedValueOnce(page(5) as never)
      .mockResolvedValueOnce(page(4) as never)
    vi.mocked(adminApi.getInquiries)
      .mockResolvedValueOnce(page(2) as never)
      .mockResolvedValueOnce(page(1) as never)
    const counts = useAdminModerationCounts()

    await counts.load()
    await counts.refresh()

    expect(adminApi.getReports).toHaveBeenCalledTimes(2)
    expect(adminApi.getInquiries).toHaveBeenCalledTimes(2)
    expect(counts.openReportCount.value).toBe(4)
    expect(counts.openInquiryCount.value).toBe(1)
  })

  it('refreshes one count while keeping the last value visible during the request', async () => {
    vi.mocked(adminApi.getReports)
      .mockResolvedValueOnce(page(5) as never)
      .mockResolvedValueOnce(page(4) as never)
    vi.mocked(adminApi.getInquiries).mockResolvedValue(page(2) as never)
    const counts = useAdminModerationCounts()

    await counts.load()
    let resolveReport: ((value: { data: { totalElements: number } }) => void) | undefined
    vi.mocked(adminApi.getReports).mockReturnValueOnce(new Promise((resolve) => {
      resolveReport = resolve
    }) as never)

    const refresh = counts.loadReports(true)
    expect(counts.openReportCount.value).toBe(5)
    expect(counts.openInquiryCount.value).toBe(2)

    resolveReport!(page(4))
    await refresh

    expect(counts.openReportCount.value).toBe(4)
    expect(counts.openInquiryCount.value).toBe(2)
    expect(adminApi.getReports).toHaveBeenCalledTimes(2)
    expect(adminApi.getInquiries).toHaveBeenCalledOnce()
  })
})
