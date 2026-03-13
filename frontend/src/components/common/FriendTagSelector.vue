<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import { ChevronDown, RotateCcw, Search, UserPlus, X } from 'lucide-vue-next'
import type { TaggableFriend } from '@/types'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import { useSwal } from '@/composables/useSwal'

type SelectedFriendSummary = {
  id: number
  name: string
}

type SelectedFriendEntry = TaggableFriend & {
  isUnavailable?: boolean
}

const props = withDefaults(defineProps<{
  modelValue: number[]
  friends: TaggableFriend[]
  selectedSummaries?: SelectedFriendSummary[]
  disabled?: boolean
}>(), {
  disabled: false,
  selectedSummaries: () => [],
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: number[]): void
}>()

const { confirm } = useSwal()
const searchQuery = ref('')
const isExpanded = ref(props.modelValue.length > 0)
const showSelectedOnly = ref(false)
const listRef = ref<HTMLElement | null>(null)
const hasMoreBelow = ref(false)

const normalizedQuery = computed(() => searchQuery.value.trim().toLowerCase())
const selectedIdSet = computed(() => new Set(props.modelValue))
const selectedCount = computed(() => props.modelValue.length)
const friendMap = computed(() => new Map(sortedFriends.value.map((friend) => [friend.id, friend])))
const selectedSummaryMap = computed(() => new Map(props.selectedSummaries.map((friend) => [friend.id, friend])))

const sortedFriends = computed(() => {
  return [...props.friends].sort((a, b) => {
    const aPinned = a.pinOrder == null ? 1 : 0
    const bPinned = b.pinOrder == null ? 1 : 0
    if (aPinned !== bPinned) {
      return aPinned - bPinned
    }

    if (a.pinOrder != null && b.pinOrder != null && a.pinOrder !== b.pinOrder) {
      return a.pinOrder - b.pinOrder
    }

    const aFamily = a.isFamily ? 0 : 1
    const bFamily = b.isFamily ? 0 : 1
    if (aFamily !== bFamily) {
      return aFamily - bFamily
    }

    return a.name.localeCompare(b.name, 'ko')
  })
})

const unavailableSelectedFriends = computed<SelectedFriendEntry[]>(() => {
  return props.modelValue.map((friendId) => {
    const friend = friendMap.value.get(friendId)
    if (friend) {
      return null
    }

    const fallback = selectedSummaryMap.value.get(friendId)
    return {
      id: friendId,
      name: fallback?.name ?? `친구 #${friendId}`,
      teamId: null,
      team: null,
      hasProfilePhoto: false,
      profilePhotoVersion: 0,
      isFamily: false,
      pinOrder: null,
      isUnavailable: true,
    }
  }).filter((friend): friend is SelectedFriendEntry => friend !== null)
})

const visibleFriends = computed<SelectedFriendEntry[]>(() => {
  const selectedFriends = sortedFriends.value.filter((friend) => selectedIdSet.value.has(friend.id))

  if (showSelectedOnly.value) {
    return [...selectedFriends, ...unavailableSelectedFriends.value]
  }

  const orderedVisibleFriends = sortedFriends.value.filter(
    (friend) => selectedIdSet.value.has(friend.id) || matchesQuery(friend)
  )

  return [...orderedVisibleFriends, ...unavailableSelectedFriends.value]
})

watch(selectedCount, (count, previousCount) => {
  if (count > 0 && previousCount === 0) {
    isExpanded.value = true
  }

  if (count === 0) {
    showSelectedOnly.value = false
  }
})

watch([visibleFriends, isExpanded, showSelectedOnly], async () => {
  await nextTick()
  updateScrollHint()
}, { deep: true })

function matchesQuery(friend: TaggableFriend) {
  if (!normalizedQuery.value) {
    return true
  }

  const target = `${friend.name} ${friend.team ?? ''}`.toLowerCase()
  return target.includes(normalizedQuery.value)
}

function isSelected(friendId: number) {
  return selectedIdSet.value.has(friendId)
}

