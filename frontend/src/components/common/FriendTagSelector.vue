<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Check, Home, RotateCcw, Search, Star, UserPlus, X } from 'lucide-vue-next'
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

const prioritizedSelectedFriends = computed<SelectedFriendEntry[]>(() => {
  return props.modelValue.map((friendId) => {
    const friend = friendMap.value.get(friendId)
    if (friend) {
      return friend
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
  })
})

const visibleFriends = computed<SelectedFriendEntry[]>(() => {
  const filteredUnselectedFriends = sortedFriends.value.filter(
    (friend) => !selectedIdSet.value.has(friend.id) && matchesQuery(friend)
  )

  return [...prioritizedSelectedFriends.value, ...filteredUnselectedFriends]
})

watch(selectedCount, (count, previousCount) => {
  if (count > 0 && previousCount === 0) {
    isExpanded.value = true
  }
})

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
}

function openSelector() {
  if (props.disabled) {
    return
  }

  isExpanded.value = true
}

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
  <section :class="isExpanded ? 'friend-tag-selector space-y-2.5 rounded-2xl border border-dp-border-primary bg-dp-bg-card p-3 sm:p-4' : ''">
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

    <div v-else class="space-y-2.5">
      <div class="flex items-center gap-2">
        <label for="friend-tag-search" class="sr-only">친구 검색</label>
        <div class="friend-tag-selector__search min-w-0 flex-1">
          <Search class="friend-tag-selector__search-icon" />
          <input
            id="friend-tag-search"
            v-model="searchQuery"
            type="text"
            inputmode="search"
            class="form-control friend-tag-selector__search-input friend-tag-selector__search-input--compact w-full rounded-xl"
            placeholder="친구 검색"
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
          class="inline-flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full text-dp-text-secondary transition hover:bg-dp-bg-hover hover:text-dp-text-primary"
          aria-label="선택된 친구 전체 해제"
          title="전체 해제"
          @click.stop="clearSelection"
        >
          <RotateCcw class="h-3.5 w-3.5" />
        </button>
      </div>

      <div class="overflow-hidden rounded-2xl border border-dp-border-primary bg-dp-bg-secondary">
        <div
          v-if="visibleFriends.length"
          class="friend-tag-selector__list max-h-72 overflow-y-auto lg:grid lg:grid-cols-2 lg:gap-px lg:bg-dp-border-primary"
        >
          <button
            v-for="friend in visibleFriends"
            :key="friend.id"
            type="button"
            class="flex min-h-[52px] w-full items-center gap-2 border-b border-dp-border-primary bg-dp-bg-primary px-2.5 py-2 text-left transition last:border-b-0 hover:bg-dp-bg-hover lg:border-b-0"
            :class="isSelected(friend.id) ? 'bg-dp-accent-soft' : ''"
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
              <div class="flex items-center gap-2">
                <span class="truncate text-sm font-medium text-dp-text-primary">{{ friend.name }}</span>
                <Star
                  v-if="friend.pinOrder != null"
                  class="h-3.5 w-3.5 flex-shrink-0 text-dp-warning"
                  fill="currentColor"
                  title="즐겨찾기"
                />
                <Home
                  v-if="friend.isFamily"
                  class="h-3.5 w-3.5 flex-shrink-0 text-dp-warning"
                  title="가족"
                />
              </div>
              <p v-if="getSubtitle(friend)" class="truncate text-xs text-dp-text-muted">{{ getSubtitle(friend) }}</p>
            </div>

            <div
              class="flex h-6 w-6 flex-shrink-0 items-center justify-center rounded-full border"
              :class="isSelected(friend.id)
                ? 'border-dp-accent bg-dp-accent text-dp-text-on-dark'
                : 'border-dp-border-secondary text-dp-text-muted'"
            >
              <Check v-if="isSelected(friend.id)" class="h-3.5 w-3.5" />
            </div>
          </button>
        </div>

        <div v-else class="px-4 py-10 text-center">
          <p class="text-sm font-medium text-dp-text-primary">검색 결과가 없어요.</p>
          <p class="mt-1 text-xs text-dp-text-muted">이름이나 팀명을 바꿔서 다시 찾아보세요.</p>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.friend-tag-selector__avatar {
  flex-shrink: 0;
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

@media (min-width: 1024px) {
  .friend-tag-selector__list:has(> :last-child:nth-child(odd))::after {
    content: '';
    display: block;
    min-height: 52px;
    background: var(--dp-bg-primary);
  }
}
</style>
