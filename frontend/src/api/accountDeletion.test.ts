import { AxiosError } from 'axios'
import { beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('./client', () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
  },
}))

import apiClient from './client'
import {
  AccountDeletionOAuthError,
  accountDeletionApi,
  getWebSocialReauthenticationProviders,
  getAccountDeletionErrorKey,
  isAccountDeletionAlreadyPending,
  requiresIosAppleReauthentication,
  type AccountDeletionPreview,
} from './accountDeletion'

function apiError(status: number, code: string): AxiosError {
  return new AxiosError('failed', 'ERR_BAD_REQUEST', undefined, undefined, {
    status,
    data: { status, code },
  } as never)
}

describe('account deletion API contract', () => {
  beforeEach(() => vi.clearAllMocks())

  it('loads the deletion preview and reauthenticates for DELETE_ACCOUNT', async () => {
    vi.mocked(apiClient.get).mockResolvedValue({ data: {} })
    vi.mocked(apiClient.post).mockResolvedValue({ data: {} })

    await accountDeletionApi.getPreview()
    await accountDeletionApi.reauthenticateWithPassword('secret')

    expect(apiClient.get).toHaveBeenCalledWith('/members/me/deletion')
    expect(apiClient.post).toHaveBeenCalledWith('/auth/reauth/password', {
      purpose: 'DELETE_ACCOUNT',
      password: 'secret',
    })
  })

  it('submits the exact deletion request contract', async () => {
    vi.mocked(apiClient.post).mockResolvedValue({ data: { jobId: 3, status: 'ACCEPTED' } })

    await accountDeletionApi.requestDeletion('proof', 17)

    expect(apiClient.post).toHaveBeenCalledWith('/members/me/deletion', {
      confirmation: 'DELETE',
      password: null,
      reauthProof: 'proof',
      transferAdminToMemberId: 17,
    })
  })

  it('uses the mobile OAuth authorize and proof-exchange contracts', async () => {
    vi.mocked(apiClient.post).mockResolvedValue({ data: {} })

    await accountDeletionApi.authorizeSocialReauthentication('KAKAO', 'https://dutypark.test/callback', 'challenge')
    await accountDeletionApi.exchangeSocialReauthentication('code', 'verifier', 'https://dutypark.test/callback')

    expect(apiClient.post).toHaveBeenNthCalledWith(1, '/auth/mobile/oauth/authorize', {
      provider: 'KAKAO',
      purpose: 'DELETE_ACCOUNT',
      callbackUri: 'https://dutypark.test/callback',
      codeChallenge: 'challenge',
    })
    expect(apiClient.post).toHaveBeenNthCalledWith(2, '/auth/mobile/oauth/exchange', {
      code: 'code',
      codeVerifier: 'verifier',
      callbackUri: 'https://dutypark.test/callback',
    })
  })

  it('never sends Apple through the generic mobile OAuth authorize flow', async () => {
    expect(() => accountDeletionApi.authorizeSocialReauthentication(
      'APPLE',
      'https://dutypark.test/callback',
      'challenge',
    )).toThrow(AccountDeletionOAuthError)
    await expect(accountDeletionApi.reauthenticateWithSocial('APPLE')).rejects.toMatchObject({
      name: 'AccountDeletionOAuthError',
      reason: 'unsupported_provider',
    } satisfies Partial<AccountDeletionOAuthError>)
    expect(apiClient.post).not.toHaveBeenCalled()
  })

  it('offers only Kakao and Naver on web and identifies Apple-only reauthentication', () => {
    const appleOnly: Pick<AccountDeletionPreview, 'hasPassword' | 'socialProviders'> = {
      hasPassword: false,
      socialProviders: ['APPLE'],
    }
    const mixed: Pick<AccountDeletionPreview, 'hasPassword' | 'socialProviders'> = {
      hasPassword: false,
      socialProviders: ['APPLE', 'KAKAO'],
    }

    expect(getWebSocialReauthenticationProviders(appleOnly)).toEqual([])
    expect(requiresIosAppleReauthentication(appleOnly)).toBe(true)
    expect(getWebSocialReauthenticationProviders(mixed)).toEqual(['KAKAO'])
    expect(requiresIosAppleReauthentication(mixed)).toBe(false)
  })
})

describe('account deletion API error mapping', () => {
  it('recognizes already-pending completion separately', () => {
    expect(isAccountDeletionAlreadyPending(apiError(409, 'account.delete.alreadyPending'))).toBe(true)
  })

  it('maps reauthentication, transfer, and impersonation failures', () => {
    expect(getAccountDeletionErrorKey(apiError(401, 'auth.reauth.failed')))
      .toBe('member.accountDeletion.errors.reauthentication')
    expect(getAccountDeletionErrorKey(apiError(409, 'account.delete.teamAdminTransferInvalid')))
      .toBe('member.accountDeletion.errors.transferInvalid')
    expect(getAccountDeletionErrorKey(apiError(403, 'account.delete.impersonationForbidden')))
      .toBe('member.accountDeletion.errors.impersonation')
  })
})
