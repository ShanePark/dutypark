export interface CreateInquiryRequest {
  email: string
  subject?: string
  content: string
}

export interface CreateInquiryResponse {
  id: string
}
