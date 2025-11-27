<script setup lang="ts">
import { computed, toRef } from 'vue'
import { X, Users, Check } from 'lucide-vue-next'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'

interface Friend {
  id: number
  name: string
  profileImage?: string
}

interface Props {
  isOpen: boolean
  friends: Friend[]
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
.hover-bg:hover {
  background-color: var(--dp-bg-secondary);
}

.friend-item:hover {
  background-color: var(--dp-bg-tertiary);
}
</style>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @click.self="emit('close')"
    >
      <div class="rounded-lg shadow-xl w-full max-w-[95vw] sm:max-w-md max-h-[90dvh] sm:max-h-[90vh] overflow-hidden mx-2 sm:mx-4" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
        <!-- Header -->
        <div class="flex items-center justify-between p-3 sm:p-4" :style="{ backgroundColor: 'var(--dp-bg-tertiary)', borderBottom: '1px solid var(--dp-border-primary)' }">
          <div class="flex items-center gap-2">
            <Users class="w-5 h-5 text-blue-600" />
            <h2 class="text-base sm:text-lg font-bold" :style="{ color: 'var(--dp-text-primary)' }">함께보기</h2>
          </div>
          <button @click="emit('close')" class="p-2 rounded-full transition hover-bg-light">
            <X class="w-6 h-6" :style="{ color: 'var(--dp-text-primary)' }" />
          </button>
        </div>

        <!-- Description -->
        <div class="px-3 sm:px-4 py-2 bg-blue-50 text-xs sm:text-sm text-blue-700">
          친구의 근무표를 함께 볼 수 있습니다. (최대 {{ maxSelections }}명)
        </div>

        <!-- Content -->
        <div class="p-3 sm:p-4 overflow-y-auto max-h-[calc(90dvh-180px)] sm:max-h-[calc(90vh-180px)]">
          <div v-if="friends.length === 0" class="text-center py-8" :style="{ color: 'var(--dp-text-muted)' }">
            친구 목록이 없습니다.
          </div>

          <div v-else class="grid grid-cols-2 gap-2">
            <div
              v-for="friend in friends"
              :key="friend.id"
              @click="handleToggle(friend.id)"
              class="flex items-center gap-2 p-2 rounded-lg cursor-pointer transition"
              :class="{
                'bg-blue-50 border-2 border-blue-500': isSelected(friend.id),
                'border-2 border-transparent friend-item':
                  !isSelected(friend.id) && canSelectMore,
                'opacity-50 cursor-not-allowed border-2 border-transparent':
                  !isSelected(friend.id) && !canSelectMore,
              }"
              :style="!isSelected(friend.id) && canSelectMore ? { backgroundColor: 'var(--dp-bg-secondary)' } : {}"
            >
              <!-- Profile Image -->
              <div
                class="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0"
                :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }"
              >
                <img
                  v-if="friend.profileImage"
                  :src="friend.profileImage"
                  :alt="friend.name"
                  class="w-8 h-8 rounded-full object-cover"
                />
                <span v-else class="font-medium text-sm" :style="{ color: 'var(--dp-text-muted)' }">
                  {{ friend.name.charAt(0) }}
                </span>
              </div>

              <!-- Name -->
              <div class="flex-1 min-w-0">
                <span class="font-medium text-sm truncate block" :style="{ color: 'var(--dp-text-primary)' }">{{ friend.name }}</span>
              </div>

              <!-- Check icon -->
              <div
                v-if="isSelected(friend.id)"
                class="w-5 h-5 bg-blue-600 rounded-full flex items-center justify-center flex-shrink-0"
              >
                <Check class="w-3 h-3 text-white" />
              </div>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="p-3 sm:p-4 border-t" :style="{ borderColor: 'var(--dp-border-primary)' }">
          <div class="flex flex-col-reverse sm:flex-row items-stretch sm:items-center sm:justify-between gap-2">
            <span class="text-sm text-center sm:text-left" :style="{ color: 'var(--dp-text-muted)' }">
              {{ selectedFriendIds.length }} / {{ maxSelections }}명 선택됨
            </span>
            <button
              @click="emit('close')"
              class="w-full sm:w-auto px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
            >
              확인
            </button>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>
