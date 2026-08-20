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
import { Users, UserPlus, Star, GripVertical, CheckCircle2 } from 'lucide-vue-next'

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
const MENU_WIDTH = 176 // w-44, matches FriendActionMenu

let friendSortable: Sortable | null = null
const friendListRef = ref<HTMLElement | null>(null)
const friendSectionRef = ref<HTMLElement | null>(null)

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
      showWarning(t('friends.messages.pinFailed'))
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
      showWarning(t('friends.messages.unpinFailed'))
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
    draggable: '.pinned-friend',
    handle: '.handle',
    ghostClass: 'sortable-ghost',
    fallbackClass: 'sortable-fallback',
    fallbackOnBody: true,
    forceFallback: true,
    chosenClass: 'sortable-chosen',
    onStart: () => {
      dragClickGuard.startDrag()
      friendSectionRef.value?.classList.add('friend-section-sorting')
    },
    onEnd: () => {
      dragClickGuard.endDrag()
      friendSectionRef.value?.classList.remove('friend-section-sorting')
      updateFriendsPin()
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
    showWarning(t('friends.messages.reorderFailed'))
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
  if (dragClickGuard.isDragging.value) {
    dragClickGuard.cancelDrag()
  }
}

function onDocumentKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') closeDropdown()
}

onMounted(async () => {
  document.addEventListener('click', closeDropdown)
  document.addEventListener('keydown', onDocumentKeydown)
  loadBlockedMembers()
  await loadFriendInfo()
  nextTick(() => {
    initFriendSortable()
  })
})

onUnmounted(() => {
  document.removeEventListener('click', closeDropdown)
  document.removeEventListener('keydown', onDocumentKeydown)
  destroyFriendSortable()
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <PageHeader :title="t('header.menu.friends')" :icon="UserPlus" show-back back-fallback="/more">
      <HelpButton
        :label="t('friends.help.openAriaLabel')"
        @click="isHelpModalOpen = true"
      />
      <button
        class="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-dp-surface-strong to-dp-surface-strong-alt text-dp-text-on-dark rounded-xl hover:from-dp-surface-strong-alt hover:to-dp-surface-strong-hover transition-all shadow-lg font-medium cursor-pointer"
        @click="openSearchModal"
      >
        <UserPlus class="w-4 h-4" />
        {{ t('friends.actions.addFriend') }}
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
        class="friend-section rounded-2xl shadow-sm border bg-dp-bg-card border-dp-border-primary"
      >
        <div class="bg-gradient-to-r from-dp-surface-strong to-dp-surface-strong-alt px-6 py-3">
          <div class="flex items-center gap-2">
            <Users class="w-5 h-5 text-dp-text-on-dark" />
            <span class="text-dp-text-on-dark font-bold">{{ t('friends.sections.list') }}</span>
            <span v-if="friendInfo.friends.length" class="ml-2 px-2 py-0.5 bg-dp-overlay-light/20 rounded-full text-xs text-dp-text-on-dark">
              {{ friendInfo.friends.length }}
            </span>
          </div>
        </div>
        <div class="p-5">
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
            class="grid grid-cols-1 sm:grid-cols-2 gap-2 sm:gap-3"
            @pointerdown.capture="dragClickGuard.handlePointerDown"
            @click.capture="dragClickGuard.handleClick"
          >
            <FriendCard
              v-for="friend in sortedFriends"
              :key="friend.member.id ?? 'unknown'"
              :friend="friend"
              @select="moveTo(friend.member.id)"
              @pin="pinFriend(friend.member)"
              @unpin="unpinFriend(friend.member)"
              @open-menu="toggleDropdown"
            />

            <div
              class="group rounded-xl sm:rounded-2xl border-2 border-dashed cursor-pointer hover:border-dp-accent-border hover:bg-dp-accent-soft transition-all duration-300 flex flex-col items-center justify-center min-h-[80px] sm:min-h-[120px] border-dp-border-secondary"
              @click="openSearchModal"
            >
              <div class="w-8 h-8 sm:w-12 sm:h-12 group-hover:bg-dp-accent-soft rounded-full flex items-center justify-center mb-1 sm:mb-2 transition-colors bg-dp-bg-tertiary">
                <UserPlus class="w-4 h-4 sm:w-6 sm:h-6 group-hover:text-dp-accent transition-colors text-dp-text-muted" />
              </div>
              <span class="font-semibold text-xs sm:text-sm group-hover:text-dp-accent transition-colors text-dp-text-muted">{{ t('friends.actions.addFriend') }}</span>
            </div>
          </div>
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
      <!-- The three blocks are one procedure, so they are numbered. -->
      <HelpSection
        :step="1"
        :icon="Star"
        :title="t('friends.help.pinTitle')"
        :text="t('friends.help.pinText')"
      />
      <HelpSection
        :step="2"
        :icon="GripVertical"
        :title="t('friends.help.reorderTitle')"
        :text="t('friends.help.reorderText')"
      />
      <HelpSection
        :step="3"
        :icon="CheckCircle2"
        :title="t('friends.help.saveTitle')"
        :text="t('friends.help.saveText')"
      />

      <HelpNote :messages="[t('friends.help.note')]" />
    </HelpModal>
  </div>
</template>
