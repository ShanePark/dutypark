import apiClient from './client'
import type { SocialAccountProvider } from './member'
import { extractApiError } from '@/utils/resolveApiError'
import {
  isAccountDeletionOAuthMessage,
  type AccountDeletionOAuthCallbackError,
  type AccountDeletionOAuthMessage,
} from '@/utils/accountDeletionFlow'

export interface AccountDeletionTransferCandidate {
  memberId: number
  name: string
}

export interface AccountDeletionTeamImpact {
  teamId: number
  teamName: string
  isAdmin: boolean
  activeMemberCount: number
  willDeleteTeam: boolean
  transferCandidates: AccountDeletionTransferCandidate[]
}

export interface AccountDeletionAuxiliaryImpact {
  memberId: number
  name: string
  willDelete: boolean
}

export interface AccountDeletionPreview {
  hasPassword: boolean
  socialProviders: SocialAccountProvider[]
  teamImpact: AccountDeletionTeamImpact | null
  auxiliaryImpacts: AccountDeletionAuxiliaryImpact[]
}

export type WebSocialReauthenticationProvider = Exclude<SocialAccountProvider, 'APPLE'>

export function isWebSocialReauthenticationProvider(
  provider: SocialAccountProvider,
): provider is WebSocialReauthenticationProvider {
  return provider === 'KAKAO' || provider === 'NAVER'
}

export function getWebSocialReauthenticationProviders(
  preview: Pick<AccountDeletionPreview, 'socialProviders'>,
): WebSocialReauthenticationProvider[] {
  return preview.socialProviders.filter(isWebSocialReauthenticationProvider)
}

export function requiresIosAppleReauthentication(
  preview: Pick<AccountDeletionPreview, 'hasPassword' | 'socialProviders'>,
): boolean {
  return preview.socialProviders.includes('APPLE')
    && !preview.hasPassword
    && getWebSocialReauthenticationProviders(preview).length === 0
}

export interface AccountDeletionReauthProofResponse {
  reauthProof: string
  expiresIn: number
}

export interface AccountDeletionAcceptedResponse {
  jobId: number
  status: string
  receiptToken: string
  estimatedCompletionAt: string
}

export type AccountDeletionStatus = 'PROCESSING' | 'COMPLETED' | 'FAILED'

export interface AccountDeletionStatusResponse {
  status: AccountDeletionStatus
  estimatedCompletionAt: string
  completedAt?: string | null
  receiptExpiresAt?: string | null
}

interface SocialReauthAuthorizeResponse {
  authorizationUrl: string
  expiresIn: number
}

interface SocialReauthExchangeResponse {
  signupRequired: false
  expiresIn: number
  reauthProof: string
}

export type AccountDeletionErrorKey =
  | 'member.accountDeletion.errors.reauthentication'
  | 'member.accountDeletion.errors.transferRequired'
  | 'member.accountDeletion.errors.transferInvalid'
  | 'member.accountDeletion.errors.noTransferCandidate'
  | 'member.accountDeletion.errors.impersonation'
  | 'member.accountDeletion.errors.receiptStorage'
  | 'member.accountDeletion.errors.receiptAlreadyPending'
  | 'member.accountDeletion.errors.receiptOwnedByAnotherAccount'
  | 'member.accountDeletion.errors.receiptMismatch'
  | 'member.accountDeletion.errors.generic'

export type AccountDeletionOAuthFailure =
  | AccountDeletionOAuthCallbackError
  | 'popup_blocked'
  | 'popup_closed'
  | 'popup_timeout'
  | 'invalid_response'
  | 'unsupported_provider'

export class AccountDeletionOAuthError extends Error {
  readonly reason: AccountDeletionOAuthFailure

  constructor(reason: AccountDeletionOAuthFailure) {
    super(reason)
    this.name = 'AccountDeletionOAuthError'
    this.reason = reason
  }
}

export function getAccountDeletionErrorKey(error: unknown): AccountDeletionErrorKey {
  const code = extractApiError(error)?.code
  switch (code) {
    case 'auth.reauth.failed':
    case 'auth.reauth.proof.invalid':
    case 'auth.reauth.password.required':
    case 'auth.reauth.password.invalid':
    case 'account.delete.reauthenticationFailed':
      return 'member.accountDeletion.errors.reauthentication'
    case 'account.delete.teamAdminTransferRequired':
      return 'member.accountDeletion.errors.transferRequired'
    case 'account.delete.teamAdminTransferInvalid':
      return 'member.accountDeletion.errors.transferInvalid'
    case 'account.delete.auxiliaryTeamTransferRequired':
      return 'member.accountDeletion.errors.noTransferCandidate'
    case 'account.delete.receiptToken.mismatch':
      return 'member.accountDeletion.errors.receiptMismatch'
    case 'account.delete.impersonationForbidden':
    case 'auth.reauth.impersonationForbidden':
      return 'member.accountDeletion.errors.impersonation'
    default:
      return 'member.accountDeletion.errors.generic'
  }
}

export function isAccountDeletionAlreadyPending(error: unknown): boolean {
  return extractApiError(error)?.code === 'account.delete.alreadyPending'
}

function base64Url(bytes: Uint8Array): string {
  const binary = Array.from(bytes, (byte) => String.fromCharCode(byte)).join('')
  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '')
}

export async function createAccountDeletionPkcePair(): Promise<{
  verifier: string
  challenge: string
}> {
  const random = new Uint8Array(32)
  window.crypto.getRandomValues(random)
  const verifier = base64Url(random)
  const digest = await window.crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier))
  return {
    verifier,
    challenge: base64Url(new Uint8Array(digest)),
  }
}

