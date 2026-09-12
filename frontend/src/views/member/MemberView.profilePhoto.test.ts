import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { nextTick } from 'vue'
import { findHostNode, findHostNodes, mountHost, triggerHost, type HostNode } from '@/test/hostRenderer'

const mocks = vi.hoisted(() => ({
  getMyInfo: vi.fn(),
  getFamilyMembers: vi.fn(),
  getManagers: vi.fn(),
  getManagedMembers: vi.fn(),
  getRefreshTokens: vi.fn(),
  updateProfilePhoto: vi.fn(),
  fetchPhoto: vi.fn(),
  showError: vi.fn(),
}))

// The account page's unrelated manager selector needs DOM options, which the
// lightweight host renderer does not implement.
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
vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({ user: { id: 1 }, isImpersonating: false }),
}))
vi.mock('@/stores/contentFilter', () => ({ useContentFilterStore: () => ({ isBlocked: vi.fn() }) }))
vi.mock('@/api/member', () => ({
  memberApi: {
    getMyInfo: mocks.getMyInfo,
    getFamilyMembers: mocks.getFamilyMembers,
    getManagers: mocks.getManagers,
    getManagedMembers: mocks.getManagedMembers,
    updateProfilePhoto: mocks.updateProfilePhoto,
  },
  refreshTokenApi: { getRefreshTokens: mocks.getRefreshTokens },
  getVisibleSocialAccountProviders: () => [],
  canUnlinkSocialAccount: () => false,
  getSocialAccountUnlinkErrorKey: vi.fn(),
  refreshAppleLinkMemberState: vi.fn(),
}))
vi.mock('@/api/auth', () => ({ authApi: {} }))
vi.mock('@/api/attachment', () => ({ fetchAuthenticatedImage: mocks.fetchPhoto }))
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
vi.mock('@/composables/useNaver', () => ({
  useNaver: () => ({ isNaverEnabled: false, naverLink: vi.fn() }),
}))
vi.mock('@/composables/useApple', () => ({
  AppleSignInError: class extends Error {},
  isAppleSignInCancellation: () => false,
  useApple: () => ({ isAppleConfigured: false, isAppleReady: { value: false } }),
}))

const emptyStub = { default: { setup: () => () => null } }
vi.mock('@/components/common/BaseModal.vue', () => emptyStub)
vi.mock('@/components/common/PageHeader.vue', () => emptyStub)
vi.mock('@/components/common/SessionTokenList.vue', () => emptyStub)
vi.mock('@/components/member/DutyPatternCard.vue', () => emptyStub)
vi.mock('@/components/member/SocialAccountConnectionModal.vue', () => emptyStub)
vi.mock('@/components/member/AccountDeletionModal.vue', () => emptyStub)
vi.mock('@/components/common/ImageCropModal.vue', async () => {
  const { defineComponent, h } = await import('vue')
  return {
    default: defineComponent({
      props: { isOpen: Boolean },
      emits: ['close', 'confirm'],
      setup: (props, { emit }) => () => h('crop-modal', {
        open: props.isOpen,
        onClose: () => emit('close'),
        onConfirm: (file: File) => emit('confirm', file),
      }),
    }),
  }
})

const { default: MemberView } = await import('./MemberView.vue')
const member = { id: 1, name: 'Tester', profilePhotoVersion: 1 }

function hasClass(node: HostNode, name: string) {
  return String(node.props.class ?? '').split(/\s+/).includes(name)
}

async function flush() {
  for (let index = 0; index < 6; index++) {
    await Promise.resolve()
    await nextTick()
  }
}

