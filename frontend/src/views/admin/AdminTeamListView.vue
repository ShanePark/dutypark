<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
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
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()

interface Team {
  id: number
  name: string
  description: string
  memberCount: number
}

// Dummy data
const teams = ref<Team[]>([
  { id: 1, name: '개발팀', description: '소프트웨어 개발 및 유지보수', memberCount: 12 },
  { id: 2, name: '디자인팀', description: 'UI/UX 디자인 및 브랜딩', memberCount: 5 },
  { id: 3, name: '마케팅팀', description: '마케팅 전략 및 실행', memberCount: 8 },
  { id: 4, name: '영업팀', description: '고객 관리 및 영업', memberCount: 15 },
  { id: 5, name: '인사팀', description: '인사 관리 및 채용', memberCount: 4 },
  { id: 6, name: '재무팀', description: '재무 관리 및 회계', memberCount: 6 },
  { id: 7, name: '기획팀', description: '사업 기획 및 전략', memberCount: 7 },
  { id: 8, name: '고객지원팀', description: '고객 문의 및 지원', memberCount: 10 },
])

const keyword = ref('')
const page = ref(0)
const size = 10
const isLoading = ref(false)

const filteredTeams = computed(() => {
  if (!keyword.value) return teams.value
  const searchKeyword = keyword.value.toLowerCase()
  return teams.value.filter(
    (team) =>
      team.name.toLowerCase().includes(searchKeyword) ||
      team.description.toLowerCase().includes(searchKeyword)
  )
})

const totalElements = computed(() => filteredTeams.value.length)
const totalPages = computed(() => Math.ceil(filteredTeams.value.length / size))
const paginatedTeams = computed(() => {
  const start = page.value * size
  return filteredTeams.value.slice(start, start + size)
})

// New team modal state
const showNewTeamModal = ref(false)
const newTeamName = ref('')
const newTeamDescription = ref('')
const nameCheckResult = ref<'OK' | 'TOO_SHORT' | 'TOO_LONG' | 'DUPLICATED' | null>(null)
const isCheckingName = ref(false)

function openNewTeamModal() {
  newTeamName.value = ''
  newTeamDescription.value = ''
  nameCheckResult.value = null
  showNewTeamModal.value = true
}

function closeNewTeamModal() {
  showNewTeamModal.value = false
}

