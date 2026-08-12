import apiClient from './client'
import type { PolicyDto } from './policy'

export interface AiScheduleParsingConsentDto {
  consented: boolean
  currentPolicyVersion: string
  consentVersion: string | null
  needsRenewal: boolean
  consentedAt: string | null
  revokedAt: string | null
  policy: PolicyDto & { policyType: 'AI_SCHEDULE_PARSING' }
}

export const aiScheduleParsingConsentApi = {
  async getCurrent(): Promise<AiScheduleParsingConsentDto> {
    const response = await apiClient.get<AiScheduleParsingConsentDto>('/consents/ai-schedule-parsing')
    return response.data
  },

  async grant(policyVersion: string): Promise<AiScheduleParsingConsentDto> {
    const response = await apiClient.put<AiScheduleParsingConsentDto>(
      '/consents/ai-schedule-parsing',
      { consented: true, policyVersion },
    )
    return response.data
  },

  async revoke(): Promise<AiScheduleParsingConsentDto> {
    const response = await apiClient.put<AiScheduleParsingConsentDto>(
      '/consents/ai-schedule-parsing',
      { consented: false },
    )
    return response.data
  },
}
