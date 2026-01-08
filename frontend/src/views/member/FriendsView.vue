<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from 'vue'
import { useRouter } from 'vue-router'
import { dashboardApi } from '@/api/dashboard'
import { friendApi } from '@/api/member'
import { useSwal } from '@/composables/useSwal'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
import { useNotificationStore } from '@/stores/notification'
import Sortable from 'sortablejs'
import type { DashboardFriendInfo, FriendDto } from '@/types'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import {
  Users,
  UserCheck,
  UserPlus,
  Home,
  Star,
  GripVertical,
  MoreVertical,
  Trash2,
  X,
  Search,
  ChevronLeft,
  ChevronRight,
} from 'lucide-vue-next'

const router = useRouter()
const notificationStore = useNotificationStore()
const { showWarning, confirm, confirmDelete, toastSuccess } = useSwal()

// Watch for notification-triggered refresh
watch(() => notificationStore.friendsRefreshTrigger, (newValue) => {
  if (newValue > 0) {
    loadFriendInfo()
  }
})

const loading = ref(false)
const error = ref<string | null>(null)
const friendInfo = ref<DashboardFriendInfo | null>(null)

// Dropdown state for friend management
const openDropdownId = ref<number | null>(null)
const dropdownPosition = ref({ top: 0, left: 0 })

// Sortable instance
let friendSortable: Sortable | null = null
const friendListRef = ref<HTMLElement | null>(null)
const friendSectionRef = ref<HTMLElement | null>(null)
let isDragging = false

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

const hasPendingRequests = computed(() => {
  if (!friendInfo.value) return false
  return friendInfo.value.pendingRequestsTo.length > 0 || friendInfo.value.pendingRequestsFrom.length > 0
})

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

const openDropdownFriend = computed(() => {
  if (!openDropdownId.value || !friendInfo.value) return null
  return friendInfo.value.friends.find(f => f.member.id === openDropdownId.value) || null
})

async function loadFriendInfo() {
  loading.value = true
  error.value = null
  try {
    friendInfo.value = await dashboardApi.getFriendsDashboard()
    nextTick(() => {
      initFriendSortable()
    })
  } catch (e) {
    console.error('Failed to load friend info:', e)
    error.value = '친구 정보를 불러오는데 실패했습니다.'
  } finally {
    loading.value = false
  }
}

// Friend request actions
async function acceptFriendRequest(req: { fromMember: { id: number | null; name: string } }) {
  if (!friendInfo.value || !req.fromMember.id) return
  try {
    await friendApi.acceptFriendRequest(req.fromMember.id)
    await loadFriendInfo()
    notificationStore.fetchFriendRequestCount()
    toastSuccess(`${req.fromMember.name}님의 친구 요청을 수락했습니다.`)
  } catch (e) {
    console.error('Failed to accept friend request:', e)
    showWarning('친구 요청 수락에 실패했습니다.')
  }
}

async function rejectFriendRequest(req: { fromMember: { id: number | null; name: string } }) {
  if (!friendInfo.value || !req.fromMember.id) return
  if (!await confirm(`${req.fromMember.name}님의 친구 요청을 거절하시겠습니까?`, '요청 거절')) return
  try {
    await friendApi.rejectFriendRequest(req.fromMember.id)
    friendInfo.value.pendingRequestsTo = friendInfo.value.pendingRequestsTo.filter(
      (r) => r.fromMember.id !== req.fromMember.id
    )
    notificationStore.fetchFriendRequestCount()
    toastSuccess(`${req.fromMember.name}님의 친구 요청을 거절했습니다.`)
  } catch (e) {
    console.error('Failed to reject friend request:', e)
    showWarning('친구 요청 거절에 실패했습니다.')
  }
}

