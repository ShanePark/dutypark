import { describe, expect, it } from 'vitest'
import { shouldSkipUnauthorizedRefresh } from './unauthorizedRetryPolicy'

describe('unauthorized retry policy', () => {
  it.each([
    '/auth/reauth/password',
    '/members/me/deletion',
    '/auth/mobile/oauth/exchange',
  ])('does not refresh and replay one-time POST %s', (url) => {
    expect(shouldSkipUnauthorizedRefresh('post', url)).toBe(true)
  })

  it('still allows refresh for preview, authorize, and non-POST requests', () => {
    expect(shouldSkipUnauthorizedRefresh('get', '/members/me/deletion')).toBe(false)
    expect(shouldSkipUnauthorizedRefresh('post', '/auth/mobile/oauth/authorize')).toBe(false)
    expect(shouldSkipUnauthorizedRefresh('get', '/auth/mobile/oauth/exchange')).toBe(false)
  })

  it('matches exact paths while tolerating a query string', () => {
    expect(shouldSkipUnauthorizedRefresh('POST', '/auth/reauth/password?source=settings')).toBe(true)
    expect(shouldSkipUnauthorizedRefresh('post', '/auth/reauth/password/extra')).toBe(false)
  })
})
