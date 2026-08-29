import { createRenderer, defineComponent, type Component, type RendererOptions, type VNode } from 'vue'

export type HostProps = Record<string, unknown>

export type HostNode = {
  type: string
  props: HostProps
  children: HostNode[]
  parent: HostNode | null
  text?: string
  value?: string
  addEventListener: (event: string, handler: (payload: unknown) => void) => void
  removeEventListener: (event: string, handler: (payload: unknown) => void) => void
  listeners: Map<string, Set<(payload: unknown) => void>>
}

function createHostNode(type: string, props: HostProps = {}): HostNode {
  const listeners = new Map<string, Set<(payload: unknown) => void>>()
  return {
    type,
    props,
    children: [],
    parent: null,
    listeners,
    addEventListener(event, handler) {
      const eventHandlers = listeners.get(event) ?? new Set()
      eventHandlers.add(handler)
      listeners.set(event, eventHandlers)
    },
    removeEventListener(event, handler) {
      listeners.get(event)?.delete(handler)
    },
  }
}

const rendererOptions: RendererOptions<HostNode, HostNode> = {
  patchProp(node, key, _previous, next) {
    if (next == null) {
      delete node.props[key]
    } else {
      node.props[key] = next
    }
    if (key === 'value' && typeof next === 'string') {
      node.value = next
    }
  },
  insert(node, parent, anchor) {
    const currentIndex = parent.children.indexOf(node)
    if (currentIndex >= 0) parent.children.splice(currentIndex, 1)
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
  createElement(type) {
    return createHostNode(type)
  },
  createText(text) {
    const node = createHostNode('#text')
    node.text = text
    return node
  },
  createComment(text) {
    const node = createHostNode('#comment')
    node.text = text
    return node
  },
  setText(node, text) {
    node.text = text
  },
  setElementText(node, text) {
    node.children = []
    const child = createHostNode('#text')
    child.text = text
    child.parent = node
    node.children.push(child)
  },
  parentNode(node) {
    return node.parent
  },
  nextSibling(node) {
    if (!node.parent) return null
    return node.parent.children[node.parent.children.indexOf(node) + 1] ?? null
  },
}
const renderer = createRenderer<HostNode, HostNode>(rendererOptions)

export function mountHost(
  component: Component,
  props: Record<string, unknown> = {},
  plugins: unknown[] = [],
): { root: HostNode; app: ReturnType<typeof renderer.createApp> } {
  const root = createHostNode('root')
  const app = renderer.createApp(component, props)
  // Vue's scoped-style runtime records module ids through the SSR context when
  // no DOM renderer is available. Supplying the same well-known context key
  // keeps the host renderer compatible with scoped SFCs.
  app.provide(Symbol.for('v-scx'), { modules: new Set<string>() })
  for (const plugin of plugins) {
    app.use(plugin as never)
  }
  app.mount(root)
  return { root, app }
}

export function createHostWrapper(
  render: () => VNode,
): Component {
  return defineComponent({ setup: () => render })
}

export function findHostNode(
  root: HostNode,
  predicate: (node: HostNode) => boolean,
): HostNode | null {
  if (predicate(root)) return root
  for (const child of root.children) {
    const match = findHostNode(child, predicate)
    if (match) return match
  }
  return null
}

export function findHostNodes(
  root: HostNode,
  predicate: (node: HostNode) => boolean,
): HostNode[] {
  const matches: HostNode[] = []
  if (predicate(root)) matches.push(root)
  for (const child of root.children) {
    matches.push(...findHostNodes(child, predicate))
  }
  return matches
}

export function hostText(root: HostNode): string {
  if (root.type === '#text') return root.text ?? ''
  return root.children.map(hostText).join('')
}

export function triggerHost(
  node: HostNode,
  event: string,
  payload: unknown = {},
): void {
  if (
    (event === 'onInput' || event === 'onChange') &&
    typeof payload === 'object' &&
    payload !== null &&
    'target' in payload &&
    typeof payload.target === 'object' &&
    payload.target !== null &&
    'value' in payload.target
  ) {
    node.value = String(payload.target.value)
  }
  const handler = node.props[event]
  if (typeof handler === 'function') handler(payload)
  if (event.startsWith('on')) {
    const eventName = event.slice(2).toLowerCase()
    node.listeners.get(eventName)?.forEach(listener => listener(payload))
  }
}
