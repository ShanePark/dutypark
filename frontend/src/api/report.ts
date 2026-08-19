import apiClient from './client'
import type { PageResponse } from '@/types'
import type { CreateReportRequest, CreateReportResponse, MyReport } from '@/types/report'

export const reportApi = {
  // 201 for a new report, 200 when the same open report already exists. Both are a success.
  createReport: async (request: CreateReportRequest): Promise<CreateReportResponse> => {
    const response = await apiClient.post<CreateReportResponse>('/reports', request)
    return response.data
  },

  /** Signed-in members only; the server scopes the page to the caller's own reports. */
  fetchMine: async (page: number = 0, size: number = 10): Promise<PageResponse<MyReport>> => {
    const response = await apiClient.get<PageResponse<MyReport>>('/reports/me', {
      params: { page, size },
    })
    return response.data
  },
}