async function cancelRequest(req: { toMember: { id: number | null; name: string } }) {
  if (!friendInfo.value || !req.toMember.id) return
  if (!await confirm(`${req.toMember.name}님에게 보낸 요청을 취소하시겠습니까?`, '요청 취소')) return
  try {
    await friendApi.cancelFriendRequest(req.toMember.id)
    await loadFriendInfo()
    toastSuccess('친구 요청이 취소되었습니다.')
  } catch (e) {
    console.error('Failed to cancel friend request:', e)
    showWarning('친구 요청 취소에 실패했습니다.')
  }
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
    } catch (e) {
      console.error('Failed to pin friend:', e)
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
    } catch (e) {
      console.error('Failed to unpin friend:', e)
      friend.pinOrder = oldPinOrder
      sortFriendsByPinOrder()
      showWarning('친구 고정 해제에 실패했습니다.')
    }
  }
}

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
    await loadFriendInfo()
    toastSuccess(`${member.name}님에게 가족 요청을 보냈습니다.`)
  } catch (e) {
    console.error('Failed to send family request:', e)
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
    } catch (e) {
      console.error('Failed to unfriend:', e)
      showWarning('친구 삭제에 실패했습니다.')
    }
  } else {
    closeDropdown()
  }
}

// Dropdown management
function toggleDropdown(memberId: number, event: Event) {
  event.stopPropagation()
  if (openDropdownId.value === memberId) {
    openDropdownId.value = null
  } else {
    openDropdownId.value = memberId
    const button = event.currentTarget as HTMLElement
    const rect = button.getBoundingClientRect()
    dropdownPosition.value = {
      top: rect.bottom + window.scrollY + 4,
      left: rect.right + window.scrollX - 128 // 128px = dropdown width (w-32)
    }
  }
}

function closeDropdown() {
  openDropdownId.value = null
}

// Navigate to friend's duty
function moveTo(memberId?: number | null) {
  if (isDragging) return
  if (!memberId) return
  router.push(`/duty/${memberId}`)
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
  } catch (e) {
    console.error('Failed to search friends:', e)
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
    closeSearchModal()
    await loadFriendInfo()
    toastSuccess(`${member.name}님에게 친구 요청을 보냈습니다.`)
  } catch (e) {
    console.error('Failed to send friend request:', e)
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

// Sortable
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
      setTimeout(() => {
        isDragging = false
      }, 100)
    },
  })
}

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
  } catch (e) {
    console.error('Failed to update friend pin order:', e)
    showWarning('친구 순서 변경에 실패했습니다.')
  }
}

function applyFriendOrder(friendIds: number[]) {
  if (!friendInfo.value || friendIds.length === 0) return

  const friendMap = new Map(friendInfo.value.friends.map((f) => [f.member.id, f]))
  const pinnedSet = new Set(friendIds)
  const pinnedFriends = friendIds.map((id) => friendMap.get(id)).filter(Boolean)
  const unpinnedFriends = friendInfo.value.friends.filter((f) => f.member.id !== null && !pinnedSet.has(f.member.id))

  friendInfo.value.friends = [...pinnedFriends, ...unpinnedFriends] as typeof friendInfo.value.friends
}

function destroyFriendSortable() {
  if (friendSortable) {
    friendSortable.destroy()
    friendSortable = null
  }
}

onMounted(async () => {
  document.addEventListener('click', closeDropdown)
  await loadFriendInfo()
  nextTick(() => {
    initFriendSortable()
  })
})

