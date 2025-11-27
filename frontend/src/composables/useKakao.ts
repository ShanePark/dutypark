declare global {
  interface Window {
    Kakao: {
      init: (appKey: string) => void
      isInitialized: () => boolean
      Auth: {
        authorize: (options: {
          redirectUri: string
          state?: string
        }) => void
      }
    }
  }
}

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || window.location.origin
const KAKAO_APP_KEY = import.meta.env.VITE_KAKAO_APP_KEY

let initialized = false

export function useKakao() {
  const initKakao = () => {
    if (initialized || !window.Kakao) return

    if (!window.Kakao.isInitialized()) {
      window.Kakao.init(KAKAO_APP_KEY)
    }
    initialized = true
  }

  const kakaoLogin = (referer: string = '/') => {
    initKakao()

    const redirectUri = `${API_BASE_URL}/api/auth/Oauth2ClientCallback/kakao`
    const callbackUrl = `${window.location.origin}/auth/oauth-callback`

    window.Kakao.Auth.authorize({
      redirectUri,
      state: JSON.stringify({
        referer,
        callbackUrl,
      }),
    })
  }

  const kakaoLink = (referer: string = '/member') => {
    initKakao()

    const redirectUri = `${API_BASE_URL}/api/auth/Oauth2ClientCallback/kakao`
    const fullReferer = referer.startsWith('http') ? referer : `${window.location.origin}${referer}`

    window.Kakao.Auth.authorize({
      redirectUri,
      state: JSON.stringify({
        referer: fullReferer,
        login: true,
      }),
    })
  }

  return {
    initKakao,
    kakaoLogin,
    kakaoLink,
  }
}
