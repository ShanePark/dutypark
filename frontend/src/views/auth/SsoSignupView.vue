<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { marked } from 'marked'

marked.setOptions({
  breaks: true,
})
import { authApi } from '@/api/auth'
import { policyApi, type CurrentPoliciesDto } from '@/api/policy'
import { useAuthStore } from '@/stores/auth'
import { useSwal } from '@/composables/useSwal'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import type { AxiosError } from 'axios'

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

const renderedTerms = computed(() => {
  if (!policies.value?.terms?.content) return ''
  return marked(policies.value.terms.content) as string
})

const renderedPrivacy = computed(() => {
  if (!policies.value?.privacy?.content) return ''
  return marked(policies.value.privacy.content) as string
})

const modalTitle = computed(() => {
  return policyModal.value === 'terms' ? '이용약관' : '개인정보 처리방침'
})

const modalContent = computed(() => {
  return policyModal.value === 'terms' ? renderedTerms.value : renderedPrivacy.value
})

function openPolicyModal(type: 'terms' | 'privacy') {
  policyModal.value = type
}

function closePolicyModal() {
  policyModal.value = null
}

// Validation
const usernameError = computed(() => {
  if (!username.value) return ''
  if (username.value.length < 1) return '사용자명을 입력해주세요.'
  if (username.value.length > 10) return '사용자명은 10자 이내로 입력해주세요.'
  return ''
})

