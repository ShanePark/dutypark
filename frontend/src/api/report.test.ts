import { beforeEach, describe, expect, it, vi } from 'vitest'

const { get, post } = vi.hoisted(() => ({
  get: vi.fn(),
  post: vi.fn(),
}))

vi.mock('./client', () => ({
  default: { get, post },
}))

import { reportApi } from './report'

beforeEach(() => {
  get.mockReset()
  post.mockReset()
})

describe('reportApi', () => {
  it('reads the caller own reports one page at a time', () => {
    get.mockResolvedValue({ data: { content: [], number: 2, totalPages: 3, totalElements: 25 } })

    reportApi.fetchMine(2, 10)

    expect(get).toHaveBeenCalledWith('/reports/me', { params: { page: 2, size: 10 } })
  })

  it('withdraws a report and returns the row the server sends back', async () => {
    post.mockResolvedValue({ data: { id: 'report-id', status: 'CANCELED' } })

    const updated = await reportApi.cancelMine('report-id')

    expect(post).toHaveBeenCalledWith('/reports/report-id/cancel')
    expect(updated.status).toBe('CANCELED')
  })
})
