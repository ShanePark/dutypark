<script setup lang="ts">
import { computed, toRef } from 'vue'
import { X, Users, Check } from 'lucide-vue-next'
import type { TaggableFriend } from '@/types'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'

interface Props {
  isOpen: boolean
  friends: TaggableFriend[]
  selectedFriendIds: number[]
  maxSelections?: number
}

const props = withDefaults(defineProps<Props>(), {
  maxSelections: 3,
})

useBodyScrollLock(toRef(props, 'isOpen'))

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'toggle', friendId: number): void
}>()

useEscapeKey(toRef(props, 'isOpen'), () => emit('close'))

const canSelectMore = computed(() => {
  return props.selectedFriendIds.length < props.maxSelections
})

function isSelected(friendId: number) {
  return props.selectedFriendIds.includes(friendId)
}

function handleToggle(friendId: number) {
  if (!isSelected(friendId) && !canSelectMore.value) {
    return
  }
  emit('toggle', friendId)
}
</script>

<style scoped>
.friend-item {
  transition: all 0.15s ease;
}

.friend-item:hover {
  background-color: var(--dp-bg-tertiary);
  transform: translateY(-1px);
  box-shadow: var(--dp-shadow-sm);
}

.friend-item-disabled {
  transition: all 0.15s ease;
}

.friend-item-disabled:hover {
  background-color: var(--dp-bg-tertiary);
}
</style>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center bg-dp-overlay-dark/50"
      @click.self="emit('close')"
    >
      <div class="modal-container max-w-[95vw] sm:max-w-md max-h-[90dvh] sm:max-h-[90vh]">
        <!-- Header -->
        <div class="flex items-center justify-between p-3 sm:p-4 bg-dp-bg-tertiary border-b border-dp-border-primary">
          <div class="flex items-center gap-2">
            <Users class="w-5 h-5 text-dp-accent" />
            <h2 class="text-base sm:text-lg font-bold text-dp-text-primary">함께보기</h2>
          </div>
          <button @click="emit('close')" class="p-2 rounded-full hover-close-btn cursor-pointer">
            <X class="w-6 h-6 text-dp-text-primary" />
          </button>
        </div>

        <!-- Description -->
        <div class="px-3 sm:px-4 py-2 text-xs sm:text-sm bg-dp-accent/10 text-dp-accent dark:bg-dp-accent/20 dark:text-dp-accent-light">
          친구의 근무표를 함께 볼 수 있습니다. (최대 {{ maxSelections }}명)
        </div>

        <!-- Content -->
        <div class="p-3 sm:p-4 overflow-y-auto max-h-[calc(90dvh-180px)] sm:max-h-[calc(90vh-180px)]">
          <div v-if="friends.length === 0" class="text-center py-8 text-dp-text-muted">
            친구 목록이 없습니다.
          </div>

          <div v-else class="grid grid-cols-2 gap-2">
            <div
              v-for="friend in friends"
              :key="friend.id"
              @click="handleToggle(friend.id)"
              class="flex items-center gap-2 p-2 rounded-lg cursor-pointer transition"
              :class="{
                'bg-dp-accent/15 dark:bg-dp-accent/25 border-2 border-dp-accent-border': isSelected(friend.id),
                'border-2 border-transparent friend-item':
                  !isSelected(friend.id) && canSelectMore,
                'opacity-50 cursor-not-allowed border-2 border-transparent friend-item-disabled':
                  !isSelected(friend.id) && !canSelectMore,
              }"
              :style="!isSelected(friend.id) && canSelectMore ? { backgroundColor: 'var(--dp-bg-secondary)' } : {}"
            >
              <!-- Profile Image -->
              <ProfileAvatar
                :member-id="friend.id"
                :name="friend.name"
                :has-profile-photo="friend.hasProfilePhoto"
                :profile-photo-version="friend.profilePhotoVersion"
                size="sm"
              />

              <!-- Name -->
              <div class="flex-1 min-w-0">
                <span class="font-medium text-sm truncate block text-dp-text-primary">{{ friend.name }}</span>
              </div>

              <!-- Check icon -->
              <div
                v-if="isSelected(friend.id)"
                class="w-5 h-5 bg-dp-accent rounded-full flex items-center justify-center flex-shrink-0"
              >
                <Check class="w-3 h-3 text-dp-text-on-dark" />
              </div>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="p-3 sm:p-4 border-t border-dp-border-primary">
          <div class="flex flex-col-reverse sm:flex-row items-stretch sm:items-center sm:justify-between gap-2">
            <span class="text-sm text-center sm:text-left text-dp-text-muted">
              {{ selectedFriendIds.length }} / {{ maxSelections }}명 선택됨
            </span>
            <button
              @click="emit('close')"
              class="w-full sm:w-auto px-4 py-2 bg-dp-accent text-dp-text-on-dark rounded-lg hover:bg-dp-accent-hover transition cursor-pointer"
            >
              확인
            </button>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>
