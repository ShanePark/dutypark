import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { h, nextTick, ref } from 'vue'
import { fetchAuthenticatedImage } from '@/api/attachment'
import { createHostWrapper, findHostNode, mountHost, type HostNode } from '@/test/hostRenderer'
import ProfileAvatar from './ProfileAvatar.vue'
import profileAvatar from './ProfileAvatar.vue?raw'

vi.mock('@/api/attachment', () => ({ fetchAuthenticatedImage: vi.fn() }))

const template = profileAvatar.slice(
  profileAvatar.indexOf('<template>'),
  profileAvatar.indexOf('<style'),
)

describe('ProfileAvatar image dragging', () => {
  it('disables native image dragging so pointer swipes can start on the photo', () => {
    expect(template).toMatch(/<img\b[^>]*\sdraggable="false"[^>]*>/)
  })
})

describe('ProfileAvatar fallback image', () => {
  it('uses the shared full-size silhouette when a photo is unavailable', () => {
    expect(template).toContain('src="/img/default-profile.png"')
    expect(template).toMatch(/<img\b[^>]*class="w-full h-full object-cover"/)
    expect(template).not.toContain('<User')
  })
})

describe('ProfileAvatar image lifecycle', () => {
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

  function mountAvatar(props = ref({ memberId: 1, hasProfilePhoto: true, profilePhotoVersion: 1 })) {
    const mounted = mountHost(createHostWrapper(() => h(ProfileAvatar, props.value)))
    mountedApps.push(mounted.app)
    return { ...mounted, props }
  }

  function imageSource(root: HostNode) {
    return findHostNode(root, (node) => node.type === 'img')?.props.src
  }

  beforeEach(() => {
    vi.mocked(fetchAuthenticatedImage).mockReset()
    liveUrls = new Set()
    revokeObjectURL = vi.fn((url: string) => { liveUrls.delete(url) })
    vi.stubGlobal('URL', { revokeObjectURL })
  })

  afterEach(() => {
    mountedApps.splice(0).forEach((app) => app.unmount())
    vi.unstubAllGlobals()
  })

  it('releases its displayed image when unmounted', async () => {
    const finish = imageRequest('blob:displayed')
    const { app } = mountAvatar()
    await finish()

    app.unmount()

    expect(revokeObjectURL).toHaveBeenCalledExactlyOnceWith('blob:displayed')
    expect(liveUrls.size).toBe(0)
  })

  it('releases a response that finishes after unmount', async () => {
    const finish = imageRequest('blob:late')
    const { app } = mountAvatar()
    app.unmount()

    await finish()

    expect(revokeObjectURL).toHaveBeenCalledExactlyOnceWith('blob:late')
    expect(liveUrls.size).toBe(0)
  })

  it('keeps the latest member photo when older requests finish out of order', async () => {
    const finishOld = imageRequest('blob:old')
    const finishCurrent = imageRequest('blob:current')
    const { app, props, root } = mountAvatar()
    props.value.memberId = 2
    await nextTick()

    await finishCurrent()
    await finishOld()

    expect(imageSource(root)).toBe('blob:current')
    expect(revokeObjectURL).toHaveBeenCalledExactlyOnceWith('blob:old')
    expect(liveUrls).toEqual(new Set(['blob:current']))
    app.unmount()
    expect(liveUrls.size).toBe(0)
  })

  it('discards a pending photo when the member no longer has one', async () => {
    const finish = imageRequest('blob:removed')
    const { props, root } = mountAvatar()
    props.value.hasProfilePhoto = false
    await nextTick()

    await finish()

    expect(imageSource(root)).toBe('/img/default-profile.png')
    expect(liveUrls.size).toBe(0)
    expect(fetchAuthenticatedImage).toHaveBeenCalledTimes(1)
  })

  it('ignores an older failed request after the current photo succeeds', async () => {
    const finishOld = imageRequest(null)
    const finishCurrent = imageRequest('blob:current')
    const { props, root } = mountAvatar()
    props.value.profilePhotoVersion = 2
    await nextTick()

    await finishCurrent()
    await finishOld()

    expect(imageSource(root)).toBe('blob:current')
  })
})
