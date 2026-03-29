<script setup lang="ts">
import { ref, watch } from 'vue'
import { X, Plus, Minus, RotateCcw, Lock, Unlock } from 'lucide-vue-next'
import { useI18n } from 'vue-i18n'
import BaseModal from '@/components/common/BaseModal.vue'
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

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save', dday: DDay): void
}>()

const { t } = useI18n()

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
  <BaseModal
    :is-open="isOpen"
    size="md"
    height="default"
    @close="handleClose"
  >
    <!-- Header -->
    <div class="modal-header">
      <h2>{{ dday ? t('duty.ddayModal.editTitle') : t('duty.ddayModal.addTitle') }}</h2>
      <button @click="handleClose" class="p-2 rounded-full hover-close-btn cursor-pointer">
        <X class="w-6 h-6 text-dp-text-primary" />
      </button>
    </div>

    <!-- Content -->
    <div class="modal-body-form-compact">
      <div>
        <label class="form-label">
          {{ t('duty.ddayModal.fields.title') }} <span class="text-dp-danger">*</span>
          <CharacterCounter :current="title.length" :max="30" />
        </label>
        <input
          v-model="title"
          type="text"
          maxlength="30"
          class="form-control"
          :placeholder="t('duty.ddayModal.placeholders.title')"
        />
      </div>

      <div>
        <label class="form-label">
          {{ t('duty.ddayModal.fields.date') }} <span class="text-dp-danger">*</span>
        </label>
        <input
          v-model="date"
          type="date"
          class="form-control"
        />
      </div>

      <!-- Quick Date Buttons -->
      <div class="flex justify-center gap-2">
        <button
          @click="addDays(-7)"
          class="date-adjust-btn flex items-center justify-center gap-1 px-3 py-1.5 text-xs rounded"
        >
          <Minus class="w-3 h-3" />
          {{ t('duty.ddayModal.quick.minusWeek') }}
        </button>
        <button
          @click="addDays(-1)"
          class="date-adjust-btn flex items-center justify-center gap-1 px-3 py-1.5 text-xs rounded"
        >
          <Minus class="w-3 h-3" />
          {{ t('duty.ddayModal.quick.minusDay') }}
        </button>
        <button
          @click="resetToToday"
          class="date-adjust-btn date-adjust-btn--today flex items-center justify-center gap-1 px-3 py-1.5 text-xs rounded"
        >
          <RotateCcw class="w-3 h-3" />
          {{ t('duty.ddayModal.quick.today') }}
        </button>
        <button
          @click="addDays(1)"
          class="date-adjust-btn flex items-center justify-center gap-1 px-3 py-1.5 text-xs rounded"
        >
          <Plus class="w-3 h-3" />
          {{ t('duty.ddayModal.quick.plusDay') }}
        </button>
        <button
          @click="addDays(7)"
          class="date-adjust-btn flex items-center justify-center gap-1 px-3 py-1.5 text-xs rounded"
        >
          <Plus class="w-3 h-3" />
          {{ t('duty.ddayModal.quick.plusWeek') }}
        </button>
      </div>

      <!-- Privacy Toggle -->
      <div class="flex items-center justify-between p-3 rounded-lg bg-dp-bg-secondary">
        <div class="flex items-center gap-2">
          <component :is="isPrivate ? Lock : Unlock" class="w-5 h-5 text-dp-text-secondary" />
          <span class="text-sm text-dp-text-primary">{{ t('visibility.labels.private') }}</span>
        </div>
        <button
          @click="isPrivate = !isPrivate"
          class="relative inline-flex h-6 w-11 items-center rounded-full transition cursor-pointer"
          :class="isPrivate ? 'bg-dp-accent' : 'bg-dp-border-secondary'"
        >
          <span
            class="inline-block h-4 w-4 transform rounded-full bg-dp-bg-primary transition"
            :class="isPrivate ? 'translate-x-6' : 'translate-x-1'"
          ></span>
        </button>
      </div>
    </div>

    <!-- Footer (sticky at bottom) -->
    <div class="modal-actions-compact modal-actions-end modal-footer-safe">
      <button
        @click="handleClose"
        class="flex-1 sm:flex-none px-4 py-2 rounded-lg transition btn-outline cursor-pointer"
      >
        {{ t('common.actions.cancel') }}
      </button>
      <button
        @click="handleSave"
        :disabled="!title.trim() || !date"
        class="flex-1 sm:flex-none px-4 py-2 bg-dp-accent text-dp-text-on-dark rounded-lg hover:bg-dp-accent-hover transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
      >
        {{ t('duty.ddayModal.save') }}
      </button>
    </div>
  </BaseModal>
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
  box-shadow: var(--dp-shadow-sm);
}

.date-adjust-btn:active {
  transform: scale(0.92);
  box-shadow: inset 0 1px 3px color-mix(in srgb, var(--dp-overlay-scrim) 30%, transparent);
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
