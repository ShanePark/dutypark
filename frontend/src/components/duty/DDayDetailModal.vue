<script setup lang="ts">
import { computed } from 'vue'
import { X, Star, Pencil, Trash2, Lock, CalendarCheck } from 'lucide-vue-next'
import { useI18n } from 'vue-i18n'
import BaseModal from '@/components/common/BaseModal.vue'

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

const { t, locale } = useI18n()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'edit', dday: DDay): void
  (e: 'delete', dday: DDay): void
  (e: 'toggle-pin', dday: DDay): void
}>()

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
  return date.toLocaleDateString(locale.value, {
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
  <BaseModal
    :is-open="isOpen && !!dday"
    size="md"
    height="default"
    rounded
    @close="handleClose"
  >
    <template v-if="dday">
      <div class="modal-header">
        <h2>{{ t('duty.ddayDetail.title') }}</h2>
        <button
          @click="handleClose"
          class="p-2 rounded-full hover-close-btn cursor-pointer"
        >
          <X class="w-5 h-5 text-dp-text-primary" />
        </button>
      </div>

      <div class="modal-body-form-lg">
        <div class="flex items-center justify-center">
          <div
            class="inline-flex items-center px-6 py-3 rounded-full text-2xl font-bold shadow-lg"
            :class="ddayBadgeClass"
          >
            {{ dday.dDayText }}
          </div>
        </div>

        <div>
          <label class="block text-xs font-medium mb-1 text-dp-text-muted">
            {{ t('duty.ddayDetail.labels.title') }}
          </label>
          <p class="text-lg flex items-center gap-2 text-dp-text-primary">
            <Lock v-if="dday.isPrivate" class="w-4 h-4 flex-shrink-0 text-dp-text-muted" />
            {{ dday.title }}
          </p>
        </div>

        <div>
          <label class="block text-xs font-medium mb-1 text-dp-text-muted">
            {{ t('duty.ddayDetail.labels.date') }}
          </label>
          <p class="text-base flex items-center gap-2 text-dp-text-primary">
            <CalendarCheck class="w-4 h-4 text-dp-text-muted" />
            {{ formattedDate }}
          </p>
        </div>

        <div class="flex items-center justify-between p-3 rounded-lg bg-dp-bg-secondary">
          <div class="flex items-center gap-2">
            <Star
              class="w-5 h-5"
              :class="isPinned ? 'text-dp-warning fill-dp-warning' : ''"
              :style="!isPinned ? { color: 'var(--dp-text-muted)' } : {}"
            />
            <span class="text-sm text-dp-text-primary">
              {{ isPinned ? t('duty.ddayDetail.pinEnabled') : t('duty.ddayDetail.pinDisabled') }}
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

      <div class="modal-actions modal-actions-between modal-footer-safe">
        <div class="flex gap-2">
          <button
            v-if="canEdit"
            @click="handleEdit"
            class="flex items-center gap-1.5 px-3 py-2 rounded-lg transition btn-outline cursor-pointer"
          >
            <Pencil class="w-4 h-4" />
            {{ t('duty.ddayDetail.edit') }}
          </button>
          <button
            v-if="canEdit"
            @click="handleDelete"
            class="flex items-center gap-1.5 px-3 py-2 rounded-lg text-dp-danger border border-dp-danger-border hover:bg-dp-danger-soft transition cursor-pointer"
          >
            <Trash2 class="w-4 h-4" />
            {{ t('common.actions.delete') }}
          </button>
        </div>
        <button
          @click="handleClose"
          class="px-4 py-2 rounded-lg transition btn-outline cursor-pointer"
        >
          {{ t('common.actions.close') }}
        </button>
      </div>
    </template>
  </BaseModal>
</template>
