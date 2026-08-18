import apiClient from './client'
import type { PageResponse } from '@/types'
import type { CreateInquiryRequest, CreateInquiryResponse, MyInquiry } from '@/types/inquiry'

interface CreateInquiryOptions {
  verifyMemberSession?: boolean
}

async function verifyMemberSession(): Promise<void> {
  await apiClient.get('/inquiries/me', {
    params: { page: 0, size: 1 },
  })
}

/** The support form is the published contact channel, so it stays callable without a session. */
export const inquiryApi = {
  create: async (
    request: CreateInquiryRequest,
    options: CreateInquiryOptions = {},
  ): Promise<CreateInquiryResponse> => {
    if (options.verifyMemberSession) {
      // This protected request lets the shared client refresh an expired access cookie or log out
      // before the public create endpoint could accidentally record a signed-in member as a guest.
      await verifyMemberSession()
    }
    const response = await apiClient.post<CreateInquiryResponse>('/inquiries', request)
    return response.data
  },

  /** Signed-in members only; the server scopes the page to the caller's own inquiries. */
  fetchMine: async (page: number = 0, size: number = 10): Promise<PageResponse<MyInquiry>> => {
    const response = await apiClient.get<PageResponse<MyInquiry>>('/inquiries/me', {
      params: { page, size },
    })
    return response.data
  },
}
