import apiClient from './client'
import type { CreateReportRequest, CreateReportResponse } from '@/types/report'

export const reportApi = {
  // 201 for a new report, 200 when the same open report already exists. Both are a success.
  createReport: async (request: CreateReportRequest): Promise<CreateReportResponse> => {
    const response = await apiClient.post<CreateReportResponse>('/reports', request)
    return response.data
  },
}
