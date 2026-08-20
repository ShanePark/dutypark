<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { Check, ChevronLeft, ChevronRight, RotateCcw, Search, UserPlus, X } from 'lucide-vue-next'
import type { TaggableFriend } from '@/types'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import {
  buildSelectedEntries,
  filterTaggableFriends,
  sortTaggableFriends,
} from '@/components/common/friendTagSelection'
import { useSwal } from '@/composables/useSwal'

type SelectedFriendSummary = {
  id: number
  name: string
}

const props = withDefaults(defineProps<{
  modelValue: number[]
  friends: TaggableFriend[]
  selectedSummaries?: SelectedFriendSummary[]
}>(), {
  selectedSummaries: () => [],
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: number[]): void
}>()

const { t, locale } = useI18n()
const { confirm } = useSwal()
const searchQuery = ref('')
const isExpanded = ref(props.modelValue.length > 0)
const railRef = ref<HTMLElement | null>(null)
const selectedBlockRef = ref<HTMLElement | null>(null)
const canScrollPrev = ref(false)
const canScrollNext = ref(false)

const selectedIdSet = computed(() => new Set(props.modelValue))
const selectedCount = computed(() => props.modelValue.length)
const selectedSummaryMap = computed(() => new Map(props.selectedSummaries.map((friend) => [friend.id, friend])))

const sortedFriends = computed(() => sortTaggableFriends(props.friends, locale.value))

/** Chips keep the friend sort order so a new pick lands in a stable slot instead of jumping to the end. */
const selectedFriends = computed(() => buildSelectedEntries({
  sortedFriends: sortedFriends.value,
  selectedIds: props.modelValue,
  resolveUnavailableName: (id) => selectedSummaryMap.value.get(id)?.name
    ?? t('friendTagSelector.fallbackName', { id }),
}))

/** The rail only lists friends that can still be tagged; stale picks stay reachable through their chip. */
const railFriends = computed(() => filterTaggableFriends(sortedFriends.value, searchQuery.value))

watch(selectedCount, (count, previousCount) => {
  if (count > 0 && previousCount === 0) {
    isExpanded.value = true
  }
})

watch([railFriends, isExpanded], async () => {
  await nextTick()
  updateRailHints()
}, { deep: true })

function isSelected(friendId: number) {
  return selectedIdSet.value.has(friendId)
}

function toggleFriend(friendId: number) {
  if (isSelected(friendId)) {
    removeFriend(friendId)
    return
  }

  emit('update:modelValue', [...props.modelValue, friendId])
}

function removeFriend(friendId: number) {
  emit('update:modelValue', props.modelValue.filter((id) => id !== friendId))
}

async function clearSelection() {
  if (props.modelValue.length === 0) {
    return
  }

  if (!await confirm(
    t('friendTagSelector.clearConfirm', { count: selectedCount.value }),
    t('friendTagSelector.clearTitle'),
  )) {
    return
  }

  emit('update:modelValue', [])
}

async function openSelector() {
  isExpanded.value = true
  await nextTick()

  if (!window.matchMedia('(max-width: 639px)').matches) {
    return
  }

  selectedBlockRef.value?.scrollIntoView({
    behavior: 'smooth',
    block: 'nearest',
  })
}

function updateRailHints() {
  const rail = railRef.value
  if (!rail) {
    canScrollPrev.value = false
    canScrollNext.value = false
    return
  }

  const maxScroll = rail.scrollWidth - rail.clientWidth
  canScrollPrev.value = rail.scrollLeft > 4
  canScrollNext.value = maxScroll - rail.scrollLeft > 4
}

function scrollRail(direction: -1 | 1) {
  const rail = railRef.value
  if (!rail) {
    return
  }

  rail.scrollBy({
    left: direction * Math.max(rail.clientWidth * 0.8, 160),
    behavior: 'smooth',
  })
}

onMounted(() => {
  updateRailHints()
  window.addEventListener('resize', updateRailHints)
})

onUnmounted(() => {
  window.removeEventListener('resize', updateRailHints)
})

/** Blank rather than null: the team line always renders so every card keeps one identical layout. */
function getSubtitle(friend: TaggableFriend) {
  return friend.team || ''
}
</script>