function toggleFriend(friendId: number) {
  if (props.disabled) {
    return
  }

  if (isSelected(friendId)) {
    emit('update:modelValue', props.modelValue.filter((id) => id !== friendId))
    return
  }

  emit('update:modelValue', [...props.modelValue, friendId])
}

async function clearSelection() {
  if (props.disabled || props.modelValue.length === 0) {
    return
  }

  if (!await confirm('선택된 친구 태그를 모두 해제하시겠습니까?', '전체 해제')) {
    return
  }

  emit('update:modelValue', [])
  showSelectedOnly.value = false
}

function openSelector() {
  if (props.disabled) {
    return
  }

  isExpanded.value = true
}

function toggleSelectedOnly() {
  if (props.disabled || selectedCount.value === 0) {
    return
  }

  showSelectedOnly.value = !showSelectedOnly.value
}

function updateScrollHint() {
  const listElement = listRef.value
  if (!listElement) {
    hasMoreBelow.value = false
    return
  }

  const canScroll = listElement.scrollHeight - listElement.clientHeight > 4
  const remainingScroll = listElement.scrollHeight - listElement.clientHeight - listElement.scrollTop
  hasMoreBelow.value = canScroll && remainingScroll > 4
}

function handleListScroll() {
  updateScrollHint()
}

function scrollListDown() {
  const listElement = listRef.value
  if (!listElement) {
    return
  }

  listElement.scrollBy({
    top: Math.max(listElement.clientHeight * 0.5, 88),
    behavior: 'smooth',
  })
}

onMounted(() => {
  updateScrollHint()
  window.addEventListener('resize', updateScrollHint)
})

onUnmounted(() => {
  window.removeEventListener('resize', updateScrollHint)
})

function getSubtitle(friend: TaggableFriend) {
  if ('isUnavailable' in friend && friend.isUnavailable) {
    return '현재 친구 목록에 없음'
  }
  if (friend.team) {
    return friend.team
  }
  return null
}
</script>

