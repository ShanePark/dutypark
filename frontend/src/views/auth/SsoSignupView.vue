<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { marked } from 'marked'
import { authApi } from '@/api/auth'
import { policyApi, type CurrentPoliciesDto } from '@/api/policy'
import { useAuthStore } from '@/stores/auth'
import { useSwal } from '@/composables/useSwal'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import PolicyModal from '@/components/common/PolicyModal.vue'
import type { AxiosError } from 'axios'
import { getSafeRedirect } from '@/utils/redirect'

marked.setOptions({
  breaks: true,
})

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { showError } = useSwal()
const { t } = useI18n()

const uuid = ref('')
const username = ref('')
const termAgree = ref(false)
const privacyAgree = ref(false)
const isLoading = ref(false)
const isPoliciesLoading = ref(true)
const policies = ref<CurrentPoliciesDto | null>(null)
const policyModal = ref<'terms' | 'privacy' | null>(null)
const usernameInput = ref<HTMLInputElement | null>(null)
const redirectTarget = computed(() => getSafeRedirect(route.query.redirect))

const renderedTerms = computed(() => {
  if (!policies.value?.terms?.content) return ''
  return marked(policies.value.terms.content) as string
})

const renderedPrivacy = computed(() => {
  if (!policies.value?.privacy?.content) return ''
  return marked(policies.value.privacy.content) as string
})

function openPolicyModal(type: 'terms' | 'privacy') {
  policyModal.value = type
}

// Validation
const trimmedUsername = computed(() => username.value.trim())

const hasStartedFormInput = computed(() => {
  return username.value.length > 0 || termAgree.value || privacyAgree.value
})

const isUsernameMissing = computed(() => trimmedUsername.value.length === 0)
const isUsernameTooLong = computed(() => trimmedUsername.value.length > 10)
const missingRequiredItems = computed(() => {
  const items: string[] = []

  if (isUsernameMissing.value) {
    items.push(t('auth.ssoSignup.requiredItems.username'))
  } else if (isUsernameTooLong.value) {
    items.push(t('auth.ssoSignup.requiredItems.usernameMax'))
  }

  if (!termAgree.value) items.push(t('auth.ssoSignup.requiredItems.terms'))
  if (!privacyAgree.value) items.push(t('auth.ssoSignup.requiredItems.privacy'))

  return items
})

const shouldHighlightUsername = computed(() => {
  return (isUsernameMissing.value && hasStartedFormInput.value) || isUsernameTooLong.value
})

const usernameHelperText = computed(() => {
  if (isUsernameMissing.value) {
    return hasStartedFormInput.value
      ? t('auth.ssoSignup.username.helper.emptyActive')
      : t('auth.ssoSignup.username.helper.emptyIdle')
  }
  if (isUsernameTooLong.value) return t('auth.ssoSignup.username.helper.tooLong')
  return t('auth.ssoSignup.username.helper.valid')
})

const submitHint = computed(() => {
  if (isPoliciesLoading.value) return t('auth.ssoSignup.hints.loadingPolicies')
  if (!policies.value?.terms || !policies.value?.privacy) {
    return t('auth.ssoSignup.hints.missingPolicies')
  }
  if (!uuid.value) return t('auth.ssoSignup.hints.missingUuid')
  if (missingRequiredItems.value.length === 0) return ''
  return t('auth.ssoSignup.hints.requiredPrefix', {
    items: missingRequiredItems.value.join(', '),
  })
})

const submitHintClass = computed(() => {
  if (isPoliciesLoading.value) return 'text-dp-text-muted'
  if (!policies.value?.terms || !policies.value?.privacy || !uuid.value) return 'text-dp-danger'
  if (!hasStartedFormInput.value) return 'text-dp-text-muted'
  if (!submitHint.value) return 'text-dp-text-muted'
  return 'text-dp-danger'
})

const isSubmitDisabled = computed(() => {
  return !isFormValid.value || isLoading.value
})

const isFormValid = computed(() => {
  return (
    trimmedUsername.value.length >= 1 &&
    trimmedUsername.value.length <= 10 &&
    termAgree.value &&
    privacyAgree.value &&
    uuid.value &&
    policies.value?.terms &&
    policies.value?.privacy
  )
})

onMounted(async () => {
  // Parse uuid from query parameter
  const uuidParam = route.query.uuid
  if (typeof uuidParam === 'string' && uuidParam) {
    uuid.value = uuidParam
  } else {
    showError(t('auth.ssoSignup.errors.invalidAccess'))
    router.push('/auth/login')
    return
  }

  // Fetch policies from API
  try {
    policies.value = await policyApi.getCurrentPolicies()
  } catch {
    // policies remain null, which will show error in template
  } finally {
    isPoliciesLoading.value = false
  }
})

