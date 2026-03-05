<script setup lang="ts">
import { onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const username = computed(() => authStore.user?.name || '')

onMounted(() => {
  if (!authStore.isLoggedIn) {
    router.push('/')
  }
})

function goHome() {
  router.push('/')
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center px-4 pb-safe pt-safe" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
    <div class="w-full max-w-md">
      <div class="rounded-2xl shadow-lg sm:shadow-xl p-6 sm:p-8 text-center" :style="{ backgroundColor: 'var(--dp-bg-card)' }">
        <h1 class="text-2xl sm:text-3xl font-bold mb-6" :style="{ color: 'var(--dp-text-primary)' }">
          회원 가입 성공 🎉
        </h1>

        <hr class="mb-6" :style="{ borderColor: 'var(--dp-border-primary)' }">

        <div class="space-y-4 mb-8">
          <p class="text-lg sm:text-xl font-medium" :style="{ color: 'var(--dp-text-primary)' }">
            {{ username }} 님, 환영합니다!
          </p>
          <p :style="{ color: 'var(--dp-text-secondary)' }">
            지금부터 Dutypark 서비스를 이용하실 수 있습니다.
          </p>
        </div>

        <button
          type="button"
          @click="goHome"
          class="w-full bg-dp-accent text-dp-text-on-dark py-3 px-4 rounded-lg font-medium hover:bg-dp-accent-hover transition cursor-pointer"
        >
          홈으로
        </button>
      </div>
    </div>
  </div>
</template>
