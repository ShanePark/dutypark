import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { AxiosError } from 'axios'
import type { LoginMember, LoginDto } from '@/types'
import { authApi } from '@/api/auth'
import { tokenManager } from '@/api/client'

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
  const user = ref<LoginMember | null>(tokenManager.hasTokens() ? loadCachedUser() : null)
  const isLoading = ref(false)
  const isInitialized = ref(false)

  const isLoggedIn = computed(() => user.value !== null)
  const hasTokens = computed(() => tokenManager.hasTokens())
  const isAdmin = computed(() => user.value?.isAdmin ?? false)

  async function initialize() {
    if (isInitialized.value) return

    isLoading.value = true
    try {
      const refreshToken = tokenManager.getRefreshToken()
      if (hasTokens.value || refreshToken) {
        try {
          user.value = await authApi.getStatus()
          saveCachedUser(user.value)
        } catch (error) {
          const status = (error as AxiosError)?.response?.status
          if (status === 401 || status === 403) {
            tokenManager.clearTokens()
            user.value = null
            saveCachedUser(null)
          } else {
            console.warn('로그인 상태 확인 실패: 서버 오류 또는 네트워크 문제로 토큰을 유지합니다.', error)
          }
          return
        }

        if (!user.value && refreshToken) {
          try {
            await authApi.refresh(refreshToken)
            user.value = await authApi.getStatus()
            saveCachedUser(user.value)
          } catch (error) {
            const status = (error as AxiosError)?.response?.status
            if (status === 401 || status === 403) {
              tokenManager.clearTokens()
              user.value = null
              saveCachedUser(null)
            } else {
              console.warn('토큰 갱신 실패: 서버 오류 또는 네트워크 문제로 토큰을 유지합니다.', error)
            }
            return
          }
        }

        if (!user.value) {
          tokenManager.clearTokens()
          saveCachedUser(null)
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
      await authApi.loginWithToken(data)
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
  }

  function clearAuth() {
    user.value = null
    tokenManager.clearTokens()
    saveCachedUser(null)
    isInitialized.value = false
  }

  async function checkAuth(): Promise<void> {
    isLoading.value = true
    try {
      user.value = await authApi.getStatus()
      isInitialized.value = true
      saveCachedUser(user.value)
    } catch (error) {
      const status = (error as AxiosError)?.response?.status
      if (status === 401 || status === 403) {
        tokenManager.clearTokens()
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
    hasTokens,
    isAdmin,
    initialize,
    login,
    logout,
    setUser,
    clearAuth,
    checkAuth,
  }
})
