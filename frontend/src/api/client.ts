import axios, { type AxiosInstance, type AxiosError, type InternalAxiosRequestConfig } from 'axios'
import type { ApiError } from '@/types'

const apiClient: AxiosInstance = axios.create({
  baseURL: '/api',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // Include cookies for auth
})

// Request interceptor
apiClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    // Bearer token can be added here if stored in localStorage
    // const token = localStorage.getItem('accessToken')
    // if (token) {
    //   config.headers.Authorization = `Bearer ${token}`
    // }
    return config
  },
  (error) => Promise.reject(error)
)

// Response interceptor
apiClient.interceptors.response.use(
  (response) => response,
  async (error: AxiosError<ApiError>) => {
    const originalRequest = error.config

    // Handle 401 - try to refresh token
    if (error.response?.status === 401 && originalRequest) {
      // Cookie-based refresh is handled automatically by the backend
      // If still 401, redirect to login
      window.location.href = '/auth/login'
      return Promise.reject(error)
    }

    // Handle other errors
    if (error.response?.status === 403) {
      console.error('Access denied')
    }

    return Promise.reject(error)
  }
)

export default apiClient