<template>
  <section :class="isExpanded ? 'friend-tag-selector space-y-2 rounded-2xl border border-dp-border-primary bg-dp-bg-card p-2.5 sm:space-y-2.5 sm:p-4' : ''">
    <button
      v-if="!isExpanded"
      type="button"
      class="flex min-h-[56px] w-full items-center gap-3 rounded-2xl border border-dp-border-primary bg-dp-bg-card px-4 py-3 text-left transition hover:border-dp-accent-border hover:bg-dp-bg-hover"
      @click="openSelector"
    >
      <div class="flex min-w-0 flex-1 items-center gap-3">
        <div class="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full bg-dp-bg-tertiary text-dp-accent">
          <UserPlus class="h-4 w-4" />
        </div>
        <span class="truncate text-sm font-medium text-dp-text-primary">{{ t('friendTagSelector.openButton') }}</span>
      </div>
      <span
        v-if="selectedCount"
        class="flex-shrink-0 rounded-full bg-dp-accent-soft px-2.5 py-1 text-xs font-semibold text-dp-accent"
      >
        {{ t('friendTagSelector.selectedCount', { count: selectedCount }) }}
      </span>
    </button>

    <div v-else class="space-y-2 sm:space-y-2.5">
      <div class="friend-tag-selector__search">
        <label for="friend-tag-search" class="sr-only">{{ t('friendTagSelector.searchLabel') }}</label>
        <Search class="friend-tag-selector__search-icon" />
        <input
          id="friend-tag-search"
          v-model="searchQuery"
          type="text"
          inputmode="search"
          class="form-control friend-tag-selector__search-input w-full rounded-xl"
          :placeholder="t('friendTagSelector.searchPlaceholder')"
          @keydown.esc="searchQuery = ''"
        />
        <button
          v-if="searchQuery"
          type="button"
          class="friend-tag-selector__search-clear"
          :aria-label="t('friendTagSelector.clearSearchAria')"
          @click="searchQuery = ''"
        >
          <X class="h-4 w-4" />
        </button>
      </div>

      <div v-if="railFriends.length" class="friend-tag-selector__rail-frame">
        <div
          ref="railRef"
          class="friend-tag-selector__rail"
          @scroll.passive="updateRailHints"
        >
          <button
            v-for="friend in railFriends"
            :key="friend.id"
            type="button"
            class="friend-tag-selector__card"
            :class="isSelected(friend.id) ? 'friend-tag-selector__card--selected' : ''"
            :aria-pressed="isSelected(friend.id)"
            @click="toggleFriend(friend.id)"
          >
            <span class="friend-tag-selector__photo">
              <ProfileAvatar
                :member-id="friend.id"
                :name="friend.name"
                :has-profile-photo="friend.hasProfilePhoto"
                :profile-photo-version="friend.profilePhotoVersion"
                shape="portrait"
                size="xl"
              />
              <span v-if="isSelected(friend.id)" class="friend-tag-selector__check">
                <Check class="h-3 w-3" />
              </span>
            </span>
            <span class="friend-tag-selector__card-name">{{ friend.name }}</span>
            <span
              class="friend-tag-selector__card-team"
              :aria-hidden="getSubtitle(friend) ? undefined : 'true'"
            >{{ getSubtitle(friend) }}</span>
          </button>
        </div>

        <button
          v-if="canScrollPrev"
          type="button"
          class="friend-tag-selector__rail-nav friend-tag-selector__rail-nav--prev"
          :aria-label="t('friendTagSelector.scrollPrevAria')"
          @click="scrollRail(-1)"
        >
          <ChevronLeft class="h-4 w-4" />
        </button>
        <button
          v-if="canScrollNext"
          type="button"
          class="friend-tag-selector__rail-nav friend-tag-selector__rail-nav--next"
          :aria-label="t('friendTagSelector.scrollNextAria')"
          @click="scrollRail(1)"
        >
          <ChevronRight class="h-4 w-4" />
        </button>
      </div>

      <div v-else class="rounded-2xl border border-dp-border-primary bg-dp-bg-secondary px-4 py-8 text-center">
        <p class="text-sm font-medium text-dp-text-primary">{{ t('friendTagSelector.emptyTitle') }}</p>
        <p class="mt-1 text-xs text-dp-text-muted">{{ t('friendTagSelector.emptyDescription') }}</p>
      </div>

      <div ref="selectedBlockRef" class="friend-tag-selector__selected">
        <div class="friend-tag-selector__selected-header">
          <span class="text-xs font-semibold text-dp-text-secondary">
            {{ t('friendTagSelector.selectedCount', { count: selectedCount }) }}
          </span>
          <button
            v-if="selectedFriends.length"
            type="button"
            class="friend-tag-selector__clear"
            :aria-label="t('friendTagSelector.clearSelectionAria')"
            :title="t('friendTagSelector.clearTitle')"
            @click="clearSelection"
          >
            <RotateCcw class="h-3 w-3" />
            {{ t('friendTagSelector.clearTitle') }}
          </button>
        </div>

        <div class="friend-tag-selector__chips">
          <button
            v-for="friend in selectedFriends"
            :key="`chip-${friend.id}`"
            type="button"
            class="friend-tag-selector__chip"
            :class="friend.isUnavailable ? 'friend-tag-selector__chip--unavailable' : ''"
            :title="friend.isUnavailable ? t('friendTagSelector.unavailable') : friend.name"
            :aria-label="t('friendTagSelector.removeTagAria', { name: friend.name })"
            @click="removeFriend(friend.id)"
          >
            <ProfileAvatar
              :member-id="friend.isUnavailable ? null : friend.id"
              :name="friend.name"
              :has-profile-photo="friend.hasProfilePhoto"
              :profile-photo-version="friend.profilePhotoVersion"
              size="sm"
              class="friend-tag-selector__chip-avatar"
            />
            <span class="friend-tag-selector__chip-name">{{ friend.name }}</span>
            <X class="h-3 w-3 flex-shrink-0" />
          </button>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.friend-tag-selector__selected {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
  padding: 0.5rem;
  border: 1px solid var(--dp-accent-border);
  border-radius: 1rem;
  background: var(--dp-accent-bg);
}

