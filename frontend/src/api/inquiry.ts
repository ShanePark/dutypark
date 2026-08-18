import apiClient from './client'
import type { CreateInquiryRequest, CreateInquiryResponse } from '@/types/inquiry'

/** The support form is the published contact channel, so it stays callable without a session. */
export const inquiryApi = {
  create: async (request: CreateInquiryRequest): Promise<CreateInquiryResponse> => {
    const response = await apiClient.post<CreateInquiryResponse>('/inquiries', request)
    return response.data
  },
}
