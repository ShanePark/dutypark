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
  ChevronDown,
  UserPlus,
  Home,
  Trash2,
  X,
  Search,
  ChevronLeft,
  ChevronRight,
  User,
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
  { icon: 'calendar', text: '일정 관리 (등록, 검색, 공개 설정)' },
  { icon: 'check', text: '할일 관리로 까먹지 않는 일상' },
  { icon: 'clock', text: '근무 관리 및 시간표 등록' },
  { icon: 'users', text: '팀원들의 시간표와 일정 공유' },
  { icon: 'heart', text: '친구 및 가족의 일정 조회와 태그 기능' },
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
        class="group bg-white rounded-xl shadow-sm border-2 border-gray-200 mb-4 overflow-hidden cursor-pointer hover:shadow-lg hover:border-gray-400 hover:scale-[1.01] transition-all duration-200"
        @click="moveTo()"
      >
        <div class="bg-gray-600 group-hover:bg-gray-800 py-2 text-white font-bold uppercase flex items-center justify-between px-4 transition-colors duration-200">
          <span class="flex-1 text-center">{{ myInfo?.member.name || '로딩중...' }}</span>
          <ChevronRight class="w-5 h-5 opacity-70 group-hover:opacity-100 group-hover:translate-x-2 transition-all duration-200" />
        </div>
        <div class="p-5">
          <!-- Error state -->
          <div v-if="myInfoError" class="text-center py-4 text-red-500">
            {{ myInfoError }}
          </div>
          <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- Left column: Date & Duty -->
            <div class="space-y-3">
              <div class="flex items-center gap-2 text-gray-700">
                <Calendar class="w-5 h-5 text-gray-500" />
                <span class="font-medium">{{ today }}</span>
              </div>

              <div class="flex items-center gap-2">
                <Briefcase class="w-5 h-5 text-gray-500" />
                <span class="text-gray-600">근무:</span>
                <template v-if="myInfoLoading">
                  <div class="w-4 h-4 border-2 border-gray-300 border-t-gray-600 rounded-full animate-spin"></div>
                </template>
                <template v-else-if="myInfo?.duty">
                  <span
                    class="px-2 py-0.5 rounded font-medium text-sm"
                    :style="{
                      backgroundColor: myInfo.duty.dutyColor || '#666',
                      color: isLightColor(myInfo.duty.dutyColor) ? '#1f2937' : '#ffffff'
                    }"
                  >
                    {{ myInfo.duty.dutyType || '휴무' }}
                  </span>
                </template>
                <span v-else class="text-gray-400">없음</span>
              </div>
            </div>

            <!-- Right column: Today's schedules -->
            <div class="border-t pt-4 mt-1 sm:border-t-0 sm:pt-0 sm:mt-0 sm:border-l sm:pl-6 border-gray-200">
              <div class="flex items-center gap-2 mb-2">
                <ClipboardList class="w-5 h-5 text-gray-500" />
                <span class="text-gray-700 font-medium">오늘 일정</span>
              </div>
              <template v-if="myInfoLoading">
                <div class="flex justify-center py-3">
                  <div class="w-5 h-5 border-2 border-gray-300 border-t-gray-600 rounded-full animate-spin"></div>
                </div>
              </template>
              <ul v-else class="space-y-1">
                <li
                  v-for="schedule in myInfo?.schedules || []"
                  :key="schedule.id"
                  class="py-1 border-b border-gray-100 last:border-0 text-gray-700"
                >
                  <span>{{ printSchedule(schedule) }}</span>
                  <span class="text-gray-400 ml-2 text-sm">{{ printScheduleTime(schedule.startDateTime) }}</span>
                </li>
                <li v-if="!myInfo?.schedules?.length" class="text-gray-400 text-sm">
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
        class="bg-white rounded-xl shadow-sm border border-gray-200 mb-4 overflow-hidden"
      >
        <div class="bg-gray-600 text-center py-2 text-white font-bold uppercase">
          친구 요청 관리
        </div>
        <div class="p-5">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <!-- Requests received (to me) -->
            <div
              v-for="req in friendInfo.pendingRequestsTo"
              :key="'to-' + req.fromMember.id"
              class="p-4 border rounded-lg bg-blue-50 border-blue-200"
            >
              <div class="flex justify-between items-center">
                <div class="font-bold text-gray-800 flex items-center gap-2">
                  <Home v-if="req.requestType === 'FAMILY_REQUEST'" class="w-4 h-4 text-blue-600" />
                  <UserPlus v-else class="w-4 h-4 text-blue-600" />
                  {{ req.fromMember.name }}
                </div>
                <div class="flex gap-2">
                  <button
                    class="px-3 py-1 text-sm border border-green-500 text-green-600 rounded hover:bg-green-50 transition"
                    @click.stop="acceptFriendRequest(req)"
                  >
                    승인
                  </button>
                  <button
                    class="px-3 py-1 text-sm border border-red-500 text-red-600 rounded hover:bg-red-50 transition"
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
              class="p-4 border rounded-lg bg-yellow-50 border-yellow-200"
            >
              <div class="flex justify-between items-center">
                <div class="font-bold text-gray-800 flex items-center gap-2">
                  <Home v-if="req.requestType === 'FAMILY_REQUEST'" class="w-4 h-4 text-yellow-600" />
                  <UserPlus v-else class="w-4 h-4 text-yellow-600" />
                  {{ req.toMember.name }}
                </div>
                <button
                  class="px-3 py-1 text-sm border border-yellow-500 text-yellow-700 rounded hover:bg-yellow-100 transition"
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
      <div ref="friendSectionRef" class="friend-section bg-white rounded-xl shadow-sm border border-gray-200 mb-4 overflow-hidden">
        <div class="bg-gray-600 text-center py-2 text-white font-bold uppercase">
          친구 목록
        </div>
        <div class="p-5">
          <!-- Error state -->
          <div v-if="friendInfoError" class="text-center py-4 text-red-500">
            {{ friendInfoError }}
          </div>
          <template v-else-if="friendInfoLoading">
            <div class="flex justify-center py-10">
              <div class="w-8 h-8 border-3 border-gray-300 border-t-gray-600 rounded-full animate-spin"></div>
            </div>
          </template>
          <div v-else ref="friendListRef" class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <!-- Friend Cards -->
            <div
              v-for="friend in sortedFriends"
              :key="friend.member.id ?? 'unknown'"
              :data-member-id="friend.member.id"
              class="friend-card p-4 border-2 border-gray-200 rounded-lg cursor-pointer transition-all duration-200 shadow-sm hover:shadow-lg hover:scale-[1.02] hover:border-blue-300 hover:bg-blue-50 flex flex-col"
              :class="{
                'pinned-friend bg-yellow-50': friend.pinOrder,
              }"
              @click="moveTo(friend.member.id)"
            >
              <div class="flex-grow">
                <!-- Header: Name & Actions -->
                <div class="flex justify-between items-center mb-2">
                  <div class="font-bold text-gray-800 flex items-center gap-1">
                    <User v-if="!friend.isFamily" class="w-4 h-4 text-gray-500" />
                    <Home v-if="friend.isFamily" class="w-4 h-4 text-gray-600" fill="currentColor" />
                    {{ friend.member.name }}
                  </div>
                  <div class="flex items-center gap-2" @click.stop>
                    <!-- Pin/Unpin button -->
                    <button
                      v-if="friend.pinOrder"
                      class="p-2 min-h-11 min-w-11 flex items-center justify-center text-yellow-500 hover:text-yellow-600 transition"
                      @click.stop="unpinFriend(friend.member)"
                      title="고정 해제"
                    >
                      <Star class="w-5 h-5" fill="currentColor" />
                    </button>
                    <button
                      v-else
                      class="p-2 min-h-11 min-w-11 flex items-center justify-center text-gray-400 hover:text-yellow-500 transition"
                      @click.stop="pinFriend(friend.member)"
                      title="고정"
                    >
                      <Star class="w-5 h-5" />
                    </button>

                    <!-- Dropdown toggle -->
                    <div v-if="friend.member.id" class="relative">
                      <button
                        class="px-3 py-2 min-h-11 text-sm border border-gray-300 rounded hover:bg-gray-100 transition flex items-center gap-1"
                        @click="toggleDropdown(friend.member.id, $event)"
                      >
                        관리
                        <ChevronDown class="w-3 h-3" />
                      </button>
                      <!-- Dropdown menu -->
                      <div
                        v-if="openDropdownId === friend.member.id"
                        class="absolute right-0 mt-1 w-32 bg-white border border-gray-200 rounded-lg shadow-lg z-10"
                      >
                        <button
                          v-if="!friend.isFamily"
                          class="w-full px-3 py-2 text-left text-sm text-blue-600 hover:bg-blue-50 flex items-center gap-2"
                          @click="addFamily(friend.member)"
                        >
                          <Home class="w-4 h-4" />
                          가족 등록
                        </button>
                        <button
                          class="w-full px-3 py-2 text-left text-sm text-red-600 hover:bg-red-50 flex items-center gap-2"
                          @click="unfriend(friend.member)"
                        >
                          <Trash2 class="w-4 h-4" />
                          친구 삭제
                        </button>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Duty info -->
                <p class="text-sm text-gray-600 mb-2 flex items-center gap-1">
                  <Briefcase class="w-4 h-4 text-gray-400" />
                  근무:
                  <span v-if="friend.duty" class="ml-1">{{ friend.duty.dutyType || '휴무' }}</span>
                  <span v-else class="ml-1 text-gray-400">-</span>
                </p>

                <!-- Schedules -->
                <div v-if="friend.schedules && friend.schedules.length" class="mt-2">
                  <ul class="space-y-1">
                    <li
                      v-for="schedule in friend.schedules"
                      :key="schedule.id"
                      class="text-sm sm:text-base py-1 border-b border-gray-100 last:border-0 text-gray-600"
                    >
                      <span>{{ printSchedule(schedule) }}</span>
                      <span class="text-gray-400 ml-2">{{ printScheduleTime(schedule.startDateTime) }}</span>
                    </li>
                  </ul>
                </div>
              </div>

              <!-- Drag handle for pinned friends -->
              <div v-if="friend.pinOrder" class="flex justify-end mt-2" @click.stop>
                <div
                  class="handle bg-gray-100 rounded-full border border-gray-200 px-2 py-1 shadow-sm cursor-grab active:cursor-grabbing"
                  title="드래그하여 순서 변경"
                >
                  <GripVertical class="w-4 h-4 text-gray-400" />
                </div>
              </div>
            </div>

            <!-- Add Friend Card -->
            <div
              v-if="friendInfoInitialized"
              class="group p-4 border-2 border-dashed border-blue-300 rounded-lg cursor-pointer bg-blue-50 hover:bg-blue-400 hover:border-blue-400 hover:scale-[1.02] transition-all duration-200 flex flex-col items-center justify-center min-h-[120px]"
              @click="openSearchModal"
            >
              <UserPlus class="w-8 h-8 text-blue-400 group-hover:text-white mb-2 transition-colors duration-200" />
              <span class="font-bold text-blue-400 group-hover:text-white transition-colors duration-200">친구 추가</span>
            </div>
          </div>
        </div>
      </div>

    </template>

    <!-- Guest Dashboard -->
    <template v-else>
      <!-- Hero Section -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-4 sm:p-8 text-center mb-6">
        <h1 class="text-2xl sm:text-4xl font-bold text-gray-900 mb-4">Dutypark</h1>
        <p class="text-gray-600 mb-6 max-w-lg mx-auto">
          Dutypark는 근무 관리, 시간표 등록, 일정 관리, 할일 관리 및 팀원들의 시간표 조회, 친구 및 가족의 일정 공유 등 다양한 기능을 통해 여러분의 일상을 도와줍니다.
        </p>
        <router-link
          to="/auth/login"
          class="inline-block border-2 border-gray-800 text-gray-800 px-8 py-3 rounded-lg font-medium hover:bg-gray-800 hover:!text-white transition"
        >
          로그인 / 회원가입
        </router-link>
      </div>

      <!-- Features Section -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-4 sm:p-8">
        <h2 class="text-2xl font-bold text-gray-900 mb-6">주요 기능</h2>
        <ul class="space-y-4">
          <li v-for="feature in features" :key="feature.text" class="flex items-start gap-3">
            <Calendar v-if="feature.icon === 'calendar'" class="w-6 h-6 text-gray-500 mt-0.5" />
            <CheckCircle v-else-if="feature.icon === 'check'" class="w-6 h-6 text-gray-500 mt-0.5" />
            <Clock v-else-if="feature.icon === 'clock'" class="w-6 h-6 text-gray-500 mt-0.5" />
            <Users v-else-if="feature.icon === 'users'" class="w-6 h-6 text-gray-500 mt-0.5" />
            <Heart v-else-if="feature.icon === 'heart'" class="w-6 h-6 text-gray-500 mt-0.5" />
            <span class="text-gray-700">{{ feature.text }}</span>
          </li>
        </ul>
        <p class="mt-6 text-gray-600">
          지금 바로 Dutypark을 사용해보세요!<br>
          <span class="text-sm text-gray-500">(현재 회원가입은 카카오톡 로그인을 지원합니다.)</span>
        </p>
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
        <div class="absolute inset-0 bg-black/50" @click="closeSearchModal"></div>

        <!-- Modal Content -->
        <div class="relative bg-white rounded-xl shadow-2xl w-full max-w-2xl mx-2 sm:mx-4 max-h-[90vh] overflow-hidden">
          <!-- Header -->
          <div class="flex items-center justify-between p-3 sm:p-4 border-b border-gray-200">
            <h3 class="text-xl font-semibold text-gray-900">친구 추가</h3>
            <button
              class="text-gray-400 hover:text-gray-600 transition"
              @click="closeSearchModal"
            >
              <X class="w-6 h-6" />
            </button>
          </div>

          <!-- Body -->
          <div class="p-3 sm:p-4 overflow-y-auto max-h-[calc(90vh-140px)]">
            <!-- Search Input -->
            <div class="flex gap-2 mb-4">
              <div class="flex-grow relative">
                <input
                  v-model="searchKeyword"
                  type="text"
                  placeholder="이름 또는 팀 검색"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
                  @keyup.enter="search"
                />
              </div>
              <button
                class="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition flex items-center gap-2"
                @click="search"
              >
                <Search class="w-4 h-4" />
                검색
              </button>
            </div>

            <!-- Search Loading -->
            <div v-if="searchLoading" class="flex justify-center py-8">
              <div class="w-6 h-6 border-2 border-gray-300 border-t-gray-600 rounded-full animate-spin"></div>
            </div>

            <!-- Search Results -->
            <div v-else-if="searchResult.length > 0">
              <table class="w-full">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-4 py-2 text-left text-sm font-medium text-gray-600 w-12">#</th>
                    <th class="px-4 py-2 text-left text-sm font-medium text-gray-600">팀</th>
                    <th class="px-4 py-2 text-left text-sm font-medium text-gray-600">이름</th>
                    <th class="px-4 py-2 text-center text-sm font-medium text-gray-600 w-24">요청</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  <tr v-for="(member, index) in searchResult" :key="member.id ?? index" class="hover:bg-gray-50">
                    <td class="px-4 py-3 text-sm text-gray-500">
                      {{ searchPage * searchPageSize + index + 1 }}
                    </td>
                    <td class="px-4 py-3 text-sm text-gray-700">{{ member.team ?? '-' }}</td>
                    <td class="px-4 py-3 text-sm text-gray-900 font-medium">{{ member.name }}</td>
                    <td class="px-4 py-3 text-center">
                      <button
                        class="px-3 py-1 text-sm border border-green-500 text-green-600 rounded hover:bg-green-50 transition"
                        @click="requestFriend(member)"
                      >
                        친구 요청
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>

              <!-- Pagination -->
              <div v-if="searchTotalPage > 1" class="flex justify-center items-center gap-2 mt-4">
                <button
                  class="p-2 h-10 min-w-10 sm:h-8 sm:min-w-8 flex items-center justify-center rounded border border-gray-300 hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed transition"
                  :disabled="searchPage === 0"
                  @click="prevPage"
                >
                  <ChevronLeft class="w-4 h-4" />
                </button>

                <template v-for="i in searchTotalPage" :key="i">
                  <button
                    class="h-10 min-w-10 sm:h-8 sm:min-w-8 rounded border transition"
                    :class="(i - 1) === searchPage
                      ? 'bg-blue-600 text-white border-blue-600'
                      : 'border-gray-300 hover:bg-gray-100'"
                    @click="goToPage(i - 1)"
                  >
                    {{ i }}
                  </button>
                </template>

                <button
                  class="p-2 h-10 min-w-10 sm:h-8 sm:min-w-8 flex items-center justify-center rounded border border-gray-300 hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed transition"
                  :disabled="searchPage >= searchTotalPage - 1"
                  @click="nextPage"
                >
                  <ChevronRight class="w-4 h-4" />
                </button>
              </div>

              <p class="text-center text-sm text-gray-500 mt-2">
                페이지 {{ searchPage + 1 }} / {{ searchTotalPage }} | 전체 결과: {{ searchTotalElements }}
              </p>
            </div>
            <p v-else class="text-center text-gray-500 py-8">
              검색어를 입력하고 검색해주세요.
            </p>
          </div>

          <!-- Footer -->
          <div class="flex justify-end p-3 sm:p-4 border-t border-gray-200">
            <button
              class="px-4 py-2 bg-gray-500 text-white rounded-lg hover:bg-gray-600 transition"
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
