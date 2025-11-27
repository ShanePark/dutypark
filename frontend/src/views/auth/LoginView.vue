<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useKakao } from '@/composables/useKakao'
import { AxiosError } from 'axios'

const REMEMBER_EMAIL_KEY = 'dp-remember-email'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const { initKakao, kakaoLogin } = useKakao()

const email = ref('')
const password = ref('')
const rememberMe = ref(false)
const isLoading = ref(false)
const error = ref('')

onMounted(() => {
  initKakao()

  const savedEmail = localStorage.getItem(REMEMBER_EMAIL_KEY)
  if (savedEmail) {
    email.value = savedEmail
    rememberMe.value = true
  }
})

async function handleLogin() {
  error.value = ''
  isLoading.value = true

  try {
    await authStore.login({
      email: email.value,
      password: password.value,
      rememberMe: rememberMe.value,
    })

    if (rememberMe.value) {
      localStorage.setItem(REMEMBER_EMAIL_KEY, email.value)
    } else {
      localStorage.removeItem(REMEMBER_EMAIL_KEY)
    }

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

function handleKakaoLogin() {
  const referer = (route.query.redirect as string) || '/'
  kakaoLogin(referer)
}

</script>

<template>
  <div class="min-h-screen flex items-center justify-center px-4 pb-safe pt-safe" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
    <div class="w-full max-w-md">
      <!-- Logo -->
      <div class="text-center mb-8">
        <h1 class="text-3xl font-bold" :style="{ color: 'var(--dp-text-primary)' }">Dutypark</h1>
        <p class="mt-2" :style="{ color: 'var(--dp-text-muted)' }">로그인하여 시작하세요</p>
      </div>

      <!-- Login Card -->
      <div class="rounded-2xl shadow-sm p-8" :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }">
        <form @submit.prevent="handleLogin" class="space-y-5">
          <!-- Email Field -->
          <div>
            <label for="email" class="block text-sm font-medium mb-2" :style="{ color: 'var(--dp-text-secondary)' }">
              이메일
            </label>
            <input
              id="email"
              v-model="email"
              type="text"
              autocomplete="email"
              class="w-full px-4 py-3 rounded-xl focus:ring-2 focus:ring-gray-900 focus:border-transparent transition"
              :style="{
                border: '1px solid var(--dp-border-input)',
                backgroundColor: 'var(--dp-bg-input)',
                color: 'var(--dp-text-primary)'
              }"
              placeholder="이메일 주소"
            />
            <div class="flex items-center mt-3">
              <input
                id="rememberMe"
                v-model="rememberMe"
                type="checkbox"
                class="h-4 w-4 text-gray-900 focus:ring-gray-500 rounded cursor-pointer"
                :style="{ borderColor: 'var(--dp-border-input)' }"
              />
              <label for="rememberMe" class="ml-2 text-sm cursor-pointer" :style="{ color: 'var(--dp-text-secondary)' }">
                아이디 저장
              </label>
            </div>
          </div>

          <!-- Password Field -->
          <div>
            <label for="password" class="block text-sm font-medium mb-2" :style="{ color: 'var(--dp-text-secondary)' }">
              비밀번호
            </label>
            <input
              id="password"
              v-model="password"
              type="password"
              required
              maxlength="16"
              autocomplete="current-password"
              class="w-full px-4 py-3 rounded-xl focus:ring-2 focus:ring-gray-900 focus:border-transparent transition"
              :style="{
                border: '1px solid var(--dp-border-input)',
                backgroundColor: 'var(--dp-bg-input)',
                color: 'var(--dp-text-primary)'
              }"
              placeholder="비밀번호"
            />
          </div>

          <!-- Error Message -->
          <div v-if="error" class="text-red-600 text-sm bg-red-50 p-3 rounded-xl border border-red-100">
            {{ error }}
          </div>

          <!-- Login Button -->
          <button
            type="submit"
            :disabled="isLoading"
            class="w-full bg-gray-900 text-white py-3.5 px-4 rounded-xl font-semibold hover:bg-gray-800 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-sm"
          >
            {{ isLoading ? '로그인 중...' : '로그인' }}
          </button>

          <!-- Divider -->
          <div class="relative my-6">
            <div class="absolute inset-0 flex items-center">
              <div class="w-full border-t" :style="{ borderColor: 'var(--dp-border-primary)' }"></div>
            </div>
            <div class="relative flex justify-center text-sm">
              <span class="px-4" :style="{ backgroundColor: 'var(--dp-bg-card)', color: 'var(--dp-text-muted)' }">또는</span>
            </div>
          </div>

          <!-- Kakao Login Button -->
          <button
            type="button"
            @click="handleKakaoLogin"
            class="w-full py-3.5 px-4 rounded-xl font-semibold transition-all flex items-center justify-center gap-3 hover:opacity-90 cursor-pointer shadow-sm"
            style="background-color: #FEE500; color: #000000;"
          >
            <img src="/img/kakao.png" alt="Kakao" class="w-5 h-5" />
            <span>카카오 로그인</span>
          </button>
        </form>
      </div>

      <!-- Back to Home -->
      <div class="text-center mt-6">
        <router-link to="/" class="text-sm transition" :style="{ color: 'var(--dp-text-muted)' }">
          홈으로 돌아가기
        </router-link>
      </div>
    </div>
  </div>
</template>