.friend-tag-selector__selected-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  min-height: 1.5rem;
  padding-inline: 0.125rem;
}

.friend-tag-selector__clear {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.25rem 0.5rem;
  border-radius: 9999px;
  color: var(--dp-text-secondary);
  font-size: 0.6875rem;
  font-weight: 600;
  line-height: 1;
  cursor: pointer;
}

.friend-tag-selector__clear:hover {
  background: var(--dp-bg-hover);
  color: var(--dp-text-primary);
}

.friend-tag-selector__clear:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: 2px;
}

.friend-tag-selector__chips {
  display: flex;
  gap: 0.375rem;
  min-height: 2rem;
  overflow-x: auto;
  padding-bottom: 0.125rem;
  scrollbar-width: none;
}

.friend-tag-selector__chips::-webkit-scrollbar {
  display: none;
}

.friend-tag-selector__chip {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 0.3125rem;
  max-width: 9rem;
  min-height: 2rem;
  padding: 0.1875rem 0.5rem 0.1875rem 0.1875rem;
  border: 1px solid var(--dp-accent-border);
  border-radius: 9999px;
  background: var(--dp-bg-card);
  color: var(--dp-text-primary);
  font-size: 0.75rem;
  font-weight: 500;
  cursor: pointer;
  transition: border-color 0.15s ease, background-color 0.15s ease;
}

.friend-tag-selector__chip:hover {
  border-color: var(--dp-accent);
  background: var(--dp-accent-bg-hover);
}

.friend-tag-selector__chip:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: 2px;
}

.friend-tag-selector__chip--unavailable {
  border-style: dashed;
  color: var(--dp-text-muted);
}

.friend-tag-selector__chip-avatar {
  width: 1.5rem;
  height: 1.5rem;
}

.friend-tag-selector__chip-name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.friend-tag-selector__rail-frame {
  position: relative;
  overflow: hidden;
  border: 1px solid var(--dp-border-primary);
  border-radius: 1rem;
  background: var(--dp-bg-secondary);
}

.friend-tag-selector__rail {
  --friend-card-gap: 0.375rem;
  --friend-card-min: 3.75rem;
  --friend-card-max: 5.5rem;
  display: flex;
  align-items: flex-start;
  gap: var(--friend-card-gap);
  overflow-x: auto;
  padding: 0.5rem;
  scroll-snap-type: x proximity;
  scrollbar-width: thin;
  scrollbar-color: var(--dp-border-secondary) transparent;
  overscroll-behavior-x: contain;
}

