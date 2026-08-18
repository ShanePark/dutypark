import { beforeEach, describe, expect, it, vi } from 'vitest'

const { get, post, patch, remove } = vi.hoisted(() => ({
  get: vi.fn(),
  post: vi.fn(),
  patch: vi.fn(),
  remove: vi.fn(),
}))

vi.mock('axios', () => ({
  default: {
    create: () => ({ get, post, patch, delete: remove }),
  },
}))

import { adminApi } from './admin'

beforeEach(() => {
  get.mockReset()
  post.mockReset()
  patch.mockReset()
  remove.mockReset()
})

describe('adminApi report management', () => {
  it('defaults the report list to the open queue', () => {
    adminApi.getReports()

    expect(get).toHaveBeenCalledWith('/reports', {
      params: { status: 'OPEN', page: 0, size: 10 },
    })
  })

  it('drops the status parameter for the ALL filter', () => {
    adminApi.getReports('ALL', 2, 20)

    expect(get).toHaveBeenCalledWith('/reports', {
      params: { status: undefined, page: 2, size: 20 },
    })
  })

  it('patches the report status with an admin memo', () => {
    adminApi.updateReportStatus('report-id', { status: 'RESOLVED', memo: 'deleted the schedule' })

    expect(patch).toHaveBeenCalledWith('/reports/report-id/status', {
      status: 'RESOLVED',
      memo: 'deleted the schedule',
    })
  })

  it('deletes the reported content through the target endpoint', () => {
    adminApi.deleteReportTarget('report-id')

    expect(remove).toHaveBeenCalledWith('/reports/report-id/target')
  })
})

describe('adminApi inquiry management', () => {
  it('defaults the inquiry list to the open queue', () => {
    adminApi.getInquiries()

    expect(get).toHaveBeenCalledWith('/inquiries', {
      params: { status: 'OPEN', page: 0, size: 10 },
    })
  })

  it('drops the status parameter for the ALL filter', () => {
    adminApi.getInquiries('ALL', 1, 5)

    expect(get).toHaveBeenCalledWith('/inquiries', {
      params: { status: undefined, page: 1, size: 5 },
    })
  })

  it('patches the inquiry status', () => {
    adminApi.updateInquiryStatus('inquiry-id', { status: 'CLOSED' })

    expect(patch).toHaveBeenCalledWith('/inquiries/inquiry-id/status', { status: 'CLOSED' })
  })
})

describe('adminApi member suspension', () => {
  it('suspends a member with POST on the suspension sub-resource', () => {
    adminApi.suspendMember(7)

    expect(post).toHaveBeenCalledWith('/members/7/suspension')
  })

  it('lifts a suspension with DELETE on the same sub-resource', () => {
    adminApi.unsuspendMember(7)

    expect(remove).toHaveBeenCalledWith('/members/7/suspension')
  })
})
