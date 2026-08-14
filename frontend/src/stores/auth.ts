import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { AxiosError } from 'axios'
import type { LoginMember, LoginDto } from '@/types'
import { authApi } from '@/api/auth'
import { setAuthFailureHandler, setImpersonationHandlers, resetRefreshState } from '@/api/client'
import router from '@/router'
import { buildLoginRoute } from '@/utils/redirect'

const USER_CACHE_KEY = 'dp-login-member'
const IMPERSONATION_EXPIRES_KEY = 'dp-impersonation-expires'
const EXPLICIT_LOGIN_REQUIRED_KEY = 'dp-session-recovery-login-required'

function isTransientSessionError(error: unknown): boolean {
  const axiosError = error as AxiosError
  const status = axiosError.response?.status
  return !axiosError.response || (status !== undefined && status >= 500)
}

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

function requiresExplicitLogin(): boolean {
  try {
    return localStorage.getItem(EXPLICIT_LOGIN_REQUIRED_KEY) === 'true'
  } catch {
    return false
  }
}

function saveExplicitLoginRequired(required: boolean) {
  if (required) {
    localStorage.setItem(EXPLICIT_LOGIN_REQUIRED_KEY, 'true')
    return
  }
  localStorage.removeItem(EXPLICIT_LOGIN_REQUIRED_KEY)
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
  const sessionCheckFailed = ref(false)
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
    sessionCheckFailed.value = false
    try {
      if (requiresExplicitLogin()) {
        user.value = null
        saveCachedUser(null)
        sessionCheckFailed.value = true
        return
      }

      let status: LoginMember | null = null

      try {
        status = await authApi.getStatus()
      } catch (error) {
        if (isTransientSessionError(error)) {
          user.value = null
          saveCachedUser(null)
          sessionCheckFailed.value = true
          saveExplicitLoginRequired(true)
          return
        }
      }

      if (!status) {
        try {
          await authApi.refresh()
          resetRefreshState()
          status = await authApi.getStatus()
        } catch (error) {
          sessionCheckFailed.value = isTransientSessionError(error)
          saveExplicitLoginRequired(sessionCheckFailed.value)
          status = null
        }
      }

      user.value = status
      saveCachedUser(status)
      if (!sessionCheckFailed.value) {
        saveExplicitLoginRequired(false)
      }
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
      sessionCheckFailed.value = false
      saveExplicitLoginRequired(false)
    } finally {
      isLoading.value = false
    }
  }

  async function logout(): Promise<boolean> {
    let serverSessionCleared = true
    try {
      await authApi.logout()
    } catch {
      serverSessionCleared = false
    } finally {
      user.value = null
      saveCachedUser(null)
      impersonationExpiresAt.value = null
      saveImpersonationExpiresAt(null)
      sessionCheckFailed.value = false
      saveExplicitLoginRequired(!serverSessionCleared)
      isLoading.value = false
      isInitialized.value = true
      initializePromise = null
      resetRefreshState()
    }
    return serverSessionCleared
  }

  function setUser(member: LoginMember | null) {
    user.value = member
    saveCachedUser(member)
    sessionCheckFailed.value = false
    saveExplicitLoginRequired(false)
  }

  function clearAuth() {
    user.value = null
    saveCachedUser(null)
    impersonationExpiresAt.value = null
    saveImpersonationExpiresAt(null)
    sessionCheckFailed.value = false
    saveExplicitLoginRequired(false)
    isInitialized.value = false
  }

  function completeAccountDeletion() {
    user.value = null
    saveCachedUser(null)
    impersonationExpiresAt.value = null
    saveImpersonationExpiresAt(null)
    isLoading.value = false
    isInitialized.value = true
    sessionCheckFailed.value = false
    saveExplicitLoginRequired(false)
    initializePromise = null
    resetRefreshState()
  }

  function handleAuthFailure() {
    clearAuth()
    // Do not let the login-route guard immediately retry the failed session.
    isInitialized.value = true
    router.push(buildLoginRoute(router.currentRoute.value.fullPath))
  }

  function handleImpersonationExpired() {
    // Clear impersonation state and redirect to login
    // The restore API requires valid access token which is already expired
    impersonationExpiresAt.value = null
    saveImpersonationExpiresAt(null)
    clearAuth()
    isInitialized.value = true
    router.push(buildLoginRoute(router.currentRoute.value.fullPath))
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
      sessionCheckFailed.value = false
      saveExplicitLoginRequired(false)
    } catch (error) {
      const status = (error as AxiosError)?.response?.status
      if (status === 401 || status === 403) {
        user.value = null
        saveCachedUser(null)
        sessionCheckFailed.value = false
      } else if (isTransientSessionError(error)) {
        sessionCheckFailed.value = true
        saveExplicitLoginRequired(true)
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
      sessionCheckFailed.value = false
      saveExplicitLoginRequired(false)
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
      sessionCheckFailed.value = false
      saveExplicitLoginRequired(false)
    } finally {
      isLoading.value = false
    }
  }

  return {
    user,
    isLoading,
    isInitialized,
    sessionCheckFailed,
    isLoggedIn,
    isAdmin,
    isImpersonating,
    impersonationExpiresAt,
    initialize,
    login,
    logout,
    setUser,
    clearAuth,
    completeAccountDeletion,
    checkAuth,
    impersonate,
    restore,
  }
})
