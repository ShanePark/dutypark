<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useKakao } from '@/composables/useKakao'
import { useNaver } from '@/composables/useNaver'
import { AxiosError } from 'axios'
import PolicyModal from '@/components/common/PolicyModal.vue'
import { getSafeRedirect } from '@/utils/redirect'

const REMEMBER_EMAIL_KEY = 'dp-remember-email'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const { initKakao, kakaoLogin } = useKakao()
const { isNaverEnabled, naverLogin } = useNaver()

const email = ref('')
const password = ref('')
const rememberMe = ref(false)
const isLoading = ref(false)
const isKakaoLoading = ref(false)
const isNaverLoading = ref(false)
const error = ref('')
const remainingAttempts = ref<number | null>(null)
const policyModal = ref<'terms' | 'privacy' | null>(null)
const redirectTarget = () => getSafeRedirect(route.query.redirect) || '/'

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
  remainingAttempts.value = null
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

    router.push(redirectTarget())
  } catch (e: unknown) {
    if (e instanceof AxiosError && e.response?.data) {
      error.value = e.response.data.error || '로그인에 실패했습니다.'
      if (typeof e.response.data.remainingAttempts === 'number') {
        remainingAttempts.value = e.response.data.remainingAttempts
      }
    } else {
      error.value = '로그인에 실패했습니다. 이메일과 비밀번호를 확인해주세요.'
    }
  } finally {
    isLoading.value = false
  }
}

function handleKakaoLogin() {
  if (isKakaoLoading.value) return
  isKakaoLoading.value = true
  kakaoLogin(redirectTarget())
}

function handleNaverLogin() {
  if (isNaverLoading.value) return
  isNaverLoading.value = true
  naverLogin(redirectTarget())
}

</script>

<template>
  <div class="min-h-screen flex items-center justify-center px-4 pb-safe pt-safe bg-dp-bg-secondary">
    <div class="w-full max-w-md">
      <!-- Logo -->
      <div class="text-center mb-8">
        <h1 class="text-3xl font-bold text-dp-text-primary">Dutypark</h1>
        <p class="mt-2 text-dp-text-muted">로그인하여 시작하세요</p>
      </div>

      <!-- Login Card -->
      <div class="rounded-2xl shadow-sm p-8 bg-dp-bg-card border border-dp-border-primary">
        <form @submit.prevent="handleLogin" class="space-y-5">
          <!-- Email Field -->
          <div>
            <label for="email" class="block text-sm font-medium mb-2 text-dp-text-secondary">
              이메일
            </label>
            <input
              id="email"
              v-model="email"
              type="text"
              autocomplete="email"
              class="w-full px-4 py-3 rounded-xl focus:ring-2 focus:ring-dp-text-primary focus:border-transparent transition"
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
                class="h-4 w-4 text-dp-text-primary focus:ring-dp-text-secondary rounded cursor-pointer border-dp-border-input"
              />
              <label for="rememberMe" class="ml-2 text-sm cursor-pointer text-dp-text-secondary">
                아이디 저장
              </label>
            </div>
          </div>

          <!-- Password Field -->
          <div>
            <label for="password" class="block text-sm font-medium mb-2 text-dp-text-secondary">
              비밀번호
            </label>
            <input
              id="password"
              v-model="password"
              type="password"
              required
              maxlength="20"
              autocomplete="current-password"
              class="w-full px-4 py-3 rounded-xl focus:ring-2 focus:ring-dp-text-primary focus:border-transparent transition"
              :style="{
                border: '1px solid var(--dp-border-input)',
                backgroundColor: 'var(--dp-bg-input)',
                color: 'var(--dp-text-primary)'
              }"
              placeholder="비밀번호"
            />
          </div>

          <!-- Error Message -->
          <div v-if="error" class="text-sm p-3 rounded-xl border" :class="remainingAttempts !== null && remainingAttempts <= 1 ? 'text-dp-warning bg-dp-warning-soft border-dp-warning-border' : 'text-dp-danger bg-dp-danger-soft border-dp-danger-border'">
            <div>{{ error }}</div>
            <div v-if="remainingAttempts !== null && remainingAttempts <= 3" class="mt-1 font-medium">
              <template v-if="remainingAttempts === 0">
                로그인이 차단되었습니다. 잠시 후 다시 시도해주세요.
              </template>
              <template v-else-if="remainingAttempts === 1">
                주의: 마지막 시도입니다!
              </template>
              <template v-else>
                남은 시도 횟수: {{ remainingAttempts }}회
              </template>
            </div>
          </div>

          <!-- Login Button -->
          <button
            type="submit"
            :disabled="isLoading"
            class="w-full bg-dp-surface-strong text-dp-text-on-dark py-3.5 px-4 rounded-xl font-semibold hover:bg-dp-surface-strong-hover disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-sm"
          >
            {{ isLoading ? '로그인 중...' : '로그인' }}
          </button>

          <!-- Divider -->
          <div class="relative my-6">
            <div class="absolute inset-0 flex items-center">
              <div class="w-full border-t border-dp-border-primary"></div>
            </div>
            <div class="relative flex justify-center text-sm">
              <span class="px-4 bg-dp-bg-card text-dp-text-muted">또는</span>
            </div>
          </div>

          <div class="space-y-3">
            <!-- Kakao Login Button -->
            <button
              type="button"
              @click="handleKakaoLogin"
              :disabled="isKakaoLoading"
              class="w-full py-3.5 px-4 rounded-xl font-semibold transition-all flex items-center justify-center gap-3 hover:opacity-90 cursor-pointer shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
              :style="{ backgroundColor: 'var(--dp-kakao)', color: 'var(--dp-kakao-text)' }"
            >
              <img src="/img/kakao.png" alt="Kakao" class="w-5 h-5" />
              <span>{{ isKakaoLoading ? '로그인 중...' : '카카오 로그인' }}</span>
            </button>

            <button
              v-if="isNaverEnabled"
              type="button"
              @click="handleNaverLogin"
              :disabled="isNaverLoading"
              class="w-full py-3.5 px-4 rounded-xl font-semibold transition-all flex items-center justify-center gap-3 hover:opacity-95 cursor-pointer shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
              :style="{ backgroundColor: 'var(--dp-naver)', color: 'var(--dp-naver-text)' }"
            >
              <img src="/img/naver.svg" alt="Naver" class="w-5 h-5" />
              <span>{{ isNaverLoading ? '로그인 중...' : '네이버 로그인' }}</span>
            </button>
          </div>
        </form>
      </div>

      <!-- Back to Home -->
      <div class="text-center mt-6">
        <router-link to="/" class="text-sm transition text-dp-text-muted">
          홈으로 돌아가기
        </router-link>
      </div>

      <!-- Policy Links -->
      <div class="text-center mt-4">
        <button
          type="button"
          class="text-xs transition hover:underline text-dp-text-muted"
          @click="policyModal = 'terms'"
        >
          이용약관
        </button>
        <span class="mx-2 text-xs text-dp-text-muted">|</span>
        <button
          type="button"
          class="text-xs transition hover:underline text-dp-text-muted"
          @click="policyModal = 'privacy'"
        >
          개인정보 처리방침
        </button>
      </div>
    </div>

    <PolicyModal :type="policyModal" @close="policyModal = null" />
  </div>
</template>