<template>
  <section :class="isExpanded ? 'friend-tag-selector space-y-2 rounded-2xl border border-dp-border-primary bg-dp-bg-card p-2.5 sm:space-y-2.5 sm:p-4' : ''">
    <button
      v-if="!isExpanded"
      type="button"
      class="flex min-h-[56px] w-full items-center gap-3 rounded-2xl border border-dp-border-primary bg-dp-bg-card px-4 py-3 text-left transition hover:border-dp-accent-border hover:bg-dp-bg-hover disabled:cursor-not-allowed disabled:opacity-60"
      :disabled="props.disabled"
      @click="openSelector"
    >
      <div class="flex min-w-0 items-center gap-3">
        <div class="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full bg-dp-bg-tertiary text-dp-accent">
          <UserPlus class="h-4 w-4" />
        </div>
        <span class="truncate text-sm font-medium text-dp-text-primary">친구 태그 추가</span>
      </div>
    </button>

    <div v-else class="space-y-2 sm:space-y-2.5">
      <div class="flex items-center gap-1.5 sm:gap-2">
        <label for="friend-tag-search" class="sr-only">친구 검색</label>
        <div class="friend-tag-selector__search min-w-0 flex-1">
          <Search class="friend-tag-selector__search-icon" />
          <input
            id="friend-tag-search"
            v-model="searchQuery"
            type="text"
            inputmode="search"
            class="form-control friend-tag-selector__search-input friend-tag-selector__search-input--compact w-full rounded-xl"
            placeholder="검색"
            @keydown.esc="searchQuery = ''"
          />
          <button
            v-if="searchQuery"
            type="button"
            class="friend-tag-selector__search-clear"
            aria-label="검색어 지우기"
            @click="searchQuery = ''"
          >
            <X class="h-4 w-4" />
          </button>
        </div>
        <button
          v-if="selectedCount"
          type="button"
          class="inline-flex h-8 flex-shrink-0 items-center rounded-full border px-2.5 text-xs font-semibold transition"
          :class="showSelectedOnly
            ? 'border-dp-accent bg-dp-accent text-dp-text-on-dark'
            : 'border-dp-accent-border bg-dp-accent-soft text-dp-text-primary hover:border-dp-accent hover:bg-dp-accent-bg'"
          :aria-label="showSelectedOnly ? `선택된 친구 ${selectedCount}명만 보는 중` : `선택된 친구 ${selectedCount}명만 보기`"
          :aria-pressed="showSelectedOnly"
          @click="toggleSelectedOnly"
        >
          {{ selectedCount }}명
        </button>
        <button
          v-if="selectedCount"
          type="button"
          class="inline-flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full text-dp-text-secondary transition hover:bg-dp-bg-hover hover:text-dp-text-primary"
          aria-label="선택된 친구 전체 해제"
          title="전체 해제"
          @click.stop="clearSelection"
        >
          <RotateCcw class="h-3.5 w-3.5" />
        </button>
      </div>

      <div class="friend-tag-selector__list-frame overflow-hidden rounded-2xl border border-dp-border-primary bg-dp-bg-secondary">
        <template v-if="visibleFriends.length">
          <div
            ref="listRef"
            class="friend-tag-selector__list grid grid-cols-2 gap-px overflow-y-auto bg-dp-border-primary"
            @scroll.passive="handleListScroll"
          >
            <button
              v-for="friend in visibleFriends"
              :key="friend.id"
              type="button"
              class="friend-tag-selector__item flex w-full items-start gap-2 bg-dp-bg-primary px-2 py-2 text-left transition sm:items-center sm:gap-3 sm:px-3 sm:py-2.5"
              :class="isSelected(friend.id) ? 'friend-tag-selector__item--selected' : ''"
              @click="toggleFriend(friend.id)"
            >
              <ProfileAvatar
                :member-id="friend.id"
                :name="friend.name"
                :has-profile-photo="friend.hasProfilePhoto"
                :profile-photo-version="friend.profilePhotoVersion"
                size="xs"
                class="friend-tag-selector__avatar"
              />

              <div class="min-w-0 flex-1">
                <div class="truncate text-[13px] font-medium leading-tight text-dp-text-primary sm:text-sm">{{ friend.name }}</div>
                <p v-if="getSubtitle(friend)" class="truncate text-[11px] text-dp-text-muted sm:text-xs">{{ getSubtitle(friend) }}</p>
              </div>
            </button>
          </div>

          <div v-if="hasMoreBelow" class="friend-tag-selector__scroll-hint">
            <button
              type="button"
              class="friend-tag-selector__scroll-hint-pill"
              aria-label="친구 목록 조금 더 아래로 보기"
              @click="scrollListDown"
            >
              <ChevronDown class="h-3 w-3" />
              아래로 더 보기
            </button>
          </div>
        </template>

        <div v-else class="px-4 py-10 text-center">
          <p class="text-sm font-medium text-dp-text-primary">검색 결과가 없어요.</p>
          <p class="mt-1 text-xs text-dp-text-muted">이름이나 팀명을 바꿔서 다시 찾아보세요.</p>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.friend-tag-selector__list {
  --friend-tag-row-height: 56px;
  max-height: calc((var(--friend-tag-row-height) * 3) + 2px);
  scrollbar-color: var(--dp-border-secondary) var(--dp-bg-primary);
  scrollbar-gutter: stable;
}

.friend-tag-selector__list-frame {
  position: relative;
}

.friend-tag-selector__scroll-hint {
  position: absolute;
  right: 0;
  bottom: 0;
  left: 0;
  display: flex;
  justify-content: center;
  padding: 1.75rem 0 0.375rem;
  background: linear-gradient(to bottom, transparent 0%, color-mix(in srgb, var(--dp-bg-secondary) 72%, transparent) 58%, var(--dp-bg-secondary) 100%);
  pointer-events: none;
}

.friend-tag-selector__scroll-hint-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  min-height: 1.25rem;
  padding: 0.125rem 0.5rem;
  border: 1px solid var(--dp-border-primary);
  border-radius: 9999px;
  background: color-mix(in srgb, var(--dp-bg-card) 92%, transparent);
  color: var(--dp-text-muted);
  font-size: 0.625rem;
  font-weight: 600;
  line-height: 1;
  box-shadow: 0 4px 12px color-mix(in srgb, var(--dp-overlay-dark) 12%, transparent);
  backdrop-filter: blur(4px);
  pointer-events: auto;
  cursor: pointer;
}

