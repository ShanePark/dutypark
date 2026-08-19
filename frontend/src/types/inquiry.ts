export type InquiryStatus = 'OPEN' | 'CLOSED'

/** Only a guest names a reply address; the server records the member's account e-mail. */
export interface CreateInquiryRequest {
  email?: string
  subject?: string
  content: string
}

export interface CreateInquiryResponse {
  id: string
}

/**
 * The signed-in member's own view of an inquiry. Deliberately narrower than `AdminInquiryDto`:
 * the internal memo, the reporter IP and the answering admin must never reach the user.
 */
export interface MyInquiry {
  id: string
  email: string | null
  subject: string | null
  content: string
  status: InquiryStatus
  createdAt: string
  answer: string | null
  answeredAt: string | null
}
