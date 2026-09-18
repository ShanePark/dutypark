<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { dashboardApi } from '@/api/dashboard'
import { friendApi } from '@/api/member'
import { blockApi } from '@/api/block'
import { useSwal } from '@/composables/useSwal'
import { useDragClickGuard } from '@/composables/useDragClickGuard'
import { useNotificationStore } from '@/stores/notification'
import Sortable from 'sortablejs'
import type { DashboardFriendInfo, DashboardFriendRequestDto, MemberPreviewDto } from '@/types'
import type { BlockedMember } from '@/types/block'
import FriendSearchModal from '@/components/common/FriendSearchModal.vue'
import PageHeader from '@/components/common/PageHeader.vue'
import FriendRequestList from '@/components/member/FriendRequestList.vue'
import FriendCard from '@/components/member/FriendCard.vue'
import FriendActionMenu from '@/components/member/FriendActionMenu.vue'
import BlockedMemberList from '@/components/member/BlockedMemberList.vue'
import HelpButton from '@/components/common/HelpButton.vue'
import HelpModal from '@/components/common/HelpModal.vue'
import HelpNote from '@/components/common/HelpNote.vue'
import HelpSection from '@/components/common/HelpSection.vue'
import { Users, UserPlus, CheckCircle2 } from '@lucide/vue'

const router = useRouter()
const notificationStore = useNotificationStore()
const { t } = useI18n()
const { showWarning, confirm, confirmDelete, toastSuccess } = useSwal()
const dragClickGuard = useDragClickGuard()

watch(() => notificationStore.friendsRefreshTrigger, (newValue) => {
  if (newValue > 0) {
    loadFriendInfo()
  }
})

const isHelpModalOpen = ref(false)

const loading = ref(false)
const error = ref<string | null>(null)
const friendInfo = ref<DashboardFriendInfo | null>(null)

const blockedMembers = ref<BlockedMember[]>([])
const blockedLoading = ref(false)
const blockedLoadFailed = ref(false)
const unblockingId = ref<number | null>(null)

const openDropdownId = ref<number | null>(null)
const dropdownPosition = ref({ top: 0, left: 0 })
const MENU_WIDTH = 240 // 15rem, matches FriendActionMenu on desktop

let friendSortable: Sortable | null = null
const friendListRef = ref<HTMLElement | null>(null)
const friendSectionRef = ref<HTMLElement | null>(null)
const isSavingFriendOrder = ref(false)

const showSearchModal = ref(false)
const searchKeyword = ref('')
const searchResult = ref<MemberPreviewDto[]>([])
const searchPage = ref(0)
const searchTotalPage = ref(0)
const searchTotalElements = ref(0)
const searchPageSize = 5
const searchLoading = ref(false)

