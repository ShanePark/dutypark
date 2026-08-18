import type {
  InquiryStatus,
  UpdateInquiryStatusRequest,
} from '@/types/adminModeration'

/**
 * Answers are timestamped by the server whenever they are present in a status patch.
 * Only send a non-blank answer when its normalized value actually changed.
 */
export function buildInquiryUpdateRequest(
  status: InquiryStatus,
  memo: string,
  answer: string,
  previousAnswer: string | null,
): UpdateInquiryStatusRequest {
  const normalizedAnswer = answer.trim()
  const normalizedPreviousAnswer = previousAnswer?.trim() ?? ''

  return {
    status,
    memo: memo.trim() || undefined,
    answer: normalizedAnswer && normalizedAnswer !== normalizedPreviousAnswer
      ? normalizedAnswer
      : undefined,
  }
}
