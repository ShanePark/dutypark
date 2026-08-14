import { authApi, type AppleExchangeResponse } from '@/api/auth'
import { ref } from 'vue'

const APPLE_SDK_BASE_URL = 'https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1'
const RANDOM_VALUE_LENGTH = 32

export interface AppleIdSignInOptions {
  clientId: string
  scope?: string
  redirectURI: string
  state: string
  nonce: string
  usePopup: boolean
}

interface AppleIdAuthorization {
  code?: string
  id_token?: string
  state?: string
}

interface AppleIdSignInResponse {
  authorization?: AppleIdAuthorization
  error?: string
}

export interface AppleIdSdk {
  auth: {
    init: (options: AppleIdSignInOptions) => void
    signIn: () => Promise<AppleIdSignInResponse>
  }
}

declare global {
  interface Window {
    AppleID?: AppleIdSdk
  }
}

export type AppleSignInErrorCode =
  | 'CONFIGURATION_UNAVAILABLE'
  | 'SDK_UNAVAILABLE'
  | 'INVALID_CREDENTIAL'
  | 'STATE_MISMATCH'
  | 'CANCELLED'

export class AppleSignInError extends Error {
  readonly code: AppleSignInErrorCode

  constructor(code: AppleSignInErrorCode) {
    super(code)
    this.name = 'AppleSignInError'
    this.code = code
  }
}

export function isAppleSignInCancellation(error: unknown): boolean {
  return error instanceof AppleSignInError && error.code === 'CANCELLED'
}

interface AppleSignInAttempt {
  rawNonce: string
  hashedNonce: string
  state: string
}

interface AuthorizeAppleLoginOptions {
  clientId: string
  redirectUri: string
  purpose?: AppleOAuthPurpose
  loadSdk: () => Promise<AppleIdSdk>
  exchange: typeof authApi.exchangeAppleLogin
  crypto?: Crypto
}

export type AppleOAuthPurpose = 'LOGIN' | 'LINK'

function base64Url(bytes: Uint8Array): string {
  let binary = ''
  for (const byte of bytes) {
    binary += String.fromCharCode(byte)
  }
  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '')
}

function randomBytes(cryptoProvider: Crypto): Uint8Array<ArrayBuffer> {
  const bytes = new Uint8Array(RANDOM_VALUE_LENGTH)
  cryptoProvider.getRandomValues(bytes)
  return bytes
}

async function createAppleSignInAttempt(cryptoProvider: Crypto): Promise<AppleSignInAttempt> {
  const rawNonce = base64Url(randomBytes(cryptoProvider))
  const digest = await cryptoProvider.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(rawNonce),
  )

  return {
    rawNonce,
    hashedNonce: Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join(''),
    state: base64Url(randomBytes(cryptoProvider)),
  }
}

function isCancelled(error: unknown): boolean {
  if (!error || typeof error !== 'object') return false
  const code = 'error' in error ? error.error : undefined
  return code === 'popup_closed_by_user' || code === 'user_cancelled_authorize'
}

export function createAppleSdkLoader(locale = 'en_US') {
  let loadingPromise: Promise<AppleIdSdk> | null = null
  const sdkUrl = `${APPLE_SDK_BASE_URL}/${locale}/appleid.auth.js`

  return (): Promise<AppleIdSdk> => {
    if (typeof window === 'undefined' || typeof document === 'undefined') {
      return Promise.reject(new AppleSignInError('SDK_UNAVAILABLE'))
    }
    if (window.AppleID) return Promise.resolve(window.AppleID)
    if (loadingPromise) return loadingPromise

    loadingPromise = new Promise<AppleIdSdk>((resolve, reject) => {
      const handleLoad = () => {
        if (window.AppleID) {
          resolve(window.AppleID)
        } else {
          script.remove()
          reject(new AppleSignInError('SDK_UNAVAILABLE'))
        }
      }
      const handleError = () => {
        script.remove()
        reject(new AppleSignInError('SDK_UNAVAILABLE'))
      }
      const existing = document.querySelector<HTMLScriptElement>(`script[src="${sdkUrl}"]`)
      const script = existing ?? document.createElement('script')
      script.addEventListener('load', handleLoad, { once: true })
      script.addEventListener('error', handleError, { once: true })

      if (!existing) {
        script.src = sdkUrl
        script.async = true
        script.defer = true
        document.head.appendChild(script)
      }
    })

    const currentPromise = loadingPromise
    void currentPromise.catch(() => {
      if (loadingPromise === currentPromise) {
        loadingPromise = null
      }
    })
    return currentPromise
  }
}

