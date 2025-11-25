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

const KAKAO_TEST_KEY = '962c00be36be55bd0c0b55478cc25149'
const KAKAO_PROD_KEY = 'fe206dfae05cfafc94806ad67abbcfc1'

let initialized = false

function isLocalHost(): boolean {
  return ['localhost', '127.0.0.1'].some((host) => window.location.hostname === host)
}

export function useKakao() {
  const initKakao = () => {
    if (initialized || !window.Kakao) return

    const appKey = isLocalHost() ? KAKAO_TEST_KEY : KAKAO_PROD_KEY

    if (!window.Kakao.isInitialized()) {
      window.Kakao.init(appKey)
    }
    initialized = true
  }

  const kakaoLogin = (referer: string = '/') => {
    initKakao()

    const baseUrl = isLocalHost() ? 'http://localhost:8080' : window.location.origin
    const redirectUri = `${baseUrl}/api/auth/Oauth2ClientCallback/kakao`
    const callbackUrl = `${window.location.origin}/auth/oauth-callback`

    window.Kakao.Auth.authorize({
      redirectUri,
      state: JSON.stringify({
        referer,
        callbackUrl,
      }),
    })
  }

  return {
    initKakao,
    kakaoLogin,
  }
}
