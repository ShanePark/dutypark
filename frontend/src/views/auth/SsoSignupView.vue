<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { authApi } from '@/api/auth'
import { useAuthStore } from '@/stores/auth'
import { useSwal } from '@/composables/useSwal'
import type { AxiosError } from 'axios'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { showError } = useSwal()

const uuid = ref('')
const username = ref('')
const termAgree = ref(false)
const isLoading = ref(false)

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
    uuid.value
  )
})

onMounted(() => {
  // Parse uuid from query parameter
  const uuidParam = route.query.uuid
  if (typeof uuidParam === 'string' && uuidParam) {
    uuid.value = uuidParam
  } else {
    showError('잘못된 접근입니다. 카카오 로그인을 다시 시도해주세요.')
    router.push('/auth/login')
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

const termsContent = `1. 서론
본 약관은 [Dutypark] (이하 "서비스")의 이용 조건 및 절차, 이용자와 서비스 제공자 간의 권리, 의무, 책임사항 및 기타 필요한 사항을 규정함을 목적으로 합니다.

2. 정의
"이용자"란 본 약관에 따라 서비스에 접속하여 이 약관에 따라 서비스 제공자가 제공하는 서비스를 받는 회원 및 비회원을 말합니다.
"회원"이란 서비스에 개인정보를 제공하여 회원 등록을 한 자로서, 서비스의 정보를 지속적으로 제공받으며, 서비스가 제공하는 서비스를 계속적으로 이용할 수 있는 자를 말합니다.
"비회원"이란 회원에 가입하지 않고 서비스가 제공하는 서비스를 이용하는 자를 말합니다.

3. 회원 가입
이용자는 서비스 제공자가 정한 가입 양식에 따라 회원정보를 기입한 후 본 약관에 동의한다는 의사표시를 함으로써 회원 가입을 신청합니다.
서비스 제공자는 위와 같이 회원으로 가입할 것을 신청한 이용자 중 다음 각 호에 해당하지 않는 한 회원으로 등록합니다.
- 가입 신청자가 이 약관에 의거하여 이전에 회원 자격을 상실한 적이 있는 경우
- 등록 내용에 허위, 기재누락, 오기가 있는 경우
- 기타 회원으로 등록하는 것이 서비스의 기술상 현저히 지장이 있다고 판단되는 경우

4. 서비스 이용
서비스 이용은 서비스의 이용 승낙 직후부터 가능합니다.
서비스 이용시간은 서비스 제공자의 업무 상 또는 기술상의 이유로 변동될 수 있으며, 이러한 경우 사전에 공지합니다.

5. 개인정보보호
서비스 제공자는 이용자의 개인정보 수집 시 서비스 제공에 필요한 범위에서 최소한의 개인정보를 수집합니다.
서비스 제공자는 이용자의 개인정보를 보호하기 위해 노력하며, 이용자의 개인정보 보호와 관련된 상세한 사항은 '개인정보 처리방침'을 별도로 마련하여 공지합니다. 서비스 제공자는 법령에 따른 개인정보의 보관기간 동안 이용자의 개인정보를 보관합니다.

6. 서비스의 변경 및 중지
서비스 제공자는 필요한 경우 서비스의 내용을 변경하거나 서비스 제공을 중지할 수 있습니다. 이 경우 서비스 제공자는 이용자에게 알림을 통해 사전에 공지합니다.
서비스 제공자는 다음과 같은 경우 서비스 제공을 일시적으로 중단할 수 있습니다.
- 서비스용 설비의 보수 등 공사로 인한 경우
- 전기통신사업법에 규정된 기술적 장애의 발생
- 기타 불가항력적 사유가 있는 경우

7. 이용자의 의무
이용자는 서비스 이용에 있어서 다음의 행위를 하여서는 안 됩니다.
- 신청 또는 변경 시 허위 내용의 등록
- 타인의 정보 도용
- 서비스에 게시된 정보의 변경
- 서비스가 정한 정보 이외의 정보(컴퓨터 프로그램 등)의 송신 또는 게시
- 서비스 기타 제3자의 저작권 등 지적재산권에 대한 침해
- 서비스 기타 제3자의 명예를 손상시키거나 업무를 방해하는 행위
- 외설 또는 폭력적인 메시지, 화상, 음성, 기타 공서양속에 반하는 정보를 서비스에 공개 또는 게시하는 행위

8. 저작권의 귀속 및 이용 제한
서비스 제공자가 제공하는 서비스, 그리고 서비스 내에 포함된 모든 자료(텍스트, 그래픽, 로고, 아이콘, 이미지 등)의 저작권은 서비스 제공자에게 귀속됩니다.
이용자는 서비스를 이용함으로써 얻은 정보를 서비스 제공자의 사전 승낙 없이 복제, 배포, 방송 기타 방법에 의하여 상업적으로 이용할 수 없습니다.

9. 면책 조항
서비스 제공자는 천재지변, 전쟁, 테러 행위, 기타 불가항력적 사유로 인해 서비스를 제공할 수 없을 경우에는 서비스 제공에 대한 책임이 면제됩니다.
서비스 제공자는 이용자의 귀책사유로 인한 서비스 이용의 장애에 대하여 책임을 지지 않습니다.
서비스 제공자는 이용자가 서비스의 이용과 관련하여 기대하는 이익, 서비스에 게시된 정보의 이용으로 발생하는 손해 등에 대하여 책임을 지지 않습니다.

10. 분쟁 해결
서비스 제공자와 이용자는 서비스 이용과 관련하여 발생한 분쟁을 원만하게 해결하기 위하여 필요한 모든 노력을 합니다.
불구하고 분쟁이 해결되지 않을 경우, [서비스 제공자 소재지 법원]을 합의 관할 법원으로 합니다.`
</script>

<template>
  <div class="min-h-screen flex items-center justify-center px-4 pb-safe pt-safe" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
    <div class="max-w-md w-full">
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
            <label class="block text-sm font-medium mb-2" :style="{ color: 'var(--dp-text-secondary)' }">
              이용약관
            </label>
            <div
              class="w-full h-48 px-3 py-3 rounded-lg overflow-y-auto text-sm whitespace-pre-wrap"
              :style="{
                border: '1px solid var(--dp-border-input)',
                backgroundColor: 'var(--dp-bg-tertiary)',
                color: 'var(--dp-text-secondary)'
              }"
            >
              {{ termsContent }}
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
              위 이용약관에 동의합니다
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
    </div>
  </div>
</template>
