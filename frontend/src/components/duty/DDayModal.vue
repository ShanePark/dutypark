<script setup lang="ts">
import { ref, watch, toRef } from 'vue'
import { X, Plus, Minus, RotateCcw, Lock, Unlock } from 'lucide-vue-next'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
import CharacterCounter from '@/components/common/CharacterCounter.vue'

interface DDay {
  id?: number
  title: string
  date: string
  isPrivate: boolean
  calc?: number
  dDayText?: string
}

interface Props {
  isOpen: boolean
  dday?: DDay | null
}

const props = defineProps<Props>()

useBodyScrollLock(toRef(props, 'isOpen'))

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save', dday: DDay): void
}>()

useEscapeKey(toRef(props, 'isOpen'), () => emit('close'))

const title = ref('')
const date = ref('')
const isPrivate = ref(false)

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      if (props.dday) {
        title.value = props.dday.title
        date.value = props.dday.date
        isPrivate.value = props.dday.isPrivate
      } else {
        title.value = ''
        date.value = new Date().toISOString().slice(0, 10)
        isPrivate.value = false
      }
    }
  }
)

function addDays(days: number) {
  if (date.value) {
    const currentDate = new Date(date.value)
    currentDate.setDate(currentDate.getDate() + days)
    date.value = currentDate.toISOString().slice(0, 10)
  }
}

function resetToToday() {
  date.value = new Date().toISOString().slice(0, 10)
}

function handleSave() {
  if (!title.value.trim() || !date.value) {
    return
  }
  emit('save', {
    id: props.dday?.id,
    title: title.value.trim(),
    date: date.value,
    isPrivate: isPrivate.value,
  })
}

function handleClose() {
  emit('close')
}

const isEditMode = props.dday !== null && props.dday !== undefined
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @click.self="handleClose"
    >
      <div class="rounded-lg shadow-xl w-full max-w-[95vw] sm:max-w-md max-h-[90dvh] sm:max-h-[90vh] mx-2 sm:mx-4 flex flex-col" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
        <!-- Header -->
        <div class="modal-header flex-shrink-0">
          <h2>{{ dday ? '디데이 수정' : '디데이 추가' }}</h2>
          <button @click="handleClose" class="p-2 rounded-full transition hover-bg-light cursor-pointer">
            <X class="w-6 h-6" :style="{ color: 'var(--dp-text-primary)' }" />
          </button>
        </div>

        <!-- Content -->
        <div class="p-3 sm:p-4 space-y-4 overflow-y-auto overflow-x-hidden flex-1 min-h-0">
          <div>
            <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
              제목 <span class="text-red-500">*</span>
              <CharacterCounter :current="title.length" :max="30" />
            </label>
            <input
              v-model="title"
              type="text"
              maxlength="30"
              class="w-full px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
              placeholder="디데이 제목을 입력하세요"
            />
          </div>

          <div>
            <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
              날짜 <span class="text-red-500">*</span>
            </label>
            <input
              v-model="date"
              type="date"
              class="w-full px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
            />
          </div>

          <!-- Quick Date Buttons -->
          <div class="flex justify-center gap-2">
            <button
              @click="addDays(-7)"
              class="date-adjust-btn flex items-center justify-center gap-1 px-3 py-1.5 text-xs rounded"
            >
              <Minus class="w-3 h-3" />
              7일
            </button>
            <button
              @click="addDays(-1)"
              class="date-adjust-btn flex items-center justify-center gap-1 px-3 py-1.5 text-xs rounded"
            >
              <Minus class="w-3 h-3" />
              1일
            </button>
            <button
              @click="resetToToday"
              class="date-adjust-btn date-adjust-btn--today flex items-center justify-center gap-1 px-3 py-1.5 text-xs rounded"
            >
              <RotateCcw class="w-3 h-3" />
              오늘
            </button>
            <button
              @click="addDays(1)"
              class="date-adjust-btn flex items-center justify-center gap-1 px-3 py-1.5 text-xs rounded"
            >
              <Plus class="w-3 h-3" />
              1일
            </button>
            <button
              @click="addDays(7)"
              class="date-adjust-btn flex items-center justify-center gap-1 px-3 py-1.5 text-xs rounded"
            >
              <Plus class="w-3 h-3" />
              7일
            </button>
          </div>

          <!-- Privacy Toggle -->
          <div class="flex items-center justify-between p-3 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
            <div class="flex items-center gap-2">
              <component :is="isPrivate ? Lock : Unlock" class="w-5 h-5" :style="{ color: 'var(--dp-text-secondary)' }" />
              <span class="text-sm" :style="{ color: 'var(--dp-text-primary)' }">비공개</span>
            </div>
            <button
              @click="isPrivate = !isPrivate"
              class="relative inline-flex h-6 w-11 items-center rounded-full transition cursor-pointer"
              :class="isPrivate ? 'bg-blue-600' : 'bg-gray-300'"
            >
              <span
                class="inline-block h-4 w-4 transform rounded-full bg-white transition"
                :class="isPrivate ? 'translate-x-6' : 'translate-x-1'"
              ></span>
            </button>
          </div>
        </div>

        <!-- Footer (sticky at bottom) -->
        <div class="p-3 sm:p-4 flex-shrink-0 flex flex-row gap-2 justify-end" :style="{ borderTop: '1px solid var(--dp-border-primary)' }">
          <button
            @click="handleClose"
            class="flex-1 sm:flex-none px-4 py-2 rounded-lg transition btn-outline cursor-pointer"
          >
            취소
          </button>
          <button
            @click="handleSave"
            :disabled="!title.trim() || !date"
            class="flex-1 sm:flex-none px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
          >
            저장
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.date-adjust-btn {
  cursor: pointer;
  background-color: var(--dp-bg-tertiary);
  color: var(--dp-text-primary);
  border: 1px solid transparent;
  transition: all 0.15s ease;
  position: relative;
  overflow: hidden;
}

.date-adjust-btn:hover {
  border-color: var(--dp-border-secondary);
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.date-adjust-btn:active {
  transform: scale(0.92);
  box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.15);
}

.date-adjust-btn--today {
  background-color: var(--dp-accent-bg);
  color: var(--dp-accent-text);
  font-weight: 500;
}

.date-adjust-btn--today:hover {
  filter: brightness(0.95);
}
</style>
