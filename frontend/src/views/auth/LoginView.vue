<script setup lang="ts">
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { AxiosError } from 'axios'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

const email = ref('')
const password = ref('')
const rememberMe = ref(false)
const isLoading = ref(false)
const error = ref('')

async function handleLogin() {
  error.value = ''
  isLoading.value = true

  try {
    await authStore.login({
      email: email.value,
      password: password.value,
      rememberMe: rememberMe.value,
    })

    const redirect = (route.query.redirect as string) || '/'
    router.push(redirect)
  } catch (e: unknown) {
    if (e instanceof AxiosError && e.response?.data?.error) {
      error.value = e.response.data.error
    } else {
      error.value = '로그인에 실패했습니다. 이메일과 비밀번호를 확인해주세요.'
    }
  } finally {
    isLoading.value = false
  }
}

</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-100 px-4">
    <div class="w-full max-w-md">
      <!-- Login Card -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-6">로그인</h1>
        <hr class="mb-6">

        <form @submit.prevent="handleLogin" class="space-y-4">
          <!-- Email Field -->
          <div>
            <label for="email" class="block text-sm font-medium text-gray-700 mb-1">
              이메일
            </label>
            <input
              id="email"
              v-model="email"
              type="text"
              autocomplete="email"
              class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition"
              placeholder="이메일 주소"
            />
            <div class="flex items-center mt-2">
              <input
                id="rememberMe"
                v-model="rememberMe"
                type="checkbox"
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label for="rememberMe" class="ml-2 text-sm text-gray-600">
                아이디 저장
              </label>
            </div>
          </div>

          <!-- Password Field -->
          <div>
            <label for="password" class="block text-sm font-medium text-gray-700 mb-1">
              비밀번호
            </label>
            <input
              id="password"
              v-model="password"
              type="password"
              required
              autocomplete="current-password"
              class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition"
              placeholder="비밀번호"
            />
          </div>

          <!-- Error Message -->
          <div v-if="error" class="text-red-600 text-sm bg-red-50 p-3 rounded-lg">
            {{ error }}
          </div>

          <!-- Login Button -->
          <button
            type="submit"
            :disabled="isLoading"
            class="w-full bg-blue-600 text-white py-3 px-4 rounded-lg font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition"
          >
            {{ isLoading ? '로그인 중...' : '로그인' }}
          </button>

          <!-- Divider -->
          <div class="relative my-6">
            <div class="absolute inset-0 flex items-center">
              <div class="w-full border-t border-gray-300"></div>
            </div>
            <div class="relative flex justify-center text-sm">
              <span class="px-4 bg-white text-gray-500">또는</span>
            </div>
          </div>

          <!-- Kakao Login Button -->
          <a
            href="/oauth2/authorization/kakao"
            class="w-full py-3 px-4 rounded-lg font-medium transition flex items-center justify-center gap-3 hover:opacity-90"
            style="background-color: #FEE500; color: #000000;"
          >
            <img src="/img/kakao.png" alt="Kakao" class="w-6 h-6" />
            <span>카카오 로그인</span>
          </a>
        </form>
      </div>
    </div>
  </div>
</template>
