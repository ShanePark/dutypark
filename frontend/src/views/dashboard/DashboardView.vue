<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { dashboardApi } from '@/api/dashboard'
import { friendApi } from '@/api/member'
import { useSwal } from '@/composables/useSwal'
import Sortable from 'sortablejs'
import type {
  DashboardMyDetail,
  DashboardFriendInfo,
  DashboardScheduleDto,
  FriendDto,
} from '@/types'
import {
  Calendar,
  Briefcase,
  ClipboardList,
  Heart,
  CheckCircle,
  Clock,
  Users,
  Star,
  GripVertical,
  MoreVertical,
  UserPlus,
  Home,
  Trash2,
  X,
  Search,
  ChevronLeft,
  ChevronRight,
  User,
  Sparkles,
  CalendarDays,
  ListTodo,
  UserCheck,
  Flag,
  Sun,
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const { showWarning, confirm, confirmDelete, toastSuccess } = useSwal()

// Loading states
const myInfoLoading = ref(false)
const friendInfoLoading = ref(false)
const friendInfoInitialized = ref(false)

// Error states
const myInfoError = ref<string | null>(null)
const friendInfoError = ref<string | null>(null)

// Today's date formatted
const today = computed(() => {
  return new Date().toLocaleDateString('ko-KR', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    weekday: 'long',
  })
})

// API data
const myInfo = ref<DashboardMyDetail | null>(null)
const friendInfo = ref<DashboardFriendInfo | null>(null)

// Load my dashboard data
async function loadMyDashboard() {
  if (!authStore.isLoggedIn) return

  myInfoLoading.value = true
  myInfoError.value = null
  try {
    myInfo.value = await dashboardApi.getMyDashboard()
  } catch (error) {
    console.error('Failed to load my dashboard:', error)
    myInfoError.value = '대시보드 정보를 불러오는데 실패했습니다.'
  } finally {
    myInfoLoading.value = false
  }
}

// Load friends dashboard data
async function loadFriendsDashboard() {
  if (!authStore.isLoggedIn) return

  friendInfoLoading.value = true
  friendInfoError.value = null
  try {
    friendInfo.value = await dashboardApi.getFriendsDashboard()
    friendInfoInitialized.value = true
  } catch (error) {
    console.error('Failed to load friends dashboard:', error)
    friendInfoError.value = '친구 정보를 불러오는데 실패했습니다.'
  } finally {
    friendInfoLoading.value = false
  }
}

// Search modal state
const showSearchModal = ref(false)
const searchKeyword = ref('')
const searchResult = ref<FriendDto[]>([])
const searchPage = ref(0)
const searchTotalPage = ref(0)
const searchTotalElements = ref(0)
const searchPageSize = 5
const searchLoading = ref(false)

// Dropdown state for friend management
const openDropdownId = ref<number | null>(null)

// Sortable instance
let friendSortable: Sortable | null = null
const friendListRef = ref<HTMLElement | null>(null)
const friendSectionRef = ref<HTMLElement | null>(null)
let isDragging = false

// Features for guest view
const features = [
  { icon: 'calendar', text: '일정 관리 - 등록, 검색, 공개 설정' },
  { icon: 'check', text: '할일 관리로 까먹지 않는 일상' },
  { icon: 'clock', text: '근무 관리 및 시간표 등록' },
  { icon: 'users', text: '팀원들의 시간표와 일정 공유' },
  { icon: 'heart', text: '친구 및 가족의 일정 조회와 태그 기능' },
  { icon: 'flag', text: 'D-Day 관리 - 기념일, 중요한 날 카운트다운' },
  { icon: 'sun', text: '공휴일 자동 표시 - 대한민국 공휴일 연동' },
]

// Computed: sorted friends (pinned first)
const sortedFriends = computed(() => {
  if (!friendInfo.value) return []
  return [...friendInfo.value.friends].sort((a, b) => {
    const aPinned = a.pinOrder ? 0 : 1
    const bPinned = b.pinOrder ? 0 : 1
    if (aPinned !== bPinned) {
      return aPinned - bPinned
    }
    if (a.pinOrder && b.pinOrder) {
      return (a.pinOrder || 0) - (b.pinOrder || 0)
    }
    return 0
  })
})

// Computed: has pending requests
const hasPendingRequests = computed(() => {
  if (!friendInfo.value) return false
  return friendInfo.value.pendingRequestsTo.length > 0 || friendInfo.value.pendingRequestsFrom.length > 0
})

// Methods
function moveTo(memberId?: number | null) {
  // Prevent navigation if we just finished dragging
  if (isDragging) return
  const id = memberId || myInfo.value?.member.id
  if (!id) return
  router.push(`/duty/${id}`)
}

function printSchedule(schedule: { content: string; totalDays: number; daysFromStart: number; isTagged: boolean; owner: string }) {
  let text = schedule.content
  if (schedule.totalDays > 1) {
    text = `${text} [${schedule.daysFromStart}/${schedule.totalDays}]`
  }
  if (schedule.isTagged) {
    text = `${text} (by ${schedule.owner})`
  }
  return text
}