.friend-tag-selector__scroll-hint-pill:hover {
  border-color: var(--dp-accent-border);
  color: var(--dp-text-primary);
}

.friend-tag-selector__scroll-hint-pill:focus-visible {
  outline: none;
}

.friend-tag-selector__scroll-hint-pill:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: 2px;
}

.friend-tag-selector__item {
  min-height: var(--friend-tag-row-height);
}

.friend-tag-selector__avatar {
  flex-shrink: 0;
  width: 1.625rem;
  height: 1.625rem;
}

.friend-tag-selector__item--selected {
  background-color: var(--dp-accent-bg-hover) !important;
  border-color: var(--dp-accent-border);
  box-shadow: inset 0 0 0 1px var(--dp-accent-border);
}

.friend-tag-selector__item--selected:hover {
  background-color: var(--dp-accent-bg-hover) !important;
}

.friend-tag-selector__search {
  position: relative;
}

.friend-tag-selector__search-input {
  padding-left: 2.75rem;
  padding-right: 2.75rem;
}

.friend-tag-selector__search-input--compact {
  min-height: 2.5rem;
  padding-top: 0.5rem;
  padding-bottom: 0.5rem;
  font-size: 0.875rem;
}

.friend-tag-selector__search-icon {
  position: absolute;
  top: 50%;
  left: 1rem;
  width: 1rem;
  height: 1rem;
  color: var(--dp-text-muted);
  transform: translateY(-50%);
  pointer-events: none;
}

.friend-tag-selector__search-clear {
  position: absolute;
  top: 50%;
  right: 0.5rem;
  display: inline-flex;
  width: 2rem;
  height: 2rem;
  align-items: center;
  justify-content: center;
  border-radius: 9999px;
  color: var(--dp-text-muted);
  transform: translateY(-50%);
  transition: background-color 0.15s ease, color 0.15s ease;
}

.friend-tag-selector__search-clear:hover {
  background: var(--dp-bg-hover);
  color: var(--dp-text-primary);
}

.friend-tag-selector__search-clear:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: 2px;
}

.friend-tag-selector__list::-webkit-scrollbar {
  width: 0.625rem;
}

.friend-tag-selector__list::-webkit-scrollbar-track {
  background: var(--dp-bg-primary);
}

.friend-tag-selector__list::-webkit-scrollbar-thumb {
  background: var(--dp-border-secondary);
  border: 2px solid var(--dp-bg-primary);
  border-radius: 9999px;
}

.friend-tag-selector__list::-webkit-scrollbar-corner {
  background: var(--dp-bg-primary);
}

@media (max-width: 639px) {
  .friend-tag-selector__item {
    align-items: flex-start;
  }
}

.friend-tag-selector__list > :first-child {
  border-top-left-radius: 1rem;
}

.friend-tag-selector__list > :nth-child(2) {
  border-top-right-radius: 1rem;
}

.friend-tag-selector__list > :nth-last-child(2):nth-child(odd) {
  border-bottom-left-radius: 1rem;
}

.friend-tag-selector__list > :last-child:nth-child(even) {
  border-bottom-right-radius: 1rem;
}

.friend-tag-selector__list > :last-child:nth-child(odd) {
  border-bottom-left-radius: 1rem;
}

.friend-tag-selector__list:has(> :last-child:nth-child(odd))::after {
  content: '';
  display: block;
  min-height: var(--friend-tag-row-height);
  background: var(--dp-bg-primary);
  border-bottom-right-radius: 1rem;
}

@media (min-width: 640px) {
  .friend-tag-selector__list {
    --friend-tag-row-height: 60px;
    max-height: 18rem;
  }

  .friend-tag-selector__scroll-hint {
    padding: 2rem 0 0.5rem;
  }

  .friend-tag-selector__avatar {
    width: 1.875rem;
    height: 1.875rem;
  }

  .friend-tag-selector__item {
    padding-inline: 0.75rem;
  }

  .friend-tag-selector__list:has(> :last-child:nth-child(odd))::after {
    min-height: var(--friend-tag-row-height);
  }
}
</style>
