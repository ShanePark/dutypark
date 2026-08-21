<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { dashboardApi } from '@/api/dashboard'
import { friendApi } from '@/api/member'
import { useSwal } from '@/composables/useSwal'
import { isLightColor } from '@/utils/color'
import type {
  DashboardMyDetail,
  DashboardFriendDetail,
  DashboardFriendInfo,
  MemberPreviewDto,
} from '@/types'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import FriendSearchModal from '@/components/common/FriendSearchModal.vue'
import IntroSection from '@/components/intro/IntroSection.vue'
import {
  Calendar,
  Briefcase,
  ClipboardList,
  Users,
  Star,
  Home,
  ChevronLeft,
  ChevronRight,
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const { t, locale } = useI18n()
const { showWarning, confirm, toastSuccess } = useSwal()

const myInfoLoading = ref(false)
const friendInfoLoading = ref(false)
const friendInfoInitialized = ref(false)

const myInfoError = ref<string | null>(null)
const friendInfoError = ref<string | null>(null)

const today = computed(() => {
  return new Date().toLocaleDateString(locale.value, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    weekday: 'long',
  })
})

const myInfo = ref<DashboardMyDetail | null>(null)
const friendInfo = ref<DashboardFriendInfo | null>(null)

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

const showSearchModal = ref(false)
const searchKeyword = ref('')
const searchResult = ref<MemberPreviewDto[]>([])
const searchPage = ref(0)
const searchTotalPage = ref(0)
const searchTotalElements = ref(0)
const searchPageSize = 5
const searchLoading = ref(false)

const friendRailRef = ref<HTMLElement | null>(null)
const canScrollPrev = ref(false)
const canScrollNext = ref(false)
// Leave a little room for normal mouse jitter so a click is not mistaken for a drag.
const FRIEND_RAIL_DRAG_THRESHOLD = 8
const FRIEND_RAIL_MOMENTUM_MIN_VELOCITY = 0.02
const FRIEND_RAIL_MOMENTUM_FRICTION = 0.92
const friendRailDrag = {
  captureTarget: null as Element | null,
  pointerId: null as number | null,
  startX: 0,
  startScrollLeft: 0,
  lastX: 0,
  lastTime: 0,
  velocity: 0,
  hasMoved: false,
  suppressClick: false,
  momentumFrame: null as number | null,
}

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

function moveTo(memberId?: number | null) {
  const id = memberId || myInfo.value?.member.id
  if (!id) return
  router.push(`/duty/${id}`)
}

/** The duty slot always renders, so a friend without a duty gets a dash instead of an empty line. */
function dutyLabel(friend: DashboardFriendDetail) {
  if (!friend.duty) return '-'
  return friend.duty.dutyType || t('dashboard.labels.offDuty')
}

function updateRailHints() {
  const rail = friendRailRef.value
  if (!rail) {
    canScrollPrev.value = false
    canScrollNext.value = false
    return
  }

  const maxScroll = rail.scrollWidth - rail.clientWidth
  canScrollPrev.value = rail.scrollLeft > 4
  canScrollNext.value = maxScroll - rail.scrollLeft > 4
}

function stopFriendRailMomentum() {
  if (friendRailDrag.momentumFrame !== null) {
    cancelAnimationFrame(friendRailDrag.momentumFrame)
    friendRailDrag.momentumFrame = null
  }
  friendRailDrag.velocity = 0
}

function startFriendRailMomentum(rail: HTMLElement) {
  let velocity = friendRailDrag.velocity
  if (Math.abs(velocity) < FRIEND_RAIL_MOMENTUM_MIN_VELOCITY) return

  let previousTime = performance.now()
  const animate = (time: number) => {
    const elapsed = Math.min(time - previousTime, 32)
    previousTime = time
    rail.scrollLeft += velocity * elapsed

    const maxScroll = rail.scrollWidth - rail.clientWidth
    const isAtEdge = rail.scrollLeft <= 0 || rail.scrollLeft >= maxScroll
    velocity *= Math.pow(FRIEND_RAIL_MOMENTUM_FRICTION, elapsed / 16)

    if (isAtEdge || Math.abs(velocity) < FRIEND_RAIL_MOMENTUM_MIN_VELOCITY) {
      friendRailDrag.momentumFrame = null
      friendRailDrag.velocity = 0
      return
    }

    friendRailDrag.momentumFrame = requestAnimationFrame(animate)
  }

  friendRailDrag.momentumFrame = requestAnimationFrame(animate)
}

