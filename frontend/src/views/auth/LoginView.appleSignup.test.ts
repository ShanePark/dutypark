import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, nextTick, ref } from 'vue'
import { findHostNode, mountHost, triggerHost } from '@/test/hostRenderer'

const mocks = vi.hoisted(() => ({
  appleLogin: vi.fn(),
  push: vi.fn(),
  replace: vi.fn(),
  checkAuth: vi.fn(),
}))

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: (key: string) => key }) }))
vi.mock('vue-router', () => ({
  useRoute: () => ({ query: {} }),
  useRouter: () => ({ push: mocks.push, replace: mocks.replace }),
}))
vi.mock('@/stores/auth', () => ({ useAuthStore: () => ({ checkAuth: mocks.checkAuth, login: vi.fn() }) }))
vi.mock('@/composables/useKakao', () => ({ useKakao: () => ({ initKakao: vi.fn(), kakaoLogin: vi.fn() }) }))
vi.mock('@/composables/useNaver', () => ({ useNaver: () => ({ isNaverEnabled: false, naverLogin: vi.fn() }) }))
vi.mock('@/composables/useApple', () => ({
  AppleSignInError: class extends Error {},
  isAppleSignInCancellation: () => false,
  useApple: () => ({
    isAppleConfigured: true,
    isAppleReady: ref(true),
    preloadAppleSdk: async () => undefined,
    appleLogin: mocks.appleLogin,
  }),
}))
vi.mock('@/utils/loginError', () => ({ resolveLoginErrorMessage: () => 'error' }))
vi.mock('@/utils/resolveApiError', () => ({ getApiErrorDetail: () => undefined }))
vi.mock('@/components/common/PolicyModal.vue', () => ({
  default: defineComponent({ setup: () => () => null }),
}))

const { default: LoginView } = await import('./LoginView.vue')

async function flush() {
  for (let index = 0; index < 6; index++) {
    await Promise.resolve()
    await nextTick()
  }
}

describe('LoginView Apple signup navigation', () => {
  const apps: ReturnType<typeof mountHost>['app'][] = []

  beforeEach(() => {
    vi.clearAllMocks()
    vi.stubGlobal('localStorage', { getItem: () => null, setItem: vi.fn(), removeItem: vi.fn() })
    mocks.push.mockResolvedValue(undefined)
  })

  afterEach(() => {
    apps.splice(0).forEach((app) => app.unmount())
    vi.unstubAllGlobals()
  })

  async function clickAppleLogin() {
    const mounted = mountHost(LoginView, {}, [{
      install(app: ReturnType<typeof mountHost>['app']) {
        app.component('RouterLink', { setup: () => () => null })
      },
    }])
    apps.push(mounted.app)
    await flush()
    const button = findHostNode(mounted.root, (node) => (
      node.type === 'button' && node.props['aria-label'] === 'auth.login.social.apple'
    ))!
    triggerHost(button, 'onClick')
    await flush()
  }

  it('carries the formatted Apple name to the signup form through router state, not the URL', async () => {
    mocks.appleLogin.mockResolvedValue({
      signupRequired: true,
      signupUuid: 'signup-uuid',
      expiresIn: null,
      reauthProof: null,
      appleUserName: { firstName: '길동', lastName: '홍' },
    })

    await clickAppleLogin()

    expect(mocks.push).toHaveBeenCalledExactlyOnceWith({
      path: '/auth/sso-signup',
      query: { uuid: 'signup-uuid' },
      state: { ssoSignupName: '홍길동' },
    })
  })

  it('navigates without a carried name when Apple shared none', async () => {
    mocks.appleLogin.mockResolvedValue({
      signupRequired: true,
      signupUuid: 'signup-uuid',
      expiresIn: null,
      reauthProof: null,
      appleUserName: null,
    })

    await clickAppleLogin()

    expect(mocks.push).toHaveBeenCalledExactlyOnceWith({
      path: '/auth/sso-signup',
      query: { uuid: 'signup-uuid' },
      state: undefined,
    })
  })
})
