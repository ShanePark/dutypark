import { describe, expect, it } from 'vitest'
import type { AccountDeletionPreview } from '@/api/accountDeletion'
import {
  ACCOUNT_DELETION_OAUTH_MESSAGE_TYPE,
  accountDeletionNameMatches,
  canLeaveAccountDeletionTeamStep,
  createMemoryOnlyReauthProof,
  isAccountDeletionOAuthMessage,
  parseAccountDeletionOAuthCallback,
  readValidReauthProof,
} from './accountDeletionFlow'

function preview(overrides: Partial<AccountDeletionPreview> = {}): AccountDeletionPreview {
  return {
    hasPassword: true,
    socialProviders: [],
    teamImpact: null,
    auxiliaryImpacts: [],
    ...overrides,
  }
}

describe('account deletion flow policy', () => {
  it('requires a valid successor only for admins of teams with other active members', () => {
    const adminPreview = preview({
      teamImpact: {
        teamId: 1,
        teamName: 'Team',
        isAdmin: true,
        activeMemberCount: 2,
        willDeleteTeam: false,
        transferCandidates: [{ memberId: 7, name: 'Successor' }],
      },
    })

    expect(canLeaveAccountDeletionTeamStep(adminPreview, null)).toBe(false)
    expect(canLeaveAccountDeletionTeamStep(adminPreview, 9)).toBe(false)
    expect(canLeaveAccountDeletionTeamStep(adminPreview, 7)).toBe(true)
    expect(canLeaveAccountDeletionTeamStep(preview(), null)).toBe(true)
  })

  it('keeps proof and exact-name confirmation memory-only and strict', () => {
    const proof = createMemoryOnlyReauthProof('proof', 300, 1_000)

    expect(readValidReauthProof(proof, 300_999)).toBe('proof')
    expect(readValidReauthProof(proof, 301_000)).toBeNull()
    expect(accountDeletionNameMatches('Shane', 'Shane')).toBe(true)
    expect(accountDeletionNameMatches(' shane ', 'Shane')).toBe(false)
  })
})

describe('account deletion OAuth callback validation', () => {
  it('accepts exactly one non-empty code or supported error', () => {
    expect(isAccountDeletionOAuthMessage({
      type: ACCOUNT_DELETION_OAUTH_MESSAGE_TYPE,
      code: 'one-time-code',
    })).toBe(true)
    expect(isAccountDeletionOAuthMessage({
      type: ACCOUNT_DELETION_OAUTH_MESSAGE_TYPE,
      error: 'oauth_cancelled',
    })).toBe(true)
    expect(isAccountDeletionOAuthMessage({
      type: ACCOUNT_DELETION_OAUTH_MESSAGE_TYPE,
      code: 'code',
      error: 'provider_failed',
    })).toBe(false)
    expect(isAccountDeletionOAuthMessage({ type: 'wrong', code: 'code' })).toBe(false)
  })

  it('parses only the documented callback query shape', () => {
    expect(parseAccountDeletionOAuthCallback('?code=one-time')).toEqual({
      type: ACCOUNT_DELETION_OAUTH_MESSAGE_TYPE,
      code: 'one-time',
    })
    expect(parseAccountDeletionOAuthCallback('?error=reauth_account_mismatch')).toEqual({
      type: ACCOUNT_DELETION_OAUTH_MESSAGE_TYPE,
      error: 'reauth_account_mismatch',
    })
    expect(parseAccountDeletionOAuthCallback('?code=x&error=oauth_cancelled')).toBeNull()
    expect(parseAccountDeletionOAuthCallback('?code=x&extra=value')).toBeNull()
    expect(parseAccountDeletionOAuthCallback('?code=x&code=y')).toBeNull()
    expect(parseAccountDeletionOAuthCallback('?error=unknown')).toBeNull()
  })
})
