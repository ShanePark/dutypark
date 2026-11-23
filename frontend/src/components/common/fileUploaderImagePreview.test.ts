import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { h, nextTick, withDirectives, type Directive } from 'vue'
import { fetchAuthenticatedImage } from '@/api/attachment'
import {
  createHostWrapper,
  findHostNode,
  findHostNodes,
  mountHost,
  triggerHost,
  type HostNode,
} from '@/test/hostRenderer'
import type { NormalizedAttachment } from '@/types'
import FileUploader from './FileUploader.vue'

const uppy = vi.hoisted(() => ({
  handlers: {} as Record<string, (...args: unknown[]) => void>,
}))

vi.mock('@uppy/core', () => ({
  default: class {
    use() { return this }
    on(event: string, handler: (...args: unknown[]) => void) {
      uppy.handlers[event] = handler
      return this
    }
    addPreProcessor() {}
    cancelAll() {}
    getFile() { return undefined }
    removeFile() {}
  },
}))
vi.mock('@uppy/xhr-upload', () => ({ default: {} }))
vi.mock('@/api/attachment', () => ({
  attachmentApi: { createSession: vi.fn(), discardSession: vi.fn() },
  attachmentValidation: { maxFileSizeBytes: 1024, maxFileSizeLabel: '50MB', tooLargeMessage: () => '' },
  normalizeAttachment: (dto: unknown) => dto,
  getDownloadUrl: (attachment: { id: string }, inline = false) =>
    `/api/attachments/${attachment.id}/download${inline ? '?inline=true' : ''}`,
  formatBytes: (size: number) => `${size} B`,
  getAttachmentIcon: (attachment: { isImage: boolean }) => (attachment.isImage ? 'image' : 'file'),
  validateFile: () => ({ valid: true }),
  fetchAuthenticatedImage: vi.fn(),
}))
vi.mock('./fileUploaderError', () => ({ resolveFileUploaderErrorMessage: () => '' }))
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key: string, params?: Record<string, unknown>) => (params ? `${key}:${JSON.stringify(params)}` : key),
  }),
}))
vi.mock('./ImageViewer.vue', async () => {
  const { defineComponent, h } = await import('vue')
  return {
    default: defineComponent({
      inheritAttrs: false,
      setup: (_, { attrs }) => () => h('image-viewer', attrs),
    }),
  }
})

// The host renderer has no DOM ancestry; the uploader looks up its enclosing dialog on mount.
const withoutDialog: Directive = {
  created(element: HostNode & { closest?: () => null }) {
    element.closest = () => null
  },
}

function attachment(overrides: Partial<NormalizedAttachment> & { id: string; name: string }): NormalizedAttachment {
  return {
    originalFilename: overrides.name,
    contentType: 'image/png',
    size: 10,
    thumbnailUrl: null,
    downloadUrl: null,
    isImage: true,
    hasThumbnail: true,
    orderIndex: 0,
    createdAt: null,
    createdBy: null,
    previewUrl: null,
    ...overrides,
  }
}

function hasClass(node: HostNode, className: string) {
  return String(node.props.class ?? '').split(/\s+/).includes(className)
}

const clickEvent = () => ({ stopPropagation: vi.fn(), preventDefault: vi.fn() })

