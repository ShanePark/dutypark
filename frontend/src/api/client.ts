import axios, {
  type AxiosInstance,
  type AxiosError,
  type InternalAxiosRequestConfig,
} from 'axios'
import type { ApiError } from '@/types'

let isRefreshing = false
let refreshFailed = false
let failedQueue: Array<{
  resolve: (value?: unknown) => void
  reject: (reason?: unknown) => void
}> = []

// Callback for handling auth failure - set by auth store
let onAuthFailure: (() => void) | null = null

export function setAuthFailureHandler(handler: () => void) {
  onAuthFailure = handler
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
                           originalRequest?.url?.includes('/auth/logout')

    // Handle 401 - try to refresh token
    if (error.response?.status === 401 && originalRequest && !originalRequest._retry) {
      if (isAuthEndpoint) {
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

// Reset refresh failed flag when needed (e.g., after successful login)
export function resetRefreshState() {
  refreshFailed = false
  isRefreshing = false
  failedQueue = []
}

export default apiClient
