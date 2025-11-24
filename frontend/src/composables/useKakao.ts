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

export function useKakao() {
  const initKakao = () => {
    if (initialized || !window.Kakao) return

    const isLocal = window.location.href.includes('localhost')
    const appKey = isLocal ? KAKAO_TEST_KEY : KAKAO_PROD_KEY

    if (!window.Kakao.isInitialized()) {
      window.Kakao.init(appKey)
    }
    initialized = true
  }

  const kakaoLogin = (referer: string = '/') => {
    initKakao()

    const spaCallbackUrl = `${window.location.origin}/auth/oauth-callback`
    const redirectUri = `${window.location.origin}/api/auth/Oauth2ClientCallback/kakao`

    window.Kakao.Auth.authorize({
      redirectUri,
      state: JSON.stringify({
        spa: true,
        spaCallbackUrl,
        redirectUri,
        referer,
      }),
    })
  }

  return {
    initKakao,
    kakaoLogin,
  }
}
