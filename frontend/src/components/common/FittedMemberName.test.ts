import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { h, nextTick, ref } from 'vue'
import { createHostWrapper, findHostNode, hostText, mountHost, type HostNode } from '@/test/hostRenderer'
import FittedMemberName from './FittedMemberName.vue'

const CHAR_WIDTH = 10

class FakeResizeObserver {
  static instances: FakeResizeObserver[] = []
  observed: unknown[] = []
  disconnected = false
  private readonly callback: () => void
  constructor(callback: () => void) {
    this.callback = callback
    FakeResizeObserver.instances.push(this)
  }
  observe(target: unknown) { this.observed.push(target) }
  disconnect() { this.disconnected = true }
  fire() { this.callback() }
}

async function flush() {
  for (let index = 0; index < 4; index++) {
    await Promise.resolve()
    await nextTick()
  }
}

// The host renderer has no layout: the label box is `box.width` wide and its
// content is CHAR_WIDTH per character, so it overflows once the text is wider.
function layOut(node: HostNode, box: { width: number }) {
  Object.defineProperty(node, 'clientWidth', { configurable: true, get: () => box.width })
  Object.defineProperty(node, 'scrollWidth', {
    configurable: true,
    get: () => Math.max(box.width, Array.from(hostText(node)).length * CHAR_WIDTH),
  })
}

describe('FittedMemberName', () => {
  const apps: ReturnType<typeof mountHost>['app'][] = []

  beforeEach(() => {
    FakeResizeObserver.instances = []
    vi.stubGlobal('ResizeObserver', FakeResizeObserver)
  })

  afterEach(() => {
    apps.splice(0).forEach((app) => app.unmount())
    vi.unstubAllGlobals()
  })

  function mount(name: string | ReturnType<typeof ref<string>>, box = { width: 200 }) {
    const nameRef = typeof name === 'string' ? ref(name) : name
    const mounted = mountHost(createHostWrapper(() => h(FittedMemberName, { name: nameRef.value!, class: 'card-name' })))
    apps.push(mounted.app)
    const label = findHostNode(mounted.root, (node) => node.props.class === 'card-name')!
    layOut(label, box)
    return { label, nameRef, observer: FakeResizeObserver.instances.at(-1)! }
  }

  it('shows the full name when it fits', async () => {
    const { label, observer } = mount('Shane Park')
    observer.fire()
    await flush()

    expect(hostText(label)).toBe('Shane Park')
    expect(label.props.title).toBeUndefined()
    expect(observer.observed).toContain(label)
  })

  it('swaps to initials only when the full name overflows, keeping the full name as its title', async () => {
    const box = { width: 60 }
    const { label, observer } = mount('Shane Park', box)
    observer.fire()
    await flush()

    expect(hostText(label)).toBe('S.P')
    expect(label.props.title).toBe('Shane Park')
  })

  it('returns to the full name once the box grows wide enough again', async () => {
    const box = { width: 60 }
    const { label, observer } = mount('Christopher Johnson', box)
    observer.fire()
    await flush()
    expect(hostText(label)).toBe('C.J')

    box.width = 190
    observer.fire()
    await flush()
    expect(hostText(label)).toBe('Christopher Johnson')
  })

  it('keeps an overflowing name without initials whole for the existing ellipsis', async () => {
    const { label, observer } = mount('남궁민수가나다', { width: 30 })
    observer.fire()
    await flush()

    expect(hostText(label)).toBe('남궁민수가나다')
    expect(label.props.title).toBeUndefined()
  })

  it('measures again when the name changes', async () => {
    const box = { width: 60 }
    const nameRef = ref('Shane Park')
    const { label, observer } = mount(nameRef, box)
    observer.fire()
    await flush()
    expect(hostText(label)).toBe('S.P')

    nameRef.value = 'Amy Li'
    await flush()
    expect(hostText(label)).toBe('Amy Li')
  })

  it('renders the full name without ResizeObserver and stops observing on unmount', async () => {
    vi.stubGlobal('ResizeObserver', undefined)
    const { label } = mount('Shane Park', { width: 10 })
    await flush()
    expect(hostText(label)).toBe('Shane Park')

    vi.stubGlobal('ResizeObserver', FakeResizeObserver)
    const { observer } = mount('Mary Jane Lee')
    apps.splice(0).forEach((app) => app.unmount())
    expect(observer.disconnected).toBe(true)
  })
})
