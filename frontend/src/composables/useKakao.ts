import apiClient from '@/api/client'

type WebOAuthPurpose = 'LOGIN' | 'LINK'

interface WebOAuthAuthorizeResponse {
  authorizationUrl: string
  expiresIn: number
}

export async function authorizeKakao(
  purpose: WebOAuthPurpose,
  referer: string,
  navigate: (url: string) => void = (url) => window.location.assign(url),
): Promise<void> {
  const response = await apiClient.post<WebOAuthAuthorizeResponse>('/auth/oauth2/authorize', {
    provider: 'KAKAO',
    purpose,
    referer,
  })
  navigate(response.data.authorizationUrl)
}

export function useKakao() {
  // Kept for call-site compatibility now that authorization is server-driven.
  const initKakao = () => {}

  const kakaoLogin = (referer: string = '/') => authorizeKakao('LOGIN', referer)
  const kakaoLink = (referer: string = '/member') => authorizeKakao('LINK', referer)

  return {
    initKakao,
    kakaoLogin,
    kakaoLink,
  }
}