export async function authorizeAppleLogin({
  clientId,
  redirectUri,
  purpose = 'LOGIN',
  loadSdk,
  exchange,
  crypto: cryptoOverride,
}: AuthorizeAppleLoginOptions): Promise<AppleExchangeResponse> {
  if (!clientId || !redirectUri) {
    throw new AppleSignInError('CONFIGURATION_UNAVAILABLE')
  }
  const cryptoProvider = cryptoOverride ?? globalThis.crypto
  if (!cryptoProvider?.getRandomValues || !cryptoProvider.subtle) {
    throw new AppleSignInError('CONFIGURATION_UNAVAILABLE')
  }

  const [sdk, attempt] = await Promise.all([
    loadSdk(),
    createAppleSignInAttempt(cryptoProvider),
  ])
  return exchangePreparedAppleLogin(sdk, attempt, clientId, redirectUri, purpose, exchange)
}

async function exchangePreparedAppleLogin(
  sdk: AppleIdSdk,
  attempt: AppleSignInAttempt,
  clientId: string,
  redirectUri: string,
  purpose: AppleOAuthPurpose,
  exchange: typeof authApi.exchangeAppleLogin,
): Promise<AppleExchangeResponse> {
  sdk.auth.init({
    clientId,
    redirectURI: redirectUri,
    state: attempt.state,
    nonce: attempt.hashedNonce,
    usePopup: true,
  })

  let signInPromise: Promise<AppleIdSignInResponse>
  try {
    // Keep the popup open call synchronous with the user's click. Awaiting Web Crypto
    // first can consume the browser's transient user activation and block the popup.
    signInPromise = sdk.auth.signIn()
  } catch (error) {
    if (isCancelled(error)) throw new AppleSignInError('CANCELLED')
    throw new AppleSignInError('SDK_UNAVAILABLE')
  }

  let response: AppleIdSignInResponse
  try {
    response = await signInPromise
  } catch (error) {
    if (isCancelled(error)) throw new AppleSignInError('CANCELLED')
    throw new AppleSignInError('SDK_UNAVAILABLE')
  }

  if (isCancelled(response)) {
    throw new AppleSignInError('CANCELLED')
  }
  if (response.error) {
    throw new AppleSignInError('SDK_UNAVAILABLE')
  }
  const authorization = response.authorization
  if (!authorization?.code || !authorization.id_token || !authorization.state) {
    throw new AppleSignInError('INVALID_CREDENTIAL')
  }
  if (authorization.state !== attempt.state) {
    throw new AppleSignInError('STATE_MISMATCH')
  }

  return exchange({
    identityToken: authorization.id_token,
    authorizationCode: authorization.code,
    rawNonce: attempt.rawNonce,
    purpose,
  })
}

const appleSdkLocale = typeof document !== 'undefined' && document.documentElement.lang.toLowerCase().startsWith('ko')
  ? 'ko_KR'
  : 'en_US'
const loadAppleSdk = createAppleSdkLoader(appleSdkLocale)
const APPLE_CLIENT_ID = import.meta.env.VITE_APPLE_CLIENT_ID ?? ''
const APPLE_REDIRECT_URI = import.meta.env.VITE_APPLE_REDIRECT_URI ?? ''

export function useApple() {
  const isAppleConfigured = Boolean(APPLE_CLIENT_ID && APPLE_REDIRECT_URI)
  const isAppleReady = ref(false)
  let preparedAttempt: AppleSignInAttempt | null = null
  let preparedSdk: AppleIdSdk | null = null
  let preparationPromise: Promise<void> | null = null

  const prepareAppleLogin = (): Promise<void> => {
    if (!isAppleConfigured) return Promise.resolve()
    if (preparedAttempt && preparedSdk) return Promise.resolve()
    if (preparationPromise) return preparationPromise

    preparationPromise = Promise.all([
      loadAppleSdk(),
      createAppleSignInAttempt(globalThis.crypto),
    ]).then(([sdk, attempt]) => {
      preparedSdk = sdk
      preparedAttempt = attempt
      isAppleReady.value = true
    }).finally(() => {
      preparationPromise = null
    })
    return preparationPromise
  }

  const preloadAppleSdk = async () => {
    if (!isAppleConfigured) {
      return
    }
    await prepareAppleLogin()
  }

  const exchangePreparedAppleCredential = (purpose: AppleOAuthPurpose) => {
    if (!isAppleConfigured) {
      throw new AppleSignInError('CONFIGURATION_UNAVAILABLE')
    }
    if (!preparedAttempt || !preparedSdk) {
      throw new AppleSignInError('SDK_UNAVAILABLE')
    }

    const attempt = preparedAttempt
    const sdk = preparedSdk
    preparedAttempt = null
    preparedSdk = null
    isAppleReady.value = false

    const exchangePromise = exchangePreparedAppleLogin(
      sdk,
      attempt,
      APPLE_CLIENT_ID,
      APPLE_REDIRECT_URI,
      purpose,
      authApi.exchangeAppleLogin,
    )
    void prepareAppleLogin().catch(() => {
      // The current popup is already in progress; a later attempt stays disabled.
    })
    return exchangePromise
  }

  const appleLogin = () => exchangePreparedAppleCredential('LOGIN')
  const appleLink = () => exchangePreparedAppleCredential('LINK')

  return {
    isAppleConfigured,
    isAppleReady,
    preloadAppleSdk,
    appleLogin,
    appleLink,
  }
}
