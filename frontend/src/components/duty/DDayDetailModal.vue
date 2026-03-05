<script setup lang="ts">
import { computed, toRef } from 'vue'
import { X, Star, Pencil, Trash2, Lock, CalendarCheck } from 'lucide-vue-next'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'

interface DDay {
  id: number
  title: string
  date: string
  isPrivate: boolean
  calc: number
  dDayText: string
}

interface Props {
  isOpen: boolean
  dday: DDay | null
  isPinned: boolean
  canEdit: boolean
}

const props = defineProps<Props>()

useBodyScrollLock(toRef(props, 'isOpen'))

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'edit', dday: DDay): void
  (e: 'delete', dday: DDay): void
  (e: 'toggle-pin', dday: DDay): void
}>()

useEscapeKey(toRef(props, 'isOpen'), () => emit('close'))

function handleClose() {
  emit('close')
}

function handleEdit() {
  if (props.dday) {
    emit('edit', props.dday)
  }
}

function handleDelete() {
  if (props.dday) {
    emit('delete', props.dday)
  }
}

function handleTogglePin() {
  if (props.dday) {
    emit('toggle-pin', props.dday)
  }
}

// Format date to Korean style
const formattedDate = computed(() => {
  if (!props.dday) return ''
  const date = new Date(props.dday.date)
  return date.toLocaleDateString('ko-KR', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    weekday: 'long',
  })
})

// Get D-Day badge color based on calc value
const ddayBadgeClass = computed(() => {
  if (!props.dday) return ''
  const calc = props.dday.calc

  if (calc === 0) {
    // D-DAY
    return 'dday-badge-today'
  } else if (calc < 0) {
    // D+ (past)
    return 'dday-badge-past'
  } else if (calc <= 3) {
    // D-1 to D-3 (upcoming)
    return `dday-badge-upcoming-${calc}`
  } else {
    // D-4 or more
    return 'dday-badge-future'
  }
})
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen && dday"
      class="fixed inset-0 z-50 flex items-center justify-center bg-dp-overlay-dark/50"
      @click.self="handleClose"
    >
      <div class="modal-container modal-container-rounded max-w-[95vw] sm:max-w-md max-h-[90dvh] sm:max-h-[90vh]">
        <!-- Header -->
        <div class="modal-header">
          <h2>디데이 상세</h2>
          <button
            @click="handleClose"
            class="p-2 rounded-full transition hover-bg-light cursor-pointer"
          >
            <X class="w-5 h-5 text-dp-text-primary" />
          </button>
        </div>

        <!-- Content -->
        <div class="p-5 overflow-y-auto overflow-x-hidden flex-1 min-h-0">
          <!-- D-Day Badge -->
          <div class="flex items-center justify-center mb-5">
            <div
              class="inline-flex items-center px-6 py-3 rounded-full text-2xl font-bold shadow-lg"
              :class="ddayBadgeClass"
            >
              {{ dday.dDayText }}
            </div>
          </div>

          <!-- Title -->
          <div class="mb-4">
            <label class="block text-xs font-medium mb-1 text-dp-text-muted">
              제목
            </label>
            <p class="text-lg flex items-center gap-2 text-dp-text-primary">
              <Lock v-if="dday.isPrivate" class="w-4 h-4 flex-shrink-0 text-dp-text-muted" />
              {{ dday.title }}
            </p>
          </div>

          <!-- Date -->
          <div class="mb-4">
            <label class="block text-xs font-medium mb-1 text-dp-text-muted">
              날짜
            </label>
            <p class="text-base flex items-center gap-2 text-dp-text-primary">
              <CalendarCheck class="w-4 h-4 text-dp-text-muted" />
              {{ formattedDate }}
            </p>
          </div>

          <!-- Pin Status -->
          <div
            class="flex items-center justify-between p-3 rounded-lg mb-4 bg-dp-bg-secondary"
          >
            <div class="flex items-center gap-2">
              <Star
                class="w-5 h-5"
                :class="isPinned ? 'text-dp-warning fill-dp-warning' : ''"
                :style="!isPinned ? { color: 'var(--dp-text-muted)' } : {}"
              />
              <span class="text-sm text-dp-text-primary">
                {{ isPinned ? '캘린더에 고정됨' : '캘린더에 고정하기' }}
              </span>
            </div>
            <button
              @click="handleTogglePin"
              class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors cursor-pointer"
              :class="isPinned ? 'bg-dp-warning' : 'bg-dp-border-secondary'"
            >
              <span
                class="inline-block h-4 w-4 transform rounded-full bg-dp-bg-primary transition"
                :class="isPinned ? 'translate-x-6' : 'translate-x-1'"
              ></span>
            </button>
          </div>
        </div>

        <!-- Footer (sticky at bottom) -->
        <div
          class="p-4 flex-shrink-0 flex justify-between gap-2 border-t border-dp-border-primary"
        >
          <div class="flex gap-2">
            <button
              v-if="canEdit"
              @click="handleEdit"
              class="flex items-center gap-1.5 px-3 py-2 rounded-lg transition btn-outline cursor-pointer"
            >
              <Pencil class="w-4 h-4" />
              수정
            </button>
            <button
              v-if="canEdit"
              @click="handleDelete"
              class="flex items-center gap-1.5 px-3 py-2 rounded-lg text-dp-danger border border-dp-danger-border hover:bg-dp-danger-soft transition cursor-pointer"
            >
              <Trash2 class="w-4 h-4" />
              삭제
            </button>
          </div>
          <button
            @click="handleClose"
            class="px-4 py-2 rounded-lg transition btn-outline cursor-pointer"
          >
            닫기
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
