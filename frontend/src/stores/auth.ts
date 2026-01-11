import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { AxiosError } from 'axios'
import type { LoginMember, LoginDto } from '@/types'
import { authApi } from '@/api/auth'
import { setAuthFailureHandler } from '@/api/client'
import router from '@/router'

const USER_CACHE_KEY = 'dp-login-member'

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

export const useAuthStore = defineStore('auth', () => {
  const user = ref<LoginMember | null>(loadCachedUser())
  const isLoading = ref(false)
  const isInitialized = ref(false)

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
      // Check auth status - if token expired, axios interceptor auto-refreshes
      try {
        user.value = await authApi.getStatus()
        saveCachedUser(user.value)
      } catch (error) {
        const status = (error as AxiosError)?.response?.status
        if (status === 401 || status === 403) {
          user.value = null
          saveCachedUser(null)
        } else {
          console.warn('Failed to check login status, keeping cached user', error)
        }
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
  }

  function setUser(member: LoginMember | null) {
    user.value = member
    saveCachedUser(member)
  }

  function clearAuth() {
    user.value = null
    saveCachedUser(null)
    isInitialized.value = false
  }

  function handleAuthFailure() {
    clearAuth()
    router.push('/auth/login')
  }

  // Register auth failure handler with API client
  setAuthFailureHandler(handleAuthFailure)

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
      await authApi.impersonate(targetMemberId)

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