// Calculate if a color is light (for text contrast)
function isLightColor(hexColor: string | null | undefined): boolean {
  if (!hexColor) return false
  const hex = hexColor.replace('#', '')
  const r = parseInt(hex.substring(0, 2), 16)
  const g = parseInt(hex.substring(2, 4), 16)
  const b = parseInt(hex.substring(4, 6), 16)
  // Using luminance formula
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  return luminance > 0.6
}

function printScheduleTime(startDateTime: string) {
  const date = new Date(startDateTime)
  const now = new Date()
  if (date.toLocaleDateString() !== now.toLocaleDateString()) {
    return ''
  }
  if (date.getHours() === 0 && date.getMinutes() === 0) {
    return ''
  }
  return date.toLocaleTimeString('ko-KR', {
    hour: '2-digit',
    minute: '2-digit',
  })
}

// Pin/Unpin friend
async function pinFriend(member: { id: number | null; name: string }) {
  if (!friendInfo.value || !member.id) return
  const friend = friendInfo.value.friends.find((f) => f.member.id === member.id)
  if (friend) {
    const maxOrder = Math.max(0, ...friendInfo.value.friends.map((f) => f.pinOrder || 0))
    friend.pinOrder = maxOrder + 1
    sortFriendsByPinOrder()
    nextTick(() => {
      initFriendSortable()
    })
    try {
      await friendApi.pinFriend(member.id)
    } catch (error) {
      console.error('Failed to pin friend:', error)
      friend.pinOrder = null
      sortFriendsByPinOrder()
      showWarning('친구 고정에 실패했습니다.')
    }
  }
}

async function unpinFriend(member: { id: number | null; name: string }) {
  if (!friendInfo.value || !member.id) return
  const friend = friendInfo.value.friends.find((f) => f.member.id === member.id)
  if (friend) {
    const oldPinOrder = friend.pinOrder
    friend.pinOrder = null
    sortFriendsByPinOrder()
    nextTick(() => {
      initFriendSortable()
    })
    try {
      await friendApi.unpinFriend(member.id)
    } catch (error) {
      console.error('Failed to unpin friend:', error)
      friend.pinOrder = oldPinOrder
      sortFriendsByPinOrder()
      showWarning('친구 고정 해제에 실패했습니다.')
    }
  }
}

// Sort friends by pin order
function sortFriendsByPinOrder() {
  if (!friendInfo.value) return
  friendInfo.value.friends.sort((a, b) => {
    const aPinned = a.pinOrder ? 0 : 1
    const bPinned = b.pinOrder ? 0 : 1
    if (aPinned !== bPinned) {
      return aPinned - bPinned
    }
    if (a.pinOrder && b.pinOrder) {
      return (a.pinOrder || 0) - (b.pinOrder || 0)
    }
    return 0
  })
}

// Friend request actions
async function acceptFriendRequest(req: { fromMember: { id: number | null; name: string } }) {
  if (!friendInfo.value || !req.fromMember.id) return
  try {
    await friendApi.acceptFriendRequest(req.fromMember.id)
    await loadFriendsDashboard()
    toastSuccess(`${req.fromMember.name}님의 친구 요청을 수락했습니다.`)
  } catch (error) {
    console.error('Failed to accept friend request:', error)
    showWarning('친구 요청 수락에 실패했습니다.')
  }
}

async function rejectFriendRequest(req: { fromMember: { id: number | null; name: string } }) {
  if (!friendInfo.value || !req.fromMember.id) return
  try {
    await friendApi.rejectFriendRequest(req.fromMember.id)
    friendInfo.value.pendingRequestsTo = friendInfo.value.pendingRequestsTo.filter(
      (r) => r.fromMember.id !== req.fromMember.id
    )
    toastSuccess(`${req.fromMember.name}님의 친구 요청을 거절했습니다.`)
  } catch (error) {
    console.error('Failed to reject friend request:', error)
    showWarning('친구 요청 거절에 실패했습니다.')
  }
}

async function cancelRequest(req: { toMember: { id: number | null; name: string } }) {
  if (!friendInfo.value || !req.toMember.id) return
  if (!await confirm(`${req.toMember.name}님에게 보낸 요청을 취소하시겠습니까?`, '요청 취소')) return
  try {
    await friendApi.cancelFriendRequest(req.toMember.id)
    await loadFriendsDashboard()
  } catch (error) {
    console.error('Failed to cancel friend request:', error)
    showWarning('친구 요청 취소에 실패했습니다.')
  }
}

// Friend management actions
async function addFamily(member: { id: number | null; name: string }) {
  if (!friendInfo.value || !member.id) return
  const alreadySent = friendInfo.value.pendingRequestsFrom.some((r) => r.toMember.id === member.id)
  if (alreadySent) {
    showWarning('이미 가족 요청을 보낸 상태입니다.')
    return
  }
  closeDropdown()
  try {
    await friendApi.sendFamilyRequest(member.id)
    await loadFriendsDashboard()
    toastSuccess(`${member.name}님에게 가족 요청을 보냈습니다.`)
  } catch (error) {
    console.error('Failed to send family request:', error)
    showWarning('가족 요청 전송에 실패했습니다.')
  }
}