function scrollRail(direction: -1 | 1) {
  const rail = friendRailRef.value
  if (!rail) {
    return
  }

  stopFriendRailMomentum()
  rail.scrollBy({
    left: direction * Math.max(rail.clientWidth * 0.8, 160),
    behavior: 'smooth',
  })
}

function releaseFriendRailPointerCapture() {
  const captureTarget = friendRailDrag.captureTarget
  const pointerId = friendRailDrag.pointerId
  if (captureTarget && pointerId !== null && captureTarget.hasPointerCapture(pointerId)) {
    captureTarget.releasePointerCapture(pointerId)
  }
  friendRailDrag.captureTarget = null
  friendRailDrag.pointerId = null
}

function handleFriendRailPointerDown(event: PointerEvent) {
  friendRailDrag.suppressClick = false
  stopFriendRailMomentum()
  const rail = friendRailRef.value
  if (!rail || event.pointerType !== 'mouse' || event.button !== 0) return

  releaseFriendRailPointerCapture()
  const captureTarget = event.target instanceof Element ? event.target : rail
  const pointerTime = event.timeStamp > 0 ? event.timeStamp : performance.now()
  friendRailDrag.captureTarget = captureTarget
  friendRailDrag.pointerId = event.pointerId
  friendRailDrag.startX = event.clientX
  friendRailDrag.startScrollLeft = rail.scrollLeft
  friendRailDrag.lastX = event.clientX
  friendRailDrag.lastTime = pointerTime
  friendRailDrag.velocity = 0
  friendRailDrag.hasMoved = false
  friendRailDrag.suppressClick = false
  captureTarget.setPointerCapture(event.pointerId)
}

function handleFriendRailPointerMove(event: PointerEvent) {
  if (event.pointerId !== friendRailDrag.pointerId) return
  const rail = friendRailRef.value
  if (!rail) return

  const pointerTime = event.timeStamp > 0 ? event.timeStamp : performance.now()
  const deltaX = event.clientX - friendRailDrag.startX
  if (!friendRailDrag.hasMoved && Math.abs(deltaX) < FRIEND_RAIL_DRAG_THRESHOLD) {
    friendRailDrag.lastX = event.clientX
    friendRailDrag.lastTime = pointerTime
    return
  }

  const elapsed = pointerTime - friendRailDrag.lastTime
  if (elapsed > 0) {
    const pointerDelta = event.clientX - friendRailDrag.lastX
    const instantaneousVelocity = -pointerDelta / elapsed
    friendRailDrag.velocity = friendRailDrag.velocity * 0.65 + instantaneousVelocity * 0.35
  }
  friendRailDrag.lastX = event.clientX
  friendRailDrag.lastTime = pointerTime

  friendRailDrag.hasMoved = true
  friendRailDrag.suppressClick = true
  rail.scrollLeft = friendRailDrag.startScrollLeft - deltaX
  event.preventDefault()
}

function handleFriendRailPointerUp(event: PointerEvent) {
  if (event.pointerId !== friendRailDrag.pointerId) return
  const rail = friendRailRef.value
  const wasDragging = friendRailDrag.hasMoved
  releaseFriendRailPointerCapture()
  if (wasDragging && rail) {
    startFriendRailMomentum(rail)
  } else {
    friendRailDrag.velocity = 0
  }
  friendRailDrag.hasMoved = false
}

function handleFriendRailPointerCancel(event: PointerEvent) {
  if (event.pointerId !== friendRailDrag.pointerId) return
  releaseFriendRailPointerCapture()
  friendRailDrag.velocity = 0
  friendRailDrag.hasMoved = false
}

