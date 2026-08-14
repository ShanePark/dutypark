import { beforeEach, describe, expect, it, vi } from 'vitest'

const { post } = vi.hoisted(() => ({ post: vi.fn() }))

vi.mock('./client', () => ({
  default: { post },
}))

import { authApi } from './auth'

describe('authApi.logout', () => {
  beforeEach(() => {
    post.mockReset()
  })

  it('exposes server logout failures to the session store', async () => {
    const error = new Error('server unavailable')
    post.mockRejectedValue(error)

    await expect(authApi.logout()).rejects.toBe(error)
    expect(post).toHaveBeenCalledWith('/auth/logout')
  })
})
