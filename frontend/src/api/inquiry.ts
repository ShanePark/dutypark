import apiClient from './client'
import type { PageResponse } from '@/types'
import type { CreateInquiryRequest, CreateInquiryResponse, MyInquiry } from '@/types/inquiry'

/** The support form is the published contact channel, so it stays callable without a session. */
export const inquiryApi = {
  create: async (request: CreateInquiryRequest): Promise<CreateInquiryResponse> => {
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
