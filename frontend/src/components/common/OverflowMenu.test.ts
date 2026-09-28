import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createRenderer, defineComponent, h, nextTick, type RendererOptions } from 'vue'

vi.mock('@/composables/useEscapeKey', () => ({
  useEscapeKey: () => {},
}))

const { default: OverflowMenu } = await import('./OverflowMenu.vue')

type TestNode = {
  type: string
  props: Record<string, unknown>
  children: TestNode[]
  parent: TestNode | null
  text?: string
  listeners: Map<string, Set<(payload: unknown) => void>>
  addEventListener: (event: string, handler: (payload: unknown) => void) => void
  removeEventListener: (event: string, handler: (payload: unknown) => void) => void
  offsetWidth: number
  offsetHeight: number
  getBoundingClientRect: () => DOMRect
}

const initialTriggerRect = {
  top: 554,
  right: 812,
  bottom: 582,
  left: 780,
  width: 32,
  height: 28,
  x: 780,
  y: 554,
  toJSON: () => ({}),
} as DOMRect
let triggerRect = initialTriggerRect

beforeEach(() => {
  triggerRect = initialTriggerRect
})

function createNode(type: string): TestNode {
  const listeners = new Map<string, Set<(payload: unknown) => void>>()
  const node = {
    type,
    props: {} as Record<string, unknown>,
    children: [] as TestNode[],
    parent: null as TestNode | null,
    listeners,
    addEventListener(event: string, handler: (payload: unknown) => void) {
      const handlers = listeners.get(event) ?? new Set()
      handlers.add(handler)
      listeners.set(event, handlers)
    },
    removeEventListener(event: string, handler: (payload: unknown) => void) {
      listeners.get(event)?.delete(handler)
    },
    offsetWidth: 0,
    offsetHeight: 0,
    getBoundingClientRect() {
      return this.props['aria-label'] === 'Schedule actions'
        ? triggerRect
        : { ...triggerRect, top: 0, bottom: 0, left: 0, right: 0, width: 0, height: 0 } as DOMRect
    },
  }

  Object.defineProperties(node, {
    offsetWidth: { get: () => node.props.class?.toString().includes('overflow-menu') ? 176 : 32 },
    offsetHeight: { get: () => node.props.class?.toString().includes('overflow-menu') ? 88 : 28 },
  })

  return node
}

function findNode(root: TestNode, predicate: (node: TestNode) => boolean): TestNode | null {
  if (predicate(root)) return root
  for (const child of root.children) {
    const match = findNode(child, predicate)
    if (match) return match
  }
  return null
}

function mountMenu() {
  const body = createNode('body')
  const root = createNode('root')
  const windowStub = {
    innerWidth: 800,
    innerHeight: 600,
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  }
  vi.stubGlobal('document', {
    body,
    documentElement: { clientWidth: 800, clientHeight: 600 },
    querySelector: (selector: string) => selector === 'body' ? body : null,
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  })
  vi.stubGlobal('window', windowStub)
  const rendererOptions: RendererOptions<TestNode, TestNode> & {
    querySelector: (selector: string) => TestNode | null
  } = {
    patchProp(node, key, _previous, next) {
      if (next == null) delete node.props[key]
      else node.props[key] = next
    },
    insert(node, parent, anchor) {
      const currentIndex = node.parent?.children.indexOf(node) ?? -1
      if (currentIndex >= 0) node.parent!.children.splice(currentIndex, 1)
      const anchorIndex = anchor ? parent.children.indexOf(anchor) : -1
      if (anchorIndex >= 0) parent.children.splice(anchorIndex, 0, node)
      else parent.children.push(node)
      node.parent = parent
    },
    remove(node) {
      if (!node.parent) return
      const index = node.parent.children.indexOf(node)
      if (index >= 0) node.parent.children.splice(index, 1)
      node.parent = null
    },
    createElement: createNode,
    createText(text) {
      const node = createNode('#text')
      node.text = text
      return node
    },
    createComment(text) {
      const node = createNode('#comment')
      node.text = text
      return node
    },
    setText(node, text) {
      node.text = text
    },
    setElementText(node, text) {
      node.children = []
      const child = createNode('#text')
      child.text = text
      child.parent = node
      node.children.push(child)
    },
    parentNode: node => node.parent,
    nextSibling(node) {
      if (!node.parent) return null
      return node.parent.children[node.parent.children.indexOf(node) + 1] ?? null
    },
    querySelector: selector => selector === 'body' ? body : null,
  }
  const renderer = createRenderer<TestNode, TestNode>(rendererOptions)
  const app = renderer.createApp(defineComponent({
    setup() {
      return () => h('div', { class: 'modal-content overflow-y-auto' }, [
        h(OverflowMenu, {
          menuLabel: 'Schedule actions',
          triggerClass: 'schedule-menu-trigger',
          align: 'right',
        }, {
          trigger: () => h('span', '…'),
          default: () => [
            h('button', { role: 'menuitem' }, 'Remove tag'),
            h('button', { role: 'menuitem' }, 'Report'),
          ],
        }),
      ])
    },
  }))
  app.mount(root)

  return { app, body, root, windowStub }
}

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('OverflowMenu in a scrollable modal', () => {
  it('teleports the open menu outside the scroll container that clips its trigger', async () => {
    const { app, body, root } = mountMenu()
    const trigger = findNode(root, node => node.props['aria-label'] === 'Schedule actions')
    expect(trigger).not.toBeNull()

    ;(trigger!.props.onClick as (() => void) | undefined)?.()
    await nextTick()

    const menu = findNode(body, node => node.props.role === 'menu')
    expect(menu, 'the open menu should be rendered under body, outside modal scrollers').not.toBeNull()
    expect(menu!.parent).toBe(body)
    app.unmount()
  })

  it('flips above a low trigger and clamps the fixed panel to the viewport edges', async () => {
    const { app, body, root } = mountMenu()

    const trigger = findNode(root, node => node.props['aria-label'] === 'Schedule actions')
    expect(trigger).not.toBeNull()
    ;(trigger!.props.onClick as (() => void) | undefined)?.()
    await nextTick()

    const menu = findNode(body, node => node.props.role === 'menu')
    expect(menu).not.toBeNull()
    const style = menu!.props.style as Record<string, string>
    const top = Number.parseFloat(style.top)
    const left = Number.parseFloat(style.left)

    expect(style.position).toBe('fixed')
    expect(top).toBeLessThan(triggerRect.top)
    expect(left).toBeGreaterThanOrEqual(0)
    expect(left + menu!.offsetWidth).toBeLessThanOrEqual(800)
    expect(top + menu!.offsetHeight).toBeLessThanOrEqual(600)
    app.unmount()
  })

  it('repositions the teleported panel when its scroll container moves the trigger', async () => {
    const { app, body, root, windowStub } = mountMenu()
    const trigger = findNode(root, node => node.props['aria-label'] === 'Schedule actions')
    expect(trigger).not.toBeNull()
    ;(trigger!.props.onClick as (() => void) | undefined)?.()
    await nextTick()

    const menu = findNode(body, node => node.props.role === 'menu')
    expect(menu).not.toBeNull()
    const scrollListener = windowStub.addEventListener.mock.calls
      .find(([event]) => event === 'scroll')?.[1] as (() => void) | undefined
    expect(scrollListener).toBeTypeOf('function')

    triggerRect = { ...triggerRect, top: 200, right: 132, bottom: 228, left: 100, x: 100, y: 200 }
    scrollListener!()
    await nextTick()

    expect(Number.parseFloat((menu!.props.style as Record<string, string>).top)).toBe(236)
    app.unmount()
  })
})
