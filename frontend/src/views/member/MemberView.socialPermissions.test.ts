import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h, nextTick, reactive, ref } from 'vue'
import { findHostNode, findHostNodes, hostText, mountHost, triggerHost, type HostNode } from '@/test/hostRenderer'

const mocks = vi.hoisted(() => ({
  getMyInfo: vi.fn(), confirm: vi.fn(), confirmDelete: vi.fn(), unlink: vi.fn(),
  kakaoLink: vi.fn(), naverLink: vi.fn(), appleLink: vi.fn(), preloadAppleSdk: vi.fn(),
  showError: vi.fn(), changePassword: vi.fn(),
}))
const authState = reactive({ user: { id: 1 }, isImpersonating: false })
const appleReady = ref(true)
// The host renderer emits model updates explicitly without DOM directives.
vi.mock('vue', async original => ({ ...await original<typeof import('vue')>(), vModelSelect: {}, vModelText: {} }))
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: (key: string, args?: { provider?: string }) => args?.provider ? `${key}:${args.provider}` : key }) }))
vi.mock('@/i18n', () => ({ translateGlobal: (key: string) => key }))
vi.mock('vue-router', () => ({ useRoute: () => ({ query: {} }), useRouter: () => ({ push: vi.fn(), replace: vi.fn() }) }))
vi.mock('@/stores/auth', () => ({ useAuthStore: () => authState }))
vi.mock('@/stores/contentFilter', () => ({ useContentFilterStore: () => ({ isBlocked: () => false }) }))
vi.mock('@/api/member', () => ({
  memberApi: {
    getMyInfo: mocks.getMyInfo, getFamilyMembers: async () => ({ data: [] }),
    getManagers: async () => ({ data: [] }), getManagedMembers: async () => ({ data: [] }),
    unlinkSocialAccount: mocks.unlink,
  },
  refreshTokenApi: { getRefreshTokens: async () => ({ data: [] }) },
  getVisibleSocialAccountProviders: () => ['KAKAO', 'NAVER', 'APPLE'],
  canUnlinkSocialAccount: () => true, getSocialAccountUnlinkErrorKey: () => 'unlink.error',
  refreshAppleLinkMemberState: vi.fn(),
}))
vi.mock('@/api/auth', () => ({ authApi: { changePassword: mocks.changePassword } }))
vi.mock('@/composables/useSwal', () => ({ useSwal: () => ({
  confirm: mocks.confirm, confirmDelete: mocks.confirmDelete, showError: mocks.showError,
  showSuccess: vi.fn(), showWarning: vi.fn(), showInfo: vi.fn(), toastSuccess: vi.fn(),
}) }))
vi.mock('@/composables/useLogout', () => ({ useLogout: () => ({ logoutAndRedirect: vi.fn() }) }))
vi.mock('@/composables/useKakao', () => ({ useKakao: () => ({ kakaoLink: mocks.kakaoLink }) }))
vi.mock('@/composables/useNaver', () => ({ useNaver: () => ({ isNaverEnabled: true, naverLink: mocks.naverLink }) }))
vi.mock('@/composables/useApple', () => ({
  AppleSignInError: class extends Error {}, isAppleSignInCancellation: () => false,
  useApple: () => ({ isAppleConfigured: true, isAppleReady: appleReady, preloadAppleSdk: mocks.preloadAppleSdk, appleLink: mocks.appleLink }),
}))
const empty = { default: defineComponent({ setup: () => () => null }) }
vi.mock('@/components/common/BaseModal.vue', () => ({ default: defineComponent({
  props: ['isOpen'], setup: (props, { slots }) => () => h('base-modal', { open: props.isOpen }, props.isOpen ? slots.default?.() : []),
}) }))
vi.mock('@/components/common/PageHeader.vue', () => empty)
vi.mock('@/components/common/SessionTokenList.vue', () => empty)
vi.mock('@/components/common/ProfilePhotoUploader.vue', () => empty)
vi.mock('@/components/common/ProfileAvatar.vue', () => empty)
vi.mock('@/components/member/DutyPatternCard.vue', () => empty)
vi.mock('@/components/member/AccountDeletionModal.vue', () => ({ default: defineComponent({
  props: ['isOpen'], setup: props => () => h('account-deletion', { open: props.isOpen }),
}) }))
vi.mock('@/components/member/SocialAccountConnectionModal.vue', () => ({ default: defineComponent({
  props: ['isOpen', 'canUnlink'], emits: ['unlink'],
  setup: (props, { emit }) => () => h('social-settings', {
    canUnlink: props.canUnlink, onUnlink: () => emit('unlink'),
  }),
}) }))
const { default: MemberView } = await import('./MemberView.vue')