async function handleSubmit() {
  if (isUsernameMissing.value || isUsernameTooLong.value) {
    usernameInput.value?.focus()
  }

  if (!isFormValid.value || isLoading.value) return

  isLoading.value = true
  try {
    await authApi.ssoSignup({
      uuid: uuid.value,
      username: trimmedUsername.value,
      termAgree: termAgree.value,
      privacyAgree: privacyAgree.value,
      termsVersion: policies.value?.terms?.version,
      privacyVersion: policies.value?.privacy?.version,
    })

    // Initialize auth store to fetch user info
    await authStore.checkAuth()

    // Navigate to congrats page
    await router.push({
      path: '/auth/sso-congrats',
      query: redirectTarget.value ? { redirect: redirectTarget.value } : undefined,
    })
  } catch (error) {
    const axiosError = error as AxiosError<{ message?: string }>
    const message =
      axiosError.response?.data?.message ||
      t('auth.ssoSignup.errors.submitFailed')
    showError(message)
  } finally {
    isLoading.value = false
  }
}

</script>

<template>
  <div class="min-h-screen flex items-center justify-center px-4 pb-safe pt-safe bg-dp-bg-secondary">
    <div class="max-w-md sm:max-w-xl lg:max-w-2xl w-full">
      <div class="text-center mb-6 sm:mb-8">
        <h1 class="text-2xl sm:text-3xl font-bold text-dp-text-primary">{{ t('auth.ssoSignup.title') }}</h1>
        <p class="mt-2 text-dp-text-secondary">{{ t('auth.ssoSignup.subtitle') }}</p>
      </div>

      <div class="rounded-lg shadow-md p-5 sm:p-6 bg-dp-bg-card">
        <form class="space-y-4 sm:space-y-5" @submit.prevent="handleSubmit">
          <!-- Username input -->
          <div>
            <label for="username" class="block text-sm font-medium mb-1 text-dp-text-secondary">
              {{ t('auth.ssoSignup.username.label') }}
              <CharacterCounter :current="username.length" :max="10" />
            </label>
            <input
              id="username"
              ref="usernameInput"
              v-model="username"
              type="text"
              required
              maxlength="10"
              :disabled="isLoading"
              :aria-invalid="shouldHighlightUsername"
              class="w-full px-3 py-3 rounded-lg focus:ring-2 focus:ring-dp-accent focus:border-transparent disabled:cursor-not-allowed"
              :style="{
                border: `1px solid ${shouldHighlightUsername ? 'var(--dp-danger-border)' : 'var(--dp-border-input)'}`,
                backgroundColor: isLoading ? 'var(--dp-bg-tertiary)' : 'var(--dp-bg-input)',
                color: 'var(--dp-text-primary)'
              }"
              :placeholder="t('auth.ssoSignup.username.placeholder')"
            />
            <p
              class="mt-1 text-sm"
              :class="shouldHighlightUsername ? 'text-dp-danger' : 'text-dp-text-muted'"
            >
              {{ usernameHelperText }}
            </p>
          </div>

          <!-- Terms of Service -->
          <div>
            <div class="flex items-center justify-between mb-2">
              <label class="block text-sm font-medium text-dp-text-secondary">
                {{ t('auth.ssoSignup.policy.termsTitle') }}
              </label>
              <button
                type="button"
                class="text-xs text-dp-accent hover:text-dp-accent-hover hover:underline"
                @click="openPolicyModal('terms')"
              >
                {{ t('auth.ssoSignup.policy.viewAll') }} →
              </button>
            </div>
            <div
              v-if="isPoliciesLoading"
              class="w-full h-32 sm:h-48 rounded-lg flex items-center justify-center"
              :style="{
                border: '1px solid var(--dp-border-input)',
                backgroundColor: 'var(--dp-bg-tertiary)',
              }"
            >
              <div class="animate-spin rounded-full h-6 w-6 border-2 border-dp-accent-border border-t-transparent"></div>
            </div>
            <div
              v-else-if="!policies?.terms"
              class="w-full h-32 sm:h-48 rounded-lg flex items-center justify-center"
              :style="{
                border: '1px solid var(--dp-border-input)',
                backgroundColor: 'var(--dp-bg-tertiary)',
              }"
            >
              <p class="text-sm text-dp-danger">{{ t('auth.ssoSignup.policy.termsLoadError') }}</p>
            </div>
            <div
              v-else
              class="w-full h-32 sm:h-48 px-3 py-2 rounded-lg overflow-y-auto prose prose-sm max-w-none"
              :style="{
                border: '1px solid var(--dp-border-input)',
                backgroundColor: 'var(--dp-bg-tertiary)',
                color: 'var(--dp-text-secondary)'
              }"
              v-html="renderedTerms"
            >
            </div>
          </div>

          <!-- Terms agreement checkbox -->
          <div class="flex items-center min-h-[44px]">
            <input
              id="termAgree"
              v-model="termAgree"
              type="checkbox"
              required
              :disabled="isLoading"
              class="h-5 w-5 text-dp-accent focus:ring-dp-accent rounded cursor-pointer disabled:cursor-not-allowed border-dp-border-input"
            />
            <label for="termAgree" class="ml-2 text-sm cursor-pointer text-dp-text-secondary">
              {{ t('auth.ssoSignup.policy.agreeTerms') }} <span class="text-dp-danger">*</span>
            </label>
          </div>

          <!-- Privacy Policy -->
          <div>
            <div class="flex items-center justify-between mb-2">
              <label class="block text-sm font-medium text-dp-text-secondary">
                {{ t('auth.ssoSignup.policy.privacyTitle') }}
              </label>
              <button
                type="button"
                class="text-xs text-dp-accent hover:text-dp-accent-hover hover:underline"
                @click="openPolicyModal('privacy')"
              >
                {{ t('auth.ssoSignup.policy.viewAll') }} →
              </button>
            </div>
            <div
              v-if="isPoliciesLoading"
              class="w-full h-32 sm:h-48 rounded-lg flex items-center justify-center"
              :style="{
                border: '1px solid var(--dp-border-input)',
                backgroundColor: 'var(--dp-bg-tertiary)',
              }"
            >
              <div class="animate-spin rounded-full h-6 w-6 border-2 border-dp-accent-border border-t-transparent"></div>
            </div>
            <div
              v-else-if="!policies?.privacy"
              class="w-full h-32 sm:h-48 rounded-lg flex items-center justify-center"
              :style="{
                border: '1px solid var(--dp-border-input)',
                backgroundColor: 'var(--dp-bg-tertiary)',
              }"
            >
              <p class="text-sm text-dp-danger">{{ t('auth.ssoSignup.policy.privacyLoadError') }}</p>
            </div>
            <div
              v-else
              class="w-full h-32 sm:h-48 px-3 py-2 rounded-lg overflow-y-auto prose prose-sm max-w-none"
              :style="{
                border: '1px solid var(--dp-border-input)',
                backgroundColor: 'var(--dp-bg-tertiary)',
                color: 'var(--dp-text-secondary)'
              }"
              v-html="renderedPrivacy"
            >
            </div>
          </div>

          <!-- Privacy agreement checkbox -->
          <div class="flex items-center min-h-[44px]">
            <input
              id="privacyAgree"
              v-model="privacyAgree"
              type="checkbox"
              required
              :disabled="isLoading"
              class="h-5 w-5 text-dp-accent focus:ring-dp-accent rounded cursor-pointer disabled:cursor-not-allowed border-dp-border-input"
            />
            <label for="privacyAgree" class="ml-2 text-sm cursor-pointer text-dp-text-secondary">
              {{ t('auth.ssoSignup.policy.agreePrivacy') }} <span class="text-dp-danger">*</span>
            </label>
          </div>

          <!-- Submit button -->
          <button
            type="submit"
            :disabled="isSubmitDisabled"
            class="w-full bg-dp-accent text-dp-text-on-dark py-3 px-4 rounded-lg hover:bg-dp-accent-hover disabled:opacity-50 disabled:cursor-not-allowed transition min-h-12 flex items-center justify-center"
          >
            <template v-if="isLoading">
              <svg
                class="animate-spin -ml-1 mr-2 h-5 w-5 text-dp-text-on-dark"
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
              >
                <circle
                  class="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  stroke-width="4"
                />
                <path
                  class="opacity-75"
                  fill="currentColor"
                  d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                />
              </svg>
              {{ t('auth.ssoSignup.submit.loading') }}
            </template>
            <template v-else>{{ t('auth.ssoSignup.submit.idle') }}</template>
          </button>
          <p v-if="submitHint" class="text-sm" :class="submitHintClass">
            {{ submitHint }}
          </p>
        </form>
      </div>

      <!-- Policy Links -->
      <div class="text-center mt-4">
        <button
          type="button"
          class="text-xs transition hover:underline text-dp-text-muted"
          @click="openPolicyModal('terms')"
        >
          {{ t('auth.ssoSignup.footer.terms') }}
        </button>
        <span class="mx-2 text-xs text-dp-text-muted">|</span>
        <button
          type="button"
          class="text-xs transition hover:underline text-dp-text-muted"
          @click="openPolicyModal('privacy')"
        >
          {{ t('auth.ssoSignup.footer.privacy') }}
        </button>
      </div>
    </div>

    <PolicyModal :type="policyModal" :policies="policies" @close="policyModal = null" />
  </div>
</template>
