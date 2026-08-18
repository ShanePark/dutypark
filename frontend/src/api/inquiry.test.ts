import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { CreateInquiryRequest } from '@/types/inquiry'

const { get, post } = vi.hoisted(() => ({
  get: vi.fn(),
  post: vi.fn(),
}))

vi.mock('./client', () => ({
  default: { get, post },
}))

import { inquiryApi } from './inquiry'

const request: CreateInquiryRequest = {
  email: 'member@example.com',
  content: 'Help me',
}

beforeEach(() => {
  get.mockReset()
  post.mockReset()
  get.mockResolvedValue({ data: { content: [] } })
  post.mockResolvedValue({ data: { id: 'inquiry-id' } })
})

describe('inquiryApi.create', () => {
  it('verifies a signed-in member session through a protected endpoint before creating', async () => {
    await inquiryApi.create(request, { verifyMemberSession: true })

    expect(get).toHaveBeenCalledWith('/inquiries/me', {
      params: { page: 0, size: 1 },
    })
    expect(get.mock.invocationCallOrder[0]).toBeLessThan(post.mock.invocationCallOrder[0]!)
  })

  it('does not create a guest inquiry when the member session check fails', async () => {
    get.mockRejectedValueOnce(new Error('session expired'))

    await expect(inquiryApi.create(request, { verifyMemberSession: true })).rejects.toThrow('session expired')
    expect(post).not.toHaveBeenCalled()
  })

  it('keeps guest inquiry creation public without a protected preflight', async () => {
    await inquiryApi.create(request)

    expect(get).not.toHaveBeenCalled()
    expect(post).toHaveBeenCalledWith('/inquiries', request)
  })
})
