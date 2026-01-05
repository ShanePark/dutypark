<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { adminApi } from '@/api/admin'
import { authApi } from '@/api/auth'
import { refreshTokenApi } from '@/api/member'
import { useSwal } from '@/composables/useSwal'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
import type { AdminMemberDto, RefreshTokenDto } from '@/types'
import { extractDatePart } from '@/utils/date'
import SessionTokenList from '@/components/common/SessionTokenList.vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import {
  Users,
  Building2,
  Shield,
  Key,
  ChevronLeft,
  ChevronRight,
  Search,
  RefreshCw,
  Settings,
  Loader2,
  FileText,
  ExternalLink,
  Clock,
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const { showSuccess, showError, confirm, toastSuccess } = useSwal()

const loading = ref(true)
const members = ref<AdminMemberDto[]>([])
const allTokens = ref<RefreshTokenDto[]>([])

// Pagination state
const currentPage = ref(0)
const totalPages = ref(0)
const totalElements = ref(0)
const pageSize = 10

const stats = computed(() => {
  const today = extractDatePart(new Date().toISOString())
  const todayTokens = allTokens.value.filter(t => t.lastUsed?.startsWith(today) ?? false)

  return {
    totalMembers: totalElements.value,
    totalTeams: new Set(members.value.map(m => m.teamId).filter(Boolean)).size,
    activeTokens: allTokens.value.length,
    todayLogins: todayTokens.length,
  }
})

const searchKeyword = ref('')
const isLoading = ref(false)

// Debounce search
let searchTimeout: ReturnType<typeof setTimeout> | null = null
watch(searchKeyword, () => {
  if (searchTimeout) clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    currentPage.value = 0
    fetchMembers()
  }, 300)
})


const showPasswordModal = ref(false)
useBodyScrollLock(showPasswordModal)
useEscapeKey(showPasswordModal, () => { showPasswordModal.value = false })
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

async function handleRevokeToken(tokenId: number, member: AdminMemberDto) {
  if (!await confirm(`${member.name}님의 세션을 종료하시겠습니까?`, '세션 종료')) return

  try {
    await refreshTokenApi.deleteRefreshToken(tokenId)
    toastSuccess(`${member.name}님의 세션이 종료되었습니다.`)
    member.tokens = member.tokens.filter(t => t.id !== tokenId)
    allTokens.value = allTokens.value.filter(t => t.id !== tokenId)
  } catch (error) {
    console.error('Failed to revoke token:', error)
    showError('세션 종료에 실패했습니다.')
  }
}

async function fetchMembers() {
  isLoading.value = true
  try {
    const res = await adminApi.getMembers(searchKeyword.value, currentPage.value, pageSize)
    members.value = res.data.content
    totalPages.value = res.data.totalPages
    totalElements.value = res.data.totalElements
  } catch (error) {
    console.error('Failed to fetch members:', error)
    showError('회원 목록을 불러오는데 실패했습니다.')
  } finally {
    isLoading.value = false
  }
}

async function fetchTokens() {
  try {
    const res = await adminApi.getAllRefreshTokens()
    allTokens.value = res.data
  } catch (error) {
    console.error('Failed to fetch tokens:', error)
  }
}

async function fetchData() {
  loading.value = true
  try {
    await Promise.all([fetchMembers(), fetchTokens()])
  } catch (error) {
    console.error('Failed to fetch admin data:', error)
    showError('데이터를 불러오는데 실패했습니다.')
  } finally {
    loading.value = false
  }
}

async function refreshData() {
  await fetchData()
}

function goToPage(page: number) {
  if (page >= 0 && page < totalPages.value) {
    currentPage.value = page
    fetchMembers()
  }
}

function setHoverBg(e: Event) {
  if (e.currentTarget) {
    (e.currentTarget as HTMLElement).style.backgroundColor = 'var(--dp-bg-hover)'
  }
}

function clearHoverBg(e: Event, bgColor = 'var(--dp-bg-card)') {
  if (e.currentTarget) {
    (e.currentTarget as HTMLElement).style.backgroundColor = bgColor
  }
}