describe('FileUploader image preview', () => {
  const mountedApps: ReturnType<typeof mountHost>['app'][] = []

  async function mountUploader(existingAttachments: NormalizedAttachment[] = []) {
    const mounted = mountHost(createHostWrapper(() => withDirectives(
      h(FileUploader, { contextType: 'SCHEDULE', existingAttachments }),
      [[withoutDialog]],
    )))
    mountedApps.push(mounted.app)
    await flush()
    return mounted.root
  }

  async function flush() {
    for (let i = 0; i < 5; i++) {
      await Promise.resolve()
      await nextTick()
    }
  }

  function previewButtons(root: HostNode) {
    return findHostNodes(root, (node) => node.type === 'button' && hasClass(node, 'attachment-preview-button'))
  }

  function viewer(root: HostNode) {
    const node = findHostNode(root, (candidate) => candidate.type === 'image-viewer')
    expect(node).not.toBeNull()
    return node!
  }

  beforeEach(() => {
    uppy.handlers = {}
    vi.mocked(fetchAuthenticatedImage).mockReset()
    vi.mocked(fetchAuthenticatedImage).mockImplementation(async (url: string) => `blob:thumb${url}`)
    vi.stubGlobal('window', {
      setInterval: vi.fn(() => 1),
      clearInterval: vi.fn(),
      setTimeout: vi.fn(() => 1),
    })
    vi.stubGlobal('URL', {
      createObjectURL: vi.fn(() => 'blob:local-full'),
      revokeObjectURL: vi.fn(),
    })
  })

  afterEach(() => {
    mountedApps.splice(0).forEach((app) => app.unmount())
    vi.unstubAllGlobals()
  })

  it('opens the viewer at the clicked saved image and lets it fetch the full image', async () => {
    const root = await mountUploader([
      attachment({ id: 'img-1', name: 'first.png', thumbnailUrl: '/api/attachments/img-1/thumbnail' }),
      attachment({ id: 'doc-1', name: 'notes.pdf', contentType: 'application/pdf', isImage: false }),
      attachment({ id: 'img-2', name: 'second.png', thumbnailUrl: '/api/attachments/img-2/thumbnail' }),
    ])

    expect(viewer(root).props['is-open']).toBe(false)
    const buttons = previewButtons(root)
    expect(buttons).toHaveLength(2)
    expect(buttons[1]?.props['aria-label']).toBe('fileUploader.previewImageAria:{"name":"second.png"}')
    expect(buttons[1]?.props.type).toBe('button')

    triggerHost(buttons[1]!, 'onClick', clickEvent())
    await nextTick()

    expect(viewer(root).props['is-open']).toBe(true)
    expect(viewer(root).props['initial-index']).toBe(1)
    // Saved attachments carry no local source, so the viewer loads the full download rather than the thumbnail.
    expect(viewer(root).props.images).toEqual([
      { id: 'img-1', originalFilename: 'first.png', url: undefined },
      { id: 'img-2', originalFilename: 'second.png', url: undefined },
    ])

    ;(viewer(root).props.onClose as () => void)()
    await nextTick()
    expect(viewer(root).props['is-open']).toBe(false)
  })

  it('renders no preview button for non-image files', async () => {
    const root = await mountUploader([
      attachment({ id: 'doc-1', name: 'notes.pdf', contentType: 'application/pdf', isImage: false }),
    ])

    expect(previewButtons(root)).toHaveLength(0)
    expect(findHostNode(root, (node) => node.type === 'img')).toBeNull()
  })

  it('previews a local image with its full local file while uploading and after upload succeeds', async () => {
    const root = await mountUploader()
    const file = { name: 'photo.png', type: 'image/png', size: 2048 }
    uppy.handlers['file-added']!({ id: 'uppy-1', name: 'photo.png', data: file })
    await flush()

    triggerHost(previewButtons(root)[0]!, 'onClick', clickEvent())
    await nextTick()
    expect(viewer(root).props.images).toEqual([
      { id: 'uppy-1', originalFilename: 'photo.png', url: 'blob:local-full' },
    ])
    ;(viewer(root).props.onClose as () => void)()

    uppy.handlers['upload-success']!(
      { id: 'uppy-1', name: 'photo.png' },
      { body: attachment({ id: 'server-1', name: 'photo.png', thumbnailUrl: '/api/attachments/server-1/thumbnail' }) },
    )
    await flush()

    triggerHost(previewButtons(root)[0]!, 'onClick', clickEvent())
    await nextTick()
    // Session attachments are not downloadable until the schedule is saved, so keep the local original.
    expect(viewer(root).props.images).toEqual([
      { id: 'server-1', originalFilename: 'photo.png', url: 'blob:local-full' },
    ])
  })

  it('removes an attachment without opening the viewer', async () => {
    const root = await mountUploader([attachment({ id: 'img-1', name: 'first.png' })])
    const removeButton = findHostNode(root, (node) => node.type === 'button' && hasClass(node, 'remove-btn'))

    triggerHost(removeButton!, 'onClick', clickEvent())
    await flush()

    expect(viewer(root).props['is-open']).toBe(false)
    expect(previewButtons(root)).toHaveLength(0)
    expect(findHostNode(root, (node) => hasClass(node, 'attachment-item'))).toBeNull()
  })
})