export function createAccountDeletionReceiptToken(): string {
  const random = new Uint8Array(32)
  globalThis.crypto.getRandomValues(random)
  return base64Url(random)
}

function openAccountDeletionOAuthPopup(): Window | null {
  const width = 520
  const height = 720
  const left = Math.max(0, window.screenX + (window.outerWidth - width) / 2)
  const top = Math.max(0, window.screenY + (window.outerHeight - height) / 2)
  return window.open(
    'about:blank',
    'dutypark-account-deletion-oauth',
    `popup=yes,width=${width},height=${height},left=${Math.round(left)},top=${Math.round(top)}`,
  )
}

function waitForAccountDeletionOAuthMessage(
  popup: Window,
  timeoutMs: number,
): Promise<AccountDeletionOAuthMessage> {
  return new Promise((resolve, reject) => {
    let settled = false

    const finish = (callback: () => void) => {
      if (settled) return
      settled = true
      window.removeEventListener('message', handleMessage)
      window.clearInterval(closedPoll)
      window.clearTimeout(timeout)
      callback()
    }

    const handleMessage = (event: MessageEvent) => {
      if (
        event.origin !== window.location.origin
        || event.source !== popup
        || !isAccountDeletionOAuthMessage(event.data)
      ) return
      finish(() => resolve(event.data))
    }

    const closedPoll = window.setInterval(() => {
      if (popup.closed) {
        finish(() => reject(new AccountDeletionOAuthError('popup_closed')))
      }
    }, 250)

    const timeout = window.setTimeout(() => {
      finish(() => reject(new AccountDeletionOAuthError('popup_timeout')))
    }, timeoutMs)

    window.addEventListener('message', handleMessage)
  })
}

export const accountDeletionApi = {
  getPreview() {
    return apiClient.get<AccountDeletionPreview>('/members/me/deletion')
  },

  reauthenticateWithPassword(password: string) {
    return apiClient.post<AccountDeletionReauthProofResponse>('/auth/reauth/password', {
      purpose: 'DELETE_ACCOUNT',
      password,
    })
  },

  requestDeletion(
    reauthProof: string,
    transferAdminToMemberId: number | null,
    receiptToken: string,
  ) {
    return apiClient.post<AccountDeletionAcceptedResponse>('/members/me/deletion', {
      confirmation: 'DELETE',
      password: null,
      reauthProof,
      transferAdminToMemberId,
      receiptToken,
    })
  },

  getStatus(receiptToken: string) {
    return apiClient.post<AccountDeletionStatusResponse>('/account-deletions/status', {
      receiptToken,
    })
  },

  authorizeSocialReauthentication(
    provider: SocialAccountProvider,
    callbackUri: string,
    codeChallenge: string,
  ) {
    if (!isWebSocialReauthenticationProvider(provider)) {
      throw new AccountDeletionOAuthError('unsupported_provider')
    }
    return apiClient.post<SocialReauthAuthorizeResponse>('/auth/mobile/oauth/authorize', {
      provider,
      purpose: 'DELETE_ACCOUNT',
      callbackUri,
      codeChallenge,
    })
  },

  exchangeSocialReauthentication(code: string, codeVerifier: string, callbackUri: string) {
    return apiClient.post<SocialReauthExchangeResponse>('/auth/mobile/oauth/exchange', {
      code,
      codeVerifier,
      callbackUri,
    })
  },

  async reauthenticateWithSocial(provider: SocialAccountProvider): Promise<AccountDeletionReauthProofResponse> {
    if (!isWebSocialReauthenticationProvider(provider)) {
      throw new AccountDeletionOAuthError('unsupported_provider')
    }
    const popup = openAccountDeletionOAuthPopup()
    if (!popup) throw new AccountDeletionOAuthError('popup_blocked')

    const callbackUri = `${window.location.origin}/auth/account-deletion-oauth-callback`
    try {
      const pkce = await createAccountDeletionPkcePair()
      const authorization = await this.authorizeSocialReauthentication(
        provider,
        callbackUri,
        pkce.challenge,
      )
      if (!authorization.data.authorizationUrl || authorization.data.expiresIn <= 0) {
        throw new AccountDeletionOAuthError('invalid_response')
      }
      if (popup.closed) throw new AccountDeletionOAuthError('popup_closed')
      const messagePromise = waitForAccountDeletionOAuthMessage(
        popup,
        Math.min(Math.max(authorization.data.expiresIn * 1000, 1_000), 300_000),
      )
      const authorizationUrl = new URL(authorization.data.authorizationUrl)
      if (authorizationUrl.protocol !== 'https:') {
        throw new AccountDeletionOAuthError('invalid_response')
      }
      popup.location.href = authorizationUrl.href
      popup.focus()

      const message = await messagePromise
      if ('error' in message) throw new AccountDeletionOAuthError(message.error)

      const exchange = await this.exchangeSocialReauthentication(
        message.code,
        pkce.verifier,
        callbackUri,
      )
      if (
        exchange.data.signupRequired !== false
        || !exchange.data.reauthProof
        || exchange.data.expiresIn <= 0
      ) {
        throw new AccountDeletionOAuthError('invalid_response')
      }
      return {
        reauthProof: exchange.data.reauthProof,
        expiresIn: exchange.data.expiresIn,
      }
    } finally {
      if (!popup.closed) popup.close()
    }
  },
}
