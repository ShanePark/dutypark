import apiClient from '@/api/client'

type WebOAuthPurpose = 'LOGIN' | 'LINK'

interface WebOAuthAuthorizeResponse {
  authorizationUrl: string
  expiresIn: number
}

export async function authorizeNaver(
  purpose: WebOAuthPurpose,
  referer: string,
  navigate: (url: string) => void = (url) => window.location.assign(url),
): Promise<void> {
  const response = await apiClient.post<WebOAuthAuthorizeResponse>('/auth/oauth2/authorize', {
    provider: 'NAVER',
    purpose,
    referer,
  })
  navigate(response.data.authorizationUrl)
}

export function useNaver() {
  const isNaverEnabled = Boolean(import.meta.env.VITE_NAVER_CLIENT_ID)

  const naverLogin = (referer: string = '/') => authorizeNaver('LOGIN', referer)
  const naverLink = (referer: string = '/member') => authorizeNaver('LINK', referer)

  return {
    isNaverEnabled,
    naverLogin,
    naverLink,
  }
}