function handleFriendRailClick(event: MouseEvent) {
  if (!friendRailDrag.suppressClick) return
  if (event.detail === 0) {
    friendRailDrag.suppressClick = false
    return
  }

  event.preventDefault()
  event.stopPropagation()
  event.stopImmediatePropagation()
  friendRailDrag.suppressClick = false
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

async function pinFriend(member: { id: number | null; name: string }) {
  if (!friendInfo.value || !member.id) return
  const friend = friendInfo.value.friends.find((f) => f.member.id === member.id)
  if (friend) {
    const maxOrder = Math.max(0, ...friendInfo.value.friends.map((f) => f.pinOrder || 0))
    friend.pinOrder = maxOrder + 1
    sortFriendsByPinOrder()
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

onMounted(async () => {
  window.addEventListener('resize', updateRailHints)
  if (authStore.isLoggedIn) {
    // Load both APIs in parallel
    await Promise.all([loadMyDashboard(), loadFriendsDashboard()])
  }
})

onUnmounted(() => {
  window.removeEventListener('resize', updateRailHints)
  stopFriendRailMomentum()
  releaseFriendRailPointerCapture()
  friendRailDrag.hasMoved = false
  friendRailDrag.suppressClick = false
})

watch(sortedFriends, async () => {
  await nextTick()
  updateRailHints()
})

watch(
  () => authStore.isLoggedIn,
  async (isLoggedIn) => {
    if (isLoggedIn) {
      await Promise.all([loadMyDashboard(), loadFriendsDashboard()])
    } else {
      // Clear data on logout
      myInfo.value = null
      friendInfo.value = null
      friendInfoInitialized.value = false
    }
  }
)
</script>

<template>
  <IntroSection v-if="!authStore.isLoggedIn" />

  <div v-else class="max-w-4xl mx-auto px-4 py-6">
      <div
        class="rounded-2xl shadow-sm border mb-6 overflow-hidden"
        :style="{
          backgroundColor: 'var(--dp-bg-card)',
          borderColor: 'var(--dp-border-primary)'
        }"
      >
        <div
          class="dashboard-panel-header group px-5 py-3 flex items-center justify-between cursor-pointer"
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

        <div class="p-5">
          <div v-if="myInfoError" class="text-center py-4 text-dp-danger">
            {{ myInfoError }}
          </div>
          <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-5">
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

      <div class="friend-section rounded-2xl shadow-sm border overflow-hidden bg-dp-bg-card border-dp-border-primary">
        <div
          class="dashboard-panel-header group px-6 py-3 cursor-pointer"
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
        <div class="dashboard-friend-rail-frame">
          <div v-if="friendInfoError" class="text-center py-4 text-dp-danger">
            {{ friendInfoError }}
          </div>
          <template v-else-if="friendInfoLoading">
            <div class="flex justify-center py-10">
              <div class="w-8 h-8 border-3 rounded-full animate-spin" :style="{ borderColor: 'var(--dp-border-secondary)', borderTopColor: 'var(--dp-text-primary)' }"></div>
            </div>
          </template>
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

          <template v-else>
            <div
              ref="friendRailRef"
              class="dashboard-friend-rail"
              @pointerdown.capture="handleFriendRailPointerDown"
              @pointermove="handleFriendRailPointerMove"
              @pointerup="handleFriendRailPointerUp"
              @pointercancel="handleFriendRailPointerCancel"
              @click.capture="handleFriendRailClick"
              @scroll.passive="updateRailHints"
            >
              <div
                v-for="friend in sortedFriends"
                :key="friend.member.id ?? 'unknown'"
                class="dashboard-friend-card"
              >
                <button
                  type="button"
                  class="dashboard-friend-card__main"
                  :aria-label="friend.member.name"
                  @click="moveTo(friend.member.id)"
                >
                  <span class="dashboard-friend-card__photo">
                    <ProfileAvatar
                      :member-id="friend.member.id"
                      :name="friend.member.name"
                      :has-profile-photo="friend.member.hasProfilePhoto"
                      :profile-photo-version="friend.member.profilePhotoVersion"
                      shape="portrait"
                      size="xl"
                    />
                  </span>

                  <span class="dashboard-friend-card__name">
                    <span class="dashboard-friend-card__name-text" :title="friend.member.name">{{ friend.member.name }}</span>
                    <Home
                      v-if="friend.isFamily"
                      class="dashboard-friend-card__family"
                      :title="t('dashboard.labels.familyMember')"
                    />
                  </span>

                  <span class="dashboard-friend-card__team">{{ friend.member.team || '' }}</span>

                  <span
                    class="dashboard-friend-card__duty"
                    :style="friend.duty ? {
                      backgroundColor: friend.duty.dutyColor || 'var(--dp-duty-fallback)',
                      color: isLightColor(friend.duty.dutyColor) ? 'var(--dp-text-on-light)' : 'var(--dp-text-on-dark)'
                    } : undefined"
                    :title="friend.duty ? dutyLabel(friend) : undefined"
                  >{{ dutyLabel(friend) }}</span>
                </button>

                <button
                  v-if="friend.pinOrder"
                  type="button"
                  class="dashboard-friend-card__pin dashboard-friend-card__pin--on"
                  :title="t('dashboard.actions.unpin')"
                  :aria-label="t('dashboard.actions.unpin')"
                  @click.stop="unpinFriend(friend.member)"
                >
                  <Star class="h-3 w-3" fill="currentColor" />
                </button>
                <button
                  v-else
                  type="button"
                  class="dashboard-friend-card__pin"
                  :title="t('dashboard.actions.pin')"
                  :aria-label="t('dashboard.actions.pin')"
                  @click.stop="pinFriend(friend.member)"
                >
                  <Star class="h-3 w-3" />
                </button>
              </div>
            </div>

            <button
              v-if="canScrollPrev"
              type="button"
              class="dashboard-friend-rail-nav dashboard-friend-rail-nav--prev"
              :aria-label="t('dashboard.actions.scrollPrevAria')"
              @click="scrollRail(-1)"
            >
              <ChevronLeft class="h-4 w-4" />
            </button>
            <button
              v-if="canScrollNext"
              type="button"
              class="dashboard-friend-rail-nav dashboard-friend-rail-nav--next"
              :aria-label="t('dashboard.actions.scrollNextAria')"
              @click="scrollRail(1)"
            >
              <ChevronRight class="h-4 w-4" />
            </button>
          </template>
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

<style scoped>
.dashboard-friend-rail-frame {
  position: relative;
  overflow: hidden;
}

.dashboard-friend-rail {
  --friend-card-gap: 0.375rem;
  --friend-card-min: 3.75rem;
  --friend-card-max: 5.5rem;
  display: flex;
  align-items: flex-start;
  gap: var(--friend-card-gap);
  overflow-x: auto;
  padding: 0.5rem;
  scroll-snap-type: x proximity;
  scrollbar-width: none;
  overscroll-behavior-x: contain;
}

.dashboard-friend-rail::-webkit-scrollbar {
  display: none;
}

/* Three portraits plus a peek of the next one always fit the visible rail, so the
   sideways scroll is discoverable, and cards never grow past a comfortable size. */
.dashboard-friend-card {
  --friend-card-width: clamp(
    var(--friend-card-min),
    calc((100% - var(--friend-card-gap) * 3) / 3.2),
    var(--friend-card-max)
  );
  display: flex;
  flex: 0 0 var(--friend-card-width);
  width: var(--friend-card-width);
  flex-direction: column;
  align-items: stretch;
  position: relative;
  padding: 0.3125rem;
  border: 1px solid var(--dp-border-secondary);
  border-radius: 0.875rem;
  background: linear-gradient(
    180deg,
    var(--dp-bg-card),
    color-mix(in srgb, var(--dp-bg-card) 88%, var(--dp-bg-secondary))
  );
  box-shadow: var(--dp-shadow-sm);
  scroll-snap-align: start;
  transition:
    border-color 0.18s ease,
    box-shadow 0.18s ease,
    transform 0.18s ease;
}

.dashboard-friend-card__main {
  display: flex;
  min-width: 0;
  flex-direction: column;
  align-items: stretch;
  gap: 0.25rem;
  padding: 0;
  border: 0;
  border-radius: 0.625rem;
  background: transparent;
  color: inherit;
  font: inherit;
  cursor: pointer;
}

.dashboard-friend-card__main:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: 2px;
}

