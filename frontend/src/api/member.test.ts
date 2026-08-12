import { AxiosError } from 'axios'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { MemberDto } from '@/types'

vi.mock('./client', () => ({
  default: {
    delete: vi.fn(),
  },
}))

import apiClient from './client'
import {
  canUnlinkSocialAccount,
  countLinkedSocialAccounts,
  getSocialAccountUnlinkErrorKey,
  memberApi,
  type SocialAccountProvider,
} from './member'

function member(overrides: Partial<MemberDto> = {}): MemberDto {
  return {
    id: 1,
    name: 'Tester',
    email: 'tester@example.com',
    teamId: null,
    team: null,
    calendarVisibility: 'FRIENDS',
    kakaoId: null,
    naverId: null,
    hasPassword: false,
    ...overrides,
  }
}

function axiosApiError(status: number, code: string): AxiosError {
  return new AxiosError(
    'Request failed',
    'ERR_BAD_REQUEST',
    undefined,
    undefined,
    {
      data: { status, code },
      status,
    } as never,
  )
}

describe('member social account API contract', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it.each<SocialAccountProvider>(['KAKAO', 'NAVER'])(
    'uses DELETE and the uppercase %s provider path',
    async (provider) => {
      vi.mocked(apiClient.delete).mockResolvedValue({ data: undefined })

      await memberApi.unlinkSocialAccount(provider)

      expect(apiClient.delete).toHaveBeenCalledWith(`/members/me/social-accounts/${provider}`)
    },
  )
})

describe('social account unlink policy', () => {
  it('blocks the only connected social account regardless of password availability', () => {
    const withoutPassword = member({ kakaoId: 'kakao-1', hasPassword: false })
    const withPassword = member({ kakaoId: 'kakao-1', hasPassword: true })

    expect(countLinkedSocialAccounts(withoutPassword)).toBe(1)
    expect(canUnlinkSocialAccount(withoutPassword, 'KAKAO')).toBe(false)
    expect(canUnlinkSocialAccount(withPassword, 'KAKAO')).toBe(false)
  })

  it('allows either provider to be disconnected only when both are connected', () => {
    const bothConnected = member({ kakaoId: 'kakao-1', naverId: 'naver-1' })

    expect(countLinkedSocialAccounts(bothConnected)).toBe(2)
    expect(canUnlinkSocialAccount(bothConnected, 'KAKAO')).toBe(true)
    expect(canUnlinkSocialAccount(bothConnected, 'NAVER')).toBe(true)
  })

  it('does not allow disconnecting a provider that is not connected', () => {
    expect(canUnlinkSocialAccount(member({ kakaoId: 'kakao-1' }), 'NAVER')).toBe(false)
  })
})

describe('social account unlink error mapping', () => {
  it('maps the last authentication method conflict', () => {
    expect(getSocialAccountUnlinkErrorKey(
      axiosApiError(409, 'member.social.unlink.lastAuthenticationMethod'),
    )).toBe('member.sso.unlink.errors.lastAuthenticationMethod')
  })

  it('maps the impersonation code and falls back for any 403 response', () => {
    expect(getSocialAccountUnlinkErrorKey(
      axiosApiError(403, 'member.social.unlink.impersonationForbidden'),
    )).toBe('member.sso.unlink.errors.impersonationForbidden')
    expect(getSocialAccountUnlinkErrorKey(
      axiosApiError(403, 'unknown.forbidden'),
    )).toBe('member.sso.unlink.errors.impersonationForbidden')
  })

  it('uses the generic error for other failures', () => {
    expect(getSocialAccountUnlinkErrorKey(
      axiosApiError(500, 'common.badRequest'),
    )).toBe('member.sso.unlink.errors.generic')
  })
})
