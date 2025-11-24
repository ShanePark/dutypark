<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { memberApi, refreshTokenApi } from '@/api/member'
import { authApi } from '@/api/auth'
import { useSwal } from '@/composables/useSwal'
import type { FriendDto, MemberDto, RefreshTokenDto, CalendarVisibility } from '@/types'
import {
  User,
  Building2,
  Mail,
  Eye,
  Shield,
  Smartphone,
  Globe,
  Monitor,
  Link,
  Lock,
  UserX,
  LogOut,
  Trash2,
  Info,
  Check,
  X,
  ChevronRight,
  Loader2,
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const { showSuccess, showError, showInfo, confirm } = useSwal()

// Loading states
const loading = ref(false)
const tokensLoading = ref(false)
const savingVisibility = ref(false)
const savingManager = ref(false)

// Visibility settings
const calendarVisibility = ref<CalendarVisibility>('FRIENDS')
const showVisibilityModal = ref(false)

const visibilityLabel = computed(() => {
  const labels: Record<CalendarVisibility, string> = {
    PUBLIC: '누구나',
    FRIENDS: '친구만',
    FAMILY: '가족만',
    PRIVATE: '비공개',
  }
  return labels[calendarVisibility.value]
})

const visibilityOptions: { value: CalendarVisibility; label: string; color: string; description: string }[] = [
  { value: 'PUBLIC', label: '누구나', color: 'bg-green-500', description: '모든 사용자가 내 시간표를 볼 수 있습니다' },
  { value: 'FRIENDS', label: '친구만', color: 'bg-yellow-500', description: '친구로 등록된 사용자만 볼 수 있습니다' },
  { value: 'FAMILY', label: '가족만', color: 'bg-orange-500', description: '가족으로 등록된 사용자만 볼 수 있습니다' },
  { value: 'PRIVATE', label: '비공개', color: 'bg-red-500', description: '나만 볼 수 있습니다' },
]

async function setVisibility(value: CalendarVisibility) {
  if (!authStore.user) return

  savingVisibility.value = true
  try {
    await memberApi.updateVisibility(authStore.user.id, value)
    calendarVisibility.value = value
    showVisibilityModal.value = false
  } catch (error) {
    console.error('Failed to update visibility:', error)
    showError('공개 설정 변경에 실패했습니다.')
  } finally {
    savingVisibility.value = false
  }
}

// Manager delegation
const familyMembers = ref<FriendDto[]>([])
const managers = ref<MemberDto[]>([])
const selectedManagerToAdd = ref<string>('')

const availableFamilyMembers = computed(() => {
  return familyMembers.value.filter(
    (member) => !managers.value.some((m) => m.id === member.id)
  )
})

async function fetchFamilyAndManagers() {
  try {
    const [familyResponse, managersResponse] = await Promise.all([
      memberApi.getFamilyMembers(),
      memberApi.getManagers(),
    ])
    familyMembers.value = familyResponse.data
    managers.value = managersResponse.data
  } catch (error) {
    console.error('Failed to fetch family/managers:', error)
  }
}

async function assignManager() {
  if (!selectedManagerToAdd.value) return

  const memberId = parseInt(selectedManagerToAdd.value)
  savingManager.value = true
  try {
    await memberApi.assignManager(memberId)
    await fetchFamilyAndManagers()
    selectedManagerToAdd.value = ''
  } catch (error) {
    console.error('Failed to assign manager:', error)
    showError('관리자 추가에 실패했습니다.')
  } finally {
    savingManager.value = false
  }
}

async function unAssignManager(manager: MemberDto) {
  if (!await confirm(`정말 ${manager.name} 님의 관리자 권한을 해제하시겠습니까?`)) return

  try {
    await memberApi.unassignManager(manager.id!)
    await fetchFamilyAndManagers()
  } catch (error) {
    console.error('Failed to unassign manager:', error)
    showError('관리자 권한 해제에 실패했습니다.')
  }
}

// Session management
const tokens = ref<RefreshTokenDto[]>([])

async function fetchTokens() {
  tokensLoading.value = true
  try {
    const response = await refreshTokenApi.getRefreshTokens()
    tokens.value = response.data
  } catch (error) {
    console.error('Failed to fetch tokens:', error)
  } finally {
    tokensLoading.value = false
  }
}

async function deleteToken(tokenId: number) {
  if (!await confirm('정말 로그아웃 하시겠습니까? 해당 기기에서 로그아웃 됩니다.')) return

  try {
    await refreshTokenApi.deleteRefreshToken(tokenId)
    await fetchTokens()
  } catch (error) {
    console.error('Failed to delete token:', error)
    showError('세션 종료에 실패했습니다.')
  }
}

function formatLastUsed(lastUsed: string | null): string {
  if (!lastUsed) return '-'

  const date = new Date(lastUsed)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffMins = Math.floor(diffMs / 60000)
  const diffHours = Math.floor(diffMs / 3600000)
  const diffDays = Math.floor(diffMs / 86400000)

  if (diffMins < 1) return '방금 전'
  if (diffMins < 60) return `${diffMins}분 전`
  if (diffHours < 24) return `${diffHours}시간 전`
  if (diffDays < 7) return `${diffDays}일 전`
  return date.toLocaleDateString()
}

// SSO connections
interface SsoConnection {
  provider: string
  icon: string
  connected: boolean
  accountName?: string
}

const ssoConnections = ref<SsoConnection[]>([])

function connectSso(provider: string) {
  if (provider === 'Kakao') {
    window.location.href = '/oauth2/authorization/kakao'
    return
  }
}

// Password change
const showPasswordModal = ref(false)
const passwordForm = ref({
  currentPassword: '',
  newPassword: '',
  confirmPassword: '',
})
const passwordErrors = ref({
  currentPassword: '',
  newPassword: '',
  confirmPassword: '',
})

function openPasswordModal() {
  passwordForm.value = { currentPassword: '', newPassword: '', confirmPassword: '' }
  passwordErrors.value = { currentPassword: '', newPassword: '', confirmPassword: '' }
  showPasswordModal.value = true
}

function validatePasswordForm(): boolean {
  passwordErrors.value = { currentPassword: '', newPassword: '', confirmPassword: '' }
  let isValid = true

  if (!passwordForm.value.currentPassword) {
    passwordErrors.value.currentPassword = '현재 비밀번호를 입력해주세요'
    isValid = false
  }

  if (!passwordForm.value.newPassword) {
    passwordErrors.value.newPassword = '새 비밀번호를 입력해주세요'
    isValid = false
  } else if (passwordForm.value.newPassword.length < 8) {
    passwordErrors.value.newPassword = '비밀번호는 8자 이상이어야 합니다'
    isValid = false
  } else if (passwordForm.value.currentPassword === passwordForm.value.newPassword) {
    passwordErrors.value.newPassword = '현재 비밀번호와 동일합니다'
    isValid = false
  }

  if (!passwordForm.value.confirmPassword) {
    passwordErrors.value.confirmPassword = '비밀번호 확인을 입력해주세요'
    isValid = false
  } else if (passwordForm.value.newPassword !== passwordForm.value.confirmPassword) {
    passwordErrors.value.confirmPassword = '비밀번호가 일치하지 않습니다'
    isValid = false
  }

  return isValid
}

const changingPassword = ref(false)

async function changePassword() {
  if (!validatePasswordForm()) return
  if (!authStore.user) return

  changingPassword.value = true
  try {
    await authApi.changePassword({
      memberId: authStore.user.id,
      currentPassword: passwordForm.value.currentPassword,
      newPassword: passwordForm.value.newPassword,
    })
    await showSuccess('비밀번호가 변경되었습니다. 다시 로그인 해주세요.')
    showPasswordModal.value = false
    authStore.logout()
    router.push('/auth/login')
  } catch (error: any) {
    const message = error.response?.data?.message || '비밀번호 변경에 실패했습니다.'
    showError(message)
  } finally {
    changingPassword.value = false
  }
}

// Account deletion
function deleteAccount() {
  showInfo('회원 탈퇴는 관리자에게 문의해주세요.')
}

// Logout
async function logout() {
  const confirmed = await confirm('정말 로그아웃 하시겠습니까?', '로그아웃')
  if (confirmed) {
    authStore.logout()
    router.push('/auth/login')
  }
}

// Member info (fetched from API)
const memberInfo = ref<MemberDto | null>(null)

async function fetchMemberInfo() {
  const response = await memberApi.getMyInfo()
  memberInfo.value = response.data
}

// Initialize data
onMounted(async () => {
  loading.value = true
  try {
    // Fetch all data in parallel
    await Promise.all([
      fetchMemberInfo(),
      fetchFamilyAndManagers(),
      fetchTokens(),
    ])

    // Set initial visibility from user data
    if (memberInfo.value) {
      calendarVisibility.value = memberInfo.value.calendarVisibility
    }

    // Set SSO connections based on user data
    ssoConnections.value = [
      {
        provider: 'Kakao',
        icon: '/img/kakao.png',
        connected: !!memberInfo.value?.kakaoId,
      },
    ]
  } catch (error) {
    console.error('Failed to initialize:', error)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <h1 class="text-2xl font-bold text-gray-900 mb-6">내 정보</h1>

    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center py-20">
      <Loader2 class="w-8 h-8 animate-spin text-blue-500" />
    </div>

    <template v-else>
      <!-- Profile Section -->
      <section class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-4">
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <User class="w-5 h-5 text-gray-500" />
          기본 정보
        </h2>
        <div class="space-y-4">
          <div class="flex flex-col md:flex-row md:items-center py-3 border-b border-gray-100">
            <div class="w-full md:w-24 text-sm font-medium text-gray-500 flex items-center gap-2 mb-1 md:mb-0">
              <User class="w-4 h-4" />
              이름
            </div>
            <div class="flex-1 text-gray-900">{{ memberInfo?.name }}</div>
          </div>
          <div class="flex flex-col md:flex-row md:items-center py-3 border-b border-gray-100">
            <div class="w-full md:w-24 text-sm font-medium text-gray-500 flex items-center gap-2 mb-1 md:mb-0">
              <Building2 class="w-4 h-4" />
              소속
            </div>
            <div class="flex-1 text-gray-900">{{ memberInfo?.team || '-' }}</div>
          </div>
          <div v-if="memberInfo?.email" class="flex flex-col md:flex-row md:items-center py-3">
            <div class="w-full md:w-24 text-sm font-medium text-gray-500 flex items-center gap-2 mb-1 md:mb-0">
              <Mail class="w-4 h-4" />
              이메일
            </div>
            <div class="flex-1 text-gray-900">{{ memberInfo?.email }}</div>
          </div>
        </div>
      </section>

      <!-- Privacy Settings Section -->
      <section class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-4">
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <Eye class="w-5 h-5 text-gray-500" />
          시간표 공개 설정
        </h2>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div>
            <p class="text-gray-700">현재 공개 대상</p>
            <p class="text-sm text-gray-500 mt-1">내 시간표를 볼 수 있는 사람을 설정합니다</p>
          </div>
          <button
            @click="showVisibilityModal = true"
            class="px-4 py-3 sm:py-2 min-h-11 bg-gray-100 hover:bg-gray-200 rounded-lg text-gray-700 font-medium transition flex items-center justify-center gap-2"
          >
            <span
              class="w-2 h-2 rounded-full"
              :class="{
                'bg-green-500': calendarVisibility === 'PUBLIC',
                'bg-yellow-500': calendarVisibility === 'FRIENDS',
                'bg-orange-500': calendarVisibility === 'FAMILY',
                'bg-red-500': calendarVisibility === 'PRIVATE',
              }"
            ></span>
            {{ visibilityLabel }}
            <ChevronRight class="w-4 h-4" />
          </button>
        </div>
      </section>

      <!-- Manager Delegation Section -->
      <section class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-4">
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <Shield class="w-5 h-5 text-gray-500" />
          관리 권한 위임
        </h2>
        <div class="space-y-4">
          <div class="flex items-center gap-2 text-sm text-gray-500">
            <Info class="w-4 h-4" />
            <span>가족만 관리자로 추가할 수 있어요</span>
          </div>

          <!-- Add Manager -->
          <div class="flex items-center gap-3">
            <select
              v-model="selectedManagerToAdd"
              @change="assignManager"
              :disabled="savingManager || availableFamilyMembers.length === 0"
              class="flex-1 px-3 py-3 sm:py-2 min-h-11 border border-gray-300 rounded-lg bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:opacity-50"
            >
              <option value="">관리자 추가</option>
              <option v-for="member in availableFamilyMembers" :key="member.id ?? 'none'" :value="member.id">
                {{ member.name }}
              </option>
            </select>
            <Loader2 v-if="savingManager" class="w-5 h-5 animate-spin text-blue-500" />
          </div>

          <!-- Current Managers -->
          <div v-if="managers.length > 0" class="flex flex-wrap gap-2">
            <div
              v-for="manager in managers"
              :key="manager.id ?? 'none'"
              class="inline-flex items-center gap-2 px-3 py-2 bg-gray-100 rounded-lg"
            >
              <span class="text-gray-700">{{ manager.name }}</span>
              <button
                @click="unAssignManager(manager)"
                class="text-gray-400 hover:text-red-500 transition"
              >
                <Trash2 class="w-4 h-4" />
              </button>
            </div>
          </div>
          <p v-else class="text-sm text-gray-400">등록된 관리자가 없습니다</p>
        </div>
      </section>

      <!-- Session Management Section -->
      <section class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-4">
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <Smartphone class="w-5 h-5 text-gray-500" />
          접속 세션 관리
        </h2>
        <div v-if="tokensLoading" class="flex items-center justify-center py-8">
          <Loader2 class="w-6 h-6 animate-spin text-blue-500" />
        </div>
        <div v-else>
          <!-- Mobile Card Layout -->
          <div class="sm:hidden space-y-3">
            <div
              v-for="token in tokens"
              :key="token.id"
              class="p-4 bg-gray-50 rounded-lg border border-gray-200"
            >
              <div class="flex items-center justify-between mb-3">
                <span class="text-sm font-medium text-gray-700">{{ formatLastUsed(token.lastUsed) }}</span>
                <span
                  v-if="token.isCurrentLogin"
                  class="px-3 py-1 text-xs font-medium text-green-700 bg-green-100 rounded-full"
                >
                  현재 접속
                </span>
                <button
                  v-else
                  @click="deleteToken(token.id)"
                  class="px-3 py-2 min-h-11 text-xs font-medium text-yellow-700 bg-yellow-100 hover:bg-yellow-200 rounded-full transition"
                >
                  접속 종료
                </button>
              </div>
              <div class="space-y-2 text-sm">
                <div class="flex items-center gap-2 text-gray-600">
                  <span class="w-16 text-gray-500">IP</span>
                  <span>{{ token.remoteAddr || '-' }}</span>
                </div>
                <div class="flex items-center gap-2 text-gray-600">
                  <span class="w-16 text-gray-500">기기</span>
                  <span class="flex items-center gap-1">
                    <Monitor v-if="token.userAgent?.device === 'Other'" class="w-4 h-4 text-gray-400" />
                    <Smartphone v-else class="w-4 h-4 text-gray-400" />
                    {{ token.userAgent?.device || '-' }}
                  </span>
                </div>
                <div class="flex items-center gap-2 text-gray-600">
                  <span class="w-16 text-gray-500">브라우저</span>
                  <span class="flex items-center gap-1">
                    <Globe class="w-4 h-4 text-gray-400" />
                    {{ token.userAgent?.browser || '-' }}
                  </span>
                </div>
              </div>
            </div>
            <div v-if="tokens.length === 0" class="py-8 text-center text-gray-400">
              세션 정보가 없습니다
            </div>
          </div>
          <!-- Desktop Table Layout -->
          <div class="hidden sm:block overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-gray-200">
                  <th class="text-left py-3 px-2 font-medium text-gray-500">접속 시간</th>
                  <th class="text-left py-3 px-2 font-medium text-gray-500">IP</th>
                  <th class="text-left py-3 px-2 font-medium text-gray-500">기기</th>
                  <th class="text-left py-3 px-2 font-medium text-gray-500">브라우저</th>
                  <th class="text-center py-3 px-2 font-medium text-gray-500">관리</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="token in tokens" :key="token.id" class="border-b border-gray-100 hover:bg-gray-50">
                  <td class="py-3 px-2 text-gray-700">{{ formatLastUsed(token.lastUsed) }}</td>
                  <td class="py-3 px-2 text-gray-700">{{ token.remoteAddr || '-' }}</td>
                  <td class="py-3 px-2">
                    <span class="flex items-center gap-1 text-gray-700">
                      <Monitor v-if="token.userAgent?.device === 'Other'" class="w-4 h-4 text-gray-400" />
                      <Smartphone v-else class="w-4 h-4 text-gray-400" />
                      {{ token.userAgent?.device || '-' }}
                    </span>
                  </td>
                  <td class="py-3 px-2">
                    <span class="flex items-center gap-1 text-gray-700">
                      <Globe class="w-4 h-4 text-gray-400" />
                      {{ token.userAgent?.browser || '-' }}
                    </span>
                  </td>
                  <td class="py-3 px-2 text-center">
                    <button
                      v-if="!token.isCurrentLogin"
                      @click="deleteToken(token.id)"
                      class="px-3 py-1 text-xs font-medium text-yellow-700 bg-yellow-100 hover:bg-yellow-200 rounded-full transition"
                    >
                      접속 종료
                    </button>
                    <span
                      v-else
                      class="px-3 py-1 text-xs font-medium text-green-700 bg-green-100 rounded-full"
                    >
                      현재 접속
                    </span>
                  </td>
                </tr>
                <tr v-if="tokens.length === 0">
                  <td colspan="5" class="py-8 text-center text-gray-400">
                    세션 정보가 없습니다
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </section>

      <!-- SSO Connections Section -->
      <section class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-4">
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <Link class="w-5 h-5 text-gray-500" />
          소셜 계정 연동
        </h2>
        <div class="space-y-3">
          <div
            v-for="sso in ssoConnections"
            :key="sso.provider"
            class="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
          >
            <div class="flex items-center gap-3">
              <img :src="sso.icon" :alt="sso.provider" class="w-8 h-8 rounded" />
              <div>
                <p class="font-medium text-gray-900">{{ sso.provider }}</p>
                <p v-if="sso.connected && sso.accountName" class="text-sm text-gray-500">
                  {{ sso.accountName }}
                </p>
              </div>
            </div>
            <div>
              <span v-if="sso.connected" class="flex items-center gap-1 text-green-600 text-sm">
                <Check class="w-4 h-4" />
                연동중
              </span>
              <button
                v-else
                @click="connectSso(sso.provider)"
                class="px-4 py-2.5 sm:py-1.5 min-h-11 sm:min-h-0 text-sm font-medium text-blue-600 bg-blue-50 hover:bg-blue-100 rounded-lg transition"
              >
                연동하기
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- Account Management Section -->
      <section class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-4">
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
          <Lock class="w-5 h-5 text-gray-500" />
          회원정보 관리
        </h2>
        <div class="flex flex-wrap gap-3">
          <button
            v-if="memberInfo?.hasPassword"
            @click="openPasswordModal"
            class="px-4 py-3 sm:py-2 min-h-11 text-sm font-medium text-blue-600 bg-blue-50 hover:bg-blue-100 rounded-lg transition flex items-center gap-2"
          >
            <Lock class="w-4 h-4" />
            비밀번호 변경
          </button>
          <button
            @click="deleteAccount"
            class="px-4 py-3 sm:py-2 min-h-11 text-sm font-medium text-red-600 bg-red-50 hover:bg-red-100 rounded-lg transition flex items-center gap-2"
          >
            <UserX class="w-4 h-4" />
            회원 탈퇴
          </button>
        </div>
      </section>

      <!-- Logout Section -->
      <section class="bg-white rounded-xl shadow-sm border border-gray-200 p-4 sm:p-6">
        <button
          @click="logout"
          class="w-full px-4 py-3 min-h-12 text-yellow-700 bg-yellow-100 hover:bg-yellow-200 rounded-lg font-medium transition flex items-center justify-center gap-2"
        >
          <LogOut class="w-5 h-5" />
          로그아웃
        </button>
      </section>
    </template>

    <!-- Visibility Modal -->
    <Teleport to="body">
      <div
        v-if="showVisibilityModal"
        class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
        @click.self="showVisibilityModal = false"
      >
        <div class="bg-white rounded-xl shadow-xl max-w-md w-full">
          <div class="flex items-center justify-between p-4 border-b border-gray-200">
            <h3 class="text-lg font-bold text-gray-900">시간표 공개 대상 설정</h3>
            <button @click="showVisibilityModal = false" class="text-gray-400 hover:text-gray-600">
              <X class="w-5 h-5" />
            </button>
          </div>
          <div class="p-4 sm:p-6">
            <p class="text-gray-600 mb-4">내 달력을 공개할 범위를 설정하세요.</p>
            <p class="text-sm text-gray-500 mb-4">선택시 변경사항이 즉시 저장됩니다.</p>
            <div class="space-y-2">
              <button
                v-for="option in visibilityOptions"
                :key="option.value"
                @click="setVisibility(option.value)"
                :disabled="savingVisibility"
                class="w-full p-4 min-h-16 rounded-lg border-2 transition text-left disabled:opacity-50"
                :class="
                  calendarVisibility === option.value
                    ? 'border-blue-500 bg-blue-50'
                    : 'border-gray-200 hover:border-gray-300'
                "
              >
                <div class="flex items-center gap-3">
                  <span class="w-3 h-3 rounded-full" :class="option.color"></span>
                  <span class="font-medium text-gray-900">{{ option.label }}</span>
                  <Check
                    v-if="calendarVisibility === option.value"
                    class="w-5 h-5 text-blue-500 ml-auto"
                  />
                  <Loader2
                    v-if="savingVisibility && calendarVisibility !== option.value"
                    class="w-5 h-5 animate-spin text-gray-400 ml-auto"
                  />
                </div>
                <p class="text-sm text-gray-500 mt-1 ml-6">{{ option.description }}</p>
              </button>
            </div>
          </div>
          <div class="p-4 sm:p-6 border-t border-gray-200">
            <button
              @click="showVisibilityModal = false"
              class="w-full px-4 py-3 sm:py-2 min-h-11 bg-gray-100 hover:bg-gray-200 rounded-lg text-gray-700 font-medium transition"
            >
              닫기
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- Password Change Modal -->
    <Teleport to="body">
      <div
        v-if="showPasswordModal"
        class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
        @click.self="showPasswordModal = false"
      >
        <div class="bg-white rounded-xl shadow-xl max-w-md w-full">
          <div class="flex items-center justify-between p-4 border-b border-gray-200">
            <h3 class="text-lg font-bold text-gray-900">비밀번호 변경</h3>
            <button @click="showPasswordModal = false" class="text-gray-400 hover:text-gray-600">
              <X class="w-5 h-5" />
            </button>
          </div>
          <div class="p-4 sm:p-6 space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">현재 비밀번호</label>
              <input
                v-model="passwordForm.currentPassword"
                type="password"
                class="w-full px-3 py-3 sm:py-2 min-h-11 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                :class="passwordErrors.currentPassword ? 'border-red-500' : 'border-gray-300'"
                placeholder="현재 비밀번호"
              />
              <p v-if="passwordErrors.currentPassword" class="text-sm text-red-500 mt-1">
                {{ passwordErrors.currentPassword }}
              </p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">새 비밀번호</label>
              <input
                v-model="passwordForm.newPassword"
                type="password"
                class="w-full px-3 py-3 sm:py-2 min-h-11 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                :class="passwordErrors.newPassword ? 'border-red-500' : 'border-gray-300'"
                placeholder="새 비밀번호 (8자 이상)"
              />
              <p v-if="passwordErrors.newPassword" class="text-sm text-red-500 mt-1">
                {{ passwordErrors.newPassword }}
              </p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">새 비밀번호 확인</label>
              <input
                v-model="passwordForm.confirmPassword"
                type="password"
                class="w-full px-3 py-3 sm:py-2 min-h-11 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                :class="passwordErrors.confirmPassword ? 'border-red-500' : 'border-gray-300'"
                placeholder="새 비밀번호 확인"
              />
              <p v-if="passwordErrors.confirmPassword" class="text-sm text-red-500 mt-1">
                {{ passwordErrors.confirmPassword }}
              </p>
            </div>
          </div>
          <div class="p-4 sm:p-6 border-t border-gray-200 flex gap-2">
            <button
              @click="showPasswordModal = false"
              :disabled="changingPassword"
              class="flex-1 px-4 py-3 sm:py-2 min-h-11 bg-gray-100 hover:bg-gray-200 rounded-lg text-gray-700 font-medium transition disabled:opacity-50"
            >
              취소
            </button>
            <button
              @click="changePassword"
              :disabled="changingPassword"
              class="flex-1 px-4 py-3 sm:py-2 min-h-11 bg-blue-600 hover:bg-blue-700 rounded-lg text-white font-medium transition disabled:opacity-50 flex items-center justify-center gap-2"
            >
              <Loader2 v-if="changingPassword" class="w-4 h-4 animate-spin" />
              {{ changingPassword ? '변경 중...' : '변경' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
