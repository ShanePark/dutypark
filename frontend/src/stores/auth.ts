import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { AxiosError } from 'axios'
import type { LoginMember, LoginDto } from '@/types'
import { authApi } from '@/api/auth'
import { setAuthFailureHandler, setImpersonationHandlers, resetRefreshState } from '@/api/client'
import router from '@/router'

const USER_CACHE_KEY = 'dp-login-member'
const IMPERSONATION_EXPIRES_KEY = 'dp-impersonation-expires'

function loadCachedUser(): LoginMember | null {
  try {
    const cached = localStorage.getItem(USER_CACHE_KEY)
    return cached ? (JSON.parse(cached) as LoginMember) : null
  } catch {
    return null
  }
}

function saveCachedUser(member: LoginMember | null) {
  if (!member) {
    localStorage.removeItem(USER_CACHE_KEY)
    return
  }
  localStorage.setItem(USER_CACHE_KEY, JSON.stringify(member))
}

function loadImpersonationExpiresAt(): number | null {
  try {
    const cached = localStorage.getItem(IMPERSONATION_EXPIRES_KEY)
    return cached ? parseInt(cached, 10) : null
  } catch {
    return null
  }
}

function saveImpersonationExpiresAt(expiresAt: number | null) {
  if (expiresAt === null) {
    localStorage.removeItem(IMPERSONATION_EXPIRES_KEY)
    return
  }
  localStorage.setItem(IMPERSONATION_EXPIRES_KEY, expiresAt.toString())
}

export const useAuthStore = defineStore('auth', () => {
  const user = ref<LoginMember | null>(loadCachedUser())
  const isLoading = ref(false)
  const isInitialized = ref(false)
  const impersonationExpiresAt = ref<number | null>(loadImpersonationExpiresAt())

  // Impersonation state derived from user's JWT token
  const isImpersonating = computed(() => user.value?.isImpersonating ?? false)

  const isLoggedIn = computed(() => user.value !== null)
  const isAdmin = computed(() => user.value?.isAdmin ?? false)

  // Cache the initialization promise to prevent duplicate calls
  let initializePromise: Promise<void> | null = null

  async function initialize() {
    if (isInitialized.value) return
    if (initializePromise) return initializePromise

    initializePromise = doInitialize()
    return initializePromise
  }

  async function doInitialize() {
    isLoading.value = true
    try {
      // First check status - may return null if access token expired
      let status: LoginMember | null = null
      let isServerUnavailable = false

      try {
        status = await authApi.getStatus()
      } catch (error) {
        const axiosError = error as AxiosError
        const responseStatus = axiosError.response?.status
        // Keep cached user on network errors or server errors (5xx)
        isServerUnavailable = !axiosError.response || (responseStatus !== undefined && responseStatus >= 500)
      }

      // If not logged in but refresh token might exist, try refreshing
      if (!status && !isServerUnavailable) {
        try {
          await authApi.refresh()
          resetRefreshState()
          status = await authApi.getStatus()
        } catch {
          // Refresh failed - no valid session
        }
      }

      // Only update state if server responded properly
      if (!isServerUnavailable) {
        user.value = status
        saveCachedUser(status)
      }
      // On server unavailable, keep cached user (already loaded from localStorage)
    } finally {
      isLoading.value = false
      isInitialized.value = true
      initializePromise = null
    }
  }

  async function login(data: LoginDto): Promise<void> {
    isLoading.value = true
    try {
      await authApi.login(data)
      resetRefreshState()
      user.value = await authApi.getStatus()
      saveCachedUser(user.value)
    } finally {
      isLoading.value = false
    }
  }

  async function logout() {
    await authApi.logout()
    user.value = null
    saveCachedUser(null)
    impersonationExpiresAt.value = null
    saveImpersonationExpiresAt(null)
  }

  function setUser(member: LoginMember | null) {
    user.value = member
    saveCachedUser(member)
  }

  function clearAuth() {
    user.value = null
    saveCachedUser(null)
    impersonationExpiresAt.value = null
    saveImpersonationExpiresAt(null)
    isInitialized.value = false
  }

  function handleAuthFailure() {
    clearAuth()
    router.push('/auth/login')
  }

  function handleImpersonationExpired() {
    // Clear impersonation state and redirect to login
    // The restore API requires valid access token which is already expired
    impersonationExpiresAt.value = null
    saveImpersonationExpiresAt(null)
    clearAuth()
    router.push('/auth/login')
  }

  // Register auth failure handler with API client
  setAuthFailureHandler(handleAuthFailure)

  // Register impersonation handlers with API client
  setImpersonationHandlers(
    () => isImpersonating.value,
    handleImpersonationExpired
  )

  async function checkAuth(): Promise<void> {
    isLoading.value = true
    try {
      user.value = await authApi.getStatus()
      isInitialized.value = true
      saveCachedUser(user.value)
    } catch (error) {
      const status = (error as AxiosError)?.response?.status
      if (status === 401 || status === 403) {
        user.value = null
        saveCachedUser(null)
      }
      throw error
    } finally {
      isLoading.value = false
    }
  }

  async function impersonate(targetMemberId: number): Promise<void> {
    isLoading.value = true
    try {
      const response = await authApi.impersonate(targetMemberId)

      // Calculate and save expiration time
      const expiresAt = Date.now() + response.expiresIn * 1000
      impersonationExpiresAt.value = expiresAt
      saveImpersonationExpiresAt(expiresAt)

      // Refresh user info after impersonation (includes isImpersonating from JWT)
      user.value = await authApi.getStatus()
      saveCachedUser(user.value)
    } finally {
      isLoading.value = false
    }
  }

  async function restore(): Promise<void> {
    isLoading.value = true
    try {
      await authApi.restore()

      // Clear impersonation expiration
      impersonationExpiresAt.value = null
      saveImpersonationExpiresAt(null)

      // Refresh user info after restore (isImpersonating will be false)
      user.value = await authApi.getStatus()
      saveCachedUser(user.value)
    } finally {
      isLoading.value = false
    }
  }

  return {
    user,
    isLoading,
    isInitialized,
    isLoggedIn,
    isAdmin,
    isImpersonating,
    impersonationExpiresAt,
    initialize,
    login,
    logout,
    setUser,
    clearAuth,
    checkAuth,
    impersonate,
    restore,
  }
})
