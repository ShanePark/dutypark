import { describe, expect, it } from 'vitest'
import accountDeletionModal from './AccountDeletionModal.vue?raw'
import memberView from '@/views/member/MemberView.vue?raw'

describe('account deletion receipt flow', () => {
  it('creates and persists the receipt before sending the deletion request', () => {
    const ensureIndex = accountDeletionModal.indexOf('const receiptToken = ensurePendingReceiptToken()')
    const requestIndex = accountDeletionModal.indexOf('accountDeletionApi.requestDeletion(')
    const persistIndex = accountDeletionModal.indexOf('saveAccountDeletionReceipt(newReceipt)')

    expect(accountDeletionModal).toContain('createAccountDeletionReceiptToken()')
    expect(accountDeletionModal).toContain('receiptToken,')
    expect(accountDeletionModal).toContain('ownerMemberId: props.memberId')
    expect(ensureIndex).toBeGreaterThan(-1)
    expect(persistIndex).toBeGreaterThan(-1)
    expect(requestIndex).toBeGreaterThan(-1)
    expect(ensureIndex).toBeLessThan(requestIndex)
    expect(accountDeletionModal).toMatch(/const receiptToken = ensurePendingReceiptToken\(\)[\s\S]*?accountDeletionApi\.requestDeletion\(/)
    expect(accountDeletionModal).toMatch(/saveAccountDeletionReceipt\(newReceipt\)[\s\S]*?pendingReceiptToken\.value = receiptToken/)
  })

  it('reuses the pending token after an ambiguous request failure and verifies response identity', () => {
    expect(accountDeletionModal).toContain('stored?.jobId === null')
    expect(accountDeletionModal).toContain('isTrustedAcceptedResponse(responseData, receiptToken)')
    expect(accountDeletionModal).toContain('currentMemberReceipt(pendingReceipt.value ?? readAccountDeletionReceipt())')
    expect(accountDeletionModal).toContain('clearProvisionalReceipt()')
    expect(accountDeletionModal).toContain(':to="receiptRecoveryPath()"')
  })

  it('routes ambiguous transport or malformed responses to status without reauth', () => {
    expect(accountDeletionModal).toContain('isAmbiguousAccountDeletionRequestError(error)')
    expect(accountDeletionModal).toContain('completionResult = uncertainCompletionResult()')
    expect(accountDeletionModal).toContain('isTrustedAcceptedResponse(responseData, receiptToken)')
    expect(accountDeletionModal).not.toContain("errorKey.value = 'member.accountDeletion.errors.generic'\n      step.value = 'reauthentication'")
  })

  it('blocks another member from overwriting a stored receipt', () => {
    expect(accountDeletionModal).toContain('stored.ownerMemberId !== props.memberId')
    expect(accountDeletionModal).toContain('receiptOwnedByAnotherAccount')
  })

  it('blocks resubmission after a server receipt mismatch and exposes support', () => {
    expect(accountDeletionModal).toContain("receiptMismatch")
    expect(accountDeletionModal).toContain('requestBlocked.value = mappedErrorKey ===')
    expect(accountDeletionModal).toContain('to="/support"')
    expect(accountDeletionModal).toContain('v-if="preview && !requestBlocked"')
  })

  it('offers a recovery destination when browser receipt storage fails', () => {
    expect(accountDeletionModal).toContain('hasStoredAccountDeletionReceiptEntry()')
    expect(accountDeletionModal).toContain('receiptRecoveryPath()')
    expect(accountDeletionModal).toContain("errorKey.value === 'member.accountDeletion.errors.receiptStorage'")
  })

  it('persists the server receipt before clearing the authenticated session', () => {
    const persistIndex = memberView.indexOf('saveAccountDeletionReceipt(result.receipt)')
    const cleanupIndex = memberView.indexOf('authStore.completeAccountDeletion()')

    expect(persistIndex).toBeGreaterThan(-1)
    expect(cleanupIndex).toBeGreaterThan(-1)
    expect(persistIndex).toBeLessThan(cleanupIndex)
    expect(memberView).toContain("router.replace({ name: 'account-deletion-status' })")
    expect(memberView).toContain(':member-id="memberInfo.id"')
  })
})
