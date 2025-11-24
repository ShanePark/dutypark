<script setup lang="ts">
import { ref, watch } from 'vue'
import { X, Plus, Minus, RotateCcw, Lock, Unlock } from 'lucide-vue-next'

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

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save', dday: DDay): void
}>()

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
      <div class="bg-white rounded-lg shadow-xl w-full max-w-md overflow-hidden">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-gray-200">
          <h2 class="text-lg font-bold">{{ dday ? '디데이 수정' : '디데이 추가' }}</h2>
          <button @click="handleClose" class="p-1 hover:bg-gray-100 rounded-full transition">
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- Content -->
        <div class="p-4 space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              제목 <span class="text-red-500">*</span>
            </label>
            <input
              v-model="title"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="디데이 제목을 입력하세요"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              날짜 <span class="text-red-500">*</span>
            </label>
            <input
              v-model="date"
              type="date"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>

          <!-- Quick Date Buttons -->
          <div class="flex flex-wrap gap-2">
            <button
              @click="addDays(-30)"
              class="flex items-center gap-1 px-2 py-1 text-xs bg-gray-100 hover:bg-gray-200 rounded transition"
            >
              <Minus class="w-3 h-3" />
              30일
            </button>
            <button
              @click="addDays(-7)"
              class="flex items-center gap-1 px-2 py-1 text-xs bg-gray-100 hover:bg-gray-200 rounded transition"
            >
              <Minus class="w-3 h-3" />
              7일
            </button>
            <button
              @click="addDays(-1)"
              class="flex items-center gap-1 px-2 py-1 text-xs bg-gray-100 hover:bg-gray-200 rounded transition"
            >
              <Minus class="w-3 h-3" />
              1일
            </button>
            <button
              @click="resetToToday"
              class="flex items-center gap-1 px-2 py-1 text-xs bg-blue-100 hover:bg-blue-200 text-blue-700 rounded transition"
            >
              <RotateCcw class="w-3 h-3" />
              오늘
            </button>
            <button
              @click="addDays(1)"
              class="flex items-center gap-1 px-2 py-1 text-xs bg-gray-100 hover:bg-gray-200 rounded transition"
            >
              <Plus class="w-3 h-3" />
              1일
            </button>
            <button
              @click="addDays(7)"
              class="flex items-center gap-1 px-2 py-1 text-xs bg-gray-100 hover:bg-gray-200 rounded transition"
            >
              <Plus class="w-3 h-3" />
              7일
            </button>
            <button
              @click="addDays(30)"
              class="flex items-center gap-1 px-2 py-1 text-xs bg-gray-100 hover:bg-gray-200 rounded transition"
            >
              <Plus class="w-3 h-3" />
              30일
            </button>
          </div>

          <!-- Privacy Toggle -->
          <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
            <div class="flex items-center gap-2">
              <component :is="isPrivate ? Lock : Unlock" class="w-5 h-5 text-gray-500" />
              <span class="text-sm text-gray-700">비공개</span>
            </div>
            <button
              @click="isPrivate = !isPrivate"
              class="relative inline-flex h-6 w-11 items-center rounded-full transition"
              :class="isPrivate ? 'bg-blue-600' : 'bg-gray-300'"
            >
              <span
                class="inline-block h-4 w-4 transform rounded-full bg-white transition"
                :class="isPrivate ? 'translate-x-6' : 'translate-x-1'"
              ></span>
            </button>
          </div>
        </div>

        <!-- Footer -->
        <div class="p-4 border-t border-gray-200 flex justify-end gap-2">
          <button
            @click="handleClose"
            class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition"
          >
            취소
          </button>
          <button
            @click="handleSave"
            :disabled="!title.trim() || !date"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
          >
            저장
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
