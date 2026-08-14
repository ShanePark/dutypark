import apiClient from './client'
import type { LoginDto, LoginMember } from '@/types'

export interface SsoSignupDto {
  uuid: string
  username: string
  termAgree: boolean
  privacyAgree: boolean
  termsVersion?: string
  privacyVersion?: string
}

export interface AuthResponse {
  expiresIn: number
}

export interface AppleExchangeRequest {
  identityToken: string
  authorizationCode: string
  rawNonce: string
  purpose: 'LOGIN' | 'LINK'
}

export interface AppleExchangeResponse {
  signupRequired: boolean
  signupUuid: string | null
  expiresIn: number | null
  reauthProof: string | null
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
    await apiClient.post('/auth/logout')
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

  exchangeAppleLogin: async (data: AppleExchangeRequest): Promise<AppleExchangeResponse> => {
    const response = await apiClient.post<AppleExchangeResponse>('/auth/web/oauth/apple/exchange', data)
    return response.data
  },

  /**
   * Impersonate - switch to managed account
   */
  impersonate: async (targetMemberId: number): Promise<AuthResponse> => {
    const response = await apiClient.post<AuthResponse>(`/auth/impersonate/${targetMemberId}`)
    return response.data
  },

  /**
   * Restore - return to original account from impersonation
   */
  restore: async (): Promise<AuthResponse> => {
    const response = await apiClient.post<AuthResponse>('/auth/restore')
    return response.data
  },
}
