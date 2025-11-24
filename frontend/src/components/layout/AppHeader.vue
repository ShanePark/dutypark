<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'
import { useSwal } from '@/composables/useSwal'

const authStore = useAuthStore()
const { confirm } = useSwal()

const handleLogout = async () => {
  const confirmed = await confirm('정말 로그아웃 하시겠습니까?', '로그아웃')
  if (confirmed) {
    authStore.logout()
  }
}
</script>

<template>
  <header class="bg-white shadow-sm border-b border-gray-200">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between items-center h-14">
        <router-link to="/" class="text-xl font-bold text-gray-900">
          Dutypark
        </router-link>
        <nav class="flex items-center gap-4">
          <template v-if="authStore.isLoggedIn">
            <span class="text-sm text-gray-600">{{ authStore.user?.name }}</span>
            <button
              @click="handleLogout"
              class="text-sm text-gray-500 hover:text-gray-700"
            >
              로그아웃
            </button>
          </template>
          <template v-else>
            <router-link
              to="/auth/login"
              class="text-sm text-blue-600 hover:text-blue-800"
            >
              로그인
            </router-link>
          </template>
        </nav>
      </div>
    </div>
  </header>
</template>