function checkTeamName() {
  if (newTeamName.value.length < 2) {
    nameCheckResult.value = 'TOO_SHORT'
    return
  }
  if (newTeamName.value.length > 20) {
    nameCheckResult.value = 'TOO_LONG'
    return
  }
  // Check for duplicate (dummy implementation)
  const isDuplicated = teams.value.some(
    (team) => team.name.toLowerCase() === newTeamName.value.toLowerCase()
  )
  if (isDuplicated) {
    nameCheckResult.value = 'DUPLICATED'
    return
  }
  nameCheckResult.value = 'OK'
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

function handleCreateTeam() {
  if (nameCheckResult.value !== 'OK') return
  if (!newTeamDescription.value) return

  // API call would go here
  const newTeam: Team = {
    id: teams.value.length + 1,
    name: newTeamName.value,
    description: newTeamDescription.value,
    memberCount: 0,
  }
  teams.value.unshift(newTeam)
  closeNewTeamModal()

  // Navigate to team manage page
  router.push(`/team/manage/${newTeam.id}`)
}

function manageTeam(teamId: number) {
  router.push(`/team/manage/${teamId}`)
}

function handleSearch() {
  page.value = 0
}

function goToPage(pageNum: number) {
  if (pageNum >= 0 && pageNum < totalPages.value) {
    page.value = pageNum
  }
}

function refreshData() {
  isLoading.value = true
  setTimeout(() => {
    isLoading.value = false
  }, 1000)
}

onMounted(() => {
  if (!authStore.isAdmin) {
    router.push('/')
  }
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
              <h1 class="text-xl font-bold text-gray-900">팀 관리</h1>
              <p class="text-sm text-gray-500">팀 생성 및 관리</p>
            </div>
          </div>
          <div class="flex items-center gap-2">
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
      <!-- Admin Navigation -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <router-link
          to="/admin"
          class="bg-white border border-gray-200 rounded-xl p-4 hover:bg-gray-50 transition"
        >
          <Users class="w-6 h-6 mb-2 text-gray-600" />
          <span class="font-medium text-gray-700">회원 관리</span>
        </router-link>
        <router-link
          to="/admin/teams"
          class="bg-gray-700 text-white rounded-xl p-4 hover:bg-gray-800 transition"
        >
          <Building2 class="w-6 h-6 mb-2 text-white" />
          <span class="font-medium text-white">팀 관리</span>
        </router-link>
        <div class="bg-white border border-gray-200 rounded-xl p-4 opacity-50 cursor-not-allowed">
          <Shield class="w-6 h-6 mb-2 text-gray-400" />
          <span class="font-medium text-gray-400">시스템 로그</span>
        </div>
        <div class="bg-white border border-gray-200 rounded-xl p-4 opacity-50 cursor-not-allowed">
          <Settings class="w-6 h-6 mb-2 text-gray-400" />
          <span class="font-medium text-gray-400">설정</span>
        </div>
      </div>

      <!-- Team List Section -->
      <div class="bg-white rounded-xl border border-gray-200">
        <div class="p-4 border-b border-gray-200">
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h2 class="text-lg font-semibold text-gray-900">팀 목록</h2>
              <p class="text-sm text-gray-500">
                <span v-if="keyword" class="text-blue-600">[{{ keyword }}]</span>
                총 {{ totalElements }}개의 팀이 있습니다
              </p>
            </div>
            <div class="flex items-center gap-2">
              <div class="relative">
                <Search class="w-4 h-4 absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" />
                <input
                  v-model="keyword"
                  type="text"
                  placeholder="팀 검색..."
                  class="pl-9 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent"
                  @keyup.enter="handleSearch"
                />
              </div>
              <button
                @click="handleSearch"
                class="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg transition"
              >
                검색
              </button>
            </div>
          </div>
        </div>

        <!-- Team Table -->
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-12">
                  #
                </th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-40">
                  이름
                </th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-24">
                  멤버
                </th>
                <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  설명
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr
                v-for="(team, index) in paginatedTeams"
                :key="team.id"
                class="hover:bg-gray-50 cursor-pointer transition"
                @click="manageTeam(team.id)"
              >
                <td class="px-4 py-4 text-sm text-gray-500">
                  {{ page * size + index + 1 }}
                </td>
                <td class="px-4 py-4">
                  <div class="flex items-center gap-2">
                    <Building2 class="w-4 h-4 text-gray-400" />
                    <span class="font-medium text-gray-900">{{ team.name }}</span>
                  </div>
                </td>
                <td class="px-4 py-4">
                  <div class="flex items-center gap-1 text-sm text-gray-600">
                    <Users class="w-4 h-4 text-gray-400" />
                    {{ team.memberCount }}명
                  </div>
                </td>
                <td class="px-4 py-4 text-sm text-gray-600">
                  {{ team.description }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div v-if="paginatedTeams.length === 0" class="p-8 text-center text-gray-500">
          검색 결과가 없습니다
        </div>

        <!-- Footer with Button and Pagination -->
        <div class="p-4 border-t border-gray-200 flex flex-col sm:flex-row items-center justify-between gap-4">
          <button
            @click="openNewTeamModal"
            class="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition"
          >
            <Plus class="w-4 h-4" />
            새 팀 추가
          </button>

          <!-- Pagination -->
          <nav v-if="totalPages > 1" class="flex items-center gap-1">
            <button
              :disabled="page === 0"
              class="p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-lg transition disabled:opacity-50 disabled:cursor-not-allowed"
              @click="goToPage(page - 1)"
            >
              <ChevronLeft class="w-4 h-4" />
            </button>
            <button
              v-for="p in totalPages"
              :key="p"
              class="px-3 py-1 text-sm rounded-lg transition"
              :class="p - 1 === page ? 'bg-gray-900 text-white' : 'text-gray-600 hover:bg-gray-100'"
              @click="goToPage(p - 1)"
            >
              {{ p }}
            </button>
            <button
              :disabled="page === totalPages - 1"
              class="p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-lg transition disabled:opacity-50 disabled:cursor-not-allowed"
              @click="goToPage(page + 1)"
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
      <div class="bg-white rounded-xl shadow-xl w-full max-w-md mx-4">
        <div class="p-4 border-b border-gray-200 flex items-center justify-between">
          <h3 class="text-lg font-semibold text-gray-900">새 팀 추가</h3>
          <button
            @click="closeNewTeamModal"
            class="p-1 text-gray-400 hover:text-gray-600 rounded transition"
          >
            <X class="w-5 h-5" />
          </button>
        </div>
        <div class="p-4 space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">팀 이름</label>
            <div class="flex gap-2">
              <input
                v-model="newTeamName"
                type="text"
                maxlength="20"
                minlength="2"
                class="flex-1 px-3 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent"
                placeholder="팀 이름 입력"
                @input="nameCheckResult = null"
              />
              <button
                @click="checkTeamName"
                class="px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition"
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
            <label class="block text-sm font-medium text-gray-700 mb-1">설명</label>
            <input
              v-model="newTeamDescription"
              type="text"
              maxlength="50"
              class="w-full px-3 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent"
              placeholder="팀 설명 입력"
            />
          </div>
        </div>
        <div class="p-4 border-t border-gray-200 flex justify-end gap-2">
          <button
            @click="closeNewTeamModal"
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg transition"
          >
            취소
          </button>
          <button
            @click="handleCreateTeam"
            :disabled="nameCheckResult !== 'OK' || !newTeamDescription"
            class="px-4 py-2 text-sm font-medium text-white bg-gray-900 hover:bg-gray-800 rounded-lg transition disabled:opacity-50 disabled:cursor-not-allowed"
          >
            추가
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