onUnmounted(() => {
  document.removeEventListener('click', closeDropdown)
  destroyFriendSortable()
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 bg-gradient-to-br from-slate-700 to-slate-800 rounded-xl flex items-center justify-center">
          <Users class="w-5 h-5 text-white" />
        </div>
        <h1 class="text-xl font-bold" :style="{ color: 'var(--dp-text-primary)' }">친구 관리</h1>
      </div>
      <button
        class="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-slate-700 to-slate-800 text-white rounded-xl hover:from-slate-800 hover:to-slate-900 transition-all shadow-lg font-medium cursor-pointer"
        @click="openSearchModal"
      >
        <UserPlus class="w-4 h-4" />
        친구 추가
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex justify-center py-16">
      <div class="w-8 h-8 border-3 rounded-full animate-spin" :style="{ borderColor: 'var(--dp-border-secondary)', borderTopColor: 'var(--dp-text-primary)' }"></div>
    </div>

    <!-- Error -->
    <div v-else-if="error" class="text-center py-16 text-red-500">
      {{ error }}
    </div>

    <template v-else-if="friendInfo">
      <!-- Friend Request Section -->
      <div
        v-if="hasPendingRequests"
        class="rounded-2xl shadow-sm border mb-6 overflow-hidden"
        :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' }"
      >
        <div class="bg-gradient-to-r from-amber-500 to-orange-500 px-5 py-3">
          <div class="flex items-center gap-2">
            <UserCheck class="w-5 h-5 text-white" />
            <span class="text-white font-bold">친구 요청</span>
            <span class="ml-2 px-2 py-0.5 bg-white/20 rounded-full text-xs text-white">
              {{ friendInfo.pendingRequestsTo.length + friendInfo.pendingRequestsFrom.length }}
            </span>
          </div>
        </div>
        <div class="p-4 space-y-3">
          <!-- Received Requests -->
          <div
            v-for="req in friendInfo.pendingRequestsTo"
            :key="'to-' + req.fromMember.id"
            class="p-4 rounded-xl friend-request-received"
          >
            <div class="flex justify-between items-center">
              <div class="font-medium flex items-center gap-3 friend-request-name">
                <div class="relative">
                  <ProfileAvatar
                    :member-id="req.fromMember.id"
                    :has-profile-photo="req.fromMember.hasProfilePhoto"
                    :profile-photo-version="req.fromMember.profilePhotoVersion"
                    size="md"
                  />
                  <div class="absolute -bottom-0.5 -right-0.5 w-5 h-5 rounded-full flex items-center justify-center ring-2 ring-white" :class="req.requestType === 'FAMILY_REQUEST' ? 'bg-amber-500' : 'bg-blue-500'">
                    <Home v-if="req.requestType === 'FAMILY_REQUEST'" class="w-3 h-3 text-white" />
                    <UserPlus v-else class="w-3 h-3 text-white" />
                  </div>
                </div>
                <div>
                  <p :style="{ color: 'var(--dp-text-primary)' }">{{ req.fromMember.name }}</p>
                  <p class="text-xs" :style="{ color: 'var(--dp-text-secondary)' }">
                    {{ req.requestType === 'FAMILY_REQUEST' ? '가족 요청' : '친구 요청' }}
                  </p>
                </div>
              </div>
              <div class="flex gap-2">
                <button
                  class="px-4 py-2 text-sm font-medium bg-green-500 text-white rounded-lg hover:bg-green-600 transition shadow-sm cursor-pointer"
                  @click="acceptFriendRequest(req)"
                >
                  승인
                </button>
                <button
                  class="px-4 py-2 text-sm font-medium border border-red-200 rounded-lg hover:bg-red-50 transition cursor-pointer"
                  :style="{ backgroundColor: 'var(--dp-bg-card)', color: '#dc3545' }"
                  @click="rejectFriendRequest(req)"
                >
                  거절
                </button>
              </div>
            </div>
          </div>

          <!-- Sent Requests -->
          <div
            v-for="req in friendInfo.pendingRequestsFrom"
            :key="'from-' + req.toMember.id"
            class="p-4 rounded-xl friend-request-sent"
          >
            <div class="flex justify-between items-center">
              <div class="font-medium flex items-center gap-3 friend-request-name">
                <div class="relative">
                  <ProfileAvatar
                    :member-id="req.toMember.id"
                    :has-profile-photo="req.toMember.hasProfilePhoto"
                    :profile-photo-version="req.toMember.profilePhotoVersion"
                    size="md"
                  />
                  <div class="absolute -bottom-0.5 -right-0.5 w-5 h-5 rounded-full flex items-center justify-center bg-amber-500 ring-2 ring-white">
                    <Home v-if="req.requestType === 'FAMILY_REQUEST'" class="w-3 h-3 text-white" />
                    <UserPlus v-else class="w-3 h-3 text-white" />
                  </div>
                </div>
                <div>
                  <p :style="{ color: 'var(--dp-text-primary)' }">{{ req.toMember.name }}</p>
                  <p class="text-xs" :style="{ color: 'var(--dp-text-secondary)' }">
                    {{ req.requestType === 'FAMILY_REQUEST' ? '가족 요청' : '친구 요청' }} · 대기 중
                  </p>
                </div>
              </div>
              <button
                class="px-4 py-2 text-sm font-medium border border-amber-300 rounded-lg hover:bg-amber-50 transition cursor-pointer"
                :style="{ backgroundColor: 'var(--dp-bg-card)', color: '#b45309' }"
                @click="cancelRequest(req)"
              >
                요청 취소
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Friends List Section -->
      <div
        ref="friendSectionRef"
        class="friend-section rounded-2xl shadow-sm border"
        :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' }"
      >
        <div class="bg-gradient-to-r from-slate-700 to-slate-800 px-6 py-3">
          <div class="flex items-center gap-2">
            <Users class="w-5 h-5 text-white" />
            <span class="text-white font-bold">친구 목록</span>
            <span v-if="friendInfo.friends.length" class="ml-2 px-2 py-0.5 bg-white/20 rounded-full text-xs text-white">
              {{ friendInfo.friends.length }}
            </span>
          </div>
        </div>
        <div class="p-5">
          <div v-if="sortedFriends.length === 0" class="text-center py-8">
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
              class="friend-card relative rounded-xl sm:rounded-2xl cursor-pointer transition-all duration-300 hover:shadow-lg hover:scale-[1.02]"
              :class="[
                friend.pinOrder
                  ? 'pinned-friend pinned-friend-highlight border-2 shadow-md'
                  : 'border hover:border-blue-300'
              ]"
              :style="!friend.pinOrder ? { backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' } : {}"
              @click="moveTo(friend.member.id)"
            >
              <div class="flex p-3">
                <!-- Left section: Profile -->
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
                      <!-- Dropdown toggle -->
                      <button
                        v-if="friend.member.id"
                        class="p-1.5 rounded-lg transition hover:bg-opacity-80 cursor-pointer"
                        :style="{ color: 'var(--dp-text-muted)' }"
                        @click="toggleDropdown(friend.member.id, $event)"
                      >
                        <MoreVertical class="w-5 h-5" />
                      </button>
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

            <!-- Add Friend Card -->
            <div
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

    <!-- Friend Dropdown Menu (Teleported to body) -->
    <Teleport to="body">
      <div
        v-if="openDropdownId && openDropdownFriend"
        class="fixed w-32 border rounded-xl shadow-xl z-[9999] overflow-hidden"
        :style="{
          top: dropdownPosition.top + 'px',
          left: dropdownPosition.left + 'px',
          backgroundColor: 'var(--dp-bg-card)',
          borderColor: 'var(--dp-border-primary)'
        }"
        @click.stop
      >
        <button
          v-if="!openDropdownFriend.isFamily"
          class="w-full px-3 py-2.5 text-left text-sm text-blue-600 hover:bg-blue-50 flex items-center gap-2 transition cursor-pointer"
          @click="addFamily(openDropdownFriend.member)"
        >
          <Home class="w-4 h-4" />
          가족 등록
        </button>
        <button
          class="w-full px-3 py-2.5 text-left text-sm text-red-600 hover:bg-red-50 flex items-center gap-2 transition cursor-pointer"
          @click="unfriend(openDropdownFriend.member)"
        >
          <Trash2 class="w-4 h-4" />
          친구 삭제
        </button>
      </div>
    </Teleport>

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
              <div class="flex-grow relative min-w-0">
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
                class="flex-shrink-0 px-4 sm:px-5 py-3 bg-gradient-to-r from-slate-700 to-slate-800 text-white rounded-xl hover:from-slate-800 hover:to-slate-900 transition-all shadow-lg flex items-center gap-2 font-medium cursor-pointer whitespace-nowrap"
                @click="search"
              >
                <Search class="w-4 h-4" />
                <span class="hidden sm:inline">검색</span>
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
