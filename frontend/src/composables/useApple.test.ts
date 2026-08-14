import { afterEach, describe, expect, it, vi } from 'vitest'
import {
  AppleSignInError,
  authorizeAppleLogin,
  createAppleSdkLoader,
  isAppleSignInCancellation,
  useApple,
  type AppleIdSdk,
  type AppleIdSignInOptions,
} from './useApple'

describe('authorizeAppleLogin', () => {
  it('identifies only normalized user cancellation errors', () => {
    expect(isAppleSignInCancellation(new AppleSignInError('CANCELLED'))).toBe(true)
    expect(isAppleSignInCancellation(new AppleSignInError('SDK_UNAVAILABLE'))).toBe(false)
    expect(isAppleSignInCancellation(new Error('CANCELLED'))).toBe(false)
  })

  it('uses a hashed nonce and matching state before exchanging the raw nonce', async () => {
    let options: AppleIdSignInOptions | undefined
    const sdk: AppleIdSdk = {
      auth: {
        init: vi.fn((value) => {
          options = value
        }),
        signIn: vi.fn(async () => ({
          authorization: {
            code: 'authorization-code',
            id_token: 'identity-token',
            state: options?.state,
          },
        })),
      },
    }
    const exchange = vi.fn(async (_request: {
      identityToken: string
      authorizationCode: string
      rawNonce: string
      purpose: 'LOGIN' | 'LINK'
    }) => ({
      signupRequired: false,
      signupUuid: null,
      expiresIn: 3600,
      reauthProof: null,
    }))

    const response = await authorizeAppleLogin({
      clientId: 'kr.or.dutypark.web',
      redirectUri: 'https://dutypark.example/auth/apple/callback',
      loadSdk: vi.fn(async () => sdk),
      exchange,
    })

    expect(sdk.auth.init).toHaveBeenCalledOnce()
    expect(options).toMatchObject({
      clientId: 'kr.or.dutypark.web',
      redirectURI: 'https://dutypark.example/auth/apple/callback',
      usePopup: true,
    })
    expect(options).not.toHaveProperty('scope')
    expect(options?.nonce).toMatch(/^[a-f0-9]{64}$/)
    expect(options?.state).toMatch(/^[A-Za-z0-9_-]{43}$/)
    expect(exchange).toHaveBeenCalledWith({
      identityToken: 'identity-token',
      authorizationCode: 'authorization-code',
      rawNonce: expect.stringMatching(/^[A-Za-z0-9_-]{43}$/),
      purpose: 'LOGIN',
    })
    const rawNonce = exchange.mock.calls[0]?.[0].rawNonce
    const expectedDigest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(rawNonce))
    const expectedHashedNonce = Array.from(
      new Uint8Array(expectedDigest),
      (byte) => byte.toString(16).padStart(2, '0'),
    ).join('')
    expect(options?.nonce).toBe(expectedHashedNonce)
    expect(response.signupRequired).toBe(false)
  })

  it('exchanges the prepared Apple credential with LINK purpose', async () => {
    let options: AppleIdSignInOptions | undefined
    const sdk: AppleIdSdk = {
      auth: {
        init: vi.fn((value) => {
          options = value
        }),
        signIn: vi.fn(async () => ({
          authorization: {
            code: 'link-code',
            id_token: 'link-token',
            state: options?.state,
          },
        })),
      },
    }
    const exchange = vi.fn(async () => ({
      signupRequired: false,
      signupUuid: null,
      expiresIn: null,
      reauthProof: null,
    }))

    await authorizeAppleLogin({
      clientId: 'kr.or.dutypark.web',
      redirectUri: 'https://dutypark.example/auth/apple/callback',
      purpose: 'LINK',
      loadSdk: async () => sdk,
      exchange,
    })

    expect(exchange).toHaveBeenCalledWith(expect.objectContaining({
      identityToken: 'link-token',
      authorizationCode: 'link-code',
      purpose: 'LINK',
    }))
  })

  it('rejects a mismatched state without exchanging credentials', async () => {
    const exchange = vi.fn()
    const sdk: AppleIdSdk = {
      auth: {
        init: vi.fn(),
        signIn: vi.fn(async () => ({
          authorization: {
            code: 'authorization-code',
            id_token: 'identity-token',
            state: 'different-state',
          },
        })),
      },
    }

    await expect(authorizeAppleLogin({
      clientId: 'kr.or.dutypark.web',
      redirectUri: 'https://dutypark.example/auth/apple/callback',
      loadSdk: async () => sdk,
      exchange,
    })).rejects.toMatchObject({ code: 'STATE_MISMATCH' })

    expect(exchange).not.toHaveBeenCalled()
  })

  it('distinguishes a user-cancelled popup from provider failures', async () => {
    const sdk: AppleIdSdk = {
      auth: {
        init: vi.fn(),
        signIn: vi.fn(async () => {
          throw { error: 'popup_closed_by_user' }
        }),
      },
    }

    await expect(authorizeAppleLogin({
      clientId: 'kr.or.dutypark.web',
      redirectUri: 'https://dutypark.example/auth/apple/callback',
      loadSdk: async () => sdk,
      exchange: vi.fn(),
    })).rejects.toEqual(new AppleSignInError('CANCELLED'))
  })

  it('recognizes a cancellation returned as an Apple error response', async () => {
    const sdk: AppleIdSdk = {
      auth: {
        init: vi.fn(),
        signIn: vi.fn(async () => ({ error: 'user_cancelled_authorize' })),
      },
    }

    await expect(authorizeAppleLogin({
      clientId: 'kr.or.dutypark.web',
      redirectUri: 'https://dutypark.example/auth/apple/callback',
      loadSdk: async () => sdk,
      exchange: vi.fn(),
    })).rejects.toEqual(new AppleSignInError('CANCELLED'))
  })
})

