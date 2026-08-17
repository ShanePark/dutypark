import { beforeEach, describe, expect, it, vi } from 'vitest'
import { defineComponent } from 'vue'
import { createMemoryHistory, createRouter, type RouteRecordRaw } from 'vue-router'
import loginView from '@/views/auth/LoginView.vue?raw'

const authState = vi.hoisted(() => ({
  isInitialized: true,
  isLoggedIn: false,
  isAdmin: false,
}))

vi.mock('@/stores/auth', () => ({
  useAuthStore: () => authState,
}))

import { authGuard } from './authGuard'
import { routes } from './routes'

/** The real views are irrelevant here; only paths, names and meta drive the guard. */
const StubView = defineComponent({ render: () => null })

function createTestRouter() {
  const history = createMemoryHistory()
  const router = createRouter({
    history,
    routes: routes.map((route) => ({ ...route, component: StubView }) as RouteRecordRaw),
  })
  router.beforeEach(authGuard)
  return { history, router }
}

/** `router.back()` resolves through the history listener, so let its promises settle. */
function flushNavigation() {
  return new Promise((resolve) => setTimeout(resolve, 0))
}

describe('router back navigation', () => {
  beforeEach(() => {
    authState.isInitialized = true
    authState.isLoggedIn = false
    authState.isAdmin = false
  })

  it('sends a deep link to a protected page through the login page', async () => {
    const { router } = createTestRouter()

    await router.push('/friends')

    expect(router.currentRoute.value.name).toBe('login')
    expect(router.currentRoute.value.query.redirect).toBe('/friends')
  })

  it('does not strand the user on home when going back after a redirect login', async () => {
    const { router } = createTestRouter()
    await router.push('/friends')

    authState.isLoggedIn = true
    // The login view performs exactly this navigation once the credentials are accepted.
    await router.replace(String(router.currentRoute.value.query.redirect))

    router.back()
    await flushNavigation()

    expect(router.currentRoute.value.path).toBe('/friends')
  })

  it('logs in with a replacement so the consumed login page leaves no history entry', () => {
    expect(loginView).toContain('await router.replace(redirectTarget())')
    expect(loginView).not.toContain('router.push(redirectTarget())')
  })

  it('replaces the guest-only entry instead of pushing home on top of it', async () => {
    const { history, router } = createTestRouter()
    await router.push('/auth/login')
    authState.isLoggedIn = true
    await router.push('/todo')

    const push = vi.spyOn(history, 'push')
    const replace = vi.spyOn(history, 'replace')
    router.back()
    await flushNavigation()

    expect(router.currentRoute.value.name).toBe('dashboard')
    expect(replace).toHaveBeenCalledTimes(1)
    expect(push).not.toHaveBeenCalled()
  })

  it('replaces the admin-only entry instead of pushing home on top of it', async () => {
    const { history, router } = createTestRouter()
    authState.isLoggedIn = true
    authState.isAdmin = true
    await router.push('/admin')
    await router.push('/todo')
    authState.isAdmin = false

    const push = vi.spyOn(history, 'push')
    const replace = vi.spyOn(history, 'replace')
    router.back()
    await flushNavigation()

    expect(router.currentRoute.value.name).toBe('dashboard')
    expect(replace).toHaveBeenCalledTimes(1)
    expect(push).not.toHaveBeenCalled()
  })
})
