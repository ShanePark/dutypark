<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { dashboardApi } from '@/api/dashboard'
import { friendApi } from '@/api/member'
import { useSwal } from '@/composables/useSwal'
import { isLightColor } from '@/utils/color'
import Sortable from 'sortablejs'
import type {
  DashboardMyDetail,
  DashboardFriendInfo,
  DashboardScheduleDto,
  MemberPreviewDto,
} from '@/types'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import FriendSearchModal from '@/components/common/FriendSearchModal.vue'
import IntroSection from '@/components/intro/IntroSection.vue'
import {
  Calendar,
  Briefcase,
  ClipboardList,
  Clock,
  Users,
  Star,
  GripVertical,
  Home,
  ChevronRight,
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const { t, locale } = useI18n()
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
  return new Date().toLocaleDateString(locale.value, {
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
    myInfoError.value = t('dashboard.messages.loadMyFailed')
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
    friendInfoError.value = t('dashboard.messages.loadFriendsFailed')
  } finally {
    friendInfoLoading.value = false
  }
}

// Search modal state
const showSearchModal = ref(false)
const searchKeyword = ref('')
const searchResult = ref<MemberPreviewDto[]>([])
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
  return date.toLocaleTimeString(locale.value, {
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
      showWarning(t('dashboard.messages.pinFailed'))
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
      showWarning(t('dashboard.messages.unpinFailed'))
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

async function requestFriend(member: MemberPreviewDto) {
  if (!member.id) return
  if (!await confirm(
    t('dashboard.friendRequest.confirm', { name: member.name }),
    t('dashboard.friendRequest.title'),
  )) return
  try {
    await friendApi.sendFriendRequest(member.id)
    // Remove from search results to show it's been requested
    searchResult.value = searchResult.value.filter((m) => m.id !== member.id)
    // Refresh friend requests section
    await loadFriendsDashboard()
    toastSuccess(t('dashboard.friendRequest.success', { name: member.name }))
  } catch (error) {
    console.error('Failed to send friend request:', error)
    showWarning(t('dashboard.messages.friendRequestFailed'))
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
    showWarning(t('dashboard.messages.reorderFailed'))
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
          class="group px-5 py-3 bg-gradient-to-r from-dp-surface-strong to-dp-surface-strong-alt flex items-center justify-between cursor-pointer hover:from-dp-surface-strong-alt hover:to-dp-surface-strong-hover transition-all"
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
            <span class="text-lg font-bold text-dp-text-on-dark">{{ myInfo?.member.name || t('dashboard.labels.loadingName') }}</span>
          </div>
          <ChevronRight class="w-5 h-5 text-dp-text-muted group-hover:text-dp-text-on-dark group-hover:translate-x-1 transition-all" />
        </div>

        <!-- Content -->
        <div class="p-5">
          <!-- Error state -->
          <div v-if="myInfoError" class="text-center py-4 text-dp-danger">
            {{ myInfoError }}
          </div>
          <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-5">
            <!-- Left column: Date & Duty -->
            <div class="space-y-3">
              <div class="flex items-center gap-2 text-dp-text-primary">
                <Calendar class="w-5 h-5 text-dp-text-muted" />
                <span class="font-medium">{{ today }}</span>
              </div>

              <div class="flex items-center gap-2">
                <Briefcase class="w-5 h-5 text-dp-text-muted" />
                <span class="text-dp-text-secondary">{{ t('dashboard.labels.duty') }}</span>
                <template v-if="myInfoLoading">
                  <div class="w-4 h-4 border-2 rounded-full animate-spin" :style="{ borderColor: 'var(--dp-border-secondary)', borderTopColor: 'var(--dp-text-primary)' }"></div>
                </template>
                <template v-else-if="myInfo?.duty">
                  <span
                    class="px-2.5 py-0.5 rounded-md font-semibold text-sm"
                    :style="{
                      backgroundColor: myInfo.duty.dutyColor || 'var(--dp-duty-fallback)',
                      color: isLightColor(myInfo.duty.dutyColor) ? 'var(--dp-text-on-light)' : 'var(--dp-text-on-dark)'
                    }"
                  >
                    {{ myInfo.duty.dutyType || t('dashboard.labels.offDuty') }}
                  </span>
                </template>
                <span class="text-dp-text-muted" v-else>{{ t('dashboard.labels.none') }}</span>
              </div>
            </div>

            <!-- Right column: Today's schedules -->
            <div class="border-t pt-4 md:border-t-0 md:pt-0 md:border-l md:pl-5 border-dp-border-primary">
              <div class="flex items-center gap-2 mb-2">
                <ClipboardList class="w-5 h-5 text-dp-text-muted" />
                <span class="font-medium text-dp-text-primary">{{ t('dashboard.labels.todaySchedules') }}</span>
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
                  class="py-1.5 border-b last:border-0 flex items-center justify-between border-dp-border-primary text-dp-text-primary"
                >
                  <span class="truncate">{{ printSchedule(schedule) }}</span>
                  <span class="ml-2 text-sm flex-shrink-0 text-dp-text-muted">{{ printScheduleTime(schedule.startDateTime) }}</span>
                </li>
                <li v-if="!myInfo?.schedules?.length" class="text-sm text-dp-text-muted">
                  {{ t('dashboard.labels.noSchedules') }}
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>

      <!-- Friends List Section -->
      <div ref="friendSectionRef" class="friend-section rounded-2xl shadow-sm border overflow-hidden bg-dp-bg-card border-dp-border-primary">
        <div
          class="group bg-gradient-to-r from-dp-surface-strong to-dp-surface-strong-alt px-6 py-3 cursor-pointer hover:from-dp-surface-strong-alt hover:to-dp-surface-strong-hover transition-all"
          @click="router.push('/friends')"
        >
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <Users class="w-5 h-5 text-dp-text-on-dark" />
              <span class="text-dp-text-on-dark font-bold">{{ t('dashboard.labels.friends') }}</span>
              <span v-if="friendInfo?.friends.length" class="ml-2 px-2 py-0.5 bg-dp-overlay-light/20 rounded-full text-xs text-dp-text-on-dark">
                {{ friendInfo.friends.length }}
              </span>
            </div>
            <ChevronRight class="w-5 h-5 text-dp-text-muted group-hover:text-dp-text-on-dark group-hover:translate-x-1 transition-all" />
          </div>
        </div>
        <div class="p-5">
          <!-- Error state -->
          <div v-if="friendInfoError" class="text-center py-4 text-dp-danger">
            {{ friendInfoError }}
          </div>
          <template v-else-if="friendInfoLoading">
            <div class="flex justify-center py-10">
              <div class="w-8 h-8 border-3 rounded-full animate-spin" :style="{ borderColor: 'var(--dp-border-secondary)', borderTopColor: 'var(--dp-text-primary)' }"></div>
            </div>
          </template>
          <!-- Empty state -->
          <div v-else-if="sortedFriends.length === 0" class="text-center py-8">
            <Users class="w-12 h-12 mx-auto mb-3 text-dp-text-muted" />
            <p class="text-sm text-dp-text-secondary">{{ t('dashboard.labels.noFriends') }}</p>
            <button
              class="mt-4 px-4 py-2 text-sm font-medium bg-dp-accent text-dp-text-on-dark rounded-lg hover:bg-dp-accent-hover transition cursor-pointer"
              @click="openSearchModal"
            >
              {{ t('dashboard.actions.addFriend') }}
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
                  : 'border hover:border-dp-accent-border'
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
                      <span class="font-medium text-sm truncate text-dp-text-primary">{{ friend.member.name }}</span>
                      <Home v-if="friend.isFamily" class="w-3.5 h-3.5 flex-shrink-0 text-dp-warning" :title="t('dashboard.labels.familyMember')" />
                    </div>
                    <div class="flex items-center flex-shrink-0" @click.stop>
                    <!-- Pin/Unpin button -->
                    <button
                      v-if="friend.pinOrder"
                      class="p-1 text-dp-warning hover:text-dp-warning transition cursor-pointer"
                      @click.stop="unpinFriend(friend.member)"
                      :title="t('dashboard.actions.unpin')"
                    >
                      <Star class="w-4 h-4" fill="currentColor" />
                    </button>
                    <button
                      v-else
                      class="p-1 text-dp-text-muted hover:text-dp-warning transition cursor-pointer"
                      @click.stop="pinFriend(friend.member)"
                      :title="t('dashboard.actions.pin')"
                    >
                      <Star class="w-4 h-4" />
                    </button>
                  </div>
                  </div>

                  <!-- Duty info -->
                  <div class="flex items-center gap-1.5 mb-1.5">
                    <Briefcase class="w-3.5 h-3.5 flex-shrink-0 text-dp-text-muted" />
                    <span class="text-xs text-dp-text-secondary">{{ t('dashboard.labels.duty') }}</span>
                    <span v-if="friend.duty" class="text-xs font-medium truncate text-dp-text-primary">{{ friend.duty.dutyType || t('dashboard.labels.offDuty') }}</span>
                    <span v-else class="text-xs text-dp-text-muted">-</span>
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
                      {{ t('dashboard.labels.moreSchedules', { count: friend.schedules.length - 2 }) }}
                    </div>
                  </div>
                </div>
              </div>

              <!-- Drag handle for pinned friends -->
              <div v-if="friend.pinOrder" class="absolute bottom-2 right-2" @click.stop>
                <div
                  class="handle friend-drag-handle rounded-lg p-1.5 transition hover:bg-dp-overlay-dark/10 !cursor-grab active:!cursor-grabbing"
                  :title="t('dashboard.actions.dragToReorder')"
                >
                  <GripVertical class="w-4 h-4" />
                </div>
              </div>
            </div>

          </div>
        </div>
      </div>

    <FriendSearchModal
      :is-open="showSearchModal"
      :keyword="searchKeyword"
      :results="searchResult"
      :current-page="searchPage"
      :total-pages="searchTotalPage"
      :total-elements="searchTotalElements"
      :loading="searchLoading"
      @close="closeSearchModal"
      @update:keyword="searchKeyword = $event"
      @search="search"
      @request-friend="requestFriend"
      @change-page="goToPage"
    />
  </div>
</template>