const apps: Array<ReturnType<typeof mountHost>['app']> = []
async function settle() { for (let i = 0; i < 15; i++) await Promise.resolve(); await nextTick() }
async function mountMember(impersonating: boolean) {
  authState.isImpersonating = impersonating
  const mounted = mountHost(MemberView, {}, [{ install(app: ReturnType<typeof mountHost>['app']) {
    app.component('RouterLink', defineComponent({ setup: () => () => null }))
  } }])
  apps.push(mounted.app)
  await settle()
  return mounted.root
}
function manageButton(root: HostNode) {
  return findHostNode(root, node => node.type === 'button' && String(node.props['aria-label']).startsWith('member.sso.unlink.manageAction'))!
}
function connectButtons(root: HostNode) {
  return findHostNodes(root, node => node.type === 'button' && hostText(node).trim() === 'member.sso.connect')
}

beforeEach(() => {
  vi.clearAllMocks()
  authState.isImpersonating = false
  appleReady.value = true
  mocks.getMyInfo.mockResolvedValue({ data: { id: 1, name: 'Tester', email: 'tester@example.com', hasPassword: true, kakaoId: 'kakao', naverId: null, appleId: null } })
  mocks.preloadAppleSdk.mockResolvedValue(undefined)
  mocks.confirm.mockResolvedValue(false)
  mocks.confirmDelete.mockResolvedValue(false)
  vi.stubGlobal('HTMLElement', class {})
})
afterEach(() => { apps.splice(0).forEach(app => app.unmount()); vi.unstubAllGlobals() })

