import apiClient from './client'
import type { LoginDto, LoginMember } from '@/types'

export const authApi = {
  login: async (data: LoginDto): Promise<string> => {
    const response = await apiClient.post<string>('/auth/login', data)
    return response.data
  },

  logout: async (): Promise<void> => {
    window.location.href = '/logout'
  },

  getStatus: async (): Promise<LoginMember | null> => {
    try {
      const response = await apiClient.get<LoginMember>('/auth/status')
      return response.data
    } catch {
      return null
    }
  },

  changePassword: async (data: { currentPassword: string; newPassword: string }): Promise<void> => {
    await apiClient.put('/auth/password', data)
  },
}
