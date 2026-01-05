<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useThemeStore, type ThemeMode } from '@/stores/theme'
import { memberApi, refreshTokenApi } from '@/api/member'
import { authApi } from '@/api/auth'
import { useSwal } from '@/composables/useSwal'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
import { useKakao } from '@/composables/useKakao'
import type { FriendDto, MemberDto, RefreshTokenDto, CalendarVisibility, ManagedMemberDto } from '@/types'
import SessionTokenList from '@/components/common/SessionTokenList.vue'
import ProfilePhotoUploader from '@/components/common/ProfilePhotoUploader.vue'
import {
  User,
  Building2,
  Mail,
  Eye,
  Shield,
  Smartphone,
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
  Sun,
  Moon,
  Users,
  LogIn,
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const themeStore = useThemeStore()
const { showSuccess, showError, showInfo, confirm, toastSuccess } = useSwal()

// Managed members (accounts I manage)
const managedMembers = ref<ManagedMemberDto[]>([])
const managedMembersLoading = ref(false)
const impersonating = ref<number | null>(null)

async function fetchManagedMembers() {
  managedMembersLoading.value = true
  try {
    const response = await memberApi.getManagedMembers()
    managedMembers.value = response.data
  } catch (error) {
    console.error('Failed to fetch managed members:', error)
  } finally {
    managedMembersLoading.value = false
  }
}

async function handleImpersonate(member: ManagedMemberDto) {
  const confirmed = await confirm(
    `${member.name} 계정으로 전환하시겠습니까?\n\n전환 후에는 해당 계정의 모든 기능을 사용할 수 있습니다.`,
    '계정 전환'
  )

  if (!confirmed) return

  impersonating.value = member.id
  try {
    await authStore.impersonate(member.id)
    router.push('/')
  } catch (error: any) {
    console.error('Failed to impersonate:', error)
    const errorMessage = error.response?.data?.error || '계정 전환에 실패했습니다.'
    showError(errorMessage)
  } finally {
    impersonating.value = null
  }
}
const { kakaoLink } = useKakao()

// Theme settings
const themeOptions: { value: ThemeMode; label: string; icon: typeof Sun }[] = [
  { value: 'light', label: '라이트', icon: Sun },
  { value: 'dark', label: '다크', icon: Moon },
]

function setTheme(mode: ThemeMode) {
  themeStore.setTheme(mode)
}

// Loading states
const loading = ref(false)
const tokensLoading = ref(false)
const savingVisibility = ref(false)
const savingManager = ref(false)
const connectingSso = ref(false)

// Visibility settings
const calendarVisibility = ref<CalendarVisibility>('FRIENDS')
const showVisibilityModal = ref(false)
useBodyScrollLock(showVisibilityModal)
useEscapeKey(showVisibilityModal, () => { showVisibilityModal.value = false })

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
    toastSuccess('관리자가 추가되었습니다.')
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
    toastSuccess('관리자 권한이 해제되었습니다.')
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
    toastSuccess('세션이 종료되었습니다.')
  } catch (error) {
    console.error('Failed to delete token:', error)
    showError('세션 종료에 실패했습니다.')
  }
}

// SSO connections
interface SsoConnection {
  provider: string
  icon: string
  connected: boolean
  accountName?: string
}

const ssoConnections = ref<SsoConnection[]>([])

async function connectSso(provider: string) {
  if (connectingSso.value) return

  if (provider === 'Kakao') {
    const confirmed = await confirm(
      '카카오 계정을 연동하면 카카오 로그인으로 간편하게 접속할 수 있습니다. 카카오 로그인 페이지로 이동합니다.',
      '카카오 계정 연동',
    )
    if (confirmed) {
      connectingSso.value = true
      kakaoLink()
    }
    return
  }
}

