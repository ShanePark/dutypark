import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { LoginMember, LoginDto } from '@/types'
import { authApi } from '@/api/auth'

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
      user.value = await authApi.getStatus()
    } catch {
      user.value = null
    } finally {
      isLoading.value = false
      isInitialized.value = true
    }
  }

  async function login(data: LoginDto): Promise<string> {
    isLoading.value = true
    try {
      const redirectUrl = await authApi.login(data)
      user.value = await authApi.getStatus()
      return redirectUrl
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
  }
})