const isFormValid = computed(() => {
  return (
    username.value.length >= 1 &&
    username.value.length <= 10 &&
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
    showError('잘못된 접근입니다. 카카오 로그인을 다시 시도해주세요.')
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
  if (!isFormValid.value || isLoading.value) return

  isLoading.value = true
  try {
    await authApi.ssoSignup({
      uuid: uuid.value,
      username: username.value,
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
  <div class="min-h-screen flex items-center justify-center px-4 pb-safe pt-safe" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
    <div class="max-w-md sm:max-w-xl lg:max-w-2xl w-full">
      <div class="text-center mb-6 sm:mb-8">
        <h1 class="text-2xl sm:text-3xl font-bold" :style="{ color: 'var(--dp-text-primary)' }">회원가입</h1>
        <p class="mt-2" :style="{ color: 'var(--dp-text-secondary)' }">Dutypark에 오신 것을 환영합니다</p>
      </div>

      <div class="rounded-lg shadow-md p-5 sm:p-6" :style="{ backgroundColor: 'var(--dp-bg-card)' }">
        <form class="space-y-4 sm:space-y-5" @submit.prevent="handleSubmit">
          <!-- Username input -->
          <div>
            <label for="username" class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
              사용자명
              <CharacterCounter :current="username.length" :max="10" />
            </label>
            <input
              id="username"
              v-model="username"
              type="text"
              required
              maxlength="10"
              :disabled="isLoading"
              class="w-full px-3 py-3 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:cursor-not-allowed"
              :style="{
                border: '1px solid var(--dp-border-input)',
                backgroundColor: isLoading ? 'var(--dp-bg-tertiary)' : 'var(--dp-bg-input)',
                color: 'var(--dp-text-primary)'
              }"
              placeholder="사용자명을 입력하세요 (1-10자)"
            />
            <p v-if="usernameError" class="mt-1 text-sm text-red-600">
              {{ usernameError }}
            </p>
          </div>

          <!-- Terms of Service -->
          <div>
            <div class="flex items-center justify-between mb-2">
              <label class="block text-sm font-medium" :style="{ color: 'var(--dp-text-secondary)' }">
                이용약관
              </label>
              <button
                type="button"
                class="text-xs text-blue-600 hover:text-blue-700 hover:underline"
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
              <div class="animate-spin rounded-full h-6 w-6 border-2 border-blue-500 border-t-transparent"></div>
            </div>
            <div
              v-else-if="!policies?.terms"
              class="w-full h-32 sm:h-48 rounded-lg flex items-center justify-center"
              :style="{
                border: '1px solid var(--dp-border-input)',
                backgroundColor: 'var(--dp-bg-tertiary)',
              }"
            >
              <p class="text-sm text-red-600">이용약관을 불러올 수 없습니다.</p>
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
              class="h-5 w-5 text-blue-600 focus:ring-blue-500 rounded cursor-pointer disabled:cursor-not-allowed"
              :style="{ borderColor: 'var(--dp-border-input)' }"
            />
            <label for="termAgree" class="ml-2 text-sm cursor-pointer" :style="{ color: 'var(--dp-text-secondary)' }">
              이용약관에 동의합니다 <span class="text-red-500">*</span>
            </label>
          </div>

          <!-- Privacy Policy -->
          <div>
            <div class="flex items-center justify-between mb-2">
              <label class="block text-sm font-medium" :style="{ color: 'var(--dp-text-secondary)' }">
                개인정보 처리방침
              </label>
              <button
                type="button"
                class="text-xs text-blue-600 hover:text-blue-700 hover:underline"
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
              <div class="animate-spin rounded-full h-6 w-6 border-2 border-blue-500 border-t-transparent"></div>
            </div>
            <div
              v-else-if="!policies?.privacy"
              class="w-full h-32 sm:h-48 rounded-lg flex items-center justify-center"
              :style="{
                border: '1px solid var(--dp-border-input)',
                backgroundColor: 'var(--dp-bg-tertiary)',
              }"
            >
              <p class="text-sm text-red-600">개인정보 처리방침을 불러올 수 없습니다.</p>
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
              class="h-5 w-5 text-blue-600 focus:ring-blue-500 rounded cursor-pointer disabled:cursor-not-allowed"
              :style="{ borderColor: 'var(--dp-border-input)' }"
            />
            <label for="privacyAgree" class="ml-2 text-sm cursor-pointer" :style="{ color: 'var(--dp-text-secondary)' }">
              개인정보 처리방침에 동의합니다 <span class="text-red-500">*</span>
            </label>
          </div>

          <!-- Submit button -->
          <button
            type="submit"
            :disabled="!isFormValid || isLoading"
            class="w-full bg-blue-600 text-white py-3 px-4 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition min-h-12 flex items-center justify-center"
          >
            <template v-if="isLoading">
              <svg
                class="animate-spin -ml-1 mr-2 h-5 w-5 text-white"
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
            <template v-else>
              가입하기
            </template>
          </button>
        </form>
      </div>

      <!-- Policy Links -->
      <div class="text-center mt-4">
        <button
          type="button"
          class="text-xs transition hover:underline"
          :style="{ color: 'var(--dp-text-muted)' }"
          @click="openPolicyModal('terms')"
        >
          이용약관
        </button>
        <span class="mx-2 text-xs" :style="{ color: 'var(--dp-text-muted)' }">|</span>
        <button
          type="button"
          class="text-xs transition hover:underline"
          :style="{ color: 'var(--dp-text-muted)' }"
          @click="openPolicyModal('privacy')"
        >
          개인정보 처리방침
        </button>
      </div>
    </div>

    <!-- Policy Modal -->
    <Teleport to="body">
      <div
        v-if="policyModal"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
        @click.self="closePolicyModal"
      >
        <div class="fixed inset-0 bg-black/50" @click="closePolicyModal"></div>
        <div
          class="relative w-full max-w-3xl max-h-[90vh] rounded-xl shadow-xl overflow-hidden flex flex-col"
          :style="{ backgroundColor: 'var(--dp-bg-modal)' }"
        >
          <!-- Modal Header -->
          <div class="modal-header flex-shrink-0">
            <h2>{{ modalTitle }}</h2>
            <button
              type="button"
              class="p-2 rounded-full hover-close-btn"
              @click="closePolicyModal"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          <!-- Modal Body -->
          <div
            class="flex-1 overflow-y-auto p-6 prose prose-sm sm:prose-base max-w-none"
            :style="{ color: 'var(--dp-text-secondary)' }"
            v-html="modalContent"
          >
          </div>
          <!-- Modal Footer -->
          <div class="flex-shrink-0 p-4 border-t" :style="{ borderColor: 'var(--dp-border-primary)' }">
            <button
              type="button"
              class="w-full py-2.5 px-4 rounded-lg font-medium transition"
              :style="{
                backgroundColor: 'var(--dp-bg-tertiary)',
                color: 'var(--dp-text-primary)'
              }"
              @click="closePolicyModal"
            >
              닫기
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
