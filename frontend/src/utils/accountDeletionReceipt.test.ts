import { beforeEach, describe, expect, it, vi } from 'vitest'
import {
  ACCOUNT_DELETION_PROVISIONAL_404_GRACE_MS,
  ACCOUNT_DELETION_EXPECTED_COMPLETION_MS,
  ACCOUNT_DELETION_RECEIPT_STORAGE_KEY,
  hasStoredAccountDeletionReceiptEntry,
  isAccountDeletionReceipt,
  isAccountDeletionReceiptBeforeExpectedCompletion,
  isAccountDeletionReceiptWithinProvisionalGrace,
  clearAccountDeletionReceipt,
  readAccountDeletionReceipt,
  saveAccountDeletionReceipt,
  type AccountDeletionReceipt,
} from './accountDeletionReceipt'

const VALID_RECEIPT_TOKEN = 'A'.repeat(43)

const receipt: AccountDeletionReceipt = {
  ownerMemberId: 7,
  jobId: 42,
  receiptToken: VALID_RECEIPT_TOKEN,
  estimatedCompletionAt: '2026-08-29T15:05:00Z',
}

const storage = {
  getItem: vi.fn<(key: string) => string | null>(),
  setItem: vi.fn<(key: string, value: string) => void>(),
  removeItem: vi.fn<(key: string) => void>(),
}

Object.defineProperty(globalThis, 'localStorage', {
  configurable: true,
  value: storage,
})

describe('account deletion receipt persistence', () => {
  beforeEach(() => {
    storage.getItem.mockReset()
    storage.setItem.mockReset()
    storage.removeItem.mockReset()
    storage.getItem.mockReturnValue(null)
  })

  it('stores the opaque receipt and ETA for use after session cleanup', () => {
    expect(saveAccountDeletionReceipt(receipt)).toBe(true)

    expect(storage.setItem).toHaveBeenCalledWith(
      ACCOUNT_DELETION_RECEIPT_STORAGE_KEY,
      JSON.stringify(receipt),
    )
  })

  it('allows an unassigned job id while the request is still in flight', () => {
    const pendingReceipt = {
      ...receipt,
      jobId: null,
      estimatedCompletionAt: new Date(Date.now() + ACCOUNT_DELETION_EXPECTED_COMPLETION_MS).toISOString(),
    }

    expect(saveAccountDeletionReceipt(pendingReceipt)).toBe(true)
  })

  it('keeps a provisional receipt eligible for polling until its expected time', () => {
    const eta = '2026-08-29T15:05:00Z'
    const pendingReceipt = { ...receipt, jobId: null, estimatedCompletionAt: eta }
    const beforeEta = Date.parse(eta) - 1
    const afterEta = Date.parse(eta) + 1

    expect(isAccountDeletionReceiptBeforeExpectedCompletion(pendingReceipt, beforeEta)).toBe(true)
    expect(isAccountDeletionReceiptBeforeExpectedCompletion(pendingReceipt, afterEta)).toBe(false)
    expect(isAccountDeletionReceiptBeforeExpectedCompletion(receipt, beforeEta)).toBe(false)
  })

  it('keeps a provisional 404 eligible during the short post-ETA grace period', () => {
    const eta = '2026-08-29T15:05:00Z'
    const pendingReceipt = { ...receipt, jobId: null, estimatedCompletionAt: eta }
    const expectedTime = Date.parse(eta)

    expect(isAccountDeletionReceiptWithinProvisionalGrace(pendingReceipt, expectedTime)).toBe(true)
    expect(isAccountDeletionReceiptWithinProvisionalGrace(
      pendingReceipt,
      expectedTime + ACCOUNT_DELETION_PROVISIONAL_404_GRACE_MS - 1,
    )).toBe(true)
    expect(isAccountDeletionReceiptWithinProvisionalGrace(
      pendingReceipt,
      expectedTime + ACCOUNT_DELETION_PROVISIONAL_404_GRACE_MS,
    )).toBe(false)
    expect(isAccountDeletionReceiptWithinProvisionalGrace(receipt, expectedTime)).toBe(false)
  })

  it('restores a valid receipt after logout or reload', () => {
    storage.getItem.mockReturnValue(JSON.stringify(receipt))

    expect(readAccountDeletionReceipt()).toEqual(receipt)
  })

  it('does not restore malformed data and does not claim completion', () => {
    storage.getItem.mockReturnValue(JSON.stringify({ status: 'COMPLETED' }))

    expect(readAccountDeletionReceipt()).toBeNull()
    expect(hasStoredAccountDeletionReceiptEntry()).toBe(true)
    expect(storage.removeItem).not.toHaveBeenCalled()
  })

  it('distinguishes an empty storage slot from an unusable stored receipt', () => {
    storage.getItem.mockReturnValue(null)
    expect(hasStoredAccountDeletionReceiptEntry()).toBe(false)

    storage.getItem.mockReturnValue('legacy-receipt')
    expect(hasStoredAccountDeletionReceiptEntry()).toBe(true)
  })

  it('requires the server-compatible 43-character base64url token format', () => {
    expect(isAccountDeletionReceipt(receipt)).toBe(true)
    expect(isAccountDeletionReceipt({ ...receipt, receiptToken: 'too-short' })).toBe(false)
    expect(isAccountDeletionReceipt({ ...receipt, receiptToken: `${VALID_RECEIPT_TOKEN}!` })).toBe(false)
    expect(isAccountDeletionReceipt({ ...receipt, receiptToken: `${VALID_RECEIPT_TOKEN} ` })).toBe(false)
  })

  it('rejects receipt metadata with an invalid completion timestamp', () => {
    expect(saveAccountDeletionReceipt({
      ...receipt,
      estimatedCompletionAt: 'not-a-timestamp',
    })).toBe(false)
  })

  it('removes the receipt only when the caller explicitly dismisses it', () => {
    clearAccountDeletionReceipt()

    expect(storage.removeItem).toHaveBeenCalledWith(ACCOUNT_DELETION_RECEIPT_STORAGE_KEY)
  })

  it('returns false when browser storage is unavailable', () => {
    storage.setItem.mockImplementation(() => {
      throw new Error('storage disabled')
    })

    expect(saveAccountDeletionReceipt(receipt)).toBe(false)
  })

  it('does not overwrite a receipt belonging to another member', () => {
    storage.getItem.mockReturnValue(JSON.stringify({
      ...receipt,
      ownerMemberId: 99,
    }))

    expect(saveAccountDeletionReceipt(receipt)).toBe(false)
    expect(storage.setItem).not.toHaveBeenCalled()
  })

  it('does not overwrite a legacy receipt whose owner is unknown', () => {
    storage.getItem.mockReturnValue(JSON.stringify({
      jobId: null,
      receiptToken: VALID_RECEIPT_TOKEN,
      estimatedCompletionAt: receipt.estimatedCompletionAt,
    }))

    expect(saveAccountDeletionReceipt(receipt)).toBe(false)
    expect(storage.setItem).not.toHaveBeenCalled()
  })

  it('does not rotate an unresolved receipt token without explicit dismissal', () => {
    storage.getItem.mockReturnValue(JSON.stringify({
      ...receipt,
      jobId: null,
      receiptToken: `${VALID_RECEIPT_TOKEN.slice(0, 42)}B`,
    }))

    expect(saveAccountDeletionReceipt(receipt)).toBe(false)
    expect(storage.setItem).not.toHaveBeenCalled()
  })
})
