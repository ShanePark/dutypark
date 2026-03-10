import { describe, expect, it } from 'vitest'
import { buildLoginPath, buildLoginRoute, getSafeRedirect } from './redirect'

describe('redirect utilities', () => {
  it('builds login route with safe redirect', () => {
    expect(buildLoginRoute('/duty/5?month=2')).toEqual({
      name: 'login',
      query: {
        redirect: '/duty/5?month=2',
      },
    })
  })

  it('builds login path with encoded redirect', () => {
    expect(buildLoginPath('/duty/5?month=2')).toBe('/auth/login?redirect=%2Fduty%2F5%3Fmonth%3D2')
  })

  it('rejects external redirect targets', () => {
    expect(getSafeRedirect('https://evil.example.com')).toBeNull()
    expect(getSafeRedirect('//evil.example.com')).toBeNull()
    expect(buildLoginRoute('https://evil.example.com')).toEqual({
      name: 'login',
    })
  })
})
