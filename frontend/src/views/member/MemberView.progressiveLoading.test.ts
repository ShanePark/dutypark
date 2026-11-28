import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h, nextTick } from 'vue'
import { findHostNode, findHostNodes, hostText, mountHost, type HostNode } from '@/test/hostRenderer'

const mocks = vi.hoisted(() => ({
  getMyInfo: vi.fn(),
  getFamilyMembers: vi.fn(),
  getManagers: vi.fn(),
  getManagedMembers: vi.fn(),
  getRefreshTokens: vi.fn(),
  showError: vi.fn(),
  dutyPatternSetups: 0,
}))

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
vi.mock('@/stores/auth', () => ({ useAuthStore: () => ({ user: { id: 1 }, isImpersonating: false }) }))
vi.mock('@/stores/contentFilter', () => ({ useContentFilterStore: () => ({ isBlocked: vi.fn() }) }))
vi.mock('@/api/member', () => ({
  memberApi: {
    getMyInfo: mocks.getMyInfo,
    getFamilyMembers: mocks.getFamilyMembers,
    getManagers: mocks.getManagers,
    getManagedMembers: mocks.getManagedMembers,
  },
  refreshTokenApi: { getRefreshTokens: mocks.getRefreshTokens },
  getVisibleSocialAccountProviders: () => [],
  canUnlinkSocialAccount: () => false,
  getSocialAccountUnlinkErrorKey: vi.fn(),
  refreshAppleLinkMemberState: vi.fn(),
}))
vi.mock('@/api/auth', () => ({ authApi: {} }))
vi.mock('@/composables/useSwal', () => ({
  useSwal: () => ({
    showError: mocks.showError,
    showSuccess: vi.fn(),
    showWarning: vi.fn(),
    showInfo: vi.fn(),
    confirm: vi.fn(),
    confirmDelete: vi.fn(),
    toastSuccess: vi.fn(),
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
vi.mock('@/components/common/BaseModal.vue', () => empty)
vi.mock('@/components/common/PageHeader.vue', () => empty)
vi.mock('@/components/common/ProfilePhotoUploader.vue', () => empty)
vi.mock('@/components/common/ProfileAvatar.vue', () => empty)
vi.mock('@/components/common/SessionTokenList.vue', () => ({
  default: defineComponent({
    props: ['tokens', 'loading'],
    setup: (props) => () => h('session-list', {
      loading: props.loading,
      count: (props.tokens as unknown[]).length,
    }),
  }),
}))
vi.mock('@/components/member/DutyPatternCard.vue', () => ({
  default: defineComponent({
    setup: () => {
      mocks.dutyPatternSetups++
      return () => h('duty-pattern-card')
    },
  }),
}))
vi.mock('@/components/member/CalendarVisibilityCard.vue', () => empty)
vi.mock('@/components/member/AiScheduleConsentCard.vue', () => empty)
vi.mock('@/components/member/SocialAccountConnectionModal.vue', () => empty)
vi.mock('@/components/member/AccountDeletionModal.vue', () => empty)

const { default: MemberView } = await import('./MemberView.vue')

const member = { id: 1, name: 'Tester', email: 'tester@example.com', team: null, calendarVisibility: 'FRIENDS' }

function deferred<T>() {
  let resolve!: (value: T) => void
  let reject!: (error: unknown) => void
  const promise = new Promise<T>((res, rej) => {
    resolve = res
    reject = rej
  })
  return { promise, resolve, reject }
}

async function flush() {
  for (let index = 0; index < 10; index++) {
    await Promise.resolve()
    await nextTick()
  }
}

function sectionLoaders(root: HostNode, testId: string) {
  return findHostNodes(root, (node) => node.props['data-testid'] === testId)
}

function sessionList(root: HostNode) {
  return findHostNode(root, (node) => node.type === 'session-list')
}

describe('MemberView progressive loading', () => {
  const apps: ReturnType<typeof mountHost>['app'][] = []

  beforeEach(() => {
    vi.clearAllMocks()
    mocks.dutyPatternSetups = 0
    vi.spyOn(console, 'error').mockImplementation(() => {})
    mocks.getMyInfo.mockResolvedValue({ data: { ...member } })
    mocks.getFamilyMembers.mockResolvedValue({ data: [] })
    mocks.getManagers.mockResolvedValue({ data: [] })
    mocks.getManagedMembers.mockResolvedValue({ data: [] })
    mocks.getRefreshTokens.mockResolvedValue({ data: [] })
  })

  afterEach(() => {
    apps.splice(0).forEach((app) => app.unmount())
    vi.restoreAllMocks()
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

  it('starts every request at once but blocks the page only on member info', async () => {
    const myInfo = deferred<{ data: typeof member }>()
    mocks.getMyInfo.mockReturnValue(myInfo.promise)

    const root = await mountMember()

    expect(mocks.getMyInfo).toHaveBeenCalledTimes(1)
    expect(mocks.getFamilyMembers).toHaveBeenCalledTimes(1)
    expect(mocks.getManagers).toHaveBeenCalledTimes(1)
    expect(mocks.getManagedMembers).toHaveBeenCalledTimes(1)
    expect(mocks.getRefreshTokens).toHaveBeenCalledTimes(1)
    expect(hostText(root)).not.toContain('member.profile.sectionTitle')
    expect(mocks.dutyPatternSetups).toBe(0)

    myInfo.resolve({ data: { ...member } })
    await flush()

    expect(hostText(root)).toContain('Tester')
    expect(mocks.dutyPatternSetups).toBe(1)
  })

  it('renders the profile and section loaders while the other sections are still loading', async () => {
    const tokens = deferred<{ data: unknown[] }>()
    const family = deferred<{ data: unknown[] }>()
    const managed = deferred<{ data: unknown[] }>()
    mocks.getRefreshTokens.mockReturnValue(tokens.promise)
    mocks.getFamilyMembers.mockReturnValue(family.promise)
    mocks.getManagedMembers.mockReturnValue(managed.promise)

    const root = await mountMember()

    const text = hostText(root)
    expect(text).toContain('Tester')
    expect(text).toContain('member.manager.sectionTitle')
    expect(text).toContain('member.sessions.sectionTitle')
    // No misleading empty state before the managers are known.
    expect(text).not.toContain('member.manager.empty')
    expect(sectionLoaders(root, 'member-managers-loading')).toHaveLength(1)
    expect(sectionLoaders(root, 'member-managed-loading')).toHaveLength(1)
    expect(sessionList(root)?.props.loading).toBe(true)

    family.resolve({ data: [{ id: 2, name: 'Family' }] })
    managed.resolve({ data: [{ id: 3, name: 'Helper', team: null }] })
    tokens.resolve({ data: [{ id: 'a', isCurrentLogin: true }] })
    await flush()

    expect(sectionLoaders(root, 'member-managers-loading')).toHaveLength(0)
    expect(sectionLoaders(root, 'member-managed-loading')).toHaveLength(0)
    expect(hostText(root)).toContain('member.manager.empty')
    expect(hostText(root)).toContain('Helper')
    expect(sessionList(root)?.props).toMatchObject({ loading: false, count: 1 })
  })

  it('keeps the rest of the page when a secondary section fails', async () => {
    mocks.getRefreshTokens.mockRejectedValue(new Error('tokens'))
    mocks.getManagers.mockRejectedValue(new Error('managers'))
    mocks.getManagedMembers.mockRejectedValue(new Error('managed'))

    const root = await mountMember()

    expect(hostText(root)).toContain('Tester')
    expect(sectionLoaders(root, 'member-managers-loading')).toHaveLength(0)
    expect(sectionLoaders(root, 'member-managed-loading')).toHaveLength(0)
    expect(sessionList(root)?.props.loading).toBe(false)
    expect(mocks.showError).not.toHaveBeenCalled()
  })

  it('still renders the page when member info fails', async () => {
    mocks.getMyInfo.mockRejectedValue(new Error('me'))

    const root = await mountMember()

    expect(mocks.showError).toHaveBeenCalledExactlyOnceWith('member.errors.loadFailed')
    expect(hostText(root)).toContain('member.profile.sectionTitle')
    expect(hostText(root)).toContain('member.sessions.sectionTitle')
  })
})
