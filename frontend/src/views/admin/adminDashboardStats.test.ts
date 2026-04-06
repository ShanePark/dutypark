import { describe, expect, it } from 'vitest'
import type { RefreshTokenDto } from '@/types'
import { countTodayLogins } from './adminDashboardStats'

function createToken(lastUsed: string | null): RefreshTokenDto {
  return {
    memberName: 'tester',
    memberId: 1,
    validUntil: '2026-04-10T10:00:00',
    createdDate: '2026-04-01T10:00:00',
    lastUsed,
    remoteAddr: '127.0.0.1',
    id: Math.floor(Math.random() * 1000),
    token: 'token',
    userAgent: null,
    isCurrentLogin: false,
  }
}

describe('adminDashboardStats', () => {
  it('counts today logins using the local calendar date before 9am in Korea', () => {
    const tokens = [
      createToken('2026-04-06T00:15:00'),
      createToken('2026-04-05T23:50:00'),
    ]

    expect(countTodayLogins(tokens, new Date(2026, 3, 6, 8, 30))).toBe(1)
  })

  it('ignores tokens without a last used timestamp', () => {
    const tokens = [
      createToken('2026-04-06T01:00:00'),
      createToken(null),
    ]

    expect(countTodayLogins(tokens, new Date(2026, 3, 6, 10, 0))).toBe(1)
  })
})
