<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { adminApi } from '@/api/admin'
import { authApi } from '@/api/auth'
import { useSwal } from '@/composables/useSwal'
import type { MemberDto, RefreshTokenDto } from '@/types'
import {
  Users,
  Building2,
  Shield,
  Clock,
  Monitor,
  Globe,
  Key,
  ChevronRight,
  Search,
  RefreshCw,
  Settings,
  Activity,
  Loader2,
  TrendingUp,
  Zap,
  FileText,
  ExternalLink,
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const { showSuccess, showError, confirm } = useSwal()

const loading = ref(true)
const allMembers = ref<MemberDto[]>([])
const allTokens = ref<RefreshTokenDto[]>([])

const stats = computed(() => {
  const today = new Date().toISOString().split('T')[0] ?? ''
  const todayTokens = allTokens.value.filter(t => t.lastUsed?.startsWith(today) ?? false)

  return {
    totalMembers: allMembers.value.length,
    totalTeams: new Set(allMembers.value.map(m => m.teamId).filter(Boolean)).size,
    activeTokens: allTokens.value.length,
    todayLogins: todayTokens.length,
  }
})

interface MemberWithTokens {
  id: number
  name: string
  tokens: RefreshTokenDto[]
}

const members = computed<MemberWithTokens[]>(() => {
  const tokensByMember = new Map<number, RefreshTokenDto[]>()

  for (const token of allTokens.value) {
    const memberId = token.memberId
    if (!tokensByMember.has(memberId)) {
      tokensByMember.set(memberId, [])
    }
    tokensByMember.get(memberId)!.push(token)
  }

  const getLatestTokenTime = (memberId: number): number => {
    const tokens = tokensByMember.get(memberId) || []
    if (tokens.length === 0) return 0
    return Math.max(...tokens.map(t => t.lastUsed ? new Date(t.lastUsed).getTime() : 0))
  }

  return allMembers.value
    .map(member => ({
      id: member.id!,
      name: member.name,
      tokens: tokensByMember.get(member.id!) || [],
    }))
    .sort((a, b) => getLatestTokenTime(b.id) - getLatestTokenTime(a.id))
})

const searchKeyword = ref('')
const isLoading = ref(false)

const filteredMembers = computed(() => {
  if (!searchKeyword.value) return members.value
  const keyword = searchKeyword.value.toLowerCase()
  return members.value.filter((member) => member.name.toLowerCase().includes(keyword))
})

function formatRelativeTime(dateString: string | null): string {
  if (!dateString) return '-'
  const date = new Date(dateString)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffMins = Math.floor(diffMs / 60000)
  const diffHours = Math.floor(diffMs / 3600000)
  const diffDays = Math.floor(diffMs / 86400000)

  if (diffMins < 1) return '방금 전'
  if (diffMins < 60) return `${diffMins}분 전`
  if (diffHours < 24) return `${diffHours}시간 전`
  if (diffDays < 7) return `${diffDays}일 전`
  return date.toLocaleDateString('ko-KR')
}

const showPasswordModal = ref(false)
const selectedMember = ref<{ id: number; name: string } | null>(null)
const newPassword = ref('')
const confirmPassword = ref('')
const passwordError = ref('')

function openPasswordModal(member: { id: number; name: string }) {
  selectedMember.value = member
  newPassword.value = ''
  confirmPassword.value = ''
  passwordError.value = ''
  showPasswordModal.value = true
}

function closePasswordModal() {
  showPasswordModal.value = false
  selectedMember.value = null
}

const changingPassword = ref(false)

async function handleChangePassword() {
  if (!newPassword.value || !confirmPassword.value) {
    passwordError.value = '비밀번호를 입력해주세요'
    return
  }
  if (newPassword.value.length < 8) {
    passwordError.value = '비밀번호는 8자 이상이어야 합니다'
    return
  }
  if (newPassword.value !== confirmPassword.value) {
    passwordError.value = '비밀번호가 일치하지 않습니다'
    return
  }

  changingPassword.value = true
  try {
    await authApi.changePassword({
      memberId: selectedMember.value!.id,
      newPassword: newPassword.value,
    })
    showSuccess(`${selectedMember.value?.name}님의 비밀번호가 변경되었습니다.`)
    closePasswordModal()
  } catch (error: any) {
    const message = error.response?.data?.message || '비밀번호 변경에 실패했습니다.'
    passwordError.value = message
  } finally {
    changingPassword.value = false
  }
}

async function fetchData() {
  loading.value = true
  try {
    const [membersRes, tokensRes] = await Promise.all([
      adminApi.getAllMembers(),
      adminApi.getAllRefreshTokens(),
    ])
    allMembers.value = membersRes.data
    allTokens.value = tokensRes.data
  } catch (error) {
    console.error('Failed to fetch admin data:', error)
    showError('데이터를 불러오는데 실패했습니다.')
  } finally {
    loading.value = false
  }
}

async function refreshData() {
  isLoading.value = true
  await fetchData()
  isLoading.value = false
}

function navigateToTeams() {
  router.push('/admin/teams')
}


onMounted(async () => {
  if (!authStore.isAdmin) {
    router.push('/')
    return
  }
  await fetchData()
})
</script>

<template>
  <div class="min-h-screen bg-gray-50">
    <!-- Admin Header -->
    <div class="bg-white border-b border-gray-200">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 bg-gray-900 rounded-lg flex items-center justify-center">
              <Shield class="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 class="text-xl font-bold text-gray-900">회원 관리</h1>
              <p class="text-sm text-gray-500">회원 및 세션 관리</p>
            </div>
          </div>
          <div class="flex items-center gap-2 flex-wrap">
            <button
              @click="refreshData"
              class="p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-lg transition"
              :class="{ 'animate-spin': isLoading }"
            >
              <RefreshCw class="w-5 h-5" />
            </button>
            <button class="p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-lg transition">
              <Settings class="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
      <div v-if="loading" class="flex items-center justify-center py-20">
        <Loader2 class="w-8 h-8 animate-spin text-gray-500" />
      </div>

      <template v-else>
        <!-- Admin Navigation -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <router-link
            to="/admin"
            class="bg-gray-700 text-white rounded-xl p-4 hover:bg-gray-800 transition"
          >
            <Users class="w-6 h-6 mb-2 text-white" />
            <span class="font-medium text-white">회원 관리</span>
          </router-link>
          <router-link
            to="/admin/teams"
            class="bg-white border border-gray-200 rounded-xl p-4 hover:bg-gray-50 transition"
          >
            <Building2 class="w-6 h-6 mb-2 text-gray-600" />
            <span class="font-medium text-gray-700">팀 관리</span>
          </router-link>
          <a
            href="/docs/index.html"
            target="_blank"
            class="bg-white border border-gray-200 rounded-xl p-4 hover:bg-gray-50 transition"
          >
            <div class="flex items-center gap-1 mb-2">
              <FileText class="w-6 h-6 text-gray-600" />
              <ExternalLink class="w-3 h-3 text-gray-400" />
            </div>
            <span class="font-medium text-gray-700">API 문서</span>
          </a>
          <div class="bg-white border border-gray-200 rounded-xl p-4 opacity-50 cursor-not-allowed">
            <Settings class="w-6 h-6 mb-2 text-gray-400" />
            <span class="font-medium text-gray-400">설정</span>
          </div>
        </div>

        <!-- Stats Cards -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <div class="bg-white rounded-xl border border-gray-200 p-4">
            <div class="flex items-center justify-between mb-2">
              <Users class="w-5 h-5 text-gray-400" />
              <span class="text-xs text-gray-400">전체</span>
            </div>
            <p class="text-2xl font-bold text-gray-900">{{ stats.totalMembers }}</p>
            <p class="text-sm text-gray-500">등록 회원</p>
          </div>
          <div class="bg-white rounded-xl border border-gray-200 p-4">
            <div class="flex items-center justify-between mb-2">
              <Building2 class="w-5 h-5 text-gray-400" />
              <span class="text-xs text-gray-400">활성</span>
            </div>
            <p class="text-2xl font-bold text-gray-900">{{ stats.totalTeams }}</p>
            <p class="text-sm text-gray-500">등록 팀</p>
          </div>
          <div class="bg-white rounded-xl border border-gray-200 p-4">
            <div class="flex items-center justify-between mb-2">
              <Key class="w-5 h-5 text-gray-400" />
              <span class="text-xs text-gray-400">유효</span>
            </div>
            <p class="text-2xl font-bold text-gray-900">{{ stats.activeTokens }}</p>
            <p class="text-sm text-gray-500">활성 토큰</p>
          </div>
          <div class="bg-white rounded-xl border border-gray-200 p-4">
            <div class="flex items-center justify-between mb-2">
              <Clock class="w-5 h-5 text-gray-400" />
              <span class="text-xs text-gray-400">오늘</span>
            </div>
            <p class="text-2xl font-bold text-gray-900">{{ stats.todayLogins }}</p>
            <p class="text-sm text-gray-500">접속 횟수</p>
          </div>
        </div>

        <!-- Member Management Section -->
        <div class="bg-white rounded-xl border border-gray-200">
          <div class="p-4 border-b border-gray-200">
            <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <h2 class="text-lg font-semibold text-gray-900">회원 관리</h2>
              <div class="relative w-full sm:w-auto">
                <Search class="w-4 h-4 absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" />
                <input
                  v-model="searchKeyword"
                  type="text"
                  placeholder="회원 검색..."
                  class="w-full sm:w-auto pl-9 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent"
                />
              </div>
            </div>
          </div>

          <div class="divide-y divide-gray-100">
            <div
              v-for="member in filteredMembers"
              :key="member.id"
              class="p-4 hover:bg-gray-50 transition"
            >
              <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-3">
                <div class="flex items-center gap-3">
                  <div class="w-10 h-10 bg-gray-100 rounded-full flex items-center justify-center flex-shrink-0">
                    <span class="text-sm font-medium text-gray-600">{{ member.name.charAt(0) }}</span>
                  </div>
                  <div class="min-w-0">
                    <p class="font-medium text-gray-900 truncate">{{ member.name }}</p>
                    <p class="text-sm text-gray-500">
                      {{ member.tokens.length > 0 ? `${member.tokens.length}개의 활성 세션` : '활성 세션 없음' }}
                    </p>
                  </div>
                </div>
                <button
                  @click="openPasswordModal(member)"
                  class="px-3 py-1.5 text-sm font-medium text-yellow-600 bg-yellow-50 hover:bg-yellow-100 rounded-lg transition flex-shrink-0 self-start sm:self-auto"
                >
                  비밀번호 변경
                </button>
              </div>

              <div v-if="member.tokens.length > 0" class="ml-0 sm:ml-13 space-y-2">
                <div
                  v-for="(token, index) in member.tokens"
                  :key="index"
                  class="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-4 text-sm bg-gray-50 rounded-lg p-3"
                >
                  <div class="flex items-center gap-2 text-gray-600">
                    <Clock class="w-4 h-4 text-gray-400 flex-shrink-0" />
                    <span class="truncate">{{ formatRelativeTime(token.lastUsed) }}</span>
                  </div>
                  <div class="flex items-center gap-2 text-gray-600">
                    <Globe class="w-4 h-4 text-gray-400 flex-shrink-0" />
                    <span class="truncate">{{ token.remoteAddr }}</span>
                  </div>
                  <div class="flex items-center gap-2 text-gray-600">
                    <Monitor class="w-4 h-4 text-gray-400 flex-shrink-0" />
                    <span class="truncate">{{ token.userAgent?.device || '-' }}</span>
                  </div>
                  <div class="text-gray-500 truncate">
                    {{ token.userAgent?.browser || '-' }}
                  </div>
                </div>
              </div>
              <div v-else class="ml-0 sm:ml-13 text-sm text-gray-400 py-2">
                현재 활성화된 세션이 없습니다
              </div>
            </div>
          </div>

          <div v-if="filteredMembers.length === 0" class="p-8 text-center text-gray-500">
            검색 결과가 없습니다
          </div>
        </div>
      </template>
    </div>

    <!-- Password Change Modal -->
    <div
      v-if="showPasswordModal"
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50"
      @click.self="closePasswordModal"
    >
      <div class="bg-white rounded-xl shadow-xl w-full max-w-md mx-4">
        <div class="p-4 border-b border-gray-200">
          <h3 class="text-lg font-semibold text-gray-900">비밀번호 변경</h3>
          <p class="text-sm text-gray-500">{{ selectedMember?.name }}님의 비밀번호를 변경합니다</p>
        </div>
        <div class="p-4 space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">새 비밀번호</label>
            <input
              v-model="newPassword"
              type="password"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent"
              placeholder="새 비밀번호 입력"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">비밀번호 확인</label>
            <input
              v-model="confirmPassword"
              type="password"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent"
              placeholder="비밀번호 다시 입력"
            />
          </div>
          <p v-if="passwordError" class="text-sm text-red-500">{{ passwordError }}</p>
        </div>
        <div class="p-4 border-t border-gray-200 flex justify-end gap-2">
          <button
            @click="closePasswordModal"
            :disabled="changingPassword"
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg transition disabled:opacity-50"
          >
            취소
          </button>
          <button
            @click="handleChangePassword"
            :disabled="changingPassword"
            class="px-4 py-2 text-sm font-medium text-white bg-gray-900 hover:bg-gray-800 rounded-lg transition disabled:opacity-50 flex items-center gap-2"
          >
            <Loader2 v-if="changingPassword" class="w-4 h-4 animate-spin" />
            {{ changingPassword ? '변경 중...' : '변경' }}
          </button>
        </div>
      </div>
    </div>

  </div>
</template>
