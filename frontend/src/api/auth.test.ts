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

describe('authApi.exchangeAppleLogin', () => {
  beforeEach(() => {
    post.mockReset()
  })

  it('posts the Apple web credential exchange contract', async () => {
    const response = {
      signupRequired: false,
      signupUuid: null,
      expiresIn: 3600,
      reauthProof: null,
    }
    post.mockResolvedValue({ data: response })

    await expect(authApi.exchangeAppleLogin({
      identityToken: 'identity-token',
      authorizationCode: 'authorization-code',
      rawNonce: 'raw-nonce',
      purpose: 'LOGIN',
    })).resolves.toEqual(response)

    expect(post).toHaveBeenCalledWith('/auth/web/oauth/apple/exchange', {
      identityToken: 'identity-token',
      authorizationCode: 'authorization-code',
      rawNonce: 'raw-nonce',
      purpose: 'LOGIN',
    })
  })

  it('uses the same exchange endpoint for Apple account linking', async () => {
    const response = {
      signupRequired: false,
      signupUuid: null,
      expiresIn: null,
      reauthProof: null,
    }
    post.mockResolvedValue({ data: response })

    await expect(authApi.exchangeAppleLogin({
      identityToken: 'identity-token',
      authorizationCode: 'authorization-code',
      rawNonce: 'raw-nonce',
      purpose: 'LINK',
    })).resolves.toEqual(response)

    expect(post).toHaveBeenCalledWith('/auth/web/oauth/apple/exchange', {
      identityToken: 'identity-token',
      authorizationCode: 'authorization-code',
      rawNonce: 'raw-nonce',
      purpose: 'LINK',
    })
  })
})