async function unfriend(member: { id: number | null; name: string }) {
  if (!friendInfo.value || !member.id) return
  if (await confirmDelete(`정말로 [${member.name}]님을 친구목록에서 삭제하시겠습니까?`)) {
    closeDropdown()
    try {
      await friendApi.unfriend(member.id)
      friendInfo.value.friends = friendInfo.value.friends.filter((f) => f.member.id !== member.id)
      toastSuccess(`${member.name}님을 친구 목록에서 삭제했습니다.`)
    } catch (error) {
      console.error('Failed to unfriend:', error)
      showWarning('친구 삭제에 실패했습니다.')
    }
  } else {
    closeDropdown()
  }
}

// Dropdown management
function toggleDropdown(memberId: number, event: Event) {
  event.stopPropagation()
  openDropdownId.value = openDropdownId.value === memberId ? null : memberId
}

function closeDropdown() {
  openDropdownId.value = null
}

// Search modal
function openSearchModal() {
  showSearchModal.value = true
  searchKeyword.value = ''
  searchPage.value = 0
  searchResult.value = []
  searchTotalPage.value = 0
  searchTotalElements.value = 0
}

function closeSearchModal() {
  showSearchModal.value = false
}

async function search() {
  if (!searchKeyword.value.trim()) {
    searchResult.value = []
    searchTotalPage.value = 0
    searchTotalElements.value = 0
    return
  }

  searchLoading.value = true
  try {
    const response = await friendApi.searchPossibleFriends(
      searchKeyword.value,
      searchPage.value,
      searchPageSize
    )
    searchResult.value = response.data.content
    searchTotalPage.value = response.data.totalPages
    searchTotalElements.value = response.data.totalElements
  } catch (error) {
    console.error('Failed to search friends:', error)
    searchResult.value = []
  } finally {
    searchLoading.value = false
  }
}

async function requestFriend(member: FriendDto) {
  if (!member.id) return
  if (!await confirm(`${member.name}님에게 친구 요청을 보내시겠습니까?`, '친구 요청')) return
  try {
    await friendApi.sendFriendRequest(member.id)
    // Remove from search results to show it's been requested
    searchResult.value = searchResult.value.filter((m) => m.id !== member.id)
    // Refresh friend requests section
    await loadFriendsDashboard()
    toastSuccess(`${member.name}님에게 친구 요청을 보냈습니다.`)
  } catch (error) {
    console.error('Failed to send friend request:', error)
    showWarning('친구 요청을 보내는데 실패했습니다.')
  }
}

function prevPage() {
  if (searchPage.value > 0) {
    searchPage.value--
    search()
  }
}

function nextPage() {
  if (searchPage.value < searchTotalPage.value - 1) {
    searchPage.value++
    search()
  }
}

function goToPage(page: number) {
  searchPage.value = page
  search()
}

// Initialize SortableJS for friend list
function initFriendSortable() {
  if (!friendListRef.value) {
    if (friendSortable) {
      friendSortable.destroy()
      friendSortable = null
    }
    return
  }

  if (friendSortable) {
    friendSortable.destroy()
  }

  friendSortable = new Sortable(friendListRef.value, {
    animation: 150,
    draggable: '.pinned-friend',
    handle: '.handle',
    ghostClass: 'sortable-ghost',
    fallbackClass: 'sortable-fallback',
    fallbackOnBody: true,
    forceFallback: true,
    chosenClass: 'sortable-chosen',
    onStart: () => {
      isDragging = true
      friendSectionRef.value?.classList.add('friend-section-sorting')
    },
    onEnd: () => {
      friendSectionRef.value?.classList.remove('friend-section-sorting')
      updateFriendsPin()
      // Delay resetting isDragging to prevent click event from firing
      setTimeout(() => {
        isDragging = false
      }, 100)
    },
  })
}

// Update friend pin order after drag
async function updateFriendsPin() {
  if (!friendListRef.value || !friendInfo.value) return

  const pinnedElements = friendListRef.value.querySelectorAll('.pinned-friend')
  const friendIds = Array.from(pinnedElements)
    .map((el) => Number(el.getAttribute('data-member-id')))
    .filter((id) => !isNaN(id) && id > 0)

  if (friendIds.length === 0) return

  applyFriendOrder(friendIds)

  nextTick(() => {
    initFriendSortable()
  })

  try {
    await friendApi.updateFriendsPinOrder(friendIds)
  } catch (error) {
    console.error('Failed to update friend pin order:', error)
    showWarning('친구 순서 변경에 실패했습니다.')
  }
}

// Apply friend order based on IDs
function applyFriendOrder(friendIds: number[]) {
  if (!friendInfo.value || friendIds.length === 0) return

  const friendMap = new Map(friendInfo.value.friends.map((f) => [f.member.id, f]))
  const pinnedSet = new Set(friendIds)
  const pinnedFriends = friendIds.map((id) => friendMap.get(id)).filter(Boolean)
  const unpinnedFriends = friendInfo.value.friends.filter((f) => f.member.id !== null && !pinnedSet.has(f.member.id))

  friendInfo.value.friends = [...pinnedFriends, ...unpinnedFriends] as typeof friendInfo.value.friends
}

