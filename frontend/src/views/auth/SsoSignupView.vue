<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { marked } from 'marked'
import { authApi } from '@/api/auth'
import { policyApi, type CurrentPoliciesDto } from '@/api/policy'
import { useAuthStore } from '@/stores/auth'
import { useSwal } from '@/composables/useSwal'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import PolicyModal from '@/components/common/PolicyModal.vue'
import type { AxiosError } from 'axios'

marked.setOptions({
  breaks: true,
})

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { showError } = useSwal()

const uuid = ref('')
const username = ref('')
const termAgree = ref(false)
const privacyAgree = ref(false)
const isLoading = ref(false)
const isPoliciesLoading = ref(true)
const policies = ref<CurrentPoliciesDto | null>(null)
const policyModal = ref<'terms' | 'privacy' | null>(null)
const usernameInput = ref<HTMLInputElement | null>(null)

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
    items.push('사용자명 입력')
  } else if (isUsernameTooLong.value) {
    items.push('사용자명 10자 이하 입력')
  }

  if (!termAgree.value) items.push('이용약관 동의')
  if (!privacyAgree.value) items.push('개인정보 처리방침 동의')

  return items
})

const shouldHighlightUsername = computed(() => {
  return (isUsernameMissing.value && hasStartedFormInput.value) || isUsernameTooLong.value
})

const usernameHelperText = computed(() => {
  if (isUsernameMissing.value) {
    return hasStartedFormInput.value
      ? '사용자명을 입력해야 가입할 수 있어요.'
      : '가입 시 사용할 사용자명을 1-10자로 입력해주세요.'
  }
  if (isUsernameTooLong.value) return '사용자명은 10자 이내로 입력해주세요.'
  return '가입 후 프로필과 일정에 표시될 이름입니다.'
})

const submitHint = computed(() => {
  if (isPoliciesLoading.value) return '약관 정보를 불러오는 중입니다.'
  if (!policies.value?.terms || !policies.value?.privacy) {
    return '약관 정보를 불러오지 못해 지금은 가입할 수 없어요.'
  }
  if (!uuid.value) return '소셜 로그인 정보를 확인할 수 없어 다시 로그인해야 합니다.'
  if (missingRequiredItems.value.length === 0) return ''
  return `필수 항목을 완료해주세요: ${missingRequiredItems.value.join(', ')}`
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
    showError('잘못된 접근입니다. 소셜 로그인을 다시 시도해주세요.')
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
    router.push('/auth/sso-congrats')
  } catch (error) {
    const axiosError = error as AxiosError<{ message?: string }>
    const message =
      axiosError.response?.data?.message ||
      '회원가입 중 오류가 발생했습니다. 다시 시도해주세요.'
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
        <h1 class="text-2xl sm:text-3xl font-bold text-dp-text-primary">회원가입</h1>
        <p class="mt-2 text-dp-text-secondary">Dutypark에 오신 것을 환영합니다</p>
      </div>

      <div class="rounded-lg shadow-md p-5 sm:p-6 bg-dp-bg-card">
        <form class="space-y-4 sm:space-y-5" @submit.prevent="handleSubmit">
          <!-- Username input -->
          <div>
            <label for="username" class="block text-sm font-medium mb-1 text-dp-text-secondary">
              사용자명
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
              placeholder="사용자명을 입력하세요 (1-10자)"
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
                이용약관
              </label>
              <button
                type="button"
                class="text-xs text-dp-accent hover:text-dp-accent-hover hover:underline"
                @click="openPolicyModal('terms')"
              >
                전체보기 →
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
              <p class="text-sm text-dp-danger">이용약관을 불러올 수 없습니다.</p>
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
              이용약관에 동의합니다 <span class="text-dp-danger">*</span>
            </label>
          </div>

          <!-- Privacy Policy -->
          <div>
            <div class="flex items-center justify-between mb-2">
              <label class="block text-sm font-medium text-dp-text-secondary">
                개인정보 처리방침
              </label>
              <button
                type="button"
                class="text-xs text-dp-accent hover:text-dp-accent-hover hover:underline"
                @click="openPolicyModal('privacy')"
              >
                전체보기 →
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
              <p class="text-sm text-dp-danger">개인정보 처리방침을 불러올 수 없습니다.</p>
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
              개인정보 처리방침에 동의합니다 <span class="text-dp-danger">*</span>
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
              가입 처리 중...
            </template>
            <template v-else>가입하기</template>
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
          이용약관
        </button>
        <span class="mx-2 text-xs text-dp-text-muted">|</span>
        <button
          type="button"
          class="text-xs transition hover:underline text-dp-text-muted"
          @click="openPolicyModal('privacy')"
        >
          개인정보 처리방침
        </button>
      </div>
    </div>

    <PolicyModal :type="policyModal" :policies="policies" @close="policyModal = null" />
  </div>
</template>