// Password change
const showPasswordModal = ref(false)
useBodyScrollLock(showPasswordModal)
useEscapeKey(showPasswordModal, () => { showPasswordModal.value = false })
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
  } else if (passwordForm.value.newPassword.length < 8 || passwordForm.value.newPassword.length > 20) {
    passwordErrors.value.newPassword = '비밀번호는 8-20자여야 합니다'
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

// Profile photo handling
function onProfilePhotoUpdate(photoUrl: string | null) {
  if (memberInfo.value) {
    memberInfo.value = { ...memberInfo.value, profilePhotoUrl: photoUrl }
  }
}

// Initialize data
onMounted(async () => {
  loading.value = true
  try {
    // Fetch all data in parallel
    await Promise.all([
      fetchMemberInfo(),
      fetchFamilyAndManagers(),
      fetchManagedMembers(),
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
    <h1 class="text-2xl font-bold mb-6" :style="{ color: 'var(--dp-text-primary)' }">내 정보</h1>

    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center py-20">
      <Loader2 class="w-8 h-8 animate-spin text-blue-500" />
    </div>

    <template v-else>
      <!-- Profile Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4" :style="{ backgroundColor: 'var(--dp-bg-card)', borderWidth: '1px', borderColor: 'var(--dp-border-primary)' }">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
          <User class="w-5 h-5" :style="{ color: 'var(--dp-text-secondary)' }" />
          기본 정보
        </h2>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
          <!-- Profile Photo (Left) -->
          <div class="flex flex-col items-center">
            <h3 class="text-sm font-medium mb-3" :style="{ color: 'var(--dp-text-secondary)' }">프로필 사진</h3>
            <ProfilePhotoUploader
              :current-photo-url="memberInfo?.profilePhotoUrl"
              @upload-complete="onProfilePhotoUpdate"
            />
          </div>

          <!-- Member Info (Right) -->
          <div class="flex flex-col justify-center space-y-4">
            <div class="flex items-center gap-3">
              <User class="w-4 h-4 flex-shrink-0" :style="{ color: 'var(--dp-text-secondary)' }" />
              <span class="text-sm w-14 flex-shrink-0" :style="{ color: 'var(--dp-text-secondary)' }">이름</span>
              <span class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">{{ memberInfo?.name }}</span>
            </div>
            <div class="flex items-center gap-3">
              <Building2 class="w-4 h-4 flex-shrink-0" :style="{ color: 'var(--dp-text-secondary)' }" />
              <span class="text-sm w-14 flex-shrink-0" :style="{ color: 'var(--dp-text-secondary)' }">소속</span>
              <span class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">{{ memberInfo?.team || '-' }}</span>
            </div>
            <div v-if="memberInfo?.email" class="flex items-center gap-3">
              <Mail class="w-4 h-4 flex-shrink-0" :style="{ color: 'var(--dp-text-secondary)' }" />
              <span class="text-sm w-14 flex-shrink-0" :style="{ color: 'var(--dp-text-secondary)' }">이메일</span>
              <span class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">{{ memberInfo?.email }}</span>
            </div>
          </div>
        </div>
      </section>

      <!-- Privacy Settings Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4" :style="{ backgroundColor: 'var(--dp-bg-card)', borderWidth: '1px', borderColor: 'var(--dp-border-primary)' }">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
          <Eye class="w-5 h-5" :style="{ color: 'var(--dp-text-secondary)' }" />
          시간표 공개 설정
        </h2>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div>
            <p :style="{ color: 'var(--dp-text-primary)' }">현재 공개 대상</p>
            <p class="text-sm mt-1" :style="{ color: 'var(--dp-text-secondary)' }">내 시간표를 볼 수 있는 사람을 설정합니다</p>
          </div>
          <button
            @click="showVisibilityModal = true"
            class="px-4 py-3 sm:py-2 min-h-11 rounded-lg font-medium transition flex items-center justify-center gap-2 hover:brightness-95 cursor-pointer"
            :style="{ backgroundColor: 'var(--dp-bg-tertiary)', color: 'var(--dp-text-primary)' }"
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

      <!-- Theme Settings Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4" :style="{ backgroundColor: 'var(--dp-bg-card)', borderWidth: '1px', borderColor: 'var(--dp-border-primary)' }">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
          <Sun class="w-5 h-5" :style="{ color: 'var(--dp-text-secondary)' }" />
          화면 테마 설정
        </h2>
        <div class="flex flex-col sm:flex-row gap-3">
          <button
            v-for="option in themeOptions"
            :key="option.value"
            @click="setTheme(option.value)"
            class="flex-1 px-4 py-3 rounded-lg font-medium transition flex items-center justify-center gap-2 hover:brightness-95 cursor-pointer"
            :class="{ 'hover:scale-[1.02]': themeStore.mode !== option.value }"
            :style="{
              borderWidth: '2px',
              borderColor: themeStore.mode === option.value ? '#3b82f6' : 'var(--dp-border-primary)',
              backgroundColor: themeStore.mode === option.value ? (themeStore.isDark ? '#1e3a5f' : '#eff6ff') : 'var(--dp-bg-secondary)',
              color: themeStore.mode === option.value ? '#3b82f6' : 'var(--dp-text-primary)'
            }"
          >
            <component :is="option.icon" class="w-5 h-5" />
            {{ option.label }}
          </button>
        </div>
        <p class="text-sm mt-3" :style="{ color: 'var(--dp-text-muted)' }">
          {{ themeStore.mode === 'dark' ? '다크 모드가 적용됩니다' : '라이트 모드가 적용됩니다' }}
        </p>
      </section>

      <!-- Manager Delegation Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4" :style="{ backgroundColor: 'var(--dp-bg-card)', borderWidth: '1px', borderColor: 'var(--dp-border-primary)' }">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
          <Shield class="w-5 h-5" :style="{ color: 'var(--dp-text-secondary)' }" />
          관리 권한 위임
        </h2>
        <div class="space-y-4">
          <div class="flex items-center gap-2 text-sm" :style="{ color: 'var(--dp-text-secondary)' }">
            <Info class="w-4 h-4" />
            <span>가족만 관리자로 추가할 수 있어요</span>
          </div>

          <!-- Add Manager -->
          <div class="flex items-center gap-3">
            <select
              v-model="selectedManagerToAdd"
              @change="assignManager"
              :disabled="savingManager || availableFamilyMembers.length === 0"
              class="flex-1 px-3 py-3 sm:py-2 min-h-11 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:opacity-50"
              :style="{ borderWidth: '1px', borderColor: 'var(--dp-border-primary)', backgroundColor: 'var(--dp-bg-secondary)', color: 'var(--dp-text-primary)' }"
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
              class="inline-flex items-center gap-2 px-3 py-2 rounded-lg"
              :style="{ backgroundColor: 'var(--dp-bg-hover)' }"
            >
              <span :style="{ color: 'var(--dp-text-primary)' }">{{ manager.name }}</span>
              <button
                @click="unAssignManager(manager)"
                class="p-1 rounded-full hover-danger cursor-pointer"
                :style="{ color: 'var(--dp-text-muted)' }"
              >
                <Trash2 class="w-4 h-4" />
              </button>
            </div>
          </div>
          <p v-else class="text-sm" :style="{ color: 'var(--dp-text-muted)' }">등록된 관리자가 없습니다</p>

          <!-- Managed Members (accounts I manage) -->
          <div v-if="managedMembers.length > 0" class="mt-6 pt-4" :style="{ borderTopWidth: '1px', borderColor: 'var(--dp-border-primary)' }">
            <div class="flex items-center gap-2 mb-3">
              <Users class="w-4 h-4" :style="{ color: 'var(--dp-text-secondary)' }" />
              <h3 class="text-sm font-medium" :style="{ color: 'var(--dp-text-primary)' }">내가 관리 중인 계정</h3>
            </div>
            <div class="space-y-2">
              <div
                v-for="member in managedMembers"
                :key="member.id"
                class="flex items-center justify-between p-3 rounded-lg"
                :style="{ backgroundColor: 'var(--dp-bg-secondary)' }"
              >
                <div class="flex items-center gap-3">
                  <div
                    class="w-9 h-9 rounded-full flex items-center justify-center overflow-hidden"
                    :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }"
                  >
                    <img
                      v-if="member.profilePhotoUrl"
                      :src="member.profilePhotoUrl"
                      :alt="member.name"
                      class="w-full h-full object-cover"
                    />
                    <User v-else class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
                  </div>
                  <div>
                    <p class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">{{ member.name }}</p>
                    <p v-if="member.team" class="text-xs" :style="{ color: 'var(--dp-text-muted)' }">{{ member.team }}</p>
                  </div>
                </div>
                <button
                  @click="handleImpersonate(member)"
                  :disabled="impersonating === member.id"
                  class="flex items-center gap-1.5 px-3 py-2 min-h-10 text-sm font-medium text-blue-600 bg-blue-50 hover:bg-blue-100 rounded-lg transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
                >
                  <Loader2 v-if="impersonating === member.id" class="w-4 h-4 animate-spin" />
                  <LogIn v-else class="w-4 h-4" />
                  <span class="hidden sm:inline">로그인하기</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Session Management Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4" :style="{ backgroundColor: 'var(--dp-bg-card)', borderWidth: '1px', borderColor: 'var(--dp-border-primary)' }">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
          <Smartphone class="w-5 h-5" :style="{ color: 'var(--dp-text-secondary)' }" />
          접속 세션 관리
        </h2>
        <SessionTokenList
          :tokens="tokens"
          :loading="tokensLoading"
          :show-delete-button="true"
          @delete="deleteToken"
        />
      </section>

      <!-- SSO Connections Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4" :style="{ backgroundColor: 'var(--dp-bg-card)', borderWidth: '1px', borderColor: 'var(--dp-border-primary)' }">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
          <Link class="w-5 h-5" :style="{ color: 'var(--dp-text-secondary)' }" />
          소셜 계정 연동
        </h2>
        <div class="space-y-3">
          <div
            v-for="sso in ssoConnections"
            :key="sso.provider"
            class="flex items-center justify-between p-3 rounded-lg"
            :style="{ backgroundColor: 'var(--dp-bg-secondary)' }"
          >
            <div class="flex items-center gap-3">
              <img :src="sso.icon" :alt="sso.provider" class="w-8 h-8 rounded" />
              <div>
                <p class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">{{ sso.provider }}</p>
                <p v-if="sso.connected && sso.accountName" class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">
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
                :disabled="connectingSso"
                class="px-4 py-2.5 sm:py-1.5 min-h-11 sm:min-h-0 text-sm font-medium text-blue-600 bg-blue-50 hover:bg-blue-100 rounded-lg transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
              >
                {{ connectingSso ? '연동 중...' : '연동하기' }}
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- Account Management Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4" :style="{ backgroundColor: 'var(--dp-bg-card)', borderWidth: '1px', borderColor: 'var(--dp-border-primary)' }">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
          <Lock class="w-5 h-5" :style="{ color: 'var(--dp-text-secondary)' }" />
          회원정보 관리
        </h2>
        <div class="flex flex-wrap gap-3">
          <button
            v-if="memberInfo?.hasPassword"
            @click="openPasswordModal"
            class="px-4 py-3 sm:py-2 min-h-11 text-sm font-medium text-blue-600 bg-blue-50 hover:bg-blue-100 rounded-lg transition flex items-center gap-2 cursor-pointer"
          >
            <Lock class="w-4 h-4" />
            비밀번호 변경
          </button>
          <button
            @click="deleteAccount"
            class="px-4 py-3 sm:py-2 min-h-11 text-sm font-medium text-red-600 bg-red-50 hover:bg-red-100 rounded-lg transition flex items-center gap-2 cursor-pointer"
          >
            <UserX class="w-4 h-4" />
            회원 탈퇴
          </button>
        </div>
      </section>

      <!-- Logout Section -->
      <section class="rounded-xl shadow-sm p-4 sm:p-6" :style="{ backgroundColor: 'var(--dp-bg-card)', borderWidth: '1px', borderColor: 'var(--dp-border-primary)' }">
        <button
          @click="logout"
          class="w-full px-4 py-3 min-h-12 text-yellow-700 bg-yellow-100 hover:bg-yellow-200 rounded-lg font-medium transition flex items-center justify-center gap-2 cursor-pointer"
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
        <div class="rounded-xl shadow-xl max-w-md w-full" :style="{ backgroundColor: 'var(--dp-bg-card)' }">
          <div class="flex items-center justify-between p-4" :style="{ borderBottomWidth: '1px', borderColor: 'var(--dp-border-primary)' }">
            <h3 class="text-lg font-bold" :style="{ color: 'var(--dp-text-primary)' }">시간표 공개 대상 설정</h3>
            <button @click="showVisibilityModal = false" class="p-1.5 rounded-full hover-close-btn cursor-pointer" :style="{ color: 'var(--dp-text-muted)' }">
              <X class="w-5 h-5" />
            </button>
          </div>
          <div class="p-4 sm:p-6">
            <p class="mb-4" :style="{ color: 'var(--dp-text-secondary)' }">내 달력을 공개할 범위를 설정하세요.</p>
            <p class="text-sm mb-4" :style="{ color: 'var(--dp-text-muted)' }">선택시 변경사항이 즉시 저장됩니다.</p>
            <div class="space-y-2">
              <button
                v-for="option in visibilityOptions"
                :key="option.value"
                @click="setVisibility(option.value)"
                :disabled="savingVisibility"
                class="w-full p-4 min-h-16 rounded-lg transition text-left disabled:opacity-50 hover:scale-[1.01] cursor-pointer"
                :class="{ 'hover:bg-opacity-80': calendarVisibility !== option.value }"
                :style="{
                  borderWidth: '2px',
                  borderColor: calendarVisibility === option.value ? '#3b82f6' : 'var(--dp-border-primary)',
                  backgroundColor: calendarVisibility === option.value ? (themeStore.isDark ? '#1e3a5f' : '#eff6ff') : 'var(--dp-bg-secondary)'
                }"
              >
                <div class="flex items-center gap-3">
                  <span class="w-3 h-3 rounded-full" :class="option.color"></span>
                  <span class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">{{ option.label }}</span>
                  <Check
                    v-if="calendarVisibility === option.value"
                    class="w-5 h-5 text-blue-500 ml-auto"
                  />
                  <Loader2
                    v-if="savingVisibility && calendarVisibility !== option.value"
                    class="w-5 h-5 animate-spin ml-auto"
                    :style="{ color: 'var(--dp-text-muted)' }"
                  />
                </div>
                <p class="text-sm mt-1 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">{{ option.description }}</p>
              </button>
            </div>
          </div>
          <div class="p-4 sm:p-6" :style="{ borderTopWidth: '1px', borderColor: 'var(--dp-border-primary)' }">
            <button
              @click="showVisibilityModal = false"
              class="w-full px-4 py-3 sm:py-2 min-h-11 rounded-lg font-medium hover-interactive cursor-pointer"
              :style="{ backgroundColor: 'var(--dp-bg-tertiary)', color: 'var(--dp-text-primary)' }"
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
        <div class="rounded-xl shadow-xl max-w-md w-full" :style="{ backgroundColor: 'var(--dp-bg-card)' }">
          <div class="flex items-center justify-between p-4" :style="{ borderBottomWidth: '1px', borderColor: 'var(--dp-border-primary)' }">
            <h3 class="text-lg font-bold" :style="{ color: 'var(--dp-text-primary)' }">비밀번호 변경</h3>
            <button @click="showPasswordModal = false" class="p-1.5 rounded-full hover-close-btn cursor-pointer" :style="{ color: 'var(--dp-text-muted)' }">
              <X class="w-5 h-5" />
            </button>
          </div>
          <div class="p-4 sm:p-6 space-y-4">
            <div>
              <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-primary)' }">현재 비밀번호</label>
              <input
                v-model="passwordForm.currentPassword"
                type="password"
                maxlength="20"
                class="w-full px-3 py-3 sm:py-2 min-h-11 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                :style="{
                  borderWidth: '1px',
                  borderColor: passwordErrors.currentPassword ? '#ef4444' : 'var(--dp-border-primary)',
                  backgroundColor: 'var(--dp-bg-primary)',
                  color: 'var(--dp-text-primary)'
                }"
                placeholder="현재 비밀번호"
              />
              <p v-if="passwordErrors.currentPassword" class="text-sm text-red-500 mt-1">
                {{ passwordErrors.currentPassword }}
              </p>
            </div>
            <div>
              <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-primary)' }">새 비밀번호</label>
              <input
                v-model="passwordForm.newPassword"
                type="password"
                maxlength="20"
                class="w-full px-3 py-3 sm:py-2 min-h-11 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                :style="{
                  borderWidth: '1px',
                  borderColor: passwordErrors.newPassword ? '#ef4444' : 'var(--dp-border-primary)',
                  backgroundColor: 'var(--dp-bg-primary)',
                  color: 'var(--dp-text-primary)'
                }"
                placeholder="새 비밀번호 (8-20자)"
              />
              <p v-if="passwordErrors.newPassword" class="text-sm text-red-500 mt-1">
                {{ passwordErrors.newPassword }}
              </p>
            </div>
            <div>
              <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-primary)' }">새 비밀번호 확인</label>
              <input
                v-model="passwordForm.confirmPassword"
                type="password"
                maxlength="20"
                class="w-full px-3 py-3 sm:py-2 min-h-11 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                :style="{
                  borderWidth: '1px',
                  borderColor: passwordErrors.confirmPassword ? '#ef4444' : 'var(--dp-border-primary)',
                  backgroundColor: 'var(--dp-bg-primary)',
                  color: 'var(--dp-text-primary)'
                }"
                placeholder="새 비밀번호 확인"
              />
              <p v-if="passwordErrors.confirmPassword" class="text-sm text-red-500 mt-1">
                {{ passwordErrors.confirmPassword }}
              </p>
            </div>
          </div>
          <div class="p-4 sm:p-6 flex gap-2" :style="{ borderTopWidth: '1px', borderColor: 'var(--dp-border-primary)' }">
            <button
              @click="changePassword"
              :disabled="changingPassword"
              class="flex-1 px-4 py-3 sm:py-2 min-h-11 bg-blue-600 hover:bg-blue-700 rounded-lg text-white font-medium transition disabled:opacity-50 flex items-center justify-center gap-2"
            >
              <Loader2 v-if="changingPassword" class="w-4 h-4 animate-spin" />
              {{ changingPassword ? '변경 중...' : '변경' }}
            </button>
            <button
              @click="showPasswordModal = false"
              :disabled="changingPassword"
              class="flex-1 px-4 py-3 sm:py-2 min-h-11 rounded-lg font-medium hover-interactive cursor-pointer disabled:opacity-50"
              :style="{ backgroundColor: 'var(--dp-bg-hover)', color: 'var(--dp-text-primary)' }"
            >
              취소
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
