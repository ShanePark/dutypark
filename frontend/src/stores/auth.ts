import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { LoginMember, LoginDto } from '@/types'
import { authApi } from '@/api/auth'
import { tokenManager } from '@/api/client'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<LoginMember | null>(null)
  const isLoading = ref(false)
  const isInitialized = ref(false)

  const isLoggedIn = computed(() => user.value !== null)
  const isAdmin = computed(() => user.value?.isAdmin ?? false)

  async function initialize() {
    if (isInitialized.value) return

    isLoading.value = true
    try {
      // 토큰이 있으면 사용자 정보 조회
      if (authApi.hasTokens()) {
        user.value = await authApi.getStatus()
        // 토큰이 있지만 사용자 정보를 못 가져오면 토큰 클리어
        if (!user.value) {
          tokenManager.clearTokens()
        }
      }
    } catch {
      user.value = null
      tokenManager.clearTokens()
    } finally {
      isLoading.value = false
      isInitialized.value = true
    }
  }

  async function login(data: LoginDto): Promise<void> {
    isLoading.value = true
    try {
      // Bearer 토큰 방식 로그인
      await authApi.loginWithToken(data)
      user.value = await authApi.getStatus()
    } finally {
      isLoading.value = false
    }
  }

  async function logout() {
    await authApi.logout()
    user.value = null
  }

  function setUser(member: LoginMember | null) {
    user.value = member
  }

  function clearAuth() {
    user.value = null
    tokenManager.clearTokens()
    isInitialized.value = false
  }

  async function checkAuth(): Promise<void> {
    isLoading.value = true
    try {
      user.value = await authApi.getStatus()
      isInitialized.value = true
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
