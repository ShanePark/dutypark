const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || window.location.origin
const NAVER_CLIENT_ID = import.meta.env.VITE_NAVER_CLIENT_ID

interface NaverStatePayload {
  callbackUrl?: string
  login?: boolean
  referer: string
}

function encodeState(state: NaverStatePayload): string {
  const utf8Bytes = new TextEncoder().encode(JSON.stringify(state))
  const binary = Array.from(utf8Bytes, (byte) => String.fromCharCode(byte)).join('')

  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '')
}

function navigateToNaverAuthorize(state: NaverStatePayload) {
  if (!NAVER_CLIENT_ID) {
    throw new Error('VITE_NAVER_CLIENT_ID is not configured')
  }

  const authorizeUrl = new URL('https://nid.naver.com/oauth2.0/authorize')
  authorizeUrl.searchParams.set('response_type', 'code')
  authorizeUrl.searchParams.set('client_id', NAVER_CLIENT_ID)
  authorizeUrl.searchParams.set('redirect_uri', `${API_BASE_URL}/api/auth/Oauth2ClientCallback/naver`)
  authorizeUrl.searchParams.set('state', encodeState(state))

  window.location.href = authorizeUrl.toString()
}

export function useNaver() {
  const isNaverEnabled = Boolean(NAVER_CLIENT_ID)

  const naverLogin = (referer: string = '/') => {
    navigateToNaverAuthorize({
      referer,
      callbackUrl: `${window.location.origin}/auth/oauth-callback`,
    })
  }

  const naverLink = (referer: string = '/member') => {
    const fullReferer = referer.startsWith('http') ? referer : `${window.location.origin}${referer}`

    navigateToNaverAuthorize({
      referer: fullReferer,
      login: true,
    })
  }

  return {
    isNaverEnabled,
    naverLogin,
    naverLink,
  }
}
