import { describe, expect, it } from 'vitest'
import statusView from './accountDeletionStatus/AccountDeletionStatusView.vue?raw'
import { routes } from '@/router/routes'

describe('account deletion status page', () => {
  it('is available without an authenticated session for a stored receipt', () => {
    const route = routes.find((candidate) => candidate.path === '/account-deletion-status')

    expect(route?.name).toBe('account-deletion-status')
    expect(route?.meta?.requiresAuth).toBe(false)
    expect(statusView).toContain('readAccountDeletionReceipt')
    expect(statusView).toContain('accountDeletionApi.getStatus')
    expect(statusView).toContain('isAccountDeletionReceiptWithinProvisionalGrace')
  })

  it('distinguishes processing, actual completion, failure, and an unavailable receipt', () => {
    expect(statusView).toContain("status === 'PROCESSING'")
    expect(statusView).toContain("status === 'COMPLETED'")
    expect(statusView).toContain("status === 'FAILED'")
    expect(statusView).toContain('accountDeletion.status.unavailable')
    expect(statusView).toContain("response?.status === 404")
    expect(statusView).toContain('isProvisionalReceiptWithinGrace')
    expect(statusView).toContain('hasStoredAccountDeletionReceiptEntry')
  })

  it('only clears the receipt from an explicit terminal dismissal action', () => {
    expect(statusView).toContain('clearAccountDeletionReceipt()')
    expect(statusView).toContain('@click="dismissTerminalResult"')
    expect(statusView).toMatch(/async function dismissTerminalResult\(\)[\s\S]*clearAccountDeletionReceipt\(\)/)
    expect(statusView).not.toContain("if (result.data.status === 'COMPLETED') clearAccountDeletionReceipt()")
  })

  it('does not expose the receipt token in the URL', () => {
    expect(statusView).not.toContain('query.receiptToken')
    expect(statusView).toContain('to="/support"')
    expect(statusView).toContain('resetStoredReceipt')
    expect(statusView).toContain('clearAccountDeletionReceipt()')
  })

  it('discloses limited support-record retention and links the privacy policy', () => {
    expect(statusView).toContain("t('member.accountDeletion.retentionNotice')")
    expect(statusView).toContain("t('policy.privacy.title')")
    expect(statusView).toContain('to="/privacy"')
  })
})
