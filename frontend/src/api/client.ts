import axios, {
  type AxiosInstance,
  type AxiosError,
  type InternalAxiosRequestConfig,
} from 'axios'
import type { ApiError } from '@/types'

let isRefreshing = false
let refreshFailed = false
let impersonationExpiredHandled = false
let failedQueue: Array<{
  resolve: (value?: unknown) => void
  reject: (reason?: unknown) => void
}> = []

// Callback for handling auth failure - set by auth store
let onAuthFailure: (() => void) | null = null

// Callback for checking if currently impersonating - set by auth store
let isImpersonatingChecker: (() => boolean) | null = null

// Callback for handling impersonation session expiration
let onImpersonationExpired: (() => void) | null = null

export function setAuthFailureHandler(handler: () => void) {
  onAuthFailure = handler
}

export function setImpersonationHandlers(
  checker: () => boolean,
  onExpired: () => void
) {
  isImpersonatingChecker = checker
  onImpersonationExpired = onExpired
}

export function resetRefreshState() {
  refreshFailed = false
  impersonationExpiredHandled = false
}

const processQueue = (error: Error | null) => {
  failedQueue.forEach((prom) => {
    if (error) {
      prom.reject(error)
    } else {
      prom.resolve()
    }
  })
  failedQueue = []
}

const apiClient: AxiosInstance = axios.create({
  baseURL: '/api',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true,
})

// Request interceptor - handle FormData content type
apiClient.interceptors.request.use((config) => {
  if (config.data instanceof FormData) {
    delete config.headers['Content-Type']
  }
  return config
})

// Response interceptor - handle 401 and refresh token via HttpOnly cookies
apiClient.interceptors.response.use(
  (response) => response,
  async (error: AxiosError<ApiError>) => {
    const originalRequest = error.config as InternalAxiosRequestConfig & {
      _retry?: boolean
    }

    // Skip auto-refresh for auth endpoints
    const isAuthEndpoint = originalRequest?.url?.includes('/auth/token') ||
                           originalRequest?.url?.includes('/auth/login') ||
                           originalRequest?.url?.includes('/auth/refresh') ||
                           originalRequest?.url?.includes('/auth/logout') ||
                           originalRequest?.url?.includes('/auth/restore') ||
                           originalRequest?.url?.includes('/auth/impersonate')

    // Handle 401 - try to refresh token
    if (error.response?.status === 401 && originalRequest && !originalRequest._retry) {
      if (isAuthEndpoint) {
        return Promise.reject(error)
      }

      // If impersonating, don't try to refresh - trigger expiration handler instead
      if (isImpersonatingChecker?.()) {
        if (onImpersonationExpired && !impersonationExpiredHandled) {
          impersonationExpiredHandled = true
          onImpersonationExpired()
        }
        return Promise.reject(error)
      }

      // If refresh already failed, don't retry
      if (refreshFailed) {
        return Promise.reject(error)
      }

      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject })
        })
          .then(() => apiClient(originalRequest))
          .catch((err) => Promise.reject(err))
      }

      originalRequest._retry = true
      isRefreshing = true

      try {
        // Cookie is sent automatically via withCredentials
        await axios.post('/api/auth/refresh', {}, { withCredentials: true })

        // Reset refresh failure flag on successful refresh
        refreshFailed = false
        processQueue(null)

        return apiClient(originalRequest)
      } catch (refreshError) {
        processQueue(refreshError as Error)

        const axiosError = refreshError as AxiosError
        const status = axiosError.response?.status
        const isNetworkError = axiosError.code === 'ERR_NETWORK' || !axiosError.response

        // Keep session when server is down or returning 5xx
        if (isNetworkError || (status !== undefined && status >= 500)) {
          return Promise.reject(refreshError)
        }

        // Mark refresh as failed to prevent infinite loops
        refreshFailed = true

        // Clear auth state and redirect to login
        if (onAuthFailure) {
          onAuthFailure()
        }

        return Promise.reject(refreshError)
      } finally {
        isRefreshing = false
      }
    }

    if (error.response?.status === 403) {
      console.error('Access denied')
    }

    return Promise.reject(error)
  }
)

export default apiClient