function setHoverBgWithColor(e: Event, bgColor: string, textColor: string) {
  if (e.currentTarget) {
    const el = e.currentTarget as HTMLElement
    el.style.backgroundColor = bgColor
    el.style.color = textColor
  }
}

function clearHoverBgWithColor(e: Event, bgColor: string, textColor: string) {
  if (e.currentTarget) {
    const el = e.currentTarget as HTMLElement
    el.style.backgroundColor = bgColor
    el.style.color = textColor
  }
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
  <div class="min-h-screen" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
    <!-- Admin Header -->
    <div :style="{ backgroundColor: 'var(--dp-bg-primary)', borderBottom: '1px solid var(--dp-border-primary)' }">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 bg-gray-900 rounded-lg flex items-center justify-center">
              <Shield class="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 class="text-xl font-bold" :style="{ color: 'var(--dp-text-primary)' }">회원 관리</h1>
              <p class="text-sm" :style="{ color: 'var(--dp-text-muted)' }">회원 및 세션 관리</p>
            </div>
          </div>
          <div class="flex items-center gap-2 flex-wrap">
            <button
              @click="refreshData"
              class="p-2 rounded-lg transition cursor-pointer"
              :class="{ 'animate-spin': isLoading }"
              :style="{ color: 'var(--dp-text-muted)', backgroundColor: isLoading ? '' : 'transparent' }"
              @mouseover="(e: Event) => !isLoading && setHoverBgWithColor(e, 'var(--dp-bg-hover)', 'var(--dp-text-secondary)')"
              @mouseleave="(e: Event) => !isLoading && clearHoverBgWithColor(e, 'transparent', 'var(--dp-text-muted)')"
            >
              <RefreshCw class="w-5 h-5" />
            </button>
            <button
              class="p-2 rounded-lg transition cursor-pointer"
              :style="{ color: 'var(--dp-text-muted)' }"
              @mouseover="(e: Event) => setHoverBgWithColor(e, 'var(--dp-bg-hover)', 'var(--dp-text-secondary)')"
              @mouseleave="(e: Event) => clearHoverBgWithColor(e, 'transparent', 'var(--dp-text-muted)')"
            >
              <Settings class="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
      <div v-if="loading" class="flex items-center justify-center py-20">
        <Loader2 class="w-8 h-8 animate-spin" :style="{ color: 'var(--dp-text-muted)' }" />
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
            class="rounded-xl p-4 transition"
            :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }"
            @mouseover="(e: Event) => setHoverBg(e)"
            @mouseleave="(e: Event) => clearHoverBg(e)"
          >
            <Building2 class="w-6 h-6 mb-2" :style="{ color: 'var(--dp-text-secondary)' }" />
            <span class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">팀 관리</span>
          </router-link>
          <a
            href="/docs/index.html"
            target="_blank"
            class="rounded-xl p-4 transition"
            :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }"
            @mouseover="(e: Event) => setHoverBg(e)"
            @mouseleave="(e: Event) => clearHoverBg(e)"
          >
            <div class="flex items-center gap-1 mb-2">
              <FileText class="w-6 h-6" :style="{ color: 'var(--dp-text-secondary)' }" />
              <ExternalLink class="w-3 h-3" :style="{ color: 'var(--dp-text-muted)' }" />
            </div>
            <span class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">API 문서</span>
          </a>
          <div class="rounded-xl p-4 opacity-50 cursor-not-allowed" :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }">
            <Settings class="w-6 h-6 mb-2" :style="{ color: 'var(--dp-text-muted)' }" />
            <span class="font-medium" :style="{ color: 'var(--dp-text-muted)' }">설정</span>
          </div>
        </div>

        <!-- Stats Cards -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <div class="rounded-xl p-4" :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }">
            <div class="flex items-center justify-between mb-2">
              <Users class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
              <span class="text-xs" :style="{ color: 'var(--dp-text-muted)' }">전체</span>
            </div>
            <p class="text-2xl font-bold" :style="{ color: 'var(--dp-text-primary)' }">{{ stats.totalMembers }}</p>
            <p class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">등록 회원</p>
          </div>
          <div class="rounded-xl p-4" :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }">
            <div class="flex items-center justify-between mb-2">
              <Building2 class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
              <span class="text-xs" :style="{ color: 'var(--dp-text-muted)' }">활성</span>
            </div>
            <p class="text-2xl font-bold" :style="{ color: 'var(--dp-text-primary)' }">{{ stats.totalTeams }}</p>
            <p class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">등록 팀</p>
          </div>
          <div class="rounded-xl p-4" :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }">
            <div class="flex items-center justify-between mb-2">
              <Key class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
              <span class="text-xs" :style="{ color: 'var(--dp-text-muted)' }">유효</span>
            </div>
            <p class="text-2xl font-bold" :style="{ color: 'var(--dp-text-primary)' }">{{ stats.activeTokens }}</p>
            <p class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">활성 토큰</p>
          </div>
          <div class="rounded-xl p-4" :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }">
            <div class="flex items-center justify-between mb-2">
              <Clock class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
              <span class="text-xs" :style="{ color: 'var(--dp-text-muted)' }">오늘</span>
            </div>
            <p class="text-2xl font-bold" :style="{ color: 'var(--dp-text-primary)' }">{{ stats.todayLogins }}</p>
            <p class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">접속 횟수</p>
          </div>
        </div>

        <!-- Member Management Section -->
        <div class="rounded-xl" :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }">
          <div class="p-4" :style="{ borderBottom: '1px solid var(--dp-border-primary)' }">
            <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <h2 class="text-lg font-semibold" :style="{ color: 'var(--dp-text-primary)' }">회원 관리</h2>
              <div class="relative w-full sm:w-auto">
                <Search class="w-4 h-4 absolute left-3 top-1/2 transform -translate-y-1/2" :style="{ color: 'var(--dp-text-muted)' }" />
                <input
                  v-model="searchKeyword"
                  type="text"
                  placeholder="회원 검색..."
                  class="w-full sm:w-auto pl-9 pr-4 py-2 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent"
                  :style="{ backgroundColor: 'var(--dp-bg-input)', border: '1px solid var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
                />
              </div>
            </div>
          </div>

          <div :style="{ borderTop: '1px solid var(--dp-border-secondary)' }">
            <div v-if="isLoading" class="flex items-center justify-center py-12">
              <Loader2 class="w-6 h-6 animate-spin" :style="{ color: 'var(--dp-text-muted)' }" />
            </div>

            <template v-else>
              <div
                v-for="member in members"
                :key="member.id"
                class="p-4 transition"
                :style="{ borderBottom: '1px solid var(--dp-border-secondary)' }"
                @mouseover="(e: Event) => setHoverBg(e)"
                @mouseleave="(e: Event) => clearHoverBg(e, 'transparent')"
              >
                <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-3">
                  <div class="flex items-center gap-3">
                    <ProfileAvatar :member-id="member.id" :has-profile-photo="member.hasProfilePhoto" :profile-photo-version="member.profilePhotoVersion" size="md" :name="member.name" />
                    <div class="min-w-0">
                      <p class="font-medium truncate" :style="{ color: 'var(--dp-text-primary)' }">{{ member.name }}</p>
                      <p class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">
                        {{ member.tokens.length > 0 ? `${member.tokens.length}개의 활성 세션` : '활성 세션 없음' }}
                      </p>
                    </div>
                  </div>
                  <button
                    @click="openPasswordModal(member)"
                    class="px-3 py-1.5 text-sm font-medium text-yellow-600 bg-yellow-50 hover:bg-yellow-100 rounded-lg transition flex-shrink-0 self-start sm:self-auto cursor-pointer"
                  >
                    비밀번호 변경
                  </button>
                </div>

                <div v-if="member.tokens.length > 0" class="ml-0 sm:ml-13 mt-2">
                  <SessionTokenList
                    :tokens="member.tokens"
                    :loading="false"
                    :show-delete-button="true"
                    :compact="true"
                    @delete="(tokenId: number) => handleRevokeToken(tokenId, member)"
                  />
                </div>
              </div>

              <div v-if="members.length === 0" class="p-8 text-center" :style="{ color: 'var(--dp-text-muted)' }">
                검색 결과가 없습니다
              </div>
            </template>
          </div>

          <!-- Pagination -->
          <div v-if="totalPages > 1" class="p-4 flex items-center justify-between" :style="{ borderTop: '1px solid var(--dp-border-primary)' }">
            <p class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">
              총 {{ totalElements }}명 중 {{ currentPage * pageSize + 1 }}-{{ Math.min((currentPage + 1) * pageSize, totalElements) }}
            </p>
            <div class="flex items-center gap-2">
              <button
                @click="goToPage(currentPage - 1)"
                :disabled="currentPage === 0"
                class="p-2 rounded-lg transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }"
              >
                <ChevronLeft class="w-4 h-4" :style="{ color: 'var(--dp-text-secondary)' }" />
              </button>
              <span class="text-sm px-2" :style="{ color: 'var(--dp-text-primary)' }">
                {{ currentPage + 1 }} / {{ totalPages }}
              </span>
              <button
                @click="goToPage(currentPage + 1)"
                :disabled="currentPage >= totalPages - 1"
                class="p-2 rounded-lg transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }"
              >
                <ChevronRight class="w-4 h-4" :style="{ color: 'var(--dp-text-secondary)' }" />
              </button>
            </div>
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
      <div class="rounded-xl shadow-xl w-full max-w-md mx-4" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
        <div class="p-4" :style="{ borderBottom: '1px solid var(--dp-border-primary)' }">
          <h3 class="text-lg font-semibold" :style="{ color: 'var(--dp-text-primary)' }">비밀번호 변경</h3>
          <p class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">{{ selectedMember?.name }}님의 비밀번호를 변경합니다</p>
        </div>
        <div class="p-4 space-y-4">
          <div>
            <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">새 비밀번호</label>
            <input
              v-model="newPassword"
              type="password"
              class="w-full px-3 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent"
              :style="{ backgroundColor: 'var(--dp-bg-input)', border: '1px solid var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
              placeholder="새 비밀번호 입력"
            />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">비밀번호 확인</label>
            <input
              v-model="confirmPassword"
              type="password"
              class="w-full px-3 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent"
              :style="{ backgroundColor: 'var(--dp-bg-input)', border: '1px solid var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
              placeholder="비밀번호 다시 입력"
            />
          </div>
          <p v-if="passwordError" class="text-sm text-red-500">{{ passwordError }}</p>
        </div>
        <div class="p-4 flex justify-end gap-2" :style="{ borderTop: '1px solid var(--dp-border-primary)' }">
          <button
            @click="closePasswordModal"
            :disabled="changingPassword"
            class="px-4 py-2 text-sm font-medium rounded-lg transition disabled:opacity-50 cursor-pointer"
            :style="{ color: 'var(--dp-text-primary)', backgroundColor: 'var(--dp-bg-tertiary)' }"
            @mouseover="(e: Event) => !changingPassword && setHoverBg(e)"
            @mouseleave="(e: Event) => !changingPassword && clearHoverBg(e, 'var(--dp-bg-tertiary)')"
          >
            취소
          </button>
          <button
            @click="handleChangePassword"
            :disabled="changingPassword"
            class="px-4 py-2 text-sm font-medium text-white bg-gray-900 hover:bg-gray-800 rounded-lg transition disabled:opacity-50 flex items-center gap-2 cursor-pointer"
          >
            <Loader2 v-if="changingPassword" class="w-4 h-4 animate-spin" />
            {{ changingPassword ? '변경 중...' : '변경' }}
          </button>
        </div>
      </div>
    </div>

  </div>
</template>
