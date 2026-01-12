<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { dashboardApi } from '@/api/dashboard'
import { friendApi } from '@/api/member'
import { useSwal } from '@/composables/useSwal'
import { isLightColor } from '@/utils/color'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
import Sortable from 'sortablejs'
import type {
  DashboardMyDetail,
  DashboardFriendInfo,
  DashboardScheduleDto,
  FriendDto,
} from '@/types'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import IntroSection from '@/components/intro/IntroSection.vue'
import {
  Calendar,
  Briefcase,
  ClipboardList,
  Clock,
  Users,
  Star,
  GripVertical,
  UserPlus,
  Home,
  X,
  Search,
  ChevronLeft,
  ChevronRight,
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const { showWarning, confirm, toastSuccess } = useSwal()

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
useBodyScrollLock(showSearchModal)
useEscapeKey(showSearchModal, () => { showSearchModal.value = false })
const searchKeyword = ref('')
const searchResult = ref<FriendDto[]>([])
const searchPage = ref(0)
const searchTotalPage = ref(0)
const searchTotalElements = ref(0)
const searchPageSize = 5
const searchLoading = ref(false)

// Sortable instance
let friendSortable: Sortable | null = null
const friendListRef = ref<HTMLElement | null>(null)
const friendSectionRef = ref<HTMLElement | null>(null)
let isDragging = false

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
  <!-- Guest Dashboard - Full width -->
  <IntroSection v-if="!authStore.isLoggedIn" />

  <!-- Logged-in Dashboard -->
  <div v-else class="max-w-4xl mx-auto px-4 py-6">
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
            <ProfileAvatar
              :member-id="myInfo?.member.id"
              :name="myInfo?.member.name"
              :has-profile-photo="myInfo?.member.hasProfilePhoto"
              :profile-photo-version="myInfo?.member.profilePhotoVersion"
              size="md"
            />
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
                <span v-else :style="{ color: 'var(--dp-text-muted)' }">없음</span>
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

      <!-- Friends List Section -->
      <div ref="friendSectionRef" class="friend-section rounded-2xl shadow-sm border overflow-hidden" :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' }">
        <div
          class="group bg-gradient-to-r from-slate-700 to-slate-800 px-6 py-3 cursor-pointer hover:from-slate-600 hover:to-slate-700 transition-all"
          @click="router.push('/friends')"
        >
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <Users class="w-5 h-5 text-white" />
              <span class="text-white font-bold">친구관리</span>
              <span v-if="friendInfo?.friends.length" class="ml-2 px-2 py-0.5 bg-white/20 rounded-full text-xs text-white">
                {{ friendInfo.friends.length }}
              </span>
            </div>
            <ChevronRight class="w-5 h-5 text-gray-400 group-hover:text-white group-hover:translate-x-1 transition-all" />
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
          <!-- Empty state -->
          <div v-else-if="sortedFriends.length === 0" class="text-center py-8">
            <Users class="w-12 h-12 mx-auto mb-3" :style="{ color: 'var(--dp-text-muted)' }" />
            <p class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">아직 친구가 없습니다.</p>
            <button
              class="mt-4 px-4 py-2 text-sm font-medium bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition cursor-pointer"
              @click="openSearchModal"
            >
              친구 추가하기
            </button>
          </div>

          <div v-else ref="friendListRef" class="grid grid-cols-1 sm:grid-cols-2 gap-2 sm:gap-3">
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
              <div class="flex p-3">
                <!-- Left section: Large Profile -->
                <div class="flex-shrink-0 mr-3">
                  <ProfileAvatar
                    :member-id="friend.member.id"
                    :name="friend.member.name"
                    :has-profile-photo="friend.member.hasProfilePhoto"
                    :profile-photo-version="friend.member.profilePhotoVersion"
                    size="xl"
                  />
                </div>

                <!-- Right section: Info & Actions -->
                <div class="flex-1 min-w-0">
                  <!-- Top: Name & Actions -->
                  <div class="flex items-center justify-between mb-1.5">
                    <div class="flex items-center gap-1.5 min-w-0">
                      <span class="font-medium text-sm truncate" :style="{ color: 'var(--dp-text-primary)' }">{{ friend.member.name }}</span>
                      <Home v-if="friend.isFamily" class="w-3.5 h-3.5 flex-shrink-0 text-amber-500" title="Family member" />
                    </div>
                    <div class="flex items-center flex-shrink-0" @click.stop>
                    <!-- Pin/Unpin button -->
                    <button
                      v-if="friend.pinOrder"
                      class="p-1 text-amber-500 hover:text-amber-600 transition cursor-pointer"
                      @click.stop="unpinFriend(friend.member)"
                      title="고정 해제"
                    >
                      <Star class="w-4 h-4" fill="currentColor" />
                    </button>
                    <button
                      v-else
                      class="p-1 text-gray-300 hover:text-amber-500 transition cursor-pointer"
                      @click.stop="pinFriend(friend.member)"
                      title="고정"
                    >
                      <Star class="w-4 h-4" />
                    </button>
                  </div>
                  </div>

                  <!-- Duty info -->
                  <div class="flex items-center gap-1.5 mb-1.5">
                    <Briefcase class="w-3.5 h-3.5 flex-shrink-0" :style="{ color: 'var(--dp-text-muted)' }" />
                    <span class="text-xs" :style="{ color: 'var(--dp-text-secondary)' }">근무:</span>
                    <span v-if="friend.duty" class="text-xs font-medium truncate" :style="{ color: 'var(--dp-text-primary)' }">{{ friend.duty.dutyType || '휴무' }}</span>
                    <span v-else class="text-xs" :style="{ color: 'var(--dp-text-muted)' }">-</span>
                  </div>

                  <!-- Schedules -->
                  <div v-if="friend.schedules && friend.schedules.length" class="space-y-1">
                    <div
                      v-for="schedule in friend.schedules.slice(0, 2)"
                      :key="schedule.id"
                      class="text-xs py-1 px-1.5 rounded-md truncate friend-schedule-item"
                    >
                      {{ printSchedule(schedule) }}
                    </div>
                    <div v-if="friend.schedules.length > 2" class="text-xs pl-1" :style="{ color: 'var(--dp-text-muted)' }">
                      +{{ friend.schedules.length - 2 }}개 더보기
                    </div>
                  </div>
                </div>
              </div>

              <!-- Drag handle for pinned friends -->
              <div v-if="friend.pinOrder" class="absolute bottom-2 right-2" @click.stop>
                <div
                  class="handle friend-drag-handle rounded-lg p-1.5 transition hover:bg-black/10 !cursor-grab active:!cursor-grabbing"
                  title="드래그하여 순서 변경"
                >
                  <GripVertical class="w-4 h-4" />
                </div>
              </div>
            </div>

          </div>
        </div>
      </div>

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
          <div class="flex items-center justify-between p-5 border-b" :style="{ borderColor: 'var(--dp-border-primary)', backgroundColor: 'var(--dp-bg-secondary)' }">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-xl flex items-center justify-center">
                <UserPlus class="w-5 h-5 text-white" />
              </div>
              <h3 class="text-xl font-bold" :style="{ color: 'var(--dp-text-primary)' }">친구 추가</h3>
            </div>
            <button
              class="p-2 rounded-full hover-close-btn cursor-pointer"
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
                class="px-5 py-3 bg-gradient-to-r from-slate-700 to-slate-800 text-white rounded-xl hover:from-slate-800 hover:to-slate-900 transition-all shadow-lg flex items-center gap-2 font-medium cursor-pointer"
                @click="search"
              >
                <Search class="w-4 h-4" />
                검색
              </button>
            </div>

            <!-- Search Loading -->
            <div v-if="searchLoading" class="flex justify-center py-10">
              <div class="w-8 h-8 border-3 rounded-full animate-spin" :style="{ borderColor: 'var(--dp-border-secondary)', borderTopColor: 'var(--dp-accent)' }"></div>
            </div>

            <!-- Search Results -->
            <div v-else-if="searchResult.length > 0">
              <div class="space-y-2">
                <div
                  v-for="(member, index) in searchResult"
                  :key="member.id ?? index"
                  class="flex items-center justify-between p-4 rounded-xl hover-bg-light"
                  :style="{ backgroundColor: 'var(--dp-bg-secondary)' }"
                >
                  <div class="flex items-center gap-3">
                    <ProfileAvatar
                      :member-id="member.id"
                      :name="member.name"
                      :has-profile-photo="member.hasProfilePhoto"
                      :profile-photo-version="member.profilePhotoVersion"
                      size="md"
                    />
                    <div>
                      <p class="font-semibold" :style="{ color: 'var(--dp-text-primary)' }">{{ member.name }}</p>
                      <p class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">{{ member.team ?? '팀 없음' }}</p>
                    </div>
                  </div>
                  <button
                    class="px-4 py-2 text-sm font-medium bg-green-500 text-white rounded-xl hover:bg-green-600 transition shadow-sm cursor-pointer"
                    @click="requestFriend(member)"
                  >
                    친구 요청
                  </button>
                </div>
              </div>

              <!-- Pagination -->
              <div v-if="searchTotalPage > 1" class="flex justify-center items-center gap-2 mt-6">
                <button
                  class="p-2.5 rounded-xl border disabled:opacity-50 disabled:cursor-not-allowed hover-bg-light cursor-pointer"
                  :style="{ borderColor: 'var(--dp-border-primary)' }"
                  :disabled="searchPage === 0"
                  @click="prevPage"
                >
                  <ChevronLeft class="w-4 h-4" />
                </button>

                <template v-for="i in searchTotalPage" :key="i">
                  <button
                    class="w-10 h-10 rounded-xl border font-medium hover-bg-light cursor-pointer"
                    :class="(i - 1) === searchPage ? 'bg-blue-600 text-white border-blue-600' : ''"
                    :style="(i - 1) !== searchPage ? { borderColor: 'var(--dp-border-primary)' } : {}"
                    @click="goToPage(i - 1)"
                  >
                    {{ i }}
                  </button>
                </template>

                <button
                  class="p-2.5 rounded-xl border disabled:opacity-50 disabled:cursor-not-allowed hover-bg-light cursor-pointer"
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
              class="px-5 py-2.5 rounded-xl font-medium hover-interactive cursor-pointer"
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
