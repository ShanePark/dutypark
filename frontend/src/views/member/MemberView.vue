<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <h1 class="text-2xl font-bold text-gray-900 mb-6">설정</h1>
    <div class="bg-white rounded-lg shadow p-6">
      <div class="space-y-4">
        <div>
          <label class="text-sm font-medium text-gray-500">이름</label>
          <p class="text-gray-900">{{ authStore.user?.name }}</p>
        </div>
        <div>
          <label class="text-sm font-medium text-gray-500">이메일</label>
          <p class="text-gray-900">{{ authStore.user?.email }}</p>
        </div>
        <div>
          <label class="text-sm font-medium text-gray-500">팀</label>
          <p class="text-gray-900">{{ authStore.user?.team || '-' }}</p>
        </div>
      </div>
      <p class="text-gray-600 mt-6">회원 설정 콘텐츠 (구현 예정)</p>
    </div>
  </div>
</template>
