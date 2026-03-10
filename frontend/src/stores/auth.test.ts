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

Object.defineProperty(globalThis, 'localStorage', {
  value: {
    getItem: vi.fn(() => null),
    setItem: vi.fn(),
    removeItem: vi.fn(),
  },
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
})
