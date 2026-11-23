import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createRenderer, h, nextTick, ref, type RendererOptions } from 'vue'
import { fetchAuthenticatedImage } from '@/api/attachment'
import ImageViewer from './ImageViewer.vue'

vi.mock('@/api/attachment', () => ({ fetchAuthenticatedImage: vi.fn() }))
vi.mock('@/composables/useBodyScrollLock', () => ({ useBodyScrollLock: () => {} }))
vi.mock('@/composables/useEscapeKey', () => ({ useEscapeKey: () => {} }))
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: (key: string) => key }) }))

type Node = { type: string; props: Record<string, unknown>; children: Node[]; parent: Node | null; text?: string }

function createNode(type: string): Node {
  return { type, props: {}, children: [], parent: null }
}

// ImageViewer teleports to "body", so this renderer resolves that target to a dedicated host node.
const body = createNode('body')
const options: RendererOptions<Node, Node> = {
  patchProp(node, key, _previous, next) { node.props[key] = next },
  insert(node, parent, anchor) {
    node.parent?.children.splice(node.parent.children.indexOf(node), 1)
    const anchorIndex = anchor ? parent.children.indexOf(anchor) : -1
    if (anchorIndex >= 0) parent.children.splice(anchorIndex, 0, node)
    else parent.children.push(node)
    node.parent = parent
  },
  remove(node) {
    node.parent?.children.splice(node.parent.children.indexOf(node), 1)
    node.parent = null
  },
  createElement: createNode,
  createText(text) { return { ...createNode('#text'), text } },
  createComment(text) { return { ...createNode('#comment'), text } },
  setText(node, text) { node.text = text },
  setElementText(node, text) { node.children = [{ ...createNode('#text'), text, parent: node }] },
  parentNode: (node) => node.parent,
  nextSibling(node) {
    return node.parent?.children[node.parent.children.indexOf(node) + 1] ?? null
  },
  querySelector: (selector) => (selector === 'body' ? body : null),
}
const renderer = createRenderer(options)

function findImage(node: Node): Node | null {
  if (node.type === 'img') return node
  for (const child of node.children) {
    const match = findImage(child)
    if (match) return match
  }
  return null
}

describe('ImageViewer image sources', () => {
  let app: ReturnType<typeof renderer.createApp> | null = null

  beforeEach(() => {
    body.children = []
    vi.mocked(fetchAuthenticatedImage).mockReset()
    vi.stubGlobal('window', { addEventListener: vi.fn(), removeEventListener: vi.fn() })
  })

  afterEach(() => {
    app?.unmount()
    app = null
    vi.unstubAllGlobals()
  })

  async function openViewer(images: Array<{ id: string; originalFilename: string; url?: string }>) {
    const isOpen = ref(false)
    app = renderer.createApp({ render: () => h(ImageViewer, { isOpen: isOpen.value, images }) })
    app.provide(Symbol.for('v-scx'), { modules: new Set<string>() })
    app.mount(createNode('root'))
    isOpen.value = true
    await nextTick()
    await Promise.resolve()
    await nextTick()
  }

  it('shows a provided local image without fetching it from the server', async () => {
    await openViewer([{ id: 'uppy-1', originalFilename: 'photo.png', url: 'blob:local-full' }])

    expect(fetchAuthenticatedImage).not.toHaveBeenCalled()
    expect(findImage(body)?.props.src).toBe('blob:local-full')
  })

  it('fetches the full image for a saved attachment', async () => {
    vi.mocked(fetchAuthenticatedImage).mockResolvedValue('blob:server-full')

    await openViewer([{ id: 'img-1', originalFilename: 'photo.png' }])

    expect(fetchAuthenticatedImage).toHaveBeenCalledWith('/api/attachments/img-1/download?inline=true')
    expect(findImage(body)?.props.src).toBe('blob:server-full')
  })
})
