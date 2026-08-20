<script setup lang="ts">
import { computed, ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { useKakao } from '@/composables/useKakao'
import { useNaver } from '@/composables/useNaver'
import { AppleSignInError, isAppleSignInCancellation, useApple } from '@/composables/useApple'
import { useLoginAttemptGate } from '@/composables/useLoginAttemptGate'
import PolicyModal from '@/components/common/PolicyModal.vue'
import { getSafeRedirect } from '@/utils/redirect'
import { getApiErrorDetail } from '@/utils/resolveApiError'
import { resolveLoginErrorMessage } from '@/utils/loginError'

const REMEMBER_EMAIL_KEY = 'dp-remember-email'

const router = useRouter()
const route = useRoute()
const { t } = useI18n()
const authStore = useAuthStore()
const { initKakao, kakaoLogin } = useKakao()
const { isNaverEnabled, naverLogin } = useNaver()
const {
  isAppleConfigured,
  isAppleReady,
  preloadAppleSdk,
  appleLogin,
} = useApple()
const { activeAttempt, isAttemptPending, startAttempt, finishAttempt } = useLoginAttemptGate()

const email = ref('')
const password = ref('')
const rememberMe = ref(false)
const isLoading = computed(() => activeAttempt.value === 'PASSWORD')
const isKakaoLoading = computed(() => activeAttempt.value === 'KAKAO')
const isNaverLoading = computed(() => activeAttempt.value === 'NAVER')
const isAppleLoading = computed(() => activeAttempt.value === 'APPLE')
const isAppleRetrying = ref(false)
const appleMessage = ref('')
const error = ref('')
const remainingAttempts = ref<number | null>(null)
const policyModal = ref<'terms' | 'privacy' | null>(null)
const redirectTarget = () => getSafeRedirect(route.query.redirect) || '/'

const remainingAttemptsMessage = computed(() => {
  if (remainingAttempts.value === null || remainingAttempts.value > 3) {
    return ''
  }

  if (remainingAttempts.value === 0) {
    return t('auth.login.error.locked')
  }

  if (remainingAttempts.value === 1) {
    return t('auth.login.error.lastAttempt')
  }

  return t('auth.login.error.remainingAttempts', { count: remainingAttempts.value })
})

onMounted(() => {
  initKakao()
  void preloadAppleSdk().catch(() => {
    if (isAppleConfigured) {
      appleMessage.value = t('auth.login.apple.providerUnavailable')
    }
  })

  const savedEmail = localStorage.getItem(REMEMBER_EMAIL_KEY)
  if (savedEmail) {
    email.value = savedEmail
    rememberMe.value = true
  }
})

async function handleLogin() {
  if (!startAttempt('PASSWORD')) return
  error.value = ''
  remainingAttempts.value = null

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

    await router.replace(redirectTarget())
  } catch (e: unknown) {
    error.value = resolveLoginErrorMessage(e, t)
    const attempts = getApiErrorDetail<number>(e, 'remainingAttempts')
    if (typeof attempts === 'number') {
      remainingAttempts.value = attempts
    }
  } finally {
    finishAttempt('PASSWORD')
  }
}

async function handleKakaoLogin() {
  if (!startAttempt('KAKAO')) return
  error.value = ''
  remainingAttempts.value = null
  try {
    await kakaoLogin(redirectTarget())
  } catch (exception) {
    error.value = resolveLoginErrorMessage(exception, t)
  } finally {
    finishAttempt('KAKAO')
  }
}

async function handleNaverLogin() {
  if (!startAttempt('NAVER')) return
  error.value = ''
  remainingAttempts.value = null
  try {
    await naverLogin(redirectTarget())
  } catch (exception) {
    error.value = resolveLoginErrorMessage(exception, t)
  } finally {
    finishAttempt('NAVER')
  }
}

function getAppleErrorMessage(exception: unknown): string {
  if (exception instanceof AppleSignInError) {
    switch (exception.code) {
      case 'CANCELLED':
        return t('auth.login.apple.cancelled')
      case 'INVALID_CREDENTIAL':
      case 'STATE_MISMATCH':
        return t('auth.login.apple.invalidCredential')
      case 'CONFIGURATION_UNAVAILABLE':
        return t('auth.login.apple.providerUnavailable')
      case 'SDK_UNAVAILABLE':
        return t('auth.login.apple.providerUnavailable')
    }
  }

  return resolveLoginErrorMessage(exception, t, {
    genericKey: 'auth.login.apple.generic',
  })
}

