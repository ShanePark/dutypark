export const ACCOUNT_DELETION_RECEIPT_STORAGE_KEY = 'dp-account-deletion-receipt'
export const ACCOUNT_DELETION_EXPECTED_COMPLETION_MS = 5 * 60 * 1000
export const ACCOUNT_DELETION_PROVISIONAL_404_GRACE_MS = 60 * 1000

const ACCOUNT_DELETION_RECEIPT_TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/

export interface AccountDeletionReceipt {
  ownerMemberId: number
  jobId: number | null
  receiptToken: string
  estimatedCompletionAt: string
}

export function isAccountDeletionReceiptToken(value: unknown): value is string {
  return typeof value === 'string' && ACCOUNT_DELETION_RECEIPT_TOKEN_PATTERN.test(value)
}

function getStorage(): Storage | null {
  if (typeof localStorage === 'undefined') return null

  try {
    return localStorage
  } catch {
    return null
  }
}

export function isAccountDeletionReceipt(value: unknown): value is AccountDeletionReceipt {
  if (!value || typeof value !== 'object') return false
  const receipt = value as Record<string, unknown>
  return Number.isInteger(receipt.ownerMemberId)
    && (receipt.ownerMemberId as number) > 0
    && (receipt.jobId === null
      || (Number.isInteger(receipt.jobId) && (receipt.jobId as number) > 0))
    && isAccountDeletionReceiptToken(receipt.receiptToken)
    && typeof receipt.estimatedCompletionAt === 'string'
    && receipt.estimatedCompletionAt.trim().length > 0
    && Number.isFinite(Date.parse(receipt.estimatedCompletionAt))
}

export function isAccountDeletionReceiptBeforeExpectedCompletion(
  receipt: AccountDeletionReceipt,
  now = Date.now(),
): boolean {
  if (receipt.jobId !== null) return false
  const expectedTime = Date.parse(receipt.estimatedCompletionAt)
  return Number.isFinite(expectedTime) && now < expectedTime
}

/**
 * A request response can be lost while the server is committing the first job row. Keep
 * polling a provisional receipt briefly after the advertised ETA before treating it as
 * unavailable, but never use this grace period for a receipt that has a known job id.
 */
export function isAccountDeletionReceiptWithinProvisionalGrace(
  receipt: AccountDeletionReceipt,
  now = Date.now(),
): boolean {
  if (receipt.jobId !== null) return false
  const expectedTime = Date.parse(receipt.estimatedCompletionAt)
  return Number.isFinite(expectedTime)
    && now < expectedTime + ACCOUNT_DELETION_PROVISIONAL_404_GRACE_MS
}

export function saveAccountDeletionReceipt(receipt: AccountDeletionReceipt): boolean {
  const storage = getStorage()
  if (!storage || !isAccountDeletionReceipt(receipt)) return false

  try {
    // A receipt without an owner (including data written by an older build) is
    // intentionally not replaceable: its account cannot be established safely.
    const serializedExisting = storage.getItem(ACCOUNT_DELETION_RECEIPT_STORAGE_KEY)
    if (serializedExisting) {
      const existing: unknown = JSON.parse(serializedExisting)
      if (!isAccountDeletionReceipt(existing)
        || existing.ownerMemberId !== receipt.ownerMemberId
        || existing.receiptToken !== receipt.receiptToken) {
        // Never replace an existing account's capability, or rotate a token
        // while its request is still unresolved. The caller can explicitly
        // dismiss a terminal result before beginning a new request.
        return false
      }
    }
    storage.setItem(ACCOUNT_DELETION_RECEIPT_STORAGE_KEY, JSON.stringify(receipt))
    return true
  } catch {
    return false
  }
}

export function readAccountDeletionReceipt(): AccountDeletionReceipt | null {
  const storage = getStorage()
  if (!storage) return null

  try {
    const serialized = storage.getItem(ACCOUNT_DELETION_RECEIPT_STORAGE_KEY)
    if (!serialized) return null
    const parsed: unknown = JSON.parse(serialized)
    return isAccountDeletionReceipt(parsed) ? parsed : null
  } catch {
    return null
  }
}

/**
 * Distinguishes an empty slot from malformed/legacy data. The latter is intentionally not
 * overwritten automatically because it might represent a receipt from an older build.
 */
export function hasStoredAccountDeletionReceiptEntry(): boolean {
  const storage = getStorage()
  if (!storage) return false

  try {
    return storage.getItem(ACCOUNT_DELETION_RECEIPT_STORAGE_KEY) !== null
  } catch {
    return false
  }
}

export function clearAccountDeletionReceipt(): void {
  const storage = getStorage()
  if (!storage) return

  try {
    storage.removeItem(ACCOUNT_DELETION_RECEIPT_STORAGE_KEY)
  } catch {
    // Storage can be unavailable in private browsing; there is nothing else to clear.
  }
}