const sortedFriends = computed(() => {
  if (!friendInfo.value) return []
  return [...friendInfo.value.friends].sort((a, b) => {
    return (a.displayOrder ?? Number.MAX_SAFE_INTEGER) - (b.displayOrder ?? Number.MAX_SAFE_INTEGER)
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
    error.value = t('friends.messages.loadFailed')
  } finally {
    loading.value = false
  }
}

async function loadBlockedMembers() {
  blockedLoading.value = true
  blockedLoadFailed.value = false
  try {
    blockedMembers.value = await blockApi.getBlockedMembers()
  } catch (e) {
    console.error('Failed to load blocked members:', e)
    // An empty list would read as "nothing is blocked", so the failure is kept separate.
    blockedMembers.value = []
    blockedLoadFailed.value = true
  } finally {
    blockedLoading.value = false
  }
}

async function acceptFriendRequest(req: DashboardFriendRequestDto) {
  if (!friendInfo.value || !req.fromMember.id) return
  try {
    await friendApi.acceptFriendRequest(req.fromMember.id)
    await loadFriendInfo()
    notificationStore.fetchFriendRequestCount()
    toastSuccess(t('friends.messages.acceptSuccess', { name: req.fromMember.name }))
  } catch (e) {
    console.error('Failed to accept friend request:', e)
    showWarning(t('friends.messages.acceptFailed'))
  }
}

async function rejectFriendRequest(req: DashboardFriendRequestDto) {
  if (!friendInfo.value || !req.fromMember.id) return
  if (!await confirm(
    t('friends.messages.rejectConfirm', { name: req.fromMember.name }),
    t('friends.messages.rejectTitle'),
  )) return
  try {
    await friendApi.rejectFriendRequest(req.fromMember.id)
    friendInfo.value.pendingRequestsTo = friendInfo.value.pendingRequestsTo.filter(
      (r) => r.fromMember.id !== req.fromMember.id
    )
    notificationStore.fetchFriendRequestCount()
    toastSuccess(t('friends.messages.rejectSuccess', { name: req.fromMember.name }))
  } catch (e) {
    console.error('Failed to reject friend request:', e)
    showWarning(t('friends.messages.rejectFailed'))
  }
}

async function cancelRequest(req: DashboardFriendRequestDto) {
  if (!friendInfo.value || !req.toMember.id) return
  if (!await confirm(
    t('friends.messages.cancelConfirm', { name: req.toMember.name }),
    t('friends.messages.cancelTitle'),
  )) return
  try {
    await friendApi.cancelFriendRequest(req.toMember.id)
    await loadFriendInfo()
    toastSuccess(t('friends.messages.cancelSuccess'))
  } catch (e) {
    console.error('Failed to cancel friend request:', e)
    showWarning(t('friends.messages.cancelFailed'))
  }
}

async function addFamily(member: { id: number | null; name: string }) {
  if (!friendInfo.value || !member.id) return
  const alreadySent = friendInfo.value.pendingRequestsFrom.some((r) => r.toMember.id === member.id)
  if (alreadySent) {
    showWarning(t('friends.messages.familyAlreadyRequested'))
    return
  }
  if (!await confirm(
    t('friends.messages.familyRequestConfirm', { name: member.name }),
    t('friends.messages.familyRequestTitle'),
  )) return
  try {
    await friendApi.sendFamilyRequest(member.id)
    await loadFriendInfo()
    toastSuccess(t('friends.messages.familyRequestSuccess', { name: member.name }))
  } catch (e) {
    console.error('Failed to send family request:', e)
    showWarning(t('friends.messages.familyRequestFailed'))
  }
}

async function demoteFromFamily(member: { id: number | null; name: string }) {
  if (!friendInfo.value || !member.id) return
  if (!await confirm(
    t('friends.messages.removeFamilyConfirm', { name: member.name }),
    t('friends.messages.removeFamilyTitle'),
  )) return
  try {
    await friendApi.demoteFromFamily(member.id)
    const friend = friendInfo.value.friends.find((f) => f.member.id === member.id)
    if (friend) {
      friend.isFamily = false
    }
    toastSuccess(t('friends.messages.removeFamilySuccess', { name: member.name }))
  } catch (e) {
    console.error('Failed to demote from family:', e)
    showWarning(t('friends.messages.removeFamilyFailed'))
  }
}

async function unfriend(member: { id: number | null; name: string }) {
  if (!friendInfo.value || !member.id) return
  if (!await confirmDelete(t('friends.messages.unfriendConfirm', { name: member.name }))) return
  try {
    await friendApi.unfriend(member.id)
    friendInfo.value.friends = friendInfo.value.friends.filter((f) => f.member.id !== member.id)
    toastSuccess(t('friends.messages.unfriendSuccess', { name: member.name }))
  } catch (e) {
    console.error('Failed to unfriend:', e)
    showWarning(t('friends.messages.unfriendFailed'))
  }
}

async function blockFriend(member: { id: number | null; name: string }) {
  if (!friendInfo.value || !member.id) return
  if (!await confirmDelete(
    t('friends.block.confirmMessage', { name: member.name }),
    t('friends.block.confirmTitle'),
    t('friends.block.confirmAction'),
  )) return
  try {
    await blockApi.block(member.id)
    await Promise.all([loadFriendInfo(), loadBlockedMembers()])
    toastSuccess(t('friends.block.blockSuccess', { name: member.name }))
  } catch (e) {
    console.error('Failed to block member:', e)
    showWarning(t('friends.block.blockFailed'))
  }
}

async function unblockMember(member: BlockedMember) {
  if (unblockingId.value !== null) return
  if (!await confirm(
    t('friends.block.unblockConfirmMessage', { name: member.name }),
    t('friends.block.unblockConfirmTitle'),
    t('friends.block.unblockAction'),
  )) return
  unblockingId.value = member.id
  try {
    await blockApi.unblock(member.id)
    blockedMembers.value = blockedMembers.value.filter((m) => m.id !== member.id)
    toastSuccess(t('friends.block.unblockSuccess', { name: member.name }))
  } catch (e) {
    console.error('Failed to unblock member:', e)
    showWarning(t('friends.block.unblockFailed'))
  } finally {
    unblockingId.value = null
  }
}

// The menu keeps a full-screen click catcher above the confirmation dialog's layer, so it has to
// close the moment an item is picked; left open, the catcher swallows the dialog's buttons.
function addFamilyFromMenu() {
  const friend = openDropdownFriend.value
  if (!friend) return
  closeDropdown()
  addFamily(friend.member)
}

function demoteFromFamilyFromMenu() {
  const friend = openDropdownFriend.value
  if (!friend) return
  closeDropdown()
  demoteFromFamily(friend.member)
}

function unfriendFromMenu() {
  const friend = openDropdownFriend.value
  if (!friend) return
  closeDropdown()
  unfriend(friend.member)
}

function blockFromMenu() {
  const friend = openDropdownFriend.value
  if (!friend) return
  closeDropdown()
  blockFriend(friend.member)
}

function toggleDropdown(memberId: number, event: Event) {
  event.stopPropagation()
  if (openDropdownId.value === memberId) {
    openDropdownId.value = null
    return
  }
  openDropdownId.value = memberId
  const button = event.currentTarget as HTMLElement
  const rect = button.getBoundingClientRect()
  const cardTop = (button.closest('.friend-card')?.getBoundingClientRect().top ?? rect.top)
  // The popover is position: absolute in the document, so it scrolls along with the friend list.
  // Align it with the top of the friend's own card so it covers that card instead of the one below.
  dropdownPosition.value = {
    top: cardTop + window.scrollY,
    left: Math.max(8, rect.right - MENU_WIDTH) + window.scrollX
  }
}

function closeDropdown() {
  openDropdownId.value = null
}

function moveTo(memberId?: number | null) {
  if (!memberId) return
  router.push(`/duty/${memberId}`)
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

async function requestFriend(member: MemberPreviewDto) {
  if (!member.id) return
  if (!await confirm(
    t('friends.messages.friendRequestConfirm', { name: member.name }),
    t('friends.messages.friendRequestTitle'),
  )) return
  try {
    await friendApi.sendFriendRequest(member.id)
    closeSearchModal()
    await loadFriendInfo()
    toastSuccess(t('friends.messages.friendRequestSuccess', { name: member.name }))
  } catch (e) {
    console.error('Failed to send friend request:', e)
    showWarning(t('friends.messages.friendRequestFailed'))
  }
}

function goToPage(page: number) {
  searchPage.value = page
  search()
}

function initFriendSortable() {
  if (!friendListRef.value) {
    destroyFriendSortable()
    return
  }

  destroyFriendSortable()

  friendSortable = new Sortable(friendListRef.value, {
    animation: 150,
    draggable: '.friend-card',
    delay: 150,
    delayOnTouchOnly: true,
    touchStartThreshold: 4,
    ghostClass: 'sortable-ghost',
    fallbackClass: 'sortable-fallback',
    fallbackOnBody: true,
    forceFallback: true,
    chosenClass: 'sortable-chosen',
    disabled: isSavingFriendOrder.value,
    onStart: () => {
      if (isSavingFriendOrder.value) return
      dragClickGuard.startDrag()
      friendSectionRef.value?.classList.add('friend-section-sorting')
    },
    onEnd: () => {
      dragClickGuard.endDrag()
      friendSectionRef.value?.classList.remove('friend-section-sorting')
      void updateFriendsOrder()
    },
  })
}

async function updateFriendsOrder() {
  if (!friendListRef.value || !friendInfo.value) return
  if (isSavingFriendOrder.value) return

  const friendIds = Array.from(friendListRef.value.querySelectorAll('.friend-card'))
    .map((el) => Number(el.getAttribute('data-member-id')))
    .filter((id) => !isNaN(id) && id > 0)

  if (friendIds.length === 0) return

  const currentFriendIds = friendInfo.value.friends
    .map((friend) => friend.member.id)
    .filter((id): id is number => id !== null && id > 0)
  if (friendIds.length !== currentFriendIds.length || new Set(friendIds).size !== currentFriendIds.length) return
  if (friendIds.every((id, index) => id === currentFriendIds[index])) return

  const previousFriends = friendInfo.value.friends
  applyFriendOrder(friendIds)
  isSavingFriendOrder.value = true
  friendSortable?.option('disabled', true)

  nextTick(() => {
    initFriendSortable()
  })

  try {
    await friendApi.updateFriendsOrder(friendIds)
  } catch (e) {
    console.error('Failed to update friend order:', e)
    friendInfo.value.friends = previousFriends
    showWarning(t('friends.messages.reorderFailed'))
  } finally {
    isSavingFriendOrder.value = false
    nextTick(() => {
      initFriendSortable()
    })
  }
}

function applyFriendOrder(friendIds: number[]) {
  if (!friendInfo.value || friendIds.length === 0) return

  const friendMap = new Map(friendInfo.value.friends.map((f) => [f.member.id, f]))
  const orderedFriends = friendIds
    .map((id) => friendMap.get(id))
    .filter((friend): friend is NonNullable<typeof friend> => friend != null)
  const orderedSet = new Set(friendIds)
  const remainingFriends = friendInfo.value.friends.filter(
    (friend) => friend.member.id === null || !orderedSet.has(friend.member.id),
  )

  friendInfo.value.friends = [...orderedFriends, ...remainingFriends].map((friend, index) => ({
    ...friend,
    displayOrder: index + 1,
  }))
}

function destroyFriendSortable() {
  if (friendSortable) {
    friendSortable.destroy()
    friendSortable = null
  }
  if (dragClickGuard.isDragging.value) {
    dragClickGuard.cancelDrag()
  }
}

onMounted(async () => {
  document.addEventListener('click', closeDropdown)
  loadBlockedMembers()
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
    <PageHeader class="friends-page-header" :title="t('header.menu.friends')" show-back back-fallback="/more">
      <HelpButton
        :label="t('friends.help.openAriaLabel')"
        @click="isHelpModalOpen = true"
      />
      <button
        type="button"
        class="inline-flex h-11 w-11 shrink-0 items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-dp-surface-strong to-dp-surface-strong-alt text-dp-text-on-dark shadow-lg transition-all hover:from-dp-surface-strong-alt hover:to-dp-surface-strong-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring sm:w-auto sm:px-4 font-medium cursor-pointer"
        :aria-label="t('friends.actions.addFriend')"
        @click="openSearchModal"
      >
        <UserPlus class="w-4 h-4" />
        <span class="hidden sm:inline">{{ t('friends.actions.addFriend') }}</span>
      </button>
    </PageHeader>

    <div v-if="loading" class="flex justify-center py-16">
      <div class="w-8 h-8 border-3 rounded-full animate-spin" :style="{ borderColor: 'var(--dp-border-secondary)', borderTopColor: 'var(--dp-text-primary)' }"></div>
    </div>

    <div v-else-if="error" class="text-center py-16 text-dp-danger">
      {{ error }}
    </div>

    <template v-else-if="friendInfo">
      <FriendRequestList
        :requests-to="friendInfo.pendingRequestsTo"
        :requests-from="friendInfo.pendingRequestsFrom"
        @accept="acceptFriendRequest"
        @reject="rejectFriendRequest"
        @cancel="cancelRequest"
      />

      <div
        ref="friendSectionRef"
        class="friend-section"
      >
        <div class="mb-3 flex items-center gap-2 px-1">
          <Users class="h-5 w-5 text-dp-text-secondary" />
          <span class="font-semibold text-dp-text-primary">{{ t('friends.sections.list') }}</span>
          <span
            v-if="friendInfo.friends.length"
            class="rounded-full bg-dp-bg-tertiary px-2 py-0.5 text-xs font-medium text-dp-text-secondary"
          >
            {{ friendInfo.friends.length }}
          </span>
        </div>

        <div v-if="sortedFriends.length === 0" class="text-center py-8">
          <Users class="w-12 h-12 mx-auto mb-3 text-dp-text-muted" />
          <p class="text-sm text-dp-text-secondary">{{ t('friends.labels.noFriends') }}</p>
          <button
            class="mt-4 px-4 py-2 text-sm font-medium bg-dp-accent text-dp-text-on-dark rounded-lg hover:bg-dp-accent-hover transition cursor-pointer"
            @click="openSearchModal"
          >
            {{ t('friends.actions.addFriend') }}
          </button>
        </div>

        <div
          v-else
          ref="friendListRef"
          class="friend-list-surface overflow-hidden rounded-2xl border border-dp-border-primary bg-dp-bg-card"
          @pointerdown.capture="dragClickGuard.handlePointerDown"
          @click.capture="dragClickGuard.handleClick"
        >
          <FriendCard
            v-for="friend in sortedFriends"
            :key="friend.member.id ?? 'unknown'"
            :friend="friend"
            @select="moveTo(friend.member.id)"
            @open-menu="toggleDropdown"
          />

          <button
            type="button"
            class="friend-card-add flex min-h-[72px] w-full items-center gap-3 px-4 text-left text-dp-text-secondary transition hover:bg-dp-bg-tertiary hover:text-dp-text-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-dp-accent-ring cursor-pointer"
            :aria-label="t('friends.actions.addFriend')"
            @click="openSearchModal"
          >
            <span class="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-dp-bg-tertiary">
              <UserPlus class="h-4 w-4" aria-hidden="true" />
            </span>
            <span class="font-medium text-sm">{{ t('friends.actions.addFriend') }}</span>
          </button>
        </div>
      </div>
    </template>

    <BlockedMemberList
      v-if="!loading"
      class="mt-6"
      :members="blockedMembers"
      :loading="blockedLoading"
      :load-failed="blockedLoadFailed"
      :unblocking-id="unblockingId"
      @unblock="unblockMember"
      @retry="loadBlockedMembers"
    />

    <FriendActionMenu
      :friend="openDropdownFriend"
      :position="dropdownPosition"
      @close="closeDropdown"
      @add-family="addFamilyFromMenu"
      @remove-family="demoteFromFamilyFromMenu"
      @unfriend="unfriendFromMenu"
      @block="blockFromMenu"
    />

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

    <HelpModal
      :is-open="isHelpModalOpen"
      :title="t('friends.help.title')"
      @close="isHelpModalOpen = false"
    >
      <HelpSection
        :step="1"
        :icon="Users"
        :title="t('friends.help.reorderTitle')"
        :text="t('friends.help.reorderText')"
      />
      <HelpSection
        :step="2"
        :icon="CheckCircle2"
        :title="t('friends.help.saveTitle')"
        :text="t('friends.help.saveText')"
      />

      <HelpNote :messages="[t('friends.help.note')]" />
    </HelpModal>
  </div>
</template>

<style scoped>
.friends-page-header {
  flex-wrap: nowrap !important;
}
</style>
