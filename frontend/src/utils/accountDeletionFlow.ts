import type { AccountDeletionPreview } from '@/api/accountDeletion'
import type { AccountDeletionReceipt } from './accountDeletionReceipt'

export type AccountDeletionStep = 'scope' | 'team' | 'reauthentication' | 'nameConfirmation' | 'finalConfirmation'
export type AccountDeletionCompletion = 'accepted' | 'alreadyPending'

export interface AccountDeletionCompletionResult {
  completion: AccountDeletionCompletion
  receipt: AccountDeletionReceipt | null
}

/**
 * A deletion request can have been accepted even when the browser did not receive a response.
 * Only an HTTP 4xx response proves that the request was rejected before background processing.
 */
export function isAmbiguousAccountDeletionRequestError(error: unknown): boolean {
  const response = (error as { response?: { status?: unknown } }).response
  if (!response) return true
  // A 4xx response is the only response class that definitively rejects this
  // request before the asynchronous deletion job can be accepted. Everything
  // else (including malformed status metadata and redirects) is ambiguous.
  return typeof response.status !== 'number'
    || !Number.isInteger(response.status)
    || response.status < 400
    || response.status >= 500
}

export const ACCOUNT_DELETION_STEPS: AccountDeletionStep[] = [
  'scope',
  'team',
  'reauthentication',
  'nameConfirmation',
  'finalConfirmation',
]

export interface MemoryOnlyReauthProof {
  value: string
  expiresAt: number
}

export function createMemoryOnlyReauthProof(
  value: string,
  expiresInSeconds: number,
  now = Date.now(),
): MemoryOnlyReauthProof {
  return {
    value,
    expiresAt: now + expiresInSeconds * 1000,
  }
}

export function readValidReauthProof(
  proof: MemoryOnlyReauthProof | null,
  now = Date.now(),
): string | null {
  if (!proof || !proof.value || proof.expiresAt <= now) return null
  return proof.value
}

export function canLeaveAccountDeletionTeamStep(
  preview: AccountDeletionPreview,
  selectedTransferMemberId: number | null,
): boolean {
  const team = preview.teamImpact
  if (!team || !team.isAdmin || team.activeMemberCount <= 1) return true
  return team.transferCandidates.some((candidate) => candidate.memberId === selectedTransferMemberId)
}

export function accountDeletionNameMatches(typedName: string, memberName: string): boolean {
  return typedName === memberName
}

export const ACCOUNT_DELETION_OAUTH_MESSAGE_TYPE = 'dutypark:account-deletion-oauth'

export type AccountDeletionOAuthCallbackError =
  | 'oauth_cancelled'
  | 'provider_failed'
  | 'reauth_account_mismatch'

export type AccountDeletionOAuthMessage =
  | { type: typeof ACCOUNT_DELETION_OAUTH_MESSAGE_TYPE; code: string }
  | { type: typeof ACCOUNT_DELETION_OAUTH_MESSAGE_TYPE; error: AccountDeletionOAuthCallbackError }

const OAUTH_CALLBACK_ERRORS = new Set<AccountDeletionOAuthCallbackError>([
  'oauth_cancelled',
  'provider_failed',
  'reauth_account_mismatch',
])

export function isAccountDeletionOAuthMessage(value: unknown): value is AccountDeletionOAuthMessage {
  if (!value || typeof value !== 'object') return false
  const message = value as Record<string, unknown>
  if (message.type !== ACCOUNT_DELETION_OAUTH_MESSAGE_TYPE) return false

  const hasCode = typeof message.code === 'string' && message.code.length > 0
  const hasError = typeof message.error === 'string' && OAUTH_CALLBACK_ERRORS.has(
    message.error as AccountDeletionOAuthCallbackError,
  )
  return hasCode !== hasError
}

export function parseAccountDeletionOAuthCallback(search: string): AccountDeletionOAuthMessage | null {
  const params = new URLSearchParams(search)
  const keys = [...params.keys()]
  if (keys.length !== 1 || (keys[0] !== 'code' && keys[0] !== 'error')) return null
  const code = params.get('code')
  const error = params.get('error')
  if (code && !error) {
    return { type: ACCOUNT_DELETION_OAUTH_MESSAGE_TYPE, code }
  }
  if (!code && error && OAUTH_CALLBACK_ERRORS.has(error as AccountDeletionOAuthCallbackError)) {
    return {
      type: ACCOUNT_DELETION_OAUTH_MESSAGE_TYPE,
      error: error as AccountDeletionOAuthCallbackError,
    }
  }
  return null
}
