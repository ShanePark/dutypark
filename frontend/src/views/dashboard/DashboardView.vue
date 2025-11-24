<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <template v-if="authStore.isLoggedIn">
      <h1 class="text-2xl font-bold text-gray-900 mb-6">
        {{ authStore.user?.name }}님, 안녕하세요!
      </h1>
      <!-- Dashboard content will be implemented -->
      <div class="bg-white rounded-lg shadow p-6">
        <p class="text-gray-600">대시보드 콘텐츠 (구현 예정)</p>
      </div>
    </template>
    <template v-else>
      <div class="text-center py-12">
        <h1 class="text-3xl font-bold text-gray-900 mb-4">Dutypark</h1>
        <p class="text-gray-600 mb-8">당직 일정을 쉽게 관리하세요</p>
        <router-link
          to="/auth/login"
          class="inline-block bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition"
        >
          로그인하기
        </router-link>
      </div>
    </template>
  </div>
</template>
