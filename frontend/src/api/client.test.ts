import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import axios, { type AxiosAdapter, type InternalAxiosRequestConfig } from 'axios'
import apiClient, {
  resetRefreshState,
  setAuthFailureHandler,
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
  })

  afterEach(() => {
    apiClient.defaults.adapter = originalAdapter
    vi.restoreAllMocks()
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
