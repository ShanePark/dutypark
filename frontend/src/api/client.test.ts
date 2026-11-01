import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import axios, { type AxiosAdapter, type InternalAxiosRequestConfig } from 'axios'
import apiClient, {
  resetRefreshState,
  setAuthFailureHandler,
  setImpersonationHandlers,
} from './client'

function unauthorized(config: InternalAxiosRequestConfig) {
  return {
    config,
    isAxiosError: true,
    response: {
      status: 401,
      data: {},
      headers: {},
      config,
    },
  }
}

describe('api client session recovery', () => {
  const originalAdapter = apiClient.defaults.adapter

  beforeEach(() => {
    resetRefreshState()
    setAuthFailureHandler(vi.fn())
    setImpersonationHandlers(() => false, vi.fn())
  })

  afterEach(() => {
    apiClient.defaults.adapter = originalAdapter
    setImpersonationHandlers(() => false, vi.fn())
    vi.restoreAllMocks()
  })

  it.each([
    [400, false], [403, false], [400, true], [403, true],
  ])('keeps the session for business status %i with impersonation %s', async (status, impersonating) => {
    const authFailure = vi.fn()
    const impersonationExpired = vi.fn()
    setAuthFailureHandler(authFailure)
    setImpersonationHandlers(() => impersonating, impersonationExpired)
    const refresh = vi.spyOn(axios, 'post').mockResolvedValue({ data: {} })
    const adapter = vi.fn(async (config: InternalAxiosRequestConfig) => {
      throw { ...unauthorized(config), response: {
        ...unauthorized(config).response, status,
        data: { code: status === 400 ? 'auth.password.currentMismatch' : 'auth.reauth.impersonationForbidden' },
      } }
    }) as AxiosAdapter
    apiClient.defaults.adapter = adapter
    const log = vi.spyOn(console, 'error').mockImplementation(() => {})

    await expect(apiClient.put('/auth/password', {})).rejects.toMatchObject({ response: { status } })

    expect(adapter).toHaveBeenCalledOnce()
    expect(refresh).not.toHaveBeenCalled()
    expect(authFailure).not.toHaveBeenCalled()
    expect(impersonationExpired).not.toHaveBeenCalled()
    log.mockRestore()
  })

  it('still refreshes a genuine session 401 and replays the request once', async () => {
    const authFailure = vi.fn()
    setAuthFailureHandler(authFailure)
    const refresh = vi.spyOn(axios, 'post').mockResolvedValue({ data: {} })
    let attempt = 0
    const adapter = vi.fn(async (config: InternalAxiosRequestConfig) => {
      if (++attempt === 1) throw unauthorized(config)
      return { data: { id: 1 }, status: 200, statusText: 'OK', headers: {}, config }
    }) as AxiosAdapter
    apiClient.defaults.adapter = adapter

    await expect(apiClient.get('/members/me')).resolves.toMatchObject({ status: 200 })

    expect(refresh).toHaveBeenCalledOnce()
    expect(adapter).toHaveBeenCalledTimes(2)
    expect(authFailure).not.toHaveBeenCalled()
  })

  it('still expires an impersonation session once for genuine concurrent 401 responses', async () => {
    const authFailure = vi.fn()
    const impersonationExpired = vi.fn()
    setAuthFailureHandler(authFailure)
    setImpersonationHandlers(() => true, impersonationExpired)
    const refresh = vi.spyOn(axios, 'post').mockResolvedValue({ data: {} })
    apiClient.defaults.adapter = vi.fn(async (config) => { throw unauthorized(config) }) as AxiosAdapter

    await Promise.allSettled([apiClient.get('/members/me'), apiClient.get('/todos/board')])

    expect(impersonationExpired).toHaveBeenCalledOnce()
    expect(refresh).not.toHaveBeenCalled()
    expect(authFailure).not.toHaveBeenCalled()
  })

  it('lets the auth store handle status 401 without interceptor refresh or redirect', async () => {
    const authFailure = vi.fn()
    setAuthFailureHandler(authFailure)
    const refresh = vi.spyOn(axios, 'post').mockResolvedValue({ data: {} })
    apiClient.defaults.adapter = vi.fn(async (config) => {
      throw unauthorized(config)
    }) as AxiosAdapter

    await expect(apiClient.get('/auth/status')).rejects.toMatchObject({
      response: { status: 401 },
    })

    expect(refresh).not.toHaveBeenCalled()
    expect(authFailure).not.toHaveBeenCalled()
  })

  it('marks every concurrent 401 request before its single replay', async () => {
    let finishRefresh: (() => void) | undefined
    const refresh = vi.spyOn(axios, 'post').mockImplementation(() => new Promise((resolve) => {
      finishRefresh = () => resolve({ data: {} })
    }))
    const attempts = new Map<string, number>()
    const replayRetryFlags: Array<boolean | undefined> = []
    apiClient.defaults.adapter = vi.fn(async (config) => {
      const url = config.url ?? ''
      const attempt = (attempts.get(url) ?? 0) + 1
      attempts.set(url, attempt)
      if (attempt === 1) throw unauthorized(config)
      replayRetryFlags.push((config as InternalAxiosRequestConfig & { _retry?: boolean })._retry)
      return {
        data: {},
        status: 200,
        statusText: 'OK',
        headers: {},
        config,
      }
    }) as AxiosAdapter

    const first = apiClient.get('/members/me')
    await vi.waitFor(() => expect(refresh).toHaveBeenCalledTimes(1))
    const second = apiClient.get('/todos')
    await vi.waitFor(() => expect(attempts.get('/todos')).toBe(1))
    finishRefresh?.()

    await expect(Promise.all([first, second])).resolves.toHaveLength(2)
    expect(refresh).toHaveBeenCalledTimes(1)
    expect(replayRetryFlags).toEqual([true, true])
  })

  it('reports auth failure once when concurrent requests remain unauthorized after refresh', async () => {
    const authFailure = vi.fn()
    setAuthFailureHandler(authFailure)
    const refresh = vi.spyOn(axios, 'post').mockResolvedValue({ data: {} })
    const attempts = new Map<string, number>()
    apiClient.defaults.adapter = vi.fn(async (config) => {
      const url = config.url ?? ''
      attempts.set(url, (attempts.get(url) ?? 0) + 1)
      throw unauthorized(config)
    }) as AxiosAdapter

    const requests = [
      apiClient.get('/members/me'),
      apiClient.get('/todos'),
      apiClient.get('/notifications'),
    ]

    await expect(Promise.all(requests)).rejects.toMatchObject({ response: { status: 401 } })
    await Promise.allSettled(requests)

    expect(refresh).toHaveBeenCalledTimes(1)
    expect(attempts.get('/members/me')).toBe(2)
    expect(attempts.get('/todos')).toBe(2)
    expect(attempts.get('/notifications')).toBe(2)
    expect(authFailure).toHaveBeenCalledTimes(1)
  })

  it.each([
    [{ code: 'ERR_NETWORK' }, 'offline'],
    [{ code: 'ECONNABORTED' }, 'timeout'],
    [{ response: { status: 503 } }, 'server error'],
  ])('allows a later request to retry refresh after a transient %s (%s)', async (refreshError, _label) => {
    const refresh = vi.spyOn(axios, 'post')
      .mockRejectedValueOnce(refreshError)
      .mockResolvedValueOnce({ data: {} })
    const attempts = new Map<string, number>()
    apiClient.defaults.adapter = vi.fn(async (config) => {
      const url = config.url ?? ''
      const attempt = (attempts.get(url) ?? 0) + 1
      attempts.set(url, attempt)
      if (attempt === 1) throw unauthorized(config)
      return {
        data: {},
        status: 200,
        statusText: 'OK',
        headers: {},
        config,
      }
    }) as AxiosAdapter

    await expect(apiClient.get('/members/me')).rejects.toBe(refreshError)
    await expect(apiClient.get('/todos')).resolves.toMatchObject({ status: 200 })

    expect(refresh).toHaveBeenCalledTimes(2)
  })
})
