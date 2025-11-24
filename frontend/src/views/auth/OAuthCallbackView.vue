<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { tokenManager } from '@/api/client'

const router = useRouter()
const authStore = useAuthStore()

const error = ref('')
const isLoading = ref(true)

onMounted(async () => {
  const hash = window.location.hash.substring(1)
  const params = new URLSearchParams(hash)

  const errorParam = params.get('error')
  if (errorParam === 'sso_required') {
    const uuid = params.get('uuid')
    router.replace(`/auth/sso-signup?uuid=${uuid}`)
    return
  }

  const accessToken = params.get('access_token')
  const refreshToken = params.get('refresh_token')

  if (!accessToken || !refreshToken) {
    error.value = '인증 정보를 받지 못했습니다.'
    isLoading.value = false
    return
  }

  tokenManager.setTokens(accessToken, refreshToken)

  try {
    await authStore.checkAuth()
    router.replace('/')
  } catch {
    error.value = '인증에 실패했습니다.'
    tokenManager.clearTokens()
    isLoading.value = false
  }
})
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-100">
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-8 max-w-md w-full mx-4">
      <div v-if="isLoading" class="text-center">
        <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
        <p class="text-gray-600">로그인 처리 중...</p>
      </div>

      <div v-else-if="error" class="text-center">
        <div class="text-red-500 text-5xl mb-4">!</div>
        <h2 class="text-xl font-bold text-gray-900 mb-2">로그인 실패</h2>
        <p class="text-gray-600 mb-4">{{ error }}</p>
        <router-link
          to="/auth/login"
          class="inline-block bg-blue-600 text-white py-2 px-4 rounded-lg hover:bg-blue-700 transition"
        >
          로그인 페이지로 이동
        </router-link>
      </div>
    </div>
  </div>
</template>
