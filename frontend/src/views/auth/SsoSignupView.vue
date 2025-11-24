<script setup lang="ts">
import { ref } from 'vue'

const username = ref('')
const termAgree = ref(false)
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-50 px-4">
    <div class="max-w-md w-full">
      <div class="text-center mb-8">
        <h1 class="text-3xl font-bold text-gray-900">회원가입</h1>
        <p class="text-gray-600 mt-2">Dutypark에 오신 것을 환영합니다</p>
      </div>

      <div class="bg-white rounded-lg shadow-md p-6">
        <form class="space-y-4">
          <div>
            <label for="username" class="block text-sm font-medium text-gray-700 mb-1">
              사용자명
            </label>
            <input
              id="username"
              v-model="username"
              type="text"
              required
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="사용자명을 입력하세요"
            />
          </div>

          <div class="flex items-center">
            <input
              id="termAgree"
              v-model="termAgree"
              type="checkbox"
              required
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
            />
            <label for="termAgree" class="ml-2 text-sm text-gray-600">
              이용약관에 동의합니다
            </label>
          </div>

          <button
            type="submit"
            :disabled="!termAgree"
            class="w-full bg-blue-600 text-white py-2 px-4 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition"
          >
            가입하기
          </button>
        </form>
      </div>
    </div>
  </div>
</template>