// Destroy sortable on unmount
function destroyFriendSortable() {
  if (friendSortable) {
    friendSortable.destroy()
    friendSortable = null
  }
}

// Load dashboard data when logged in
onMounted(async () => {
  document.addEventListener('click', closeDropdown)

  if (authStore.isLoggedIn) {
    // Load both APIs in parallel
    await Promise.all([loadMyDashboard(), loadFriendsDashboard()])
    // Initialize sortable after data is loaded
    nextTick(() => {
      initFriendSortable()
    })
  }
})

// Cleanup on unmount
onUnmounted(() => {
  document.removeEventListener('click', closeDropdown)
  destroyFriendSortable()
})

// Watch for login state changes
watch(
  () => authStore.isLoggedIn,
  async (isLoggedIn) => {
    if (isLoggedIn) {
      await Promise.all([loadMyDashboard(), loadFriendsDashboard()])
      // Initialize sortable after data is loaded
      nextTick(() => {
        initFriendSortable()
      })
    } else {
      // Clear data on logout
      myInfo.value = null
      friendInfo.value = null
      friendInfoInitialized.value = false
      destroyFriendSortable()
    }
  }
)
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <!-- Logged-in Dashboard -->
    <template v-if="authStore.isLoggedIn">
      <!-- My Info Section -->
      <div
        class="rounded-2xl shadow-sm border mb-6 overflow-hidden"
        :style="{
          backgroundColor: 'var(--dp-bg-card)',
          borderColor: 'var(--dp-border-primary)'
        }"
      >
        <!-- Header -->
        <div
          class="group px-5 py-3 bg-gradient-to-r from-gray-700 to-gray-800 flex items-center justify-between cursor-pointer hover:from-gray-600 hover:to-gray-700 transition-all"
          @click="moveTo()"
        >
          <div class="flex items-center gap-3">
            <div class="w-9 h-9 bg-white/20 rounded-lg flex items-center justify-center">
              <User class="w-5 h-5 text-white" />
            </div>
            <span class="text-lg font-bold text-white">{{ myInfo?.member.name || '로딩중...' }}</span>
          </div>
          <ChevronRight class="w-5 h-5 text-gray-400 group-hover:text-white group-hover:translate-x-1 transition-all" />
        </div>

        <!-- Content -->
        <div class="p-5">
          <!-- Error state -->
          <div v-if="myInfoError" class="text-center py-4 text-red-500">
            {{ myInfoError }}
          </div>
          <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-5">
            <!-- Left column: Date & Duty -->
            <div class="space-y-3">
              <div class="flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Calendar class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
                <span class="font-medium">{{ today }}</span>
              </div>

              <div class="flex items-center gap-2">
                <Briefcase class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
                <span :style="{ color: 'var(--dp-text-secondary)' }">근무:</span>
                <template v-if="myInfoLoading">
                  <div class="w-4 h-4 border-2 rounded-full animate-spin" :style="{ borderColor: 'var(--dp-border-secondary)', borderTopColor: 'var(--dp-text-primary)' }"></div>
                </template>
                <template v-else-if="myInfo?.duty">
                  <span
                    class="px-2.5 py-0.5 rounded-md font-semibold text-sm"
                    :style="{
                      backgroundColor: myInfo.duty.dutyColor || '#666',
                      color: isLightColor(myInfo.duty.dutyColor) ? '#1f2937' : '#ffffff'
                    }"
                  >
                    {{ myInfo.duty.dutyType || '휴무' }}
                  </span>
                </template>
                <span :style="{ color: 'var(--dp-text-muted)' }">없음</span>
              </div>
            </div>

            <!-- Right column: Today's schedules -->
            <div class="border-t pt-4 md:border-t-0 md:pt-0 md:border-l md:pl-5" :style="{ borderColor: 'var(--dp-border-primary)' }">
              <div class="flex items-center gap-2 mb-2">
                <ClipboardList class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
                <span class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">오늘 일정</span>
              </div>
              <template v-if="myInfoLoading">
                <div class="flex justify-center py-3">
                  <div class="w-5 h-5 border-2 rounded-full animate-spin" :style="{ borderColor: 'var(--dp-border-secondary)', borderTopColor: 'var(--dp-text-primary)' }"></div>
                </div>
              </template>
              <ul v-else class="space-y-1">
                <li
                  v-for="schedule in myInfo?.schedules || []"
                  :key="schedule.id"
                  class="py-1.5 border-b last:border-0 flex items-center justify-between"
                  :style="{ borderColor: 'var(--dp-border-primary)', color: 'var(--dp-text-primary)' }"
                >
                  <span class="truncate">{{ printSchedule(schedule) }}</span>
                  <span class="ml-2 text-sm flex-shrink-0" :style="{ color: 'var(--dp-text-muted)' }">{{ printScheduleTime(schedule.startDateTime) }}</span>
                </li>
                <li v-if="!myInfo?.schedules?.length" class="text-sm" :style="{ color: 'var(--dp-text-muted)' }">
                  오늘의 일정이 없습니다.
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>

      <!-- Friend Request Section -->
      <div
        v-if="friendInfoInitialized && hasPendingRequests && friendInfo"
        class="rounded-2xl shadow-sm border mb-6 overflow-hidden"
        :style="{
          backgroundColor: 'var(--dp-bg-card)',
          borderColor: 'var(--dp-border-primary)'
        }"
      >
        <div class="bg-gradient-to-r from-amber-500 to-orange-500 px-6 py-3">
          <div class="flex items-center gap-2">
            <UserCheck class="w-5 h-5 text-white" />
            <span class="text-white font-bold">친구 요청 관리</span>
          </div>
        </div>
        <div class="p-5">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <!-- Requests received (to me) -->
            <div
              v-for="req in friendInfo.pendingRequestsTo"
              :key="'to-' + req.fromMember.id"
              class="p-4 rounded-xl bg-gradient-to-br from-blue-50 to-indigo-50 border border-blue-200"
            >
              <div class="flex justify-between items-center">
                <div class="font-bold flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                  <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
                    <Home v-if="req.requestType === 'FAMILY_REQUEST'" class="w-4 h-4 text-blue-600" />
                    <UserPlus v-else class="w-4 h-4 text-blue-600" />
                  </div>
                  {{ req.fromMember.name }}
                </div>
                <div class="flex gap-2">
                  <button
                    class="px-3 py-1.5 text-sm font-medium bg-green-500 text-white rounded-lg hover:bg-green-600 transition shadow-sm"
                    @click.stop="acceptFriendRequest(req)"
                  >
                    승인
                  </button>
                  <button
                    class="px-3 py-1.5 text-sm font-medium border border-red-200 rounded-lg hover:bg-red-50 transition"
                    :style="{ backgroundColor: 'var(--dp-bg-card)', color: '#dc3545' }"
                    @click.stop="rejectFriendRequest(req)"
                  >
                    거절
                  </button>
                </div>
              </div>
            </div>

            <!-- Requests sent (from me) -->
            <div
              v-for="req in friendInfo.pendingRequestsFrom"
              :key="'from-' + req.toMember.id"
              class="p-4 rounded-xl bg-gradient-to-br from-amber-50 to-yellow-50 border border-amber-200"
            >
              <div class="flex justify-between items-center">
                <div class="font-bold flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                  <div class="w-8 h-8 bg-amber-100 rounded-full flex items-center justify-center">
                    <Home v-if="req.requestType === 'FAMILY_REQUEST'" class="w-4 h-4 text-amber-600" />
                    <UserPlus v-else class="w-4 h-4 text-amber-600" />
                  </div>
                  {{ req.toMember.name }}
                </div>
                <button
                  class="px-3 py-1.5 text-sm font-medium border border-amber-300 rounded-lg hover:bg-amber-50 transition"
                  :style="{ backgroundColor: 'var(--dp-bg-card)', color: '#b45309' }"
                  @click.stop="cancelRequest(req)"
                >
                  요청 취소
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Friends List Section -->
      <div ref="friendSectionRef" class="friend-section rounded-2xl shadow-sm border overflow-hidden" :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' }">
        <div class="bg-gradient-to-r from-slate-700 to-slate-800 px-6 py-3">
          <div class="flex items-center gap-2">
            <Users class="w-5 h-5 text-white" />
            <span class="text-white font-bold">친구 목록</span>
            <span v-if="friendInfo?.friends.length" class="ml-2 px-2 py-0.5 bg-white/20 rounded-full text-xs text-white">
              {{ friendInfo.friends.length }}
            </span>
          </div>
        </div>
        <div class="p-5">
          <!-- Error state -->
          <div v-if="friendInfoError" class="text-center py-4 text-red-500">
            {{ friendInfoError }}
          </div>
          <template v-else-if="friendInfoLoading">
            <div class="flex justify-center py-10">
              <div class="w-8 h-8 border-3 rounded-full animate-spin" :style="{ borderColor: 'var(--dp-border-secondary)', borderTopColor: 'var(--dp-text-primary)' }"></div>
            </div>
          </template>
          <div v-else ref="friendListRef" class="grid grid-cols-2 gap-2 sm:gap-3">
            <!-- Friend Cards -->
            <div
              v-for="friend in sortedFriends"
              :key="friend.member.id ?? 'unknown'"
              :data-member-id="friend.member.id"
              class="friend-card relative overflow-hidden rounded-xl sm:rounded-2xl cursor-pointer transition-all duration-300 hover:shadow-lg hover:scale-[1.02]"
              :class="[
                friend.pinOrder
                  ? 'pinned-friend pinned-friend-highlight border-2 shadow-md'
                  : 'border hover:border-blue-300'
              ]"
              :style="!friend.pinOrder ? { backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' } : {}"
              @click="moveTo(friend.member.id)"
            >
              <div class="p-2 sm:p-4">
                <!-- Header: Name & Actions -->
                <div class="flex items-center justify-between mb-1.5 sm:mb-2">
                  <div class="flex items-center gap-1.5 min-w-0 flex-1">
                    <div
                      class="w-6 h-6 sm:w-8 sm:h-8 rounded-full flex items-center justify-center flex-shrink-0"
                      :class="friend.isFamily ? 'friend-icon-family' : 'friend-icon-regular'"
                    >
                      <Home v-if="friend.isFamily" class="w-3 h-3 sm:w-4 sm:h-4" />
                      <User v-else class="w-3 h-3 sm:w-4 sm:h-4" />
                    </div>
                    <span class="font-bold text-xs sm:text-sm truncate" :style="{ color: 'var(--dp-text-primary)' }">{{ friend.member.name }}</span>
                  </div>
                  <div class="flex items-center flex-shrink-0" @click.stop>
                    <!-- Pin/Unpin button -->
                    <button
                      v-if="friend.pinOrder"
                      class="p-0.5 sm:p-1 text-amber-500 hover:text-amber-600 transition"
                      @click.stop="unpinFriend(friend.member)"
                      title="고정 해제"
                    >
                      <Star class="w-3.5 h-3.5 sm:w-4 sm:h-4" fill="currentColor" />
                    </button>
                    <button
                      v-else
                      class="p-0.5 sm:p-1 text-gray-300 hover:text-amber-500 transition"
                      @click.stop="pinFriend(friend.member)"
                      title="고정"
                    >
                      <Star class="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                    </button>
                    <!-- Dropdown toggle -->
                    <div v-if="friend.member.id" class="relative">
                      <button
                        class="p-0.5 sm:p-1 rounded-lg transition hover:bg-opacity-80"
                        :style="{ color: 'var(--dp-text-muted)' }"
                        @click="toggleDropdown(friend.member.id, $event)"
                      >
                        <MoreVertical class="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                      </button>
                      <!-- Dropdown menu -->
                      <div
                        v-if="openDropdownId === friend.member.id"
                        class="absolute right-0 mt-1 w-28 sm:w-32 border rounded-xl shadow-xl z-10 overflow-hidden"
                        :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' }"
                      >
                        <button
                          v-if="!friend.isFamily"
                          class="w-full px-2.5 py-2 sm:px-3 sm:py-2.5 text-left text-xs sm:text-sm text-blue-600 hover:bg-blue-50 flex items-center gap-2 transition"
                          @click="addFamily(friend.member)"
                        >
                          <Home class="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                          가족 등록
                        </button>
                        <button
                          class="w-full px-2.5 py-2 sm:px-3 sm:py-2.5 text-left text-xs sm:text-sm text-red-600 hover:bg-red-50 flex items-center gap-2 transition"
                          @click="unfriend(friend.member)"
                        >
                          <Trash2 class="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                          친구 삭제
                        </button>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Duty info -->
                <div class="flex items-center gap-1.5 sm:gap-2 mb-1.5 sm:mb-2">
                  <Briefcase class="w-3 h-3 sm:w-3.5 sm:h-3.5 flex-shrink-0" :style="{ color: 'var(--dp-text-muted)' }" />
                  <span class="text-[11px] sm:text-sm" :style="{ color: 'var(--dp-text-secondary)' }">근무:</span>
                  <span v-if="friend.duty" class="text-[11px] sm:text-sm font-medium truncate" :style="{ color: 'var(--dp-text-primary)' }">{{ friend.duty.dutyType || '휴무' }}</span>
                  <span v-else class="text-[11px] sm:text-sm" :style="{ color: 'var(--dp-text-muted)' }">-</span>
                </div>

                <!-- Schedules (hidden on mobile to save space) -->
                <div v-if="friend.schedules && friend.schedules.length" class="hidden sm:block mt-2 space-y-1">
                  <div
                    v-for="schedule in friend.schedules.slice(0, 2)"
                    :key="schedule.id"
                    class="text-xs sm:text-sm py-1.5 px-2 rounded-lg truncate friend-schedule-item"
                  >
                    {{ printSchedule(schedule) }}
                  </div>
                  <div v-if="friend.schedules.length > 2" class="text-xs pl-2" :style="{ color: 'var(--dp-text-muted)' }">
                    +{{ friend.schedules.length - 2 }}개 더보기
                  </div>
                </div>
              </div>

              <!-- Drag handle for pinned friends -->
              <div v-if="friend.pinOrder" class="absolute bottom-1.5 right-1.5 sm:bottom-2 sm:right-2" @click.stop>
                <div
                  class="handle friend-drag-handle rounded-md sm:rounded-lg p-1 sm:p-1.5 transition hover:bg-black/10 !cursor-grab active:!cursor-grabbing"
                  title="드래그하여 순서 변경"
                >
                  <GripVertical class="w-3 h-3 sm:w-3.5 sm:h-3.5" />
                </div>
              </div>
            </div>

            <!-- Add Friend Card -->
            <div
              v-if="friendInfoInitialized"
              class="group rounded-xl sm:rounded-2xl border-2 border-dashed cursor-pointer hover:border-blue-400 hover:bg-blue-50 transition-all duration-300 flex flex-col items-center justify-center min-h-[80px] sm:min-h-[120px]"
              :style="{ borderColor: 'var(--dp-border-secondary)' }"
              @click="openSearchModal"
            >
              <div class="w-8 h-8 sm:w-12 sm:h-12 group-hover:bg-blue-100 rounded-full flex items-center justify-center mb-1 sm:mb-2 transition-colors" :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }">
                <UserPlus class="w-4 h-4 sm:w-6 sm:h-6 group-hover:text-blue-500 transition-colors" :style="{ color: 'var(--dp-text-muted)' }" />
              </div>
              <span class="font-semibold text-xs sm:text-sm group-hover:text-blue-600 transition-colors" :style="{ color: 'var(--dp-text-muted)' }">친구 추가</span>
            </div>
          </div>
        </div>
      </div>

    </template>

    <!-- Guest Dashboard -->
    <template v-else>
      <!-- Hero Section -->
      <div class="relative overflow-hidden rounded-3xl shadow-sm border p-8 sm:p-12 text-center mb-8" :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' }">
        <div class="relative">
          <h1 class="text-4xl sm:text-5xl font-bold mb-4" :style="{ color: 'var(--dp-text-primary)' }">Dutypark</h1>
          <p class="mb-8 max-w-lg mx-auto leading-relaxed" :style="{ color: 'var(--dp-text-secondary)' }">
            근무 관리, 시간표 등록, 일정 관리, 할일 관리 및 팀원들의 시간표 조회, 친구 및 가족의 일정 공유 등 다양한 기능을 통해 여러분의 일상을 도와줍니다.
          </p>
          <router-link
            to="/auth/login"
            class="inline-flex items-center gap-2 px-8 py-3.5 rounded-xl font-semibold transition-all shadow-lg border-2 bg-blue-600 hover:bg-blue-700 border-blue-700"
            style="color: white;"
          >
            로그인 / 회원가입
            <ChevronRight class="w-5 h-5" />
          </router-link>
        </div>
      </div>

      <!-- Features Section -->
      <div class="rounded-2xl shadow-sm border p-6 sm:p-8" :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' }">
        <h2 class="text-2xl font-bold mb-8 flex items-center gap-3" :style="{ color: 'var(--dp-text-primary)' }">
          <div class="w-10 h-10 bg-gray-900 rounded-xl flex items-center justify-center">
            <Sparkles class="w-5 h-5 text-white" />
          </div>
          주요 기능
        </h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div
            v-for="feature in features"
            :key="feature.text"
            class="flex items-start gap-4 p-4 rounded-xl border hover:shadow-md transition-shadow"
            :style="{ backgroundColor: 'var(--dp-bg-secondary)', borderColor: 'var(--dp-border-primary)' }"
          >
            <div class="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0" :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }">
              <CalendarDays v-if="feature.icon === 'calendar'" class="w-5 h-5" :style="{ color: 'var(--dp-text-primary)' }" />
              <ListTodo v-else-if="feature.icon === 'check'" class="w-5 h-5" :style="{ color: 'var(--dp-text-primary)' }" />
              <Clock v-else-if="feature.icon === 'clock'" class="w-5 h-5" :style="{ color: 'var(--dp-text-primary)' }" />
              <Users v-else-if="feature.icon === 'users'" class="w-5 h-5" :style="{ color: 'var(--dp-text-primary)' }" />
              <Heart v-else-if="feature.icon === 'heart'" class="w-5 h-5" :style="{ color: 'var(--dp-text-primary)' }" />
              <Flag v-else-if="feature.icon === 'flag'" class="w-5 h-5" :style="{ color: 'var(--dp-text-primary)' }" />
              <Sun v-else-if="feature.icon === 'sun'" class="w-5 h-5" :style="{ color: 'var(--dp-text-primary)' }" />
            </div>
            <span class="font-medium pt-2" :style="{ color: 'var(--dp-text-primary)' }">{{ feature.text }}</span>
          </div>
        </div>
        <div class="mt-8 text-center">
          <p :style="{ color: 'var(--dp-text-primary)' }">
            지금 바로 Dutypark을 사용해보세요!
          </p>
          <p class="text-sm mt-1" :style="{ color: 'var(--dp-text-muted)' }">
            회원가입은 카카오톡 아이디로 로그인만 가능합니다.
          </p>
        </div>
      </div>
    </template>

    <!-- Search Modal -->
    <Teleport to="body">
      <div
        v-if="showSearchModal"
        class="fixed inset-0 z-50 flex items-center justify-center"
        @click.self="closeSearchModal"
      >
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="closeSearchModal"></div>

        <!-- Modal Content -->
        <div class="relative rounded-2xl shadow-2xl w-full max-w-2xl mx-2 sm:mx-4 max-h-[90vh] overflow-hidden" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
          <!-- Header -->
          <div class="flex items-center justify-between p-5 border-b bg-gradient-to-r from-gray-50 to-white" :style="{ borderColor: 'var(--dp-border-primary)' }">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-xl flex items-center justify-center">
                <UserPlus class="w-5 h-5 text-white" />
              </div>
              <h3 class="text-xl font-bold" :style="{ color: 'var(--dp-text-primary)' }">친구 추가</h3>
            </div>
            <button
              class="p-2 rounded-xl transition hover:bg-opacity-80"
              :style="{ color: 'var(--dp-text-muted)' }"
              @click="closeSearchModal"
            >
              <X class="w-5 h-5" />
            </button>
          </div>

          <!-- Body -->
          <div class="p-5 overflow-y-auto max-h-[calc(90vh-180px)]">
            <!-- Search Input -->
            <div class="flex gap-2 mb-5">
              <div class="flex-grow relative">
                <Search class="w-5 h-5 absolute left-3.5 top-1/2 transform -translate-y-1/2" :style="{ color: 'var(--dp-text-muted)' }" />
                <input
                  v-model="searchKeyword"
                  type="text"
                  placeholder="이름 또는 팀 검색"
                  class="w-full pl-11 pr-4 py-3 border rounded-xl focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 outline-none transition-all"
                  :style="{ backgroundColor: 'var(--dp-bg-input)', borderColor: 'var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
                  @keyup.enter="search"
                />
              </div>
              <button
                class="px-5 py-3 bg-gradient-to-r from-slate-700 to-slate-800 text-white rounded-xl hover:from-slate-800 hover:to-slate-900 transition-all shadow-lg flex items-center gap-2 font-medium"
                @click="search"
              >
                <Search class="w-4 h-4" />
                검색
              </button>
            </div>

            <!-- Search Loading -->
            <div v-if="searchLoading" class="flex justify-center py-10">
              <div class="w-8 h-8 border-3 rounded-full animate-spin" :style="{ borderColor: 'var(--dp-border-secondary)', borderTopColor: '#3b82f6' }"></div>
            </div>

            <!-- Search Results -->
            <div v-else-if="searchResult.length > 0">
              <div class="space-y-2">
                <div
                  v-for="(member, index) in searchResult"
                  :key="member.id ?? index"
                  class="flex items-center justify-between p-4 rounded-xl transition hover:bg-opacity-80"
                  :style="{ backgroundColor: 'var(--dp-bg-secondary)' }"
                >
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 bg-gradient-to-br from-gray-200 to-gray-300 rounded-full flex items-center justify-center">
                      <span class="text-sm font-bold text-gray-600">{{ member.name.charAt(0) }}</span>
                    </div>
                    <div>
                      <p class="font-semibold" :style="{ color: 'var(--dp-text-primary)' }">{{ member.name }}</p>
                      <p class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">{{ member.team ?? '팀 없음' }}</p>
                    </div>
                  </div>
                  <button
                    class="px-4 py-2 text-sm font-medium bg-green-500 text-white rounded-xl hover:bg-green-600 transition shadow-sm"
                    @click="requestFriend(member)"
                  >
                    친구 요청
                  </button>
                </div>
              </div>

              <!-- Pagination -->
              <div v-if="searchTotalPage > 1" class="flex justify-center items-center gap-2 mt-6">
                <button
                  class="p-2.5 rounded-xl border disabled:opacity-50 disabled:cursor-not-allowed transition hover:bg-opacity-80"
                  :style="{ borderColor: 'var(--dp-border-primary)' }"
                  :disabled="searchPage === 0"
                  @click="prevPage"
                >
                  <ChevronLeft class="w-4 h-4" />
                </button>

                <template v-for="i in searchTotalPage" :key="i">
                  <button
                    class="w-10 h-10 rounded-xl border font-medium transition hover:bg-opacity-80"
                    :class="(i - 1) === searchPage ? 'bg-blue-600 text-white border-blue-600' : ''"
                    :style="(i - 1) !== searchPage ? { borderColor: 'var(--dp-border-primary)' } : {}"
                    @click="goToPage(i - 1)"
                  >
                    {{ i }}
                  </button>
                </template>

                <button
                  class="p-2.5 rounded-xl border disabled:opacity-50 disabled:cursor-not-allowed transition hover:bg-opacity-80"
                  :style="{ borderColor: 'var(--dp-border-primary)' }"
                  :disabled="searchPage >= searchTotalPage - 1"
                  @click="nextPage"
                >
                  <ChevronRight class="w-4 h-4" />
                </button>
              </div>

              <p class="text-center text-sm mt-4" :style="{ color: 'var(--dp-text-secondary)' }">
                페이지 {{ searchPage + 1 }} / {{ searchTotalPage }} | 전체 결과: {{ searchTotalElements }}
              </p>
            </div>
            <div v-else class="text-center py-12">
              <Search class="w-12 h-12 mx-auto mb-3" :style="{ color: 'var(--dp-border-secondary)' }" />
              <p :style="{ color: 'var(--dp-text-secondary)' }">검색어를 입력하고 검색해주세요.</p>
            </div>
          </div>

          <!-- Footer -->
          <div class="flex justify-end p-5 border-t" :style="{ borderColor: 'var(--dp-border-primary)', backgroundColor: 'var(--dp-bg-secondary)' }">
            <button
              class="px-5 py-2.5 rounded-xl transition font-medium hover:bg-opacity-80"
              :style="{ backgroundColor: 'var(--dp-bg-tertiary)', color: 'var(--dp-text-primary)' }"
              @click="closeSearchModal"
            >
              닫기
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
