import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h, nextTick, reactive } from 'vue'
import { findHostNode, hostText, mountHost, triggerHost, type HostNode } from '@/test/hostRenderer'

const mocks = vi.hoisted(() => ({
  getMyInfo: vi.fn(),
  updateMyName: vi.fn(),
  setUser: vi.fn(),
  showError: vi.fn(),
  toastSuccess: vi.fn(),
  isBlocked: vi.fn(),
}))
const authState = reactive({
  user: { id: 1, name: 'Tester', email: null, teamId: null, team: null, isAdmin: false, isImpersonating: false, originalMemberId: null },
  isImpersonating: false,
  setUser: mocks.setUser,
})

// The manager selector needs DOM <option> support that the host renderer lacks.
vi.mock('vue', async (importOriginal) => ({
  ...await importOriginal<typeof import('vue')>(),
  vModelSelect: {},
}))
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: (key: string) => key }) }))
vi.mock('@/i18n', () => ({ translateGlobal: (key: string) => key }))
vi.mock('vue-router', () => ({
  useRoute: () => ({ query: {} }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}))
vi.mock('@/stores/auth', () => ({ useAuthStore: () => authState }))
vi.mock('@/stores/contentFilter', () => ({ useContentFilterStore: () => ({ isBlocked: mocks.isBlocked }) }))
vi.mock('@/api/member', () => ({
  memberApi: {
    getMyInfo: mocks.getMyInfo,
    updateMyName: mocks.updateMyName,
    getFamilyMembers: async () => ({ data: [] }),
    getManagers: async () => ({ data: [] }),
    getManagedMembers: async () => ({ data: [] }),
  },
  refreshTokenApi: { getRefreshTokens: async () => ({ data: [] }) },
  getVisibleSocialAccountProviders: () => [],
  canUnlinkSocialAccount: () => false,
  getSocialAccountUnlinkErrorKey: vi.fn(),
  refreshAppleLinkMemberState: vi.fn(),
}))
vi.mock('@/api/auth', () => ({ authApi: {} }))
vi.mock('@/utils/resolveApiError', () => ({
  resolveApiErrorMessage: (_error: unknown, options: { fallbackKey: string }) => options.fallbackKey,
}))
vi.mock('@/composables/useSwal', () => ({
  useSwal: () => ({
    showError: mocks.showError,
    showSuccess: vi.fn(),
    showWarning: vi.fn(),
    showInfo: vi.fn(),
    confirm: vi.fn(),
    confirmDelete: vi.fn(),
    toastSuccess: mocks.toastSuccess,
  }),
}))
vi.mock('@/composables/useLogout', () => ({ useLogout: () => ({ logoutAndRedirect: vi.fn() }) }))
vi.mock('@/composables/useKakao', () => ({ useKakao: () => ({ kakaoLink: vi.fn() }) }))
vi.mock('@/composables/useNaver', () => ({ useNaver: () => ({ isNaverEnabled: false, naverLink: vi.fn() }) }))
vi.mock('@/composables/useApple', () => ({
  AppleSignInError: class extends Error {},
  isAppleSignInCancellation: () => false,
  useApple: () => ({ isAppleConfigured: false, isAppleReady: { value: false } }),
}))

const empty = { default: defineComponent({ setup: () => () => null }) }
vi.mock('@/components/common/BaseModal.vue', () => ({
  default: defineComponent({
    props: ['isOpen'],
    emits: ['close'],
    setup: (props, { slots }) => () => h('base-modal', { open: props.isOpen }, props.isOpen ? slots.default?.() : []),
  }),
}))
vi.mock('@/components/common/PageHeader.vue', () => empty)
vi.mock('@/components/common/SessionTokenList.vue', () => empty)
vi.mock('@/components/common/ProfilePhotoUploader.vue', () => empty)
vi.mock('@/components/common/ProfileAvatar.vue', () => empty)
vi.mock('@/components/member/DutyPatternCard.vue', () => empty)
vi.mock('@/components/member/CalendarVisibilityCard.vue', () => empty)
vi.mock('@/components/member/AiScheduleConsentCard.vue', () => empty)
vi.mock('@/components/member/SocialAccountConnectionModal.vue', () => empty)
vi.mock('@/components/member/AccountDeletionModal.vue', () => empty)

const { default: MemberView } = await import('./MemberView.vue')

const member = {
  id: 1,
  name: 'Tester',
  email: 'tester@example.com',
  teamId: null,
  team: null,
  calendarVisibility: 'FRIENDS',
  kakaoId: null,
  naverId: null,
  appleId: null,
  hasPassword: false,
}

async function flush() {
  for (let index = 0; index < 10; index++) {
    await Promise.resolve()
    await nextTick()
  }
}

function button(root: HostNode, predicate: (node: HostNode) => boolean) {
  return findHostNode(root, (node) => node.type === 'button' && predicate(node))
}

describe('MemberView name change', () => {
  const apps: ReturnType<typeof mountHost>['app'][] = []

  beforeEach(() => {
    vi.clearAllMocks()
    authState.user.name = 'Tester'
    mocks.getMyInfo.mockResolvedValue({ data: { ...member } })
    mocks.isBlocked.mockReturnValue(false)
  })

  afterEach(() => {
    apps.splice(0).forEach((app) => app.unmount())
  })

  async function mountMember() {
    const mounted = mountHost(MemberView, {}, [{
      install(app: ReturnType<typeof mountHost>['app']) {
        app.component('RouterLink', defineComponent({ setup: () => () => null }))
      },
    }])
    apps.push(mounted.app)
    await flush()
    return mounted.root
  }

  async function openNameModal(root: HostNode) {
    const edit = button(root, (node) => node.props['aria-label'] === 'member.profile.nameChange.action')
    expect(edit).not.toBeNull()
    triggerHost(edit!, 'onClick')
    await flush()
    return findHostNode(root, (node) => node.type === 'input' && node.props.id === 'member-name-input')!
  }

  function saveButton(root: HostNode) {
    return button(root, (node) => hostText(node).trim() === 'member.profile.nameChange.submit')!
  }

  function type(input: HostNode, value: string) {
    triggerHost(input, 'onInput', { target: { value } })
  }

  it('opens an editor pre-filled with the current name and disables saving until it changes', async () => {
    const root = await mountMember()
    const input = await openNameModal(root)

    expect(input.value).toBe('Tester')
    expect(input.props.maxlength).toBe('10')
    expect(saveButton(root).props.disabled).toBe(true)

    type(input, '   ')
    await flush()
    expect(saveButton(root).props.disabled).toBe(true)

    type(input, ' 새이름 ')
    await flush()
    expect(saveButton(root).props.disabled).toBe(false)
  })

  it('saves the trimmed name and reflects it in the profile and auth store immediately', async () => {
    mocks.updateMyName.mockResolvedValue({ data: { ...member, name: '새이름' } })
    const root = await mountMember()
    const input = await openNameModal(root)

    type(input, ' 새이름 ')
    await flush()
    triggerHost(saveButton(root), 'onClick')
    await flush()

    expect(mocks.updateMyName).toHaveBeenCalledExactlyOnceWith('새이름')
    expect(mocks.setUser).toHaveBeenCalledExactlyOnceWith(expect.objectContaining({ id: 1, name: '새이름' }))
    expect(mocks.toastSuccess).toHaveBeenCalledExactlyOnceWith('member.profile.nameChange.success')
    expect(findHostNode(root, (node) => node.type === 'input' && node.props.id === 'member-name-input')).toBeNull()
    expect(hostText(root)).toContain('새이름')
  })

  it('keeps the editor open and shows the API error when saving fails', async () => {
    mocks.updateMyName.mockRejectedValue(new Error('400'))
    vi.spyOn(console, 'error').mockImplementation(() => {})
    const root = await mountMember()
    const input = await openNameModal(root)

    type(input, 'Other')
    await flush()
    triggerHost(saveButton(root), 'onClick')
    await flush()

    expect(mocks.showError).toHaveBeenCalledExactlyOnceWith('member.profile.nameChange.failed')
    expect(mocks.setUser).not.toHaveBeenCalled()
    expect(findHostNode(root, (node) => node.type === 'input' && node.props.id === 'member-name-input')).not.toBeNull()
  })

  it('rejects a name blocked by the content filter without calling the API', async () => {
    mocks.isBlocked.mockReturnValue(true)
    const root = await mountMember()
    const input = await openNameModal(root)

    type(input, 'Blocked')
    await flush()
    triggerHost(saveButton(root), 'onClick')
    await flush()

    expect(mocks.showError).toHaveBeenCalledExactlyOnceWith('contentFilter.blocked')
    expect(mocks.updateMyName).not.toHaveBeenCalled()
  })
})