.friend-tag-selector__rail::-webkit-scrollbar {
  height: 0.375rem;
}

.friend-tag-selector__rail::-webkit-scrollbar-thumb {
  background: var(--dp-border-secondary);
  border-radius: 9999px;
}

/* Three portraits plus a peek of the next one always fit the visible rail, so the
   sideways scroll is discoverable, and cards never grow past a comfortable size. */
.friend-tag-selector__card {
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
  gap: 0.25rem;
  padding: 0.25rem;
  border: 1px solid transparent;
  border-radius: 0.875rem;
  background: var(--dp-bg-primary);
  scroll-snap-align: start;
  cursor: pointer;
  transition: border-color 0.15s ease, background-color 0.15s ease, transform 0.15s ease;
}

.friend-tag-selector__card:hover {
  border-color: var(--dp-accent-border);
}

.friend-tag-selector__card:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: 2px;
}

.friend-tag-selector__card--selected {
  border-color: var(--dp-accent);
  background: var(--dp-accent-bg);
  box-shadow: 0 0 0 1px var(--dp-accent), 0 2px 8px var(--dp-accent-ring);
}

.friend-tag-selector__photo {
  position: relative;
  display: block;
  width: 100%;
  aspect-ratio: 3 / 4;
}

.friend-tag-selector__card--selected .friend-tag-selector__photo :deep(.profile-avatar) {
  border-color: var(--dp-accent);
}

.friend-tag-selector__check {
  position: absolute;
  right: -0.125rem;
  bottom: -0.125rem;
  display: inline-flex;
  width: 1.25rem;
  height: 1.25rem;
  align-items: center;
  justify-content: center;
  border: 2px solid var(--dp-bg-primary);
  border-radius: 9999px;
  background: var(--dp-accent);
  color: #ffffff;
}

.friend-tag-selector__card-name {
  overflow: hidden;
  font-size: 0.75rem;
  font-weight: 600;
  line-height: 1.2;
  color: var(--dp-text-primary);
  text-align: center;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.friend-tag-selector__card--selected .friend-tag-selector__card-name {
  color: var(--dp-accent);
}

/* An empty element collapses, so the blank slot of a team-less friend needs its one line
   reserved explicitly; 1.2em matches the line box this font-size and line-height produce. */
.friend-tag-selector__card-team {
  overflow: hidden;
  min-height: 1.2em;
  font-size: 0.625rem;
  line-height: 1.2;
  color: var(--dp-text-muted);
  text-align: center;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.friend-tag-selector__rail-nav {
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

.friend-tag-selector__rail-nav:hover {
  border-color: var(--dp-accent-border);
  color: var(--dp-text-primary);
}

.friend-tag-selector__rail-nav:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: 2px;
}

.friend-tag-selector__rail-nav--prev {
  left: 0.25rem;
}

.friend-tag-selector__rail-nav--next {
  right: 0.25rem;
}

/* Touch users flick the rail, so the arrows only earn their space on pointer devices,
   and they stay out of the portraits until the pointer or keyboard reaches the rail. */
@media (hover: hover) and (pointer: fine) {
  .friend-tag-selector__rail-nav {
    display: inline-flex;
  }

  .friend-tag-selector__rail-frame:hover .friend-tag-selector__rail-nav,
  .friend-tag-selector__rail-frame:focus-within .friend-tag-selector__rail-nav {
    opacity: 1;
  }
}

@media (min-width: 640px) {
  .friend-tag-selector__rail {
    --friend-card-gap: 0.5rem;
  }

  .friend-tag-selector__card-name {
    font-size: 0.8125rem;
  }

  .friend-tag-selector__card-team {
    font-size: 0.6875rem;
  }
}

.friend-tag-selector__search {
  position: relative;
}

.friend-tag-selector__search-input {
  min-height: 2.5rem;
  padding: 0.5rem 2.75rem;
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

@media (max-width: 639px) {
  .friend-tag-selector {
    padding: 0.625rem;
  }

  .friend-tag-selector__search-input {
    min-height: 2.75rem;
  }
}
</style>