describe('createAppleSdkLoader', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('loads the Apple JS SDK once and resolves after its global is available', async () => {
    const listeners = new Map<string, () => void>()
    const script = {
      async: false,
      defer: false,
      dataset: {} as Record<string, string>,
      src: '',
      addEventListener: vi.fn((event: string, listener: () => void) => {
        listeners.set(event, listener)
      }),
    }
    const sdk: AppleIdSdk = {
      auth: {
        init: vi.fn(),
        signIn: vi.fn(),
      },
    }
    const appleWindow: { AppleID?: AppleIdSdk } = {}
    const documentStub = {
      querySelector: vi.fn(() => null),
      createElement: vi.fn(() => script),
      head: {
        appendChild: vi.fn(() => {
          appleWindow.AppleID = sdk
          listeners.get('load')?.()
        }),
      },
    }
    vi.stubGlobal('window', appleWindow)
    vi.stubGlobal('document', documentStub)

    const loadAppleSdk = createAppleSdkLoader()
    const first = loadAppleSdk()
    const second = loadAppleSdk()

    await expect(first).resolves.toBe(sdk)
    await expect(second).resolves.toBe(sdk)
    expect(documentStub.createElement).toHaveBeenCalledOnce()
    expect(documentStub.head.appendChild).toHaveBeenCalledOnce()
    expect(script.src).toBe('https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js')
    expect(script.async).toBe(true)
    expect(script.defer).toBe(true)
  })

  it('does not load the SDK when Apple sign-in is not configured', async () => {
    const createElement = vi.fn()
    vi.stubGlobal('window', {})
    vi.stubGlobal('document', {
      documentElement: { lang: 'en' },
      createElement,
    })
    const { isAppleConfigured, preloadAppleSdk } = useApple()

    expect(isAppleConfigured).toBe(false)
    await expect(preloadAppleSdk()).resolves.toBeUndefined()
    expect(createElement).not.toHaveBeenCalled()
  })

  it('removes a failed SDK script and loads a fresh script when retried', async () => {
    const appleWindow: { AppleID?: AppleIdSdk } = {}
    const sdk: AppleIdSdk = {
      auth: {
        init: vi.fn(),
        signIn: vi.fn(),
      },
    }
    const scripts = Array.from({ length: 2 }, () => {
      const listeners = new Map<string, () => void>()
      return {
        element: {
          async: false,
          defer: false,
          src: '',
          addEventListener: vi.fn((event: string, listener: () => void) => {
            listeners.set(event, listener)
          }),
          remove: vi.fn(),
        },
        listeners,
      }
    })
    let appendCount = 0
    const documentStub = {
      querySelector: vi.fn(() => null),
      createElement: vi.fn(() => scripts[appendCount]?.element),
      head: {
        appendChild: vi.fn(() => {
          const current = scripts[appendCount]
          appendCount += 1
          if (appendCount === 1) {
            current?.listeners.get('error')?.()
          } else {
            appleWindow.AppleID = sdk
            current?.listeners.get('load')?.()
          }
        }),
      },
    }
    vi.stubGlobal('window', appleWindow)
    vi.stubGlobal('document', documentStub)

    const loadAppleSdk = createAppleSdkLoader()

    await expect(loadAppleSdk()).rejects.toMatchObject({ code: 'SDK_UNAVAILABLE' })
    await expect(loadAppleSdk()).resolves.toBe(sdk)
    expect(scripts[0]?.element.remove).toHaveBeenCalledOnce()
    expect(documentStub.createElement).toHaveBeenCalledTimes(2)
  })
})
