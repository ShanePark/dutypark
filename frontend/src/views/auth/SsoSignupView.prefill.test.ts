import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, nextTick } from 'vue'
import { findHostNode, hostText, mountHost, triggerHost, type HostNode } from '@/test/hostRenderer'
import { MEMBER_NAME_MAX_LENGTH } from '@/utils/signupName'

const mocks = vi.hoisted(() => ({
  getCurrentPolicies: vi.fn(),
  ssoSignup: vi.fn(),
  checkAuth: vi.fn(),
  replace: vi.fn(),
  showError: vi.fn(),
}))

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key: string) => (key === 'auth.ssoSignup.username.defaultPrefix' ? '사용자' : key),
  }),
}))
vi.mock('vue-router', () => ({
  useRoute: () => ({ query: { uuid: 'signup-uuid' } }),
  useRouter: () => ({ replace: mocks.replace, push: vi.fn() }),
}))
vi.mock('@/api/auth', () => ({ authApi: { ssoSignup: mocks.ssoSignup } }))
vi.mock('@/api/policy', () => ({ policyApi: { getCurrentPolicies: mocks.getCurrentPolicies } }))
vi.mock('@/stores/auth', () => ({ useAuthStore: () => ({ checkAuth: mocks.checkAuth }) }))
vi.mock('@/stores/contentFilter', () => ({ useContentFilterStore: () => ({ isBlocked: () => false }) }))
vi.mock('@/composables/useSwal', () => ({ useSwal: () => ({ showError: mocks.showError }) }))
vi.mock('@/utils/policyMarkdown', () => ({ renderPolicyMarkdown: (content: string) => content }))
vi.mock('@/utils/resolveApiError', () => ({ resolveApiErrorMessage: (_error: unknown, options: { fallbackKey: string }) => options.fallbackKey }))
vi.mock('@/components/common/PolicyModal.vue', () => ({
  default: defineComponent({ setup: () => () => null }),
}))

const { default: SsoSignupView } = await import('./SsoSignupView.vue')

const policies = {
  terms: { version: 't1', content: 'terms' },
  privacy: { version: 'p1', content: 'privacy' },
}

async function flush() {
  for (let index = 0; index < 6; index++) {
    await Promise.resolve()
    await nextTick()
  }
}

describe('SsoSignupView name pre-fill', () => {
  const apps: ReturnType<typeof mountHost>['app'][] = []
  let historyState: unknown = null

  beforeEach(() => {
    vi.clearAllMocks()
    historyState = null
    vi.stubGlobal('window', { history: { get state() { return historyState } } })
    mocks.getCurrentPolicies.mockResolvedValue(policies)
    mocks.ssoSignup.mockResolvedValue({ expiresIn: 3600 })
    mocks.checkAuth.mockResolvedValue(undefined)
    mocks.replace.mockResolvedValue(undefined)
  })

  afterEach(() => {
    apps.splice(0).forEach((app) => app.unmount())
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  async function mountSignup() {
    const mounted = mountHost(SsoSignupView)
    apps.push(mounted.app)
    await flush()
    return mounted.root
  }

  function nameInput(root: HostNode) {
    return findHostNode(root, (node) => node.type === 'input' && node.props.id === 'username')!
  }

  function check(root: HostNode, id: string) {
    const checkbox = findHostNode(root, (node) => node.type === 'input' && node.props.id === id)!
    ;(checkbox as HostNode & { checked?: boolean }).checked = true
    triggerHost(checkbox, 'onChange', { target: checkbox })
  }

  it('pre-fills a localized default name with four random digits when Apple shared no name', async () => {
    vi.spyOn(Math, 'random').mockReturnValue(0.0482)

    const root = await mountSignup()

    expect(nameInput(root).value).toBe('사용자0482')
    expect(hostText(root)).toContain('(7/20)')
    expect(nameInput(root).props.maxlength).toBe(MEMBER_NAME_MAX_LENGTH)
    expect(hostText(root)).not.toContain('auth.ssoSignup.username.helper.emptyIdle')
  })

  it('pre-fills the Apple name carried in the navigation state', async () => {
    historyState = { ssoSignupName: '홍길동' }

    const root = await mountSignup()

    expect(nameInput(root).value).toBe('홍길동')
  })

  it('ignores a blank carried name and uses the default instead', async () => {
    historyState = { ssoSignupName: '   ' }
    vi.spyOn(Math, 'random').mockReturnValue(0.9)

    const root = await mountSignup()

    expect(nameInput(root).value).toBe('사용자9000')
  })

  it('keeps the field editable without regenerating the default while typing', async () => {
    const random = vi.spyOn(Math, 'random').mockReturnValue(0.1234)
    const root = await mountSignup()
    const input = nameInput(root)

    triggerHost(input, 'onInput', { target: { value: '새이름' } })
    await flush()

    expect(input.value).toBe('새이름')
    expect(input.props.disabled).toBe(false)
    expect(random).toHaveBeenCalledTimes(1)
  })

  it('does not flag required items before the user interacts with the pre-filled form', async () => {
    const root = await mountSignup()

    const hint = findHostNode(root, (node) => node.type === 'p' && hostText(node).includes('auth.ssoSignup.hints.requiredPrefix'))!
    expect(String(hint.props.class)).toContain('text-dp-text-muted')
  })

  it('accepts a 20-character name and rejects a 21-character one', async () => {
    const root = await mountSignup()
    const input = nameInput(root)
    check(root, 'termAgree')
    check(root, 'privacyAgree')

    triggerHost(input, 'onInput', { target: { value: 'Christopher Johnsons' } })
    await flush()
    const submit = findHostNode(root, (node) => node.type === 'button' && node.props.type === 'submit')!
    expect(submit.props.disabled).toBe(false)

    triggerHost(input, 'onInput', { target: { value: 'Christopher Johnsonss' } })
    await flush()
    expect(submit.props.disabled).toBe(true)
  })

  it('submits the pre-filled name without the user typing anything', async () => {
    historyState = { ssoSignupName: 'John Kim' }
    const root = await mountSignup()

    check(root, 'termAgree')
    check(root, 'privacyAgree')
    await flush()
    const form = findHostNode(root, (node) => node.type === 'form')!
    triggerHost(form, 'onSubmit', { preventDefault: vi.fn() })
    await flush()

    expect(mocks.ssoSignup).toHaveBeenCalledWith(expect.objectContaining({
      uuid: 'signup-uuid',
      username: 'John Kim',
      termAgree: true,
      privacyAgree: true,
    }))
  })
})
