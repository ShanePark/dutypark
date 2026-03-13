<script setup lang="ts">
import { computed, ref } from 'vue'
import { Check, Heart, Search, Star, UserPlus, X } from 'lucide-vue-next'
import type { TaggableFriend } from '@/types'

type FilterKey = 'ALL' | 'PINNED' | 'FAMILY'
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
  title?: string
  helperText?: string
  disabled?: boolean
}>(), {
  title: '친구 태그',
  helperText: '즐겨찾기 친구를 먼저 보여주고, 검색으로 빠르게 찾을 수 있어요.',
  disabled: false,
  selectedSummaries: () => [],
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: number[]): void
}>()

const searchQuery = ref('')
const activeFilter = ref<FilterKey>('ALL')

const filterOptions: Array<{ key: FilterKey; label: string }> = [
  { key: 'ALL', label: '전체' },
  { key: 'PINNED', label: '즐겨찾기' },
  { key: 'FAMILY', label: '가족' },
]

const normalizedQuery = computed(() => searchQuery.value.trim().toLowerCase())
const selectedIdSet = computed(() => new Set(props.modelValue))
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

const pinnedFriends = computed(() => sortedFriends.value.filter((friend) => friend.pinOrder != null))

const quickPickFriends = computed(() => {
  const source = normalizedQuery.value
    ? pinnedFriends.value.filter(matchesQuery)
    : pinnedFriends.value
  return source.slice(0, 8)
})

