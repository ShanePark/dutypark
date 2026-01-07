import apiClient from './client'

export interface PolicyDto {
  policyType: 'TERMS' | 'PRIVACY'
  version: string
  content: string
  effectiveDate: string
}

export interface CurrentPoliciesDto {
  terms: PolicyDto | null
  privacy: PolicyDto | null
}

export const policyApi = {
  getCurrentPolicies: async (): Promise<CurrentPoliciesDto> => {
    const response = await apiClient.get<CurrentPoliciesDto>('/policies/current')
    return response.data
  },

  getPolicy: async (type: 'TERMS' | 'PRIVACY'): Promise<PolicyDto> => {
    const response = await apiClient.get<PolicyDto>(`/policies/${type.toLowerCase()}`)
    return response.data
  }
}
