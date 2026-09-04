<script setup lang="ts">
import { computed } from 'vue'
import { X, Users, Check, RotateCcw } from 'lucide-vue-next'
import { useI18n } from 'vue-i18n'
import type { TaggableFriend } from '@/types'
import BaseModal from '@/components/common/BaseModal.vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'

interface Props {
  isOpen: boolean
  friends: TaggableFriend[]
  selectedFriendIds: number[]
  maxSelections?: number
}

const props = withDefaults(defineProps<Props>(), {
  maxSelections: 3,
})

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'toggle', friendId: number): void
  (e: 'clear'): void
}>()

const { t } = useI18n()

const canSelectMore = computed(() => {
  return props.selectedFriendIds.length < props.maxSelections
})

const hasSelection = computed(() => props.selectedFriendIds.length > 0)

function isSelected(friendId: number) {
  return props.selectedFriendIds.includes(friendId)
}

function isTeamless(friend: TaggableFriend) {
  return friend.teamId == null
}

function handleToggle(friendId: number) {
  const friend = props.friends.find((candidate) => candidate.id === friendId)
  if (friend && isTeamless(friend) && !isSelected(friendId)) {
    return
  }

  if (!isSelected(friendId) && !canSelectMore.value) {
    return
  }
  emit('toggle', friendId)
}

function handleClear() {
  if (!hasSelection.value) {
    return
  }

  emit('clear')
}
</script>

<style scoped>
.friend-item {
  width: 100%;
  border: 2px solid transparent;
  background-color: var(--dp-bg-secondary);
  color: var(--dp-text-primary);
  cursor: pointer;
  transition: background-color 0.15s ease, border-color 0.15s ease;
}

.friend-item-selected {
  background-color: var(--dp-accent-bg);
  border-color: var(--dp-accent-border);
}

.friend-item-disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.friend-item:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: 2px;
}

:deep(.friend-item-avatar.profile-avatar) {
  transition: border-color 0.15s ease;
}

@media (hover: hover) and (pointer: fine) {
  .friend-item:not(.friend-item-selected):not(.friend-item-disabled):hover {
    background-color: var(--dp-bg-hover);
    border-color: var(--dp-accent-border);
    box-shadow: none;
  }

  .friend-item:not(.friend-item-selected):not(.friend-item-disabled):hover
    :deep(.friend-item-avatar.profile-avatar) {
    border-color: var(--dp-accent-border);
  }

  .friend-item-selected:hover {
    background-color: var(--dp-accent-bg-hover);
  }
}

@media (prefers-reduced-motion: reduce) {
  .friend-item,
  :deep(.friend-item-avatar.profile-avatar) {
    transition: none;
  }
}
</style>

<template>
  <BaseModal
    :is-open="isOpen"
    size="md"
    height="default"
    @close="emit('close')"
  >
    <div class="modal-header">
      <div class="flex items-center gap-2">
        <Users class="w-5 h-5 text-dp-accent" />
        <h2>{{ t('duty.otherDuties.title') }}</h2>
      </div>
      <button @click="emit('close')" class="p-2 rounded-full hover-close-btn cursor-pointer">
        <X class="w-6 h-6 text-dp-text-primary" />
      </button>
    </div>

    <div class="px-3 sm:px-4 py-2 text-xs sm:text-sm bg-dp-accent/10 text-dp-accent dark:bg-dp-accent/20 dark:text-dp-accent-light">
      {{ t('duty.otherDuties.description', { count: maxSelections }) }}
    </div>

    <div class="modal-body-form-compact !space-y-0 max-h-[calc(90dvh-180px)] sm:max-h-[calc(90vh-180px)]">
      <div v-if="friends.length === 0" class="text-center py-8 text-dp-text-muted">
        {{ t('duty.otherDuties.empty') }}
      </div>

      <div v-else class="grid grid-cols-2 gap-2">
        <button
          v-for="friend in friends"
          :key="friend.id"
          type="button"
          :aria-pressed="isSelected(friend.id)"
          :disabled="!isSelected(friend.id) && (isTeamless(friend) || !canSelectMore)"
          @click="handleToggle(friend.id)"
          class="friend-item flex items-center gap-2 rounded-lg p-2 text-left"
          :class="{
            'friend-item-selected': isSelected(friend.id),
            'friend-item-disabled': !isSelected(friend.id) && (isTeamless(friend) || !canSelectMore),
          }"
        >
          <ProfileAvatar
            :member-id="friend.id"
            :name="friend.name"
            :has-profile-photo="friend.hasProfilePhoto"
            :profile-photo-version="friend.profilePhotoVersion"
            size="sm"
            class="friend-item-avatar"
          />

          <span class="flex min-w-0 flex-1 flex-col">
            <span class="friend-item-name truncate font-medium text-sm text-dp-text-primary">{{ friend.name }}</span>
            <span
              v-if="isTeamless(friend)"
              class="friend-item-team truncate text-xs text-dp-text-muted"
            >
              {{ t('duty.otherDuties.noTeam') }}
            </span>
          </span>

          <span
            v-if="isSelected(friend.id)"
            class="w-5 h-5 bg-dp-accent rounded-full flex items-center justify-center flex-shrink-0"
          >
            <Check class="w-3 h-3 text-dp-text-on-dark" />
          </span>
        </button>
      </div>
    </div>

    <div class="modal-footer modal-footer-safe">
      <div class="flex flex-col-reverse sm:flex-row items-stretch sm:items-center sm:justify-between gap-2">
        <span class="text-sm text-center sm:text-left text-dp-text-muted">
          {{ t('duty.otherDuties.selectionCount', { selected: selectedFriendIds.length, count: maxSelections }) }}
        </span>
        <div class="flex flex-col sm:flex-row items-stretch gap-2 sm:w-auto">
          <button
            v-if="hasSelection"
            type="button"
            @click="handleClear"
            class="inline-flex min-h-[44px] w-full items-center justify-center gap-1 rounded-lg border border-dp-border-secondary bg-dp-bg-secondary px-4 py-2 text-dp-text-primary transition hover:bg-dp-bg-hover hover:border-dp-border-hover cursor-pointer sm:w-auto"
          >
            <RotateCcw class="w-4 h-4" />
            <span>{{ t('friendTagSelector.clearTitle') }}</span>
          </button>
          <button
            type="button"
            @click="emit('close')"
            class="min-h-[44px] w-full sm:w-auto px-4 py-2 bg-dp-accent text-dp-text-on-dark rounded-lg hover:bg-dp-accent-hover transition cursor-pointer"
          >
            {{ t('common.actions.confirm') }}
          </button>
        </div>
      </div>
    </div>
  </BaseModal>
</template>
