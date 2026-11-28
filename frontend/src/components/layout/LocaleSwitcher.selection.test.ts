import { beforeEach, describe, expect, it } from 'vitest'
import { createPinia } from 'pinia'
import { findHostNode, findHostNodes, hostText, mountHost, triggerHost, type HostNode } from '@/test/hostRenderer'

const storage = new Map<string, string>()
const localStorageMock = {
  getItem: (key: string) => storage.get(key) ?? null,
  setItem: (key: string, value: string) => { storage.set(key, value) },
  removeItem: (key: string) => { storage.delete(key) },
}
const noop = () => {}

Object.defineProperty(globalThis, 'window', {
  value: { localStorage: localStorageMock, addEventListener: noop, removeEventListener: noop },
  configurable: true,
})
Object.defineProperty(globalThis, 'document', {
  value: {
    documentElement: { lang: '', clientWidth: 375 },
    addEventListener: noop,
    removeEventListener: noop,
  },
  configurable: true,
})

const registeredWorker = { postMessage: noop }

function setNavigator(language: string, hasRegisteredServiceWorker: boolean) {
  const registration = hasRegisteredServiceWorker ? { active: registeredWorker } : undefined
  Object.defineProperty(globalThis, 'navigator', {
    value: {
      language,
      serviceWorker: {
        getRegistration: () => Promise.resolve(registration),
        // Browsers keep `ready` pending until a worker is registered, which only happens after
        // the user enables push notifications.
        ready: hasRegisteredServiceWorker ? Promise.resolve(registration) : new Promise(noop),
        controller: null,
      },
    },
    configurable: true,
  })
}

const { i18n } = await import('@/i18n')
const { useLocaleStore } = await import('@/stores/locale')
const { default: LocaleSwitcher } = await import('./LocaleSwitcher.vue')

function settle() {
  return new Promise(resolve => setTimeout(resolve, 0))
}

function mountSwitcher() {
  const pinia = createPinia()
  const store = useLocaleStore(pinia)
  store.initializeLocale()
  const { root, app } = mountHost(LocaleSwitcher, {}, [pinia, i18n])
  return { root, app, store }
}

const clickEvent = { stopPropagation: noop }

function toggleButton(root: HostNode) {
  return findHostNode(root, node => String(node.props.class).includes('locale-toggle-btn'))!
}

function dropdownItems(root: HostNode) {
  return findHostNodes(root, node => String(node.props.class).includes('locale-dropdown-item'))
}

async function chooseLanguage(root: HostNode, label: string) {
  triggerHost(toggleButton(root), 'onClick', clickEvent)
  await settle()
  const option = dropdownItems(root).find(item => hostText(item) === label)
  expect(option, `${label} option`).toBeTruthy()
  triggerHost(option!, 'onClick', clickEvent)
  await settle()
}

describe.each([
  { context: 'without a registered service worker (push not enabled, e.g. mobile Safari)', hasRegisteredServiceWorker: false },
  { context: 'with a registered service worker', hasRegisteredServiceWorker: true },
])('LocaleSwitcher language selection $context', ({ hasRegisteredServiceWorker }) => {
  beforeEach(() => {
    storage.clear()
  })

  it('applies English then Korean and closes the dropdown after each choice', async () => {
    setNavigator('ko-KR', hasRegisteredServiceWorker)
    const { root, app, store } = mountSwitcher()

    await chooseLanguage(root, 'English')
    expect(store.locale).toBe('en')
    expect(dropdownItems(root)).toHaveLength(0)

    await chooseLanguage(root, '한국어')
    expect(store.locale).toBe('ko')
    expect(dropdownItems(root)).toHaveLength(0)

    await chooseLanguage(root, 'English')
    expect(store.locale).toBe('en')
    expect(dropdownItems(root)).toHaveLength(0)

    app.unmount()
  })

  it('applies Korean from an English start and closes the dropdown', async () => {
    storage.set('dp-locale', 'en')
    setNavigator('en-US', hasRegisteredServiceWorker)
    const { root, app, store } = mountSwitcher()

    await chooseLanguage(root, '한국어')
    expect(store.locale).toBe('ko')
    expect(storage.get('dp-locale')).toBe('ko')
    expect(dropdownItems(root)).toHaveLength(0)

    app.unmount()
  })
})