const selectedFriends = computed<SelectedFriendEntry[]>(() => {
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

const filteredFriends = computed(() => {
  return sortedFriends.value.filter((friend) => {
    if (!matchesQuery(friend)) {
      return false
    }

    if (activeFilter.value === 'PINNED') {
      return friend.pinOrder != null
    }

    if (activeFilter.value === 'FAMILY') {
      return friend.isFamily
    }

    return true
  })
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

function clearSelection() {
  if (props.disabled) {
    return
  }
  emit('update:modelValue', [])
}

function getInitial(name: string) {
  return name.trim().charAt(0) || '?'
}

function getSubtitle(friend: TaggableFriend) {
  if ('isUnavailable' in friend && friend.isUnavailable) {
    return '현재 친구 목록에 없음'
  }
  if (friend.team && friend.isFamily) {
    return `${friend.team} · 가족`
  }
  if (friend.team) {
    return friend.team
  }
  if (friend.isFamily) {
    return '가족'
  }
  if (friend.pinOrder != null) {
    return `즐겨찾기 ${friend.pinOrder}순위`
  }
  return '친구'
}
</script>

<template>
  <section class="friend-tag-selector space-y-3 rounded-2xl border border-dp-border-primary p-3 sm:p-4">
    <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
      <div class="flex items-start gap-3">
        <div class="friend-tag-selector__icon-box">
          <UserPlus class="w-4 h-4 text-dp-accent" />
        </div>
        <div class="min-w-0">
          <p class="text-sm font-semibold text-dp-text-primary">{{ title }}</p>
          <p class="text-xs leading-5 text-dp-text-muted">{{ helperText }}</p>
        </div>
      </div>
      <div class="inline-flex min-h-[32px] items-center rounded-full border border-dp-accent-border bg-dp-accent-soft px-3 py-1 text-xs font-semibold text-dp-accent-hover">
        {{ selectedFriends.length }}명 선택됨
      </div>
    </div>

    <div v-if="selectedFriends.length" class="space-y-2">
      <div class="flex items-center justify-between gap-2">
        <p class="text-xs font-semibold text-dp-text-secondary">선택된 친구</p>
        <button
          type="button"
          class="min-h-[32px] rounded-full px-2 text-xs font-medium text-dp-text-secondary transition hover:bg-dp-bg-hover hover:text-dp-text-primary"
          @click="clearSelection"
        >
          전체 해제
        </button>
      </div>
      <div class="flex flex-wrap gap-2">
        <button
          v-for="friend in selectedFriends"
          :key="friend.id"
          type="button"
          class="inline-flex min-h-[36px] items-center gap-2 rounded-full border border-dp-accent-border bg-dp-accent-soft px-3 py-1 text-left text-xs font-medium text-dp-accent-hover transition hover:bg-dp-accent-soft"
          @click="toggleFriend(friend.id)"
        >
          <span class="friend-tag-selector__avatar friend-tag-selector__avatar--selected">
            {{ getInitial(friend.name) }}
          </span>
          <span class="truncate">{{ friend.name }}</span>
          <span
            v-if="friend.isUnavailable"
            class="inline-flex items-center rounded-full bg-dp-bg-primary px-2 py-0.5 text-[10px] font-semibold text-dp-text-muted"
          >
            기존 태그
          </span>
          <X class="w-3.5 h-3.5" />
        </button>
      </div>
    </div>
    <div
      v-else
      class="rounded-xl border border-dashed border-dp-border-secondary bg-dp-bg-primary px-3 py-3 text-sm text-dp-text-muted"
    >
      아직 태그된 친구가 없어요. 검색하거나 즐겨찾기 영역에서 바로 선택해보세요.
    </div>

    <div class="grid gap-2 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center">
      <label class="relative block">
        <Search class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-dp-text-muted" />
        <input
          v-model="searchQuery"
          type="search"
          class="form-control min-h-[44px] w-full rounded-xl pl-9 pr-3"
          placeholder="이름 또는 팀으로 검색"
        />
      </label>

      <div class="inline-flex overflow-hidden rounded-xl border border-dp-border-primary bg-dp-bg-primary">
        <button
          v-for="option in filterOptions"
          :key="option.key"
          type="button"
          class="min-h-[44px] px-3 text-xs font-medium transition sm:px-4"
          :class="activeFilter === option.key
            ? 'bg-dp-bg-tertiary text-dp-text-primary'
            : 'text-dp-text-secondary hover:bg-dp-bg-hover hover:text-dp-text-primary'"
          @click="activeFilter = option.key"
        >
          {{ option.label }}
        </button>
      </div>
    </div>

    <div v-if="quickPickFriends.length" class="space-y-2">
      <div class="flex items-center gap-1.5 text-xs font-semibold text-dp-text-secondary">
        <Star class="h-3.5 w-3.5 text-dp-warning" />
        자주 찾는 친구
      </div>
      <div class="flex gap-2 overflow-x-auto pb-1">
        <button
          v-for="friend in quickPickFriends"
          :key="friend.id"
          type="button"
          class="friend-tag-selector__quick-pick min-h-[72px] min-w-[170px] flex-1 rounded-2xl border p-3 text-left transition"
          :class="isSelected(friend.id)
            ? 'border-dp-accent-border bg-dp-accent-soft'
            : 'border-dp-border-primary bg-dp-bg-primary hover:border-dp-accent-border hover:bg-dp-bg-hover'"
          @click="toggleFriend(friend.id)"
        >
          <div class="flex items-start justify-between gap-2">
            <div class="flex min-w-0 items-center gap-2">
              <span class="friend-tag-selector__avatar">
                {{ getInitial(friend.name) }}
              </span>
              <div class="min-w-0">
                <p class="truncate text-sm font-semibold text-dp-text-primary">{{ friend.name }}</p>
                <p class="truncate text-xs text-dp-text-muted">{{ getSubtitle(friend) }}</p>
              </div>
            </div>
            <div
              class="mt-0.5 flex h-6 w-6 flex-shrink-0 items-center justify-center rounded-full border"
              :class="isSelected(friend.id)
                ? 'border-dp-accent bg-dp-accent text-dp-text-on-dark'
                : 'border-dp-border-secondary text-dp-text-muted'"
            >
              <Check v-if="isSelected(friend.id)" class="h-3.5 w-3.5" />
              <Star v-else class="h-3.5 w-3.5" />
            </div>
          </div>
        </button>
      </div>
    </div>

    <div class="overflow-hidden rounded-2xl border border-dp-border-primary bg-dp-bg-primary">
      <div class="flex items-center justify-between border-b border-dp-border-primary bg-dp-bg-tertiary px-3 py-2">
        <div class="flex items-center gap-1.5 text-xs font-semibold text-dp-text-secondary">
          <Heart v-if="activeFilter === 'FAMILY'" class="h-3.5 w-3.5 text-dp-danger" />
          <Star v-else-if="activeFilter === 'PINNED'" class="h-3.5 w-3.5 text-dp-warning" />
          <UserPlus v-else class="h-3.5 w-3.5 text-dp-accent" />
          <span>친구 목록</span>
        </div>
        <span class="text-xs text-dp-text-muted">{{ filteredFriends.length }}명</span>
      </div>

      <div v-if="filteredFriends.length" class="max-h-72 overflow-y-auto">
        <button
          v-for="friend in filteredFriends"
          :key="friend.id"
          type="button"
          class="flex min-h-[56px] w-full items-center gap-3 border-b border-dp-border-primary px-3 py-2.5 text-left transition last:border-b-0 hover:bg-dp-bg-hover"
          @click="toggleFriend(friend.id)"
        >
          <span class="friend-tag-selector__avatar">
            {{ getInitial(friend.name) }}
          </span>

          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <span class="truncate text-sm font-medium text-dp-text-primary">{{ friend.name }}</span>
              <span
                v-if="friend.pinOrder != null"
                class="inline-flex items-center rounded-full bg-dp-warning-soft px-2 py-0.5 text-[10px] font-semibold text-dp-warning"
              >
                즐겨찾기
              </span>
              <span
                v-else-if="friend.isFamily"
                class="inline-flex items-center rounded-full bg-dp-danger-soft px-2 py-0.5 text-[10px] font-semibold text-dp-danger"
              >
                가족
              </span>
            </div>
            <p class="truncate text-xs text-dp-text-muted">{{ getSubtitle(friend) }}</p>
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
  </section>
</template>

<style scoped>
.friend-tag-selector {
  background:
    radial-gradient(circle at top right, var(--dp-accent-ring), transparent 42%),
    linear-gradient(180deg, color-mix(in srgb, var(--dp-bg-card) 88%, var(--dp-accent-bg) 12%), var(--dp-bg-card));
}

.friend-tag-selector__icon-box {
  display: flex;
  width: 2.25rem;
  height: 2.25rem;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  border-radius: 0.9rem;
  background: var(--dp-accent-soft);
  border: 1px solid var(--dp-accent-border);
}

.friend-tag-selector__avatar {
  display: inline-flex;
  width: 2rem;
  height: 2rem;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  border-radius: 9999px;
  background: var(--dp-bg-tertiary);
  border: 1px solid var(--dp-border-primary);
  color: var(--dp-text-primary);
  font-size: 0.75rem;
  font-weight: 700;
}

.friend-tag-selector__avatar--selected {
  width: 1.5rem;
  height: 1.5rem;
  font-size: 0.7rem;
}

.friend-tag-selector__quick-pick {
  box-shadow: var(--dp-shadow-sm);
}
</style>
