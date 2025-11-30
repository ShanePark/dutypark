<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { adminApi } from '@/api/admin'
import { useSwal } from '@/composables/useSwal'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import type { SimpleTeam, TeamNameCheckResult } from '@/types'
import {
  Shield,
  Building2,
  Users,
  Search,
  Plus,
  ChevronLeft,
  ChevronRight,
  RefreshCw,
  Settings,
  X,
  Check,
  AlertCircle,
  Loader2,
  FileText,
  ExternalLink,
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const { showError, toastSuccess } = useSwal()

// Team list state
const teams = ref<SimpleTeam[]>([])
const keyword = ref('')
const searchKeyword = ref('')
const page = ref(0)
const size = 10
const totalElements = ref(0)
const totalPages = ref(0)
const isLoading = ref(false)

// New team modal state
const showNewTeamModal = ref(false)
const newTeamName = ref('')
const newTeamDescription = ref('')
const nameCheckResult = ref<TeamNameCheckResult | null>(null)
const isCheckingName = ref(false)
const isCreating = ref(false)

// Fetch teams from API
async function fetchTeams() {
  isLoading.value = true
  try {
    const response = await adminApi.getTeams(searchKeyword.value, page.value, size)
    teams.value = response.data.content
    totalElements.value = response.data.totalElements
    totalPages.value = response.data.totalPages
  } catch (error) {
    console.error('Failed to fetch teams:', error)
    showError('팀 목록을 불러오는데 실패했습니다.')
  } finally {
    isLoading.value = false
  }
}

function openNewTeamModal() {
  newTeamName.value = ''
  newTeamDescription.value = ''
  nameCheckResult.value = null
  showNewTeamModal.value = true
}

function closeNewTeamModal() {
  showNewTeamModal.value = false
}

async function checkTeamName() {
  if (newTeamName.value.length < 2) {
    nameCheckResult.value = 'TOO_SHORT'
    return
  }
  if (newTeamName.value.length > 20) {
    nameCheckResult.value = 'TOO_LONG'
    return
  }

  isCheckingName.value = true
  try {
    const response = await adminApi.checkTeamName(newTeamName.value)
    nameCheckResult.value = response.data
  } catch (error) {
    console.error('Failed to check team name:', error)
    showError('팀 이름 확인에 실패했습니다.')
  } finally {
    isCheckingName.value = false
  }
}

function getNameCheckMessage(): string {
  switch (nameCheckResult.value) {
    case 'TOO_SHORT':
      return '팀 이름은 2자 이상이어야 합니다'
    case 'TOO_LONG':
      return '팀 이름은 20자 이하여야 합니다'
    case 'DUPLICATED':
      return '이미 존재하는 팀 이름입니다'
    case 'OK':
      return '사용 가능한 팀 이름입니다'
    default:
      return ''
  }
}

async function handleCreateTeam() {
  if (nameCheckResult.value !== 'OK') return
  if (!newTeamDescription.value) return

  isCreating.value = true
  try {
    const response = await adminApi.createTeam({
      name: newTeamName.value,
      description: newTeamDescription.value,
    })
    toastSuccess('팀이 생성되었습니다.')
    closeNewTeamModal()
    // Navigate to team manage page
    router.push(`/team/manage/${response.data.id}`)
  } catch (error) {
    console.error('Failed to create team:', error)
    showError('팀 생성에 실패했습니다.')
  } finally {
    isCreating.value = false
  }
}

function manageTeam(teamId: number) {
  router.push(`/team/manage/${teamId}`)
}

function handleSearch() {
  searchKeyword.value = keyword.value
  page.value = 0
  fetchTeams()
}

function goToPage(pageNum: number) {
  if (pageNum >= 0 && pageNum < totalPages.value) {
    page.value = pageNum
    fetchTeams()
  }
}

function refreshData() {
  fetchTeams()
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


onMounted(() => {
  if (!authStore.isAdmin) {
    router.push('/')
    return
  }
  fetchTeams()
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
              <h1 class="text-xl font-bold" :style="{ color: 'var(--dp-text-primary)' }">팀 관리</h1>
              <p class="text-sm" :style="{ color: 'var(--dp-text-muted)' }">팀 생성 및 관리</p>
            </div>
          </div>
          <div class="flex items-center gap-2 flex-wrap">
            <button
              @click="refreshData"
              class="p-2 rounded-lg transition"
              :class="{ 'animate-spin': isLoading }"
              :style="{ color: 'var(--dp-text-muted)', backgroundColor: isLoading ? '' : 'transparent' }"
              @mouseover="(e: Event) => !isLoading && setHoverBgWithColor(e, 'var(--dp-bg-hover)', 'var(--dp-text-secondary)')"
              @mouseleave="(e: Event) => !isLoading && clearHoverBgWithColor(e, 'transparent', 'var(--dp-text-muted)')"
            >
              <RefreshCw class="w-5 h-5" />
            </button>
            <button
              class="p-2 rounded-lg transition"
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
      <!-- Admin Navigation -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <router-link
          to="/admin"
          class="rounded-xl p-4 transition"
          :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }"
          @mouseover="(e: Event) => setHoverBg(e)"
          @mouseleave="(e: Event) => clearHoverBg(e)"
        >
          <Users class="w-6 h-6 mb-2" :style="{ color: 'var(--dp-text-secondary)' }" />
          <span class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">회원 관리</span>
        </router-link>
        <router-link
          to="/admin/teams"
          class="bg-gray-700 text-white rounded-xl p-4 hover:bg-gray-800 transition"
        >
          <Building2 class="w-6 h-6 mb-2 text-white" />
          <span class="font-medium text-white">팀 관리</span>
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

      <!-- Team List Section -->
      <div class="rounded-xl" :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }">
        <div class="p-4" :style="{ borderBottom: '1px solid var(--dp-border-primary)' }">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h2 class="text-lg font-semibold" :style="{ color: 'var(--dp-text-primary)' }">팀 목록</h2>
              <p class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">
                <span v-if="searchKeyword" class="text-blue-600">[{{ searchKeyword }}]</span>
                총 {{ totalElements }}개의 팀이 있습니다
              </p>
            </div>
            <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-2 w-full sm:w-auto">
              <div class="relative flex-1 sm:flex-initial">
                <Search class="w-4 h-4 absolute left-3 top-1/2 transform -translate-y-1/2" :style="{ color: 'var(--dp-text-muted)' }" />
                <input
                  v-model="keyword"
                  type="text"
                  placeholder="팀 검색..."
                  class="w-full pl-9 pr-4 py-2 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent"
                  :style="{ backgroundColor: 'var(--dp-bg-input)', border: '1px solid var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
                  @keyup.enter="handleSearch"
                />
              </div>
              <button
                @click="handleSearch"
                class="px-4 py-2 text-sm font-medium rounded-lg transition"
                :style="{ color: 'var(--dp-text-primary)', backgroundColor: 'var(--dp-bg-tertiary)' }"
                @mouseover="(e: Event) => setHoverBg(e)"
                @mouseleave="(e: Event) => clearHoverBg(e, 'var(--dp-bg-tertiary)')"
              >
                검색
              </button>
              <button
                @click="openNewTeamModal"
                class="flex items-center justify-center gap-2 px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition"
              >
                <Plus class="w-4 h-4" />
                <span class="hidden sm:inline">새 팀 추가</span>
                <span class="sm:hidden">추가</span>
              </button>
            </div>
          </div>
        </div>

        <!-- Team Table (Desktop) -->
        <div class="hidden sm:block overflow-x-auto">
          <table class="w-full">
            <thead :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }">
              <tr>
                <th class="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider w-12" :style="{ color: 'var(--dp-text-muted)' }">
                  #
                </th>
                <th class="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider w-40" :style="{ color: 'var(--dp-text-muted)' }">
                  이름
                </th>
                <th class="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider w-24" :style="{ color: 'var(--dp-text-muted)' }">
                  멤버
                </th>
                <th class="px-4 py-3 text-left text-xs font-medium uppercase tracking-wider" :style="{ color: 'var(--dp-text-muted)' }">
                  설명
                </th>
              </tr>
            </thead>
            <tbody :style="{ borderTop: '1px solid var(--dp-border-secondary)' }">
              <tr
                v-for="(team, index) in teams"
                :key="team.id"
                class="cursor-pointer transition"
                :style="{ borderBottom: '1px solid var(--dp-border-secondary)' }"
                @click="manageTeam(team.id)"
                @mouseover="(e: Event) => setHoverBg(e)"
                @mouseleave="(e: Event) => clearHoverBg(e, 'transparent')"
              >
                <td class="px-4 py-4 text-sm" :style="{ color: 'var(--dp-text-muted)' }">
                  {{ page * size + index + 1 }}
                </td>
                <td class="px-4 py-4">
                  <div class="flex items-center gap-2">
                    <Building2 class="w-4 h-4" :style="{ color: 'var(--dp-text-muted)' }" />
                    <span class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">{{ team.name }}</span>
                  </div>
                </td>
                <td class="px-4 py-4">
                  <div class="flex items-center gap-1 text-sm" :style="{ color: 'var(--dp-text-secondary)' }">
                    <Users class="w-4 h-4" :style="{ color: 'var(--dp-text-muted)' }" />
                    {{ team.memberCount }}명
                  </div>
                </td>
                <td class="px-4 py-4 text-sm" :style="{ color: 'var(--dp-text-secondary)' }">
                  {{ team.description }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Team Cards (Mobile) -->
        <div class="sm:hidden" :style="{ borderTop: '1px solid var(--dp-border-secondary)' }">
          <div
            v-for="(team, index) in teams"
            :key="team.id"
            class="p-4 cursor-pointer transition"
            :style="{ borderBottom: '1px solid var(--dp-border-secondary)' }"
            @click="manageTeam(team.id)"
            @mouseover="(e: Event) => setHoverBg(e)"
            @mouseleave="(e: Event) => clearHoverBg(e, 'transparent')"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="flex items-center gap-3 min-w-0">
                <div class="w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0" :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }">
                  <Building2 class="w-5 h-5" :style="{ color: 'var(--dp-text-secondary)' }" />
                </div>
                <div class="min-w-0">
                  <p class="font-medium truncate" :style="{ color: 'var(--dp-text-primary)' }">{{ team.name }}</p>
                  <p class="text-sm truncate" :style="{ color: 'var(--dp-text-secondary)' }">{{ team.description }}</p>
                </div>
              </div>
              <div class="flex items-center gap-1 text-sm flex-shrink-0" :style="{ color: 'var(--dp-text-secondary)' }">
                <Users class="w-4 h-4" :style="{ color: 'var(--dp-text-muted)' }" />
                {{ team.memberCount }}명
              </div>
            </div>
          </div>
        </div>

        <div v-if="teams.length === 0 && !isLoading" class="p-8 text-center" :style="{ color: 'var(--dp-text-muted)' }">
          검색 결과가 없습니다
        </div>

        <!-- Footer with Pagination -->
        <div v-if="totalPages > 1" class="p-4 flex justify-center" :style="{ borderTop: '1px solid var(--dp-border-primary)' }">
          <!-- Pagination -->
          <nav class="flex items-center gap-1">
            <button
              :disabled="page === 0"
              class="p-2 rounded-lg transition disabled:opacity-50 disabled:cursor-not-allowed"
              :style="{ color: 'var(--dp-text-muted)' }"
              @click="goToPage(page - 1)"
              @mouseover="(e: Event) => page !== 0 && setHoverBgWithColor(e, 'var(--dp-bg-hover)', 'var(--dp-text-secondary)')"
              @mouseleave="(e: Event) => page !== 0 && clearHoverBgWithColor(e, 'transparent', 'var(--dp-text-muted)')"
            >
              <ChevronLeft class="w-4 h-4" />
            </button>
            <!-- Desktop: Show all page numbers -->
            <template v-for="p in totalPages" :key="p">
              <button
                v-if="totalPages <= 5 || p === 1 || p === totalPages || (p >= page && p <= page + 2)"
                class="px-3 py-1 text-sm rounded-lg transition"
                :class="p - 1 === page ? 'bg-gray-900 text-white' : ''"
                :style="p - 1 !== page ? { color: 'var(--dp-text-secondary)' } : {}"
                @click="goToPage(p - 1)"
                @mouseover="(e: Event) => p - 1 !== page && setHoverBg(e)"
                @mouseleave="(e: Event) => p - 1 !== page && clearHoverBg(e, 'transparent')"
              >
                {{ p }}
              </button>
              <span
                v-else-if="p === 2 && page > 2"
                class="px-1"
                :style="{ color: 'var(--dp-text-muted)' }"
              >...</span>
              <span
                v-else-if="p === totalPages - 1 && page < totalPages - 3"
                class="px-1"
                :style="{ color: 'var(--dp-text-muted)' }"
              >...</span>
            </template>
            <button
              :disabled="page === totalPages - 1"
              class="p-2 rounded-lg transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
              :style="{ color: 'var(--dp-text-muted)' }"
              @click="goToPage(page + 1)"
              @mouseover="(e: Event) => page !== totalPages - 1 && setHoverBgWithColor(e, 'var(--dp-bg-hover)', 'var(--dp-text-secondary)')"
              @mouseleave="(e: Event) => page !== totalPages - 1 && clearHoverBgWithColor(e, 'transparent', 'var(--dp-text-muted)')"
            >
              <ChevronRight class="w-4 h-4" />
            </button>
          </nav>
        </div>
      </div>
    </div>

    <!-- New Team Modal -->
    <div
      v-if="showNewTeamModal"
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50"
      @click.self="closeNewTeamModal"
    >
      <div class="rounded-xl shadow-xl w-full max-w-md mx-4" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
        <div class="p-4 flex items-center justify-between" :style="{ borderBottom: '1px solid var(--dp-border-primary)' }">
          <h3 class="text-lg font-semibold" :style="{ color: 'var(--dp-text-primary)' }">새 팀 추가</h3>
          <button
            @click="closeNewTeamModal"
            class="p-1 rounded transition cursor-pointer"
            :style="{ color: 'var(--dp-text-muted)' }"
            @mouseover="(e: Event) => { if (e.currentTarget) (e.currentTarget as HTMLElement).style.color = 'var(--dp-text-secondary)' }"
            @mouseleave="(e: Event) => { if (e.currentTarget) (e.currentTarget as HTMLElement).style.color = 'var(--dp-text-muted)' }"
          >
            <X class="w-5 h-5" />
          </button>
        </div>
        <div class="p-4 space-y-4">
          <div>
            <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
              팀 이름
              <CharacterCounter :current="newTeamName.length" :max="20" />
            </label>
            <div class="flex gap-2">
              <input
                v-model="newTeamName"
                type="text"
                maxlength="20"
                minlength="2"
                class="flex-1 px-3 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent"
                :style="{ backgroundColor: 'var(--dp-bg-input)', border: '1px solid var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
                placeholder="팀 이름 입력"
                @input="nameCheckResult = null"
              />
              <button
                @click="checkTeamName"
                class="px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition cursor-pointer"
              >
                확인
              </button>
            </div>
            <p
              v-if="nameCheckResult"
              class="mt-1 text-sm flex items-center gap-1"
              :class="nameCheckResult === 'OK' ? 'text-green-600' : 'text-red-500'"
            >
              <Check v-if="nameCheckResult === 'OK'" class="w-4 h-4" />
              <AlertCircle v-else class="w-4 h-4" />
              {{ getNameCheckMessage() }}
            </p>
          </div>
          <div>
            <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
              설명
              <CharacterCounter :current="newTeamDescription.length" :max="50" />
            </label>
            <input
              v-model="newTeamDescription"
              type="text"
              maxlength="50"
              class="w-full px-3 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent"
              :style="{ backgroundColor: 'var(--dp-bg-input)', border: '1px solid var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
              placeholder="팀 설명 입력"
            />
          </div>
        </div>
        <div class="p-4 flex justify-end gap-2" :style="{ borderTop: '1px solid var(--dp-border-primary)' }">
          <button
            @click="handleCreateTeam"
            :disabled="nameCheckResult !== 'OK' || !newTeamDescription"
            class="px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
          >
            추가
          </button>
          <button
            @click="closeNewTeamModal"
            class="px-4 py-2 text-sm font-medium rounded-lg transition cursor-pointer"
            :style="{ color: 'var(--dp-text-primary)', backgroundColor: 'var(--dp-bg-tertiary)' }"
            @mouseover="(e: Event) => setHoverBg(e)"
            @mouseleave="(e: Event) => clearHoverBg(e, 'var(--dp-bg-tertiary)')"
          >
            취소
          </button>
        </div>
      </div>
    </div>

  </div>
</template>
