import apiClient, { tokenManager } from './client'
import type { LoginDto, LoginMember, TokenResponse } from '@/types'

export interface SsoSignupDto {
  uuid: string
  username: string
  termAgree: boolean
}

export const authApi = {
  /**
   * Bearer 토큰 방식 로그인
   * 토큰을 localStorage에 저장합니다.
   */
  loginWithToken: async (data: LoginDto): Promise<TokenResponse> => {
    const response = await apiClient.post<TokenResponse>('/auth/token', data)
    const { accessToken, refreshToken } = response.data
    tokenManager.setTokens(accessToken, refreshToken)
    return response.data
  },

  /**
   * 쿠키 기반 로그인 (기존 방식, fallback용)
   */
  login: async (data: LoginDto): Promise<string> => {
    const response = await apiClient.post<string>('/auth/login', data)
    return response.data
  },

  logout: async (): Promise<void> => {
    // Delete current refresh token from server
    const refreshToken = tokenManager.getRefreshToken()
    if (refreshToken) {
      try {
        await apiClient.delete('/refresh-tokens/current', {
          headers: { 'X-Current-Token': refreshToken },
        })
      } catch {
        // Ignore errors during logout
      }
    }
    tokenManager.clearTokens()
    window.location.href = '/'
  },

  getStatus: async (): Promise<LoginMember | null> => {
    const response = await apiClient.get<LoginMember>('/auth/status')
    return response.data
  },

  changePassword: async (data: {
    memberId: number
    currentPassword?: string
    newPassword: string
  }): Promise<void> => {
    await apiClient.put('/auth/password', data)
  },

  /**
   * 토큰 갱신
   */
  refresh: async (refreshToken: string): Promise<TokenResponse> => {
    const response = await apiClient.post<TokenResponse>('/auth/refresh', {
      refreshToken,
    })
    const { accessToken, refreshToken: newRefreshToken } = response.data
    tokenManager.setTokens(accessToken, newRefreshToken)
    return response.data
  },

  /**
   * 토큰 존재 여부 확인
   */
  hasTokens: (): boolean => {
    return tokenManager.hasTokens()
  },

  /**
   * SSO 회원가입 (Bearer 토큰 방식)
   * 토큰을 localStorage에 저장합니다.
   */
  ssoSignupWithToken: async (data: SsoSignupDto): Promise<TokenResponse> => {
    const response = await apiClient.post<TokenResponse>('/auth/sso/signup/token', data)
    const { accessToken, refreshToken } = response.data
    tokenManager.setTokens(accessToken, refreshToken)
    return response.data
  },
}
