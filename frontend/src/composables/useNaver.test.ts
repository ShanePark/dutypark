import { describe, expect, it, vi } from 'vitest'
import apiClient from '@/api/client'
import { authorizeNaver } from './useNaver'

vi.mock('@/api/client', () => ({
  default: { post: vi.fn() },
}))

describe('authorizeNaver', () => {
  it('requests an opaque server state flow without encoding state in the browser', async () => {
    vi.mocked(apiClient.post).mockResolvedValue({
      data: { authorizationUrl: 'https://nid.naver.com/oauth2.0/authorize?state=opaque', expiresIn: 300 },
    })
    const navigate = vi.fn()

    await authorizeNaver('LOGIN', '/todo?view=mine', navigate)

    expect(apiClient.post).toHaveBeenCalledWith('/auth/oauth2/authorize', {
      provider: 'NAVER',
      purpose: 'LOGIN',
      referer: '/todo?view=mine',
    })
    expect(navigate).toHaveBeenCalledWith('https://nid.naver.com/oauth2.0/authorize?state=opaque')
  })

  it('propagates authorize request failures without navigating', async () => {
    const error = new Error('authorize unavailable')
    vi.mocked(apiClient.post).mockRejectedValue(error)
    const navigate = vi.fn()

    await expect(authorizeNaver('LINK', '/member', navigate)).rejects.toBe(error)

    expect(navigate).not.toHaveBeenCalled()
  })
})
