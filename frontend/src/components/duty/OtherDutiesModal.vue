<script setup lang="ts">
import { computed } from 'vue'
import { X, Users, Check } from 'lucide-vue-next'

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

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @click.self="emit('close')"
    >
      <div class="bg-white rounded-lg shadow-xl w-full max-w-[95vw] sm:max-w-md max-h-[90dvh] sm:max-h-[90vh] overflow-hidden mx-2 sm:mx-4">
        <!-- Header -->
        <div class="flex items-center justify-between p-3 sm:p-4 border-b border-gray-200">
          <div class="flex items-center gap-2">
            <Users class="w-5 h-5 text-blue-600" />
            <h2 class="text-base sm:text-lg font-bold">함께보기</h2>
          </div>
          <button @click="emit('close')" class="p-2 hover:bg-gray-100 rounded-full transition">
            <X class="w-6 h-6" />
          </button>
        </div>

        <!-- Description -->
        <div class="px-3 sm:px-4 py-2 bg-blue-50 text-xs sm:text-sm text-blue-700">
          친구의 근무표를 함께 볼 수 있습니다. (최대 {{ maxSelections }}명)
        </div>

        <!-- Content -->
        <div class="p-3 sm:p-4 overflow-y-auto max-h-[calc(90dvh-180px)] sm:max-h-[calc(90vh-180px)]">
          <div v-if="friends.length === 0" class="text-center py-8 text-gray-400">
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
                'bg-gray-50 hover:bg-gray-100 border-2 border-transparent':
                  !isSelected(friend.id) && canSelectMore,
                'bg-gray-50 opacity-50 cursor-not-allowed border-2 border-transparent':
                  !isSelected(friend.id) && !canSelectMore,
              }"
            >
              <!-- Profile Image -->
              <div
                class="w-8 h-8 rounded-full bg-gray-200 flex items-center justify-center flex-shrink-0"
              >
                <img
                  v-if="friend.profileImage"
                  :src="friend.profileImage"
                  :alt="friend.name"
                  class="w-8 h-8 rounded-full object-cover"
                />
                <span v-else class="text-gray-500 font-medium text-sm">
                  {{ friend.name.charAt(0) }}
                </span>
              </div>

              <!-- Name -->
              <div class="flex-1 min-w-0">
                <span class="font-medium text-sm truncate block">{{ friend.name }}</span>
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
        <div class="p-3 sm:p-4 border-t border-gray-200">
          <div class="flex flex-col-reverse sm:flex-row items-stretch sm:items-center sm:justify-between gap-2">
            <span class="text-sm text-gray-500 text-center sm:text-left">
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
