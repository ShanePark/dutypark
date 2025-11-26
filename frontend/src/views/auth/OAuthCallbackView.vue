<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

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

  const loginSuccess = params.get('login')
  if (loginSuccess !== 'success') {
    error.value = '인증 정보를 받지 못했습니다.'
    isLoading.value = false
    return
  }

  try {
    await authStore.checkAuth()
    router.replace('/')
  } catch {
    error.value = '인증에 실패했습니다.'
    isLoading.value = false
  }
})
</script>

<template>
  <div class="min-h-screen flex items-center justify-center" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
    <div class="rounded-xl shadow-sm p-8 max-w-md w-full mx-4" :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }">
      <div v-if="isLoading" class="text-center">
        <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
        <p :style="{ color: 'var(--dp-text-secondary)' }">로그인 처리 중...</p>
      </div>

      <div v-else-if="error" class="text-center">
        <div class="text-red-500 text-5xl mb-4">!</div>
        <h2 class="text-xl font-bold mb-2" :style="{ color: 'var(--dp-text-primary)' }">로그인 실패</h2>
        <p class="mb-4" :style="{ color: 'var(--dp-text-secondary)' }">{{ error }}</p>
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
