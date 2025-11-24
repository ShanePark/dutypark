<script setup lang="ts">
import { onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const username = computed(() => authStore.user?.name || '')

onMounted(() => {
  // 로그인 안 되어 있으면 홈으로 리다이렉트
  if (!authStore.isLoggedIn) {
    router.push('/')
  }
})

function goHome() {
  router.push('/')
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-white sm:bg-gray-100 px-4 pb-safe pt-safe">
    <div class="w-full max-w-md">
      <!-- Congrats Card -->
      <div class="bg-white rounded-2xl shadow-lg sm:shadow-xl p-6 sm:p-8 text-center">
        <!-- Header -->
        <h1 class="text-2xl sm:text-3xl font-bold text-gray-900 mb-6">
          회원 가입 성공 🎉
        </h1>

        <hr class="mb-6">

        <!-- Body -->
        <div class="space-y-4 mb-8">
          <p class="text-lg sm:text-xl text-gray-800 font-medium">
            {{ username }} 님, 환영합니다!
          </p>
          <p class="text-gray-600">
            지금부터 Dutypark 서비스를 이용하실 수 있습니다.
          </p>
        </div>

        <!-- Home Button -->
        <button
          type="button"
          @click="goHome"
          class="w-full bg-blue-600 text-white py-3 px-4 rounded-lg font-medium hover:bg-blue-700 transition cursor-pointer"
        >
          홈으로
        </button>
      </div>
    </div>
  </div>
</template>