describe('MemberView profile photo', () => {
  const mountedApps: ReturnType<typeof mountHost>['app'][] = []
  const viewport = { innerWidth: 390, addEventListener: vi.fn() }

  beforeEach(() => {
    vi.clearAllMocks()
    mocks.getMyInfo.mockResolvedValue({ data: member })
    mocks.getFamilyMembers.mockResolvedValue({ data: [] })
    mocks.getManagers.mockResolvedValue({ data: [] })
    mocks.getManagedMembers.mockResolvedValue({ data: [] })
    mocks.getRefreshTokens.mockResolvedValue({ data: [] })
    mocks.updateProfilePhoto.mockResolvedValue({ data: undefined })
    mocks.fetchPhoto.mockResolvedValue('blob:current')
    vi.stubGlobal('URL', { createObjectURL: () => 'blob:uploaded', revokeObjectURL: vi.fn() })
    viewport.innerWidth = 390
    vi.stubGlobal('window', viewport)
  })

  afterEach(() => {
    mountedApps.splice(0).forEach((app) => app.unmount())
    vi.unstubAllGlobals()
  })

  async function mountMember() {
    const mounted = mountHost(MemberView, {}, [{
      install(app: ReturnType<typeof mountHost>['app']) {
        app.component('RouterLink', { setup: () => () => null })
      },
    }])
    mountedApps.push(mounted.app)
    await flush()
    return mounted
  }

  it.each([390, 639, 640, 1280])('mounts and loads one uploader at a represented width of %ipx', async (width) => {
    viewport.innerWidth = width
    const { root } = await mountMember()

    expect(findHostNodes(root, (node) => hasClass(node, 'profile-photo-uploader'))).toHaveLength(1)
    expect(findHostNodes(root, (node) => node.type === 'crop-modal')).toHaveLength(1)
    expect(mocks.fetchPhoto).toHaveBeenCalledExactlyOnceWith('/api/members/1/profile-photo?v=1')
    expect(mocks.showError).not.toHaveBeenCalled()
  })

  it('keeps the uploader mounted and refreshes the photo once after upload completes', async () => {
    const { root } = await mountMember()
    const uploader = findHostNode(root, (node) => hasClass(node, 'profile-photo-uploader'))!
    const cropModal = findHostNode(root, (node) => node.type === 'crop-modal')!
    mocks.getMyInfo.mockResolvedValueOnce({ data: { ...member, profilePhotoVersion: 2 } })
    const file = new File(['photo'], 'profile.png', { type: 'image/png' })

    triggerHost(findHostNode(uploader, (node) => hasClass(node, 'photo-container'))!, 'onClick')
    await nextTick()
    expect(cropModal.props.open).toBe(true)
    triggerHost(cropModal, 'onConfirm', file)
    await flush()

    expect(mocks.updateProfilePhoto).toHaveBeenCalledExactlyOnceWith(file)
    expect(mocks.getMyInfo).toHaveBeenCalledTimes(2)
    expect(mocks.fetchPhoto.mock.calls).toEqual([
      ['/api/members/1/profile-photo?v=1'],
      ['/api/members/1/profile-photo?v=2'],
    ])
    expect(findHostNodes(root, (node) => hasClass(node, 'profile-photo-uploader'))).toEqual([uploader])
    expect(cropModal.props.open).toBe(false)
  })

  it('uses CSS for resizing and leaves photo loading unchanged on resize or crop cancellation', async () => {
    const { root } = await mountMember()
    const uploader = findHostNode(root, (node) => hasClass(node, 'profile-photo-uploader'))!
    const photo = findHostNode(uploader, (node) => hasClass(node, 'photo-container'))!
    const cropModal = findHostNode(root, (node) => node.type === 'crop-modal')!

    viewport.innerWidth = 1280
    await nextTick()
    expect(hasClass(photo, 'photo-size-responsive')).toBe(true)
    expect(findHostNodes(root, (node) => hasClass(node, 'profile-photo-uploader'))).toEqual([uploader])
    expect(viewport.addEventListener).not.toHaveBeenCalled()
    triggerHost(photo, 'onClick')
    await nextTick()
    triggerHost(cropModal, 'onClose')
    await nextTick()

    expect(cropModal.props.open).toBe(false)
    expect(mocks.fetchPhoto).toHaveBeenCalledTimes(1)
    expect(mocks.getMyInfo).toHaveBeenCalledTimes(1)
    expect(mocks.updateProfilePhoto).not.toHaveBeenCalled()
  })
})
