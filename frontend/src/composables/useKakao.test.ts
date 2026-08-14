import { describe, expect, it, vi } from 'vitest'
import apiClient from '@/api/client'
import { authorizeKakao } from './useKakao'

vi.mock('@/api/client', () => ({
  default: { post: vi.fn() },
}))

describe('authorizeKakao', () => {
  it('requests an opaque server state flow without client callback input', async () => {
    vi.mocked(apiClient.post).mockResolvedValue({
      data: { authorizationUrl: 'https://kauth.kakao.com/oauth/authorize?state=opaque', expiresIn: 300 },
    })
    const navigate = vi.fn()

    await authorizeKakao('LINK', '/member?tab=social', navigate)

    expect(apiClient.post).toHaveBeenCalledWith('/auth/oauth2/authorize', {
      provider: 'KAKAO',
      purpose: 'LINK',
      referer: '/member?tab=social',
    })
    expect(navigate).toHaveBeenCalledWith('https://kauth.kakao.com/oauth/authorize?state=opaque')
  })

  it('propagates authorize request failures without navigating', async () => {
    const error = new Error('authorize unavailable')
    vi.mocked(apiClient.post).mockRejectedValue(error)
    const navigate = vi.fn()

    await expect(authorizeKakao('LOGIN', '/', navigate)).rejects.toBe(error)

    expect(navigate).not.toHaveBeenCalled()
  })
})