.dashboard-friend-card__photo {
  position: relative;
  display: block;
  width: 100%;
  aspect-ratio: 3 / 4;
}

.dashboard-friend-card__pin {
  position: absolute;
  top: 0.125rem;
  right: 0.125rem;
  display: inline-flex;
  width: 1.25rem;
  height: 1.25rem;
  align-items: center;
  justify-content: center;
  border: 2px solid var(--dp-bg-card);
  border-radius: 9999px;
  background: var(--dp-bg-card);
  color: var(--dp-text-muted);
  cursor: pointer;
}

.dashboard-friend-card__pin:hover {
  color: var(--dp-warning);
}

.dashboard-friend-card__pin:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: 2px;
}

.dashboard-friend-card__pin--on {
  color: var(--dp-warning);
}

.dashboard-friend-card__name {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.1875rem;
  min-width: 0;
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 1.2;
  color: var(--dp-text-primary);
}

.dashboard-friend-card__name-text {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dashboard-friend-card__family {
  width: 0.75rem;
  height: 0.75rem;
  flex-shrink: 0;
  color: var(--dp-warning);
}

/* Team and duty keep their slot even when empty, so a team-less or duty-less
   friend never shortens its card next to a neighbour that has both. */
.dashboard-friend-card__team {
  overflow: hidden;
  min-height: 1.2em;
  font-size: 0.625rem;
  line-height: 1.2;
  color: var(--dp-text-muted);
  text-align: center;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dashboard-friend-card__duty {
  overflow: hidden;
  min-height: 1.4rem;
  padding: 0.125rem 0.25rem;
  border-radius: 0.375rem;
  background: var(--dp-bg-tertiary);
  font-size: 0.625rem;
  font-weight: 600;
  line-height: 1.4rem;
  color: var(--dp-text-muted);
  text-align: center;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dashboard-friend-rail-nav {
  position: absolute;
  top: 50%;
  display: none;
  opacity: 0;
  transition: opacity 0.15s ease;
  width: 1.875rem;
  height: 1.875rem;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--dp-border-primary);
  border-radius: 9999px;
  background: color-mix(in srgb, var(--dp-bg-card) 92%, transparent);
  color: var(--dp-text-secondary);
  box-shadow: 0 4px 12px color-mix(in srgb, var(--dp-overlay-dark) 12%, transparent);
  backdrop-filter: blur(4px);
  transform: translateY(-50%);
  cursor: pointer;
}

.dashboard-friend-rail-nav:hover {
  border-color: var(--dp-accent-border);
  color: var(--dp-text-primary);
}

.dashboard-friend-rail-nav:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: 2px;
}

.dashboard-friend-rail-nav--prev {
  left: 0.25rem;
}

.dashboard-friend-rail-nav--next {
  right: 0.25rem;
}

/* Touch users flick the rail, so the arrows only earn their space on pointer devices,
   and they stay out of the portraits until the pointer or keyboard reaches the rail. */
@media (hover: hover) and (pointer: fine) {
  .dashboard-friend-card:hover {
    border-color: color-mix(in srgb, var(--dp-text-muted) 65%, var(--dp-border-secondary));
    box-shadow: var(--dp-shadow-md);
    transform: translateY(-2px);
  }

  .dashboard-friend-rail-nav {
    display: inline-flex;
  }

  .dashboard-friend-rail-frame:hover .dashboard-friend-rail-nav,
  .dashboard-friend-rail-frame:focus-within .dashboard-friend-rail-nav {
    opacity: 1;
  }
}

@media (prefers-reduced-motion: reduce) {
  .dashboard-friend-card,
  .dashboard-friend-rail-nav {
    transition: none;
  }

  .dashboard-friend-card:hover {
    transform: none;
  }
}

@media (min-width: 640px) {
  .dashboard-friend-rail {
    --friend-card-gap: 0.5rem;
  }

  .dashboard-friend-card__name {
    font-size: 0.8125rem;
  }

  .dashboard-friend-card__team {
    font-size: 0.6875rem;
  }

  .dashboard-friend-card__duty {
    font-size: 0.6875rem;
  }
}

@media (min-width: 1024px) {
  .dashboard-friend-rail {
    --friend-card-gap: 0.75rem;
    --friend-card-min: 7.25rem;
    --friend-card-max: 8.5rem;
    padding: 0.75rem;
  }

  .dashboard-friend-card {
    padding: 0.5rem;
    border-radius: 1rem;
  }

  .dashboard-friend-card__main {
    gap: 0.375rem;
  }

  .dashboard-friend-card__pin {
    top: 0.25rem;
    right: 0.25rem;
    width: 1.625rem;
    height: 1.625rem;
  }

  .dashboard-friend-card__pin svg {
    width: 0.9375rem;
    height: 0.9375rem;
  }

  .dashboard-friend-card__name {
    font-size: 0.875rem;
  }

  .dashboard-friend-card__team,
  .dashboard-friend-card__duty {
    font-size: 0.75rem;
  }

  .dashboard-friend-card__duty {
    min-height: 1.75rem;
    line-height: 1.5rem;
  }
}
</style>
