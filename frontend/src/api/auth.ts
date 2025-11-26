import apiClient from './client'
import type { LoginDto, LoginMember } from '@/types'

export interface SsoSignupDto {
  uuid: string
  username: string
  termAgree: boolean
}

export interface AuthResponse {
  expiresIn: number
}

export const authApi = {
  /**
   * Login with HttpOnly cookie
   */
  login: async (data: LoginDto): Promise<AuthResponse> => {
    const response = await apiClient.post<AuthResponse>('/auth/token', data)
    return response.data
  },

  /**
   * Logout - clears HttpOnly cookies on server
   */
  logout: async (): Promise<void> => {
    try {
      await apiClient.post('/auth/logout')
    } catch {
      // Ignore errors during logout
    }
    window.location.href = '/'
  },

  getStatus: async (): Promise<LoginMember | null> => {
    const response = await apiClient.get<LoginMember>('/auth/status')
    // Server returns empty body when not logged in
    return response.data || null
  },

  changePassword: async (data: {
    memberId: number
    currentPassword?: string
    newPassword: string
  }): Promise<void> => {
    await apiClient.put('/auth/password', data)
  },

  /**
   * Refresh token - cookie is sent automatically
   */
  refresh: async (): Promise<AuthResponse> => {
    const response = await apiClient.post<AuthResponse>('/auth/refresh')
    return response.data
  },

  /**
   * SSO signup with HttpOnly cookie
   */
  ssoSignup: async (data: SsoSignupDto): Promise<AuthResponse> => {
    const response = await apiClient.post<AuthResponse>('/auth/sso/signup/token', data)
    return response.data
  },
}
