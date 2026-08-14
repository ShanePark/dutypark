import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { authApi } from '@/api/auth'

const push = vi.fn()
const currentRoute = {
  value: {
    fullPath: '/duty/5?month=2',
  },
}

let authFailureHandler: (() => void) | null = null
let impersonationExpiredHandler: (() => void) | null = null

const localStorageMock = {
  getItem: vi.fn<(key: string) => string | null>(() => null),
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

  const member = {
    id: 1,
    email: 'member@example.com',
    name: 'Member',
    teamId: null,
    team: null,
    isAdmin: false,
    isImpersonating: false,
    originalMemberId: null,
  }

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
    vi.mocked(authApi.login).mockReset()
    vi.mocked(authApi.logout).mockReset()
    vi.mocked(authApi.refresh).mockReset()
    vi.mocked(authApi.getStatus).mockReset()
    vi.mocked(authApi.impersonate).mockReset()
    vi.mocked(authApi.restore).mockReset()
  })

  it('redirects auth failures back to the original page after login', () => {
    const store = useAuthStore()
    store.setUser(member)
    localStorageMock.removeItem.mockClear()

    expect(authFailureHandler).not.toBeNull()
    authFailureHandler?.()

    expect(store.user).toBeNull()
    expect(store.isLoggedIn).toBe(false)
    expect(localStorageMock.removeItem).toHaveBeenCalledWith('dp-login-member')
    expect(push).toHaveBeenCalledWith({
      name: 'login',
      query: {
        redirect: '/duty/5?month=2',
      },
    })
    expect(useAuthStore().isInitialized).toBe(true)
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
    expect(useAuthStore().isInitialized).toBe(true)
  })

  it('completes account deletion locally without redirecting or persisting completion state', async () => {
    const { resetRefreshState } = await import('@/api/client')
    vi.mocked(resetRefreshState).mockClear()
    const store = useAuthStore()
    store.setUser(member)

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

  it.each([
    [{ code: 'ERR_NETWORK' }, 'offline'],
    [{ code: 'ECONNABORTED' }, 'timeout'],
    [{ response: { status: 503 } }, 'server error'],
  ])('uses a safe guest state when the startup session check fails due to %s (%s)', async (error, _label) => {
    localStorageMock.getItem.mockImplementation((key: string) => {
      if (key === 'dp-login-member') return JSON.stringify(member)
      return null
    })
    vi.mocked(authApi.getStatus).mockRejectedValue(error)
    const store = useAuthStore()

    expect(store.isLoggedIn).toBe(true)
    await store.initialize()

    expect(store.user).toBeNull()
    expect(store.isLoggedIn).toBe(false)
    expect(store.sessionCheckFailed).toBe(true)
    expect(localStorageMock.setItem).toHaveBeenCalledWith('dp-session-recovery-login-required', 'true')
    expect(localStorageMock.removeItem).not.toHaveBeenCalledWith('dp-session-recovery-login-required')
    expect(authApi.refresh).not.toHaveBeenCalled()
    expect(localStorageMock.removeItem).toHaveBeenCalledWith('dp-login-member')
  })

  it('treats an invalid or missing refresh session as a normal guest state', async () => {
    vi.mocked(authApi.getStatus).mockRejectedValue({ response: { status: 401 } })
    vi.mocked(authApi.refresh).mockRejectedValue({ response: { status: 401 } })
    const store = useAuthStore()

    await store.initialize()

    expect(store.isLoggedIn).toBe(false)
    expect(store.sessionCheckFailed).toBe(false)
    expect(authApi.refresh).toHaveBeenCalledTimes(1)
  })

  it('surfaces a transient refresh failure without silently authenticating after recovery', async () => {
    vi.mocked(authApi.getStatus).mockResolvedValueOnce(null)
    vi.mocked(authApi.refresh).mockRejectedValue({ response: { status: 500 } })
    const store = useAuthStore()

    await store.initialize()

    expect(store.isLoggedIn).toBe(false)
    expect(store.sessionCheckFailed).toBe(true)
    expect(localStorageMock.setItem).toHaveBeenCalledWith('dp-session-recovery-login-required', 'true')
    expect(localStorageMock.removeItem).not.toHaveBeenCalledWith('dp-session-recovery-login-required')

    vi.mocked(authApi.getStatus).mockResolvedValue(member)
    vi.mocked(authApi.refresh).mockResolvedValue({ expiresIn: 3600 })
    await store.initialize()

    expect(store.isLoggedIn).toBe(false)
    expect(authApi.getStatus).toHaveBeenCalledTimes(1)
    expect(authApi.refresh).toHaveBeenCalledTimes(1)
  })

  it('keeps the recovered browser in guest state across reloads until explicit login', async () => {
    localStorageMock.getItem.mockImplementation((key: string) => {
      if (key === 'dp-login-member') return JSON.stringify(member)
      if (key === 'dp-session-recovery-login-required') return 'true'
      return null
    })
    vi.mocked(authApi.getStatus).mockResolvedValue(member)
    const store = useAuthStore()

    await store.initialize()

    expect(store.isLoggedIn).toBe(false)
    expect(store.sessionCheckFailed).toBe(true)
    expect(authApi.getStatus).not.toHaveBeenCalled()
    expect(authApi.refresh).not.toHaveBeenCalled()
  })

  it('clears the startup warning after an explicit successful login', async () => {
    vi.mocked(authApi.getStatus).mockRejectedValueOnce({ code: 'ERR_NETWORK' })
    const store = useAuthStore()
    await store.initialize()
    expect(store.sessionCheckFailed).toBe(true)

    localStorageMock.removeItem.mockClear()
    vi.mocked(authApi.login).mockResolvedValue({ expiresIn: 3600 })
    vi.mocked(authApi.getStatus).mockResolvedValue(member)
    await store.login({ email: 'member@example.com', password: 'password', rememberMe: false })

    expect(store.user).toEqual(member)
    expect(store.sessionCheckFailed).toBe(false)
    expect(localStorageMock.removeItem).toHaveBeenCalledWith('dp-session-recovery-login-required')
  })

  it.each([
    [{ code: 'ERR_NETWORK' }, 'offline'],
    [{ code: 'ECONNABORTED' }, 'timeout'],
    [{ response: { status: 401 } }, 'unauthorized'],
    [{ response: { status: 503 } }, 'server error'],
  ])('clears all local auth state even when server logout fails due to %s (%s)', async (logoutError, _label) => {
    const { resetRefreshState } = await import('@/api/client')
    vi.mocked(resetRefreshState).mockClear()
    localStorageMock.getItem.mockImplementation((key: string) => {
      if (key === 'dp-impersonation-expires') return '123456789'
      return null
    })
    vi.mocked(authApi.logout).mockRejectedValue(logoutError)
    const store = useAuthStore()
    store.setUser({ ...member, isImpersonating: true })
    localStorageMock.setItem.mockClear()
    localStorageMock.removeItem.mockClear()

    await expect(store.logout()).resolves.toBe(false)

    expect(store.user).toBeNull()
    expect(store.isLoggedIn).toBe(false)
    expect(store.impersonationExpiresAt).toBeNull()
    expect(store.isInitialized).toBe(true)
    expect(localStorageMock.removeItem).toHaveBeenCalledWith('dp-login-member')
    expect(localStorageMock.removeItem).toHaveBeenCalledWith('dp-impersonation-expires')
    expect(localStorageMock.setItem).toHaveBeenCalledWith('dp-session-recovery-login-required', 'true')
    expect(resetRefreshState).toHaveBeenCalled()
  })

  it('reports a confirmed server logout after clearing local auth state', async () => {
    vi.mocked(authApi.logout).mockResolvedValue()
    const store = useAuthStore()
    store.setUser(member)
    localStorageMock.removeItem.mockClear()

    await expect(store.logout()).resolves.toBe(true)

    expect(store.isLoggedIn).toBe(false)
    expect(store.isInitialized).toBe(true)
    expect(localStorageMock.removeItem).toHaveBeenCalledWith('dp-session-recovery-login-required')
  })
})
