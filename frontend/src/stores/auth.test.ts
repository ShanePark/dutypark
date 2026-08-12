import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

const push = vi.fn()
const currentRoute = {
  value: {
    fullPath: '/duty/5?month=2',
  },
}

let authFailureHandler: (() => void) | null = null
let impersonationExpiredHandler: (() => void) | null = null

const localStorageMock = {
  getItem: vi.fn(() => null as string | null),
  setItem: vi.fn(),
  removeItem: vi.fn(),
}

Object.defineProperty(globalThis, 'localStorage', {
  value: localStorageMock,
  configurable: true,
})

vi.mock('@/api/auth', () => ({
  authApi: {
    login: vi.fn(),
    logout: vi.fn(),
    refresh: vi.fn(),
    getStatus: vi.fn(),
    impersonate: vi.fn(),
    restore: vi.fn(),
  },
}))

vi.mock('@/api/client', () => ({
  setAuthFailureHandler: vi.fn((handler: () => void) => {
    authFailureHandler = handler
  }),
  setImpersonationHandlers: vi.fn((_checker: () => boolean, handler: () => void) => {
    impersonationExpiredHandler = handler
  }),
  resetRefreshState: vi.fn(),
}))

vi.mock('@/router', () => ({
  default: {
    push,
    currentRoute,
  },
}))

describe('auth store redirect handling', async () => {
  const { useAuthStore } = await import('./auth')

  beforeEach(() => {
    setActivePinia(createPinia())
    push.mockReset()
    currentRoute.value.fullPath = '/duty/5?month=2'
    authFailureHandler = null
    impersonationExpiredHandler = null
    localStorageMock.getItem.mockReset()
    localStorageMock.getItem.mockReturnValue(null)
    localStorageMock.setItem.mockClear()
    localStorageMock.removeItem.mockClear()
  })

  it('redirects auth failures back to the original page after login', () => {
    useAuthStore()

    expect(authFailureHandler).not.toBeNull()
    authFailureHandler?.()

    expect(push).toHaveBeenCalledWith({
      name: 'login',
      query: {
        redirect: '/duty/5?month=2',
      },
    })
  })

  it('redirects expired impersonation sessions with the current path', () => {
    useAuthStore()

    expect(impersonationExpiredHandler).not.toBeNull()
    impersonationExpiredHandler?.()

    expect(push).toHaveBeenCalledWith({
      name: 'login',
      query: {
        redirect: '/duty/5?month=2',
      },
    })
  })

  it('completes account deletion locally without redirecting or persisting completion state', async () => {
    const { resetRefreshState } = await import('@/api/client')
    vi.mocked(resetRefreshState).mockClear()
    const store = useAuthStore()
    store.setUser({
      id: 1,
      email: 'member@example.com',
      name: 'Member',
      teamId: null,
      team: null,
      isAdmin: false,
      isImpersonating: false,
      originalMemberId: null,
    })

    store.completeAccountDeletion()

    expect(store.user).toBeNull()
    expect(store.isLoggedIn).toBe(false)
    expect(store.isInitialized).toBe(true)
    expect(localStorageMock.removeItem).toHaveBeenCalledWith('dp-login-member')
    expect(localStorageMock.removeItem).toHaveBeenCalledWith('dp-impersonation-expires')
    expect(resetRefreshState).toHaveBeenCalled()
    expect(push).not.toHaveBeenCalled()
    expect(localStorageMock.setItem).not.toHaveBeenCalledWith(
      expect.stringContaining('deletion'),
      expect.anything(),
    )
  })
})
