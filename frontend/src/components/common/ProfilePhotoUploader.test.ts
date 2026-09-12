import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { h, nextTick, ref } from 'vue'
import { fetchAuthenticatedImage } from '@/api/attachment'
import { memberApi } from '@/api/member'
import { createHostWrapper, findHostNode, mountHost, triggerHost, type HostNode } from '@/test/hostRenderer'
import ProfilePhotoUploader from './ProfilePhotoUploader.vue'

vi.mock('@/api/attachment', () => ({ fetchAuthenticatedImage: vi.fn() }))
vi.mock('@/api/member', () => ({
  memberApi: { updateProfilePhoto: vi.fn(), deleteProfilePhoto: vi.fn() },
}))
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: (key: string) => key }) }))
vi.mock('@/composables/useSwal', () => ({
  useSwal: () => ({ showError: vi.fn(), toastSuccess: vi.fn(), confirm: vi.fn() }),
}))
vi.mock('@/components/common/ImageCropModal.vue', async () => {
  const { defineComponent, h } = await import('vue')
  return {
    default: defineComponent({
      inheritAttrs: false,
      setup: (_, { attrs }) => () => h('crop-modal', attrs),
    }),
  }
})

describe('ProfilePhotoUploader image lifecycle', () => {
  const mountedApps: ReturnType<typeof mountHost>['app'][] = []
  let liveUrls: Set<string>
  let revokeObjectURL: ReturnType<typeof vi.fn>

  function imageRequest(url: string | null) {
    let resolve!: (value: string | null) => void
    const promise = new Promise<string | null>((done) => { resolve = done })
    vi.mocked(fetchAuthenticatedImage).mockReturnValueOnce(promise)
    return async () => {
      if (url) liveUrls.add(url)
      resolve(url)
      await promise
      await nextTick()
    }
  }

  function mountUploader() {
    const props = ref({ memberId: 1, profilePhotoVersion: 1 })
    const mounted = mountHost(createHostWrapper(() => h(ProfilePhotoUploader, props.value)))
    mountedApps.push(mounted.app)
    return { ...mounted, props }
  }

  function imageSource(root: HostNode) {
    return findHostNode(root, (node) => node.type === 'img')?.props.src
  }

  beforeEach(() => {
    vi.mocked(fetchAuthenticatedImage).mockReset()
    vi.mocked(memberApi.updateProfilePhoto).mockReset()
    liveUrls = new Set()
    revokeObjectURL = vi.fn((url: string) => { liveUrls.delete(url) })
    vi.stubGlobal('URL', {
      revokeObjectURL,
      createObjectURL: vi.fn(() => {
        liveUrls.add('blob:uploaded')
        return 'blob:uploaded'
      }),
    })
  })

  afterEach(() => {
    mountedApps.splice(0).forEach((app) => app.unmount())
    vi.unstubAllGlobals()
  })

  it('releases its displayed image when unmounted', async () => {
    const finish = imageRequest('blob:displayed')
    const { app } = mountUploader()
    await finish()

    app.unmount()

    expect(revokeObjectURL).toHaveBeenCalledExactlyOnceWith('blob:displayed')
    expect(liveUrls.size).toBe(0)
  })

  it('releases a response that finishes after unmount', async () => {
    const finish = imageRequest('blob:late')
    const { app } = mountUploader()
    app.unmount()

    await finish()

    expect(revokeObjectURL).toHaveBeenCalledExactlyOnceWith('blob:late')
    expect(liveUrls.size).toBe(0)
  })

  it('keeps the latest photo version when responses finish out of order', async () => {
    const finishOld = imageRequest('blob:old')
    const finishCurrent = imageRequest('blob:current')
    const { app, props, root } = mountUploader()
    props.value.profilePhotoVersion = 2
    await nextTick()

    await finishCurrent()
    await finishOld()

    expect(imageSource(root)).toBe('blob:current')
    expect(revokeObjectURL).toHaveBeenCalledExactlyOnceWith('blob:old')
    expect(liveUrls).toEqual(new Set(['blob:current']))
    app.unmount()
    expect(liveUrls.size).toBe(0)
  })

  it('releases a replaced photo and its replacement exactly once', async () => {
    const finishOld = imageRequest('blob:old')
    const finishCurrent = imageRequest('blob:current')
    const { app, props, root } = mountUploader()
    await finishOld()
    props.value.memberId = 2
    await nextTick()
    await finishCurrent()

    expect(imageSource(root)).toBe('blob:current')
    expect(revokeObjectURL).toHaveBeenCalledExactlyOnceWith('blob:old')
    app.unmount()
    expect(revokeObjectURL).toHaveBeenCalledTimes(2)
    expect(liveUrls.size).toBe(0)
  })

  it('releases an uploaded preview when unmounted', async () => {
    const finish = imageRequest(null)
    vi.mocked(memberApi.updateProfilePhoto).mockResolvedValue(undefined as never)
    const { app, root } = mountUploader()
    await finish()
    const file = new File(['photo'], 'profile.png', { type: 'image/png' })

    triggerHost(findHostNode(root, (node) => node.type === 'crop-modal')!, 'onConfirm', file)
    await Promise.resolve()
    await nextTick()
    expect(imageSource(root)).toBe('blob:uploaded')
    app.unmount()

    expect(memberApi.updateProfilePhoto).toHaveBeenCalledExactlyOnceWith(file)
    expect(liveUrls.size).toBe(0)
  })

  it('does not retain an uploaded preview after unmount during upload', async () => {
    const finish = imageRequest(null)
    let finishUpload!: () => void
    vi.mocked(memberApi.updateProfilePhoto).mockReturnValueOnce(new Promise((resolve) => {
      finishUpload = () => resolve(undefined as never)
    }))
    const { app, root } = mountUploader()
    await finish()
    const file = new File(['photo'], 'profile.png', { type: 'image/png' })
    triggerHost(findHostNode(root, (node) => node.type === 'crop-modal')!, 'onConfirm', file)
    app.unmount()

    finishUpload()
    await nextTick()

    expect(memberApi.updateProfilePhoto).toHaveBeenCalledExactlyOnceWith(file)
    expect(liveUrls.size).toBe(0)
  })

  it('keeps an uploaded preview when an earlier photo load finishes later', async () => {
    const finishOld = imageRequest('blob:old')
    vi.mocked(memberApi.updateProfilePhoto).mockResolvedValue(undefined as never)
    const { app, root } = mountUploader()
    const file = new File(['photo'], 'profile.png', { type: 'image/png' })
    triggerHost(findHostNode(root, (node) => node.type === 'crop-modal')!, 'onConfirm', file)
    await Promise.resolve()
    await nextTick()

    await finishOld()

    expect(imageSource(root)).toBe('blob:uploaded')
    expect(revokeObjectURL).toHaveBeenCalledExactlyOnceWith('blob:old')
    app.unmount()
    expect(liveUrls.size).toBe(0)
  })
})
