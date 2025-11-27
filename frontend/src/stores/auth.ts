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

  const isLoggedIn = computed(() => user.value !== null)
  const isAdmin = computed(() => user.value?.isAdmin ?? false)

  async function initialize() {
    if (isInitialized.value) return

    isLoading.value = true
    try {
      // Try to refresh access token first (in case only refresh token exists)
      try {
        await authApi.refresh()
      } catch {
        // Ignore refresh failure - user may not have refresh token
      }

      // Check auth status via cookie (sent automatically)
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

  return {
    user,
    isLoading,
    isInitialized,
    isLoggedIn,
    isAdmin,
    initialize,
    login,
    logout,
    setUser,
    clearAuth,
    checkAuth,
  }
})