describe('social account permissions', () => {
  it('omits social settings and account management entirely while impersonating', async () => {
    const root = await mountMember(true)
    for (const key of ['member.sso.sectionTitle', 'member.sso.impersonationNotice', 'member.account.sectionTitle', 'member.account.changePassword', 'member.account.deleteAccount']) {
      expect(hostText(root)).not.toContain(key)
    }
    expect(manageButton(root) === null).toBe(true)
    expect(connectButtons(root)).toHaveLength(0)
    expect(findHostNode(root, node => node.type === 'account-deletion') === null).toBe(true)
    expect(mocks.preloadAppleSdk).not.toHaveBeenCalled()
  })

  it('guards stale click handlers before dialogs, provider calls or settings are opened', async () => {
    const root = await mountMember(false)
    const manage = manageButton(root)
    const connect = connectButtons(root)
    const password = findHostNode(root, node => node.type === 'button' && hostText(node).trim() === 'member.account.changePassword')!
    const deletion = findHostNode(root, node => node.type === 'button' && hostText(node).trim() === 'member.account.deleteAccount')!
    authState.isImpersonating = true
    await settle()
    triggerHost(manage, 'onClick', { currentTarget: null })
    connect.forEach(button => triggerHost(button, 'onClick'))
    triggerHost(password, 'onClick')
    triggerHost(deletion, 'onClick')
    await settle()
    expect(findHostNode(root, node => node.type === 'social-settings') === null).toBe(true)
    expect(hostText(root)).not.toContain('member.password.modalTitle')
    expect(mocks.confirm).not.toHaveBeenCalled()
    expect(mocks.confirmDelete).not.toHaveBeenCalled()
    expect(mocks.naverLink).not.toHaveBeenCalled()
    expect(mocks.appleLink).not.toHaveBeenCalled()
    expect(mocks.unlink).not.toHaveBeenCalled()
    expect(mocks.changePassword).not.toHaveBeenCalled()
    expect(mocks.showError).not.toHaveBeenCalled()
  })

  it.each([
    [true, null, false], [true, '', false], [true, '  ', false],
    [false, 'tester@example.com', false], [true, ' tester@example.com ', true],
  ])('shows password change only for password and email capability (%s, %s)', async (hasPassword, email, expected) => {
    mocks.getMyInfo.mockResolvedValueOnce({ data: { id: 1, name: 'Tester', hasPassword, email } })
    const root = await mountMember(false)
    expect(findHostNode(root, node => node.type === 'button' && hostText(node).trim() === 'member.account.changePassword') !== null).toBe(expected)
  })

  it('closes password settings and blocks a stale save when impersonation begins', async () => {
    const root = await mountMember(false)
    triggerHost(findHostNode(root, node => node.type === 'button' && hostText(node).trim() === 'member.account.changePassword')!, 'onClick')
    await settle()
    const fields = findHostNodes(root, node => node.type === 'input' && node.props.type === 'password')
    ;['current-password', 'new-password', 'new-password'].forEach((value, index) => triggerHost(fields[index]!, 'onUpdate:modelValue', value))
    await settle()
    const save = findHostNode(root, node => node.type === 'button' && hostText(node).trim() === 'member.password.submit')!
    authState.isImpersonating = true
    await settle()
    expect(hostText(root)).not.toContain('member.password.modalTitle')
    triggerHost(save, 'onClick')
    await settle()
    expect(mocks.changePassword).not.toHaveBeenCalled()
  })

  it('closes account deletion when impersonation begins', async () => {
    const root = await mountMember(false)
    triggerHost(findHostNode(root, node => node.type === 'button' && hostText(node).trim() === 'member.account.deleteAccount')!, 'onClick')
    await settle()
    expect(findHostNode(root, node => node.type === 'account-deletion')?.props.open).toBe(true)
    authState.isImpersonating = true
    await settle()
    expect(findHostNode(root, node => node.type === 'account-deletion') === null).toBe(true)
  })

  it('guards unlink if impersonation begins after settings were opened', async () => {
    const root = await mountMember(false)
    triggerHost(manageButton(root), 'onClick', { currentTarget: null })
    await settle()
    const settings = findHostNode(root, node => node.type === 'social-settings')!
    expect(settings).not.toBeNull()
    authState.isImpersonating = true
    await settle()
    expect(findHostNode(root, node => node.type === 'social-settings') === null).toBe(true)
    triggerHost(settings, 'onUnlink')
    await settle()
    expect(mocks.confirmDelete).not.toHaveBeenCalled()
    expect(mocks.unlink).not.toHaveBeenCalled()
  })

  it('blocks connection if impersonation begins while confirmation is pending', async () => {
    let confirm!: (confirmed: boolean) => void
    mocks.confirm.mockReturnValue(new Promise<boolean>(resolve => { confirm = resolve }))
    const root = await mountMember(false)
    triggerHost(connectButtons(root)[0]!, 'onClick')
    await settle()
    authState.isImpersonating = true
    confirm(true)
    await settle()
    expect(mocks.naverLink).not.toHaveBeenCalled()
  })

  it('blocks unlink if impersonation begins while confirmation is pending', async () => {
    let confirm!: (confirmed: boolean) => void
    mocks.confirmDelete.mockReturnValue(new Promise<boolean>(resolve => { confirm = resolve }))
    const root = await mountMember(false)
    triggerHost(manageButton(root), 'onClick', { currentTarget: null })
    await settle()
    triggerHost(findHostNode(root, node => node.type === 'social-settings')!, 'onUnlink')
    await settle()
    authState.isImpersonating = true
    confirm(true)
    await settle()
    expect(mocks.unlink).not.toHaveBeenCalled()
  })

  it('hides and guards Apple SDK retry after impersonation begins', async () => {
    mocks.preloadAppleSdk.mockRejectedValueOnce(new Error('unavailable'))
    const root = await mountMember(false)
    const retry = findHostNode(root, node => node.type === 'button' && hostText(node).trim() === 'member.sso.apple.retry')!
    expect(retry).not.toBeNull()
    authState.isImpersonating = true
    await settle()
    expect(findHostNode(root, node => node.type === 'button' && hostText(node).trim() === 'member.sso.apple.retry') === null).toBe(true)
    triggerHost(retry, 'onClick')
    await settle()
    expect(mocks.preloadAppleSdk).toHaveBeenCalledOnce()
  })

  it('retains ordinary account controls and Apple preparation', async () => {
    const root = await mountMember(false)
    expect(hostText(root)).not.toContain('member.sso.impersonationNotice')
    expect(manageButton(root).props.disabled).toBe(false)
    connectButtons(root).forEach(button => expect(button.props.disabled).toBe(false))
    expect(mocks.preloadAppleSdk).toHaveBeenCalledOnce()
    triggerHost(connectButtons(root)[0]!, 'onClick')
    await settle()
    expect(mocks.confirm).toHaveBeenCalledOnce()
  })
})