async function handleAppleLogin() {
  if (!isAppleConfigured || !isAppleReady.value || !startAttempt('APPLE')) return
  appleMessage.value = ''

  try {
    const response = await appleLogin()
    const redirect = redirectTarget()

    if (response.signupRequired) {
      const uuid = response.signupUuid?.trim()
      if (!uuid) throw new AppleSignInError('INVALID_CREDENTIAL')
      await router.push({
        path: '/auth/sso-signup',
        query: redirect === '/' ? { uuid } : { uuid, redirect },
      })
      return
    }

    await authStore.checkAuth()
    await router.replace(redirect)
  } catch (exception) {
    if (isAppleSignInCancellation(exception)) return
    appleMessage.value = getAppleErrorMessage(exception)
  } finally {
    finishAttempt('APPLE')
  }
}

async function handleAppleRetry() {
  if (isAppleRetrying.value || isAppleReady.value) return
  isAppleRetrying.value = true

  try {
    await preloadAppleSdk()
    appleMessage.value = ''
  } catch {
    appleMessage.value = t('auth.login.apple.providerUnavailable')
  } finally {
    isAppleRetrying.value = false
  }
}

</script>

<template>
  <div class="min-h-screen flex items-center justify-center px-4 pb-safe pt-safe bg-dp-bg-secondary">
    <div class="w-full max-w-md">
      <div class="text-center mb-8">
        <h1 class="text-3xl font-bold text-dp-text-primary">Dutypark</h1>
        <p class="mt-2 text-dp-text-muted">{{ t('auth.login.subtitle') }}</p>
      </div>

      <div class="rounded-2xl shadow-sm p-8 bg-dp-bg-card border border-dp-border-primary">
        <form @submit.prevent="handleLogin" class="space-y-5">
          <div>
            <label for="email" class="block text-sm font-medium mb-2 text-dp-text-secondary">
              {{ t('auth.login.emailLabel') }}
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
              :placeholder="t('auth.login.emailPlaceholder')"
            />
            <div class="flex items-center mt-3">
              <input
                id="rememberMe"
                v-model="rememberMe"
                type="checkbox"
                class="h-4 w-4 text-dp-text-primary focus:ring-dp-text-secondary rounded cursor-pointer border-dp-border-input"
              />
              <label for="rememberMe" class="ml-2 text-sm cursor-pointer text-dp-text-secondary">
                {{ t('auth.login.rememberMe') }}
              </label>
            </div>
          </div>

          <div>
            <label for="password" class="block text-sm font-medium mb-2 text-dp-text-secondary">
              {{ t('auth.login.passwordLabel') }}
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
              :placeholder="t('auth.login.passwordPlaceholder')"
            />
          </div>

          <div v-if="error" class="text-sm p-3 rounded-xl border" :class="remainingAttempts !== null && remainingAttempts <= 1 ? 'text-dp-warning bg-dp-warning-soft border-dp-warning-border' : 'text-dp-danger bg-dp-danger-soft border-dp-danger-border'">
            <div>{{ error }}</div>
            <div v-if="remainingAttemptsMessage" class="mt-1 font-medium">
              {{ remainingAttemptsMessage }}
            </div>
          </div>

          <button
            type="submit"
            :disabled="isAttemptPending"
            class="w-full bg-dp-surface-strong text-dp-text-on-dark py-3.5 px-4 rounded-xl font-semibold hover:bg-dp-surface-strong-hover disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-sm"
          >
            {{ isLoading ? t('auth.login.submitting') : t('auth.login.submit') }}
          </button>

          <div class="relative my-6">
            <div class="absolute inset-0 flex items-center">
              <div class="w-full border-t border-dp-border-primary"></div>
            </div>
            <div class="relative flex justify-center text-sm">
              <span class="px-4 bg-dp-bg-card text-dp-text-muted">{{ t('common.labels.or') }}</span>
            </div>
          </div>

          <div class="space-y-3">
            <button
              type="button"
              @click="handleKakaoLogin"
              :disabled="isAttemptPending"
              class="w-full py-3.5 px-4 rounded-xl font-semibold transition-all flex items-center justify-center gap-3 hover:opacity-90 cursor-pointer shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
              :style="{ backgroundColor: 'var(--dp-kakao)', color: 'var(--dp-kakao-text)' }"
            >
              <img src="/img/kakao.png" alt="Kakao" class="w-5 h-5" />
              <span>{{ isKakaoLoading ? t('auth.login.submitting') : t('auth.login.social.kakao') }}</span>
            </button>

            <button
              v-if="isNaverEnabled"
              type="button"
              @click="handleNaverLogin"
              :disabled="isAttemptPending"
              class="w-full py-3.5 px-4 rounded-xl font-semibold transition-all flex items-center justify-center gap-3 hover:opacity-95 cursor-pointer shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
              :style="{ backgroundColor: 'var(--dp-naver)', color: 'var(--dp-naver-text)' }"
            >
              <img src="/img/naver.svg" alt="Naver" class="w-5 h-5" />
              <span>{{ isNaverLoading ? t('auth.login.submitting') : t('auth.login.social.naver') }}</span>
            </button>

            <div>
              <div
                class="relative h-[52px] w-full overflow-hidden rounded-xl bg-black transition-opacity focus-within:ring-2 focus-within:ring-dp-accent focus-within:ring-offset-2"
                :class="(isAttemptPending || !isAppleConfigured || !isAppleReady) ? 'opacity-50' : 'hover:opacity-90'"
              >
                <span
                  aria-hidden="true"
                  class="absolute inset-0 flex items-center justify-center gap-3 font-semibold text-white"
                >
                  <img src="/img/apple.svg" alt="" class="w-5 h-5" />
                  <span>{{ t('auth.login.social.apple') }}</span>
                </span>
                <div
                  id="appleid-signin"
                  aria-hidden="true"
                  class="absolute inset-0 pointer-events-none"
                  data-color="black"
                  data-border="true"
                  data-border-radius="12"
                  data-type="sign-in"
                  data-mode="center-align"
                  data-width="100%"
                  data-height="52"
                ></div>
                <button
                  type="button"
                  class="absolute inset-0 z-10 h-full w-full cursor-pointer bg-transparent disabled:cursor-not-allowed"
                  :disabled="isAttemptPending || !isAppleConfigured || !isAppleReady"
                  :aria-label="t('auth.login.social.apple')"
                  :aria-describedby="appleMessage ? 'apple-login-status' : undefined"
                  @click="handleAppleLogin"
                >
                  <span class="sr-only">
                    {{ isAppleLoading ? t('auth.login.submitting') : t('auth.login.social.apple') }}
                  </span>
                </button>
              </div>
              <div
                v-if="appleMessage || isAppleRetrying"
                class="mt-2 text-center"
              >
                <p
                  id="apple-login-status"
                  class="text-xs"
                  :class="isAppleRetrying ? 'text-dp-text-muted' : 'text-dp-danger'"
                  aria-live="polite"
                >
                  {{ isAppleRetrying ? t('auth.login.apple.retrying') : appleMessage }}
                </p>
                <button
                  v-if="isAppleConfigured && appleMessage && !isAppleReady"
                  type="button"
                  class="mt-2 text-xs font-medium text-dp-accent hover:text-dp-accent-hover hover:underline disabled:cursor-not-allowed disabled:opacity-50"
                  :disabled="isAppleRetrying"
                  @click="handleAppleRetry"
                >
                  {{ isAppleRetrying ? t('auth.login.apple.retrying') : t('auth.login.apple.retry') }}
                </button>
              </div>
            </div>
          </div>
        </form>
      </div>

      <div class="text-center mt-6">
        <router-link to="/" class="text-sm transition text-dp-text-muted">
          {{ t('common.navigation.backHome') }}
        </router-link>
      </div>

      <div class="text-center mt-4">
        <button
          type="button"
          class="text-xs transition hover:underline text-dp-text-muted"
          @click="policyModal = 'terms'"
        >
          {{ t('policy.terms.title') }}
        </button>
        <span class="mx-2 text-xs text-dp-text-muted">|</span>
        <button
          type="button"
          class="text-xs transition hover:underline text-dp-text-muted"
          @click="policyModal = 'privacy'"
        >
          {{ t('policy.privacy.title') }}
        </button>
        <span class="mx-2 text-xs text-dp-text-muted">|</span>
        <router-link to="/support" class="text-xs transition hover:underline text-dp-text-muted">
          {{ t('header.menu.support') }}
        </router-link>
      </div>
    </div>

    <PolicyModal :type="policyModal" @close="policyModal = null" />
  </div>
</template>
