<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { X, Plus, Minus, RotateCcw, Lock, Unlock, Loader2 } from 'lucide-vue-next'
import { useI18n } from 'vue-i18n'
import BaseModal from '@/components/common/BaseModal.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import DatePickerField from '@/components/common/DatePickerField.vue'
import { formatDateOnly, parseDateOnly } from '@/utils/date'

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
  isSubmitting?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  isSubmitting: false,
})

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save', dday: DDay): void
}>()

const { t } = useI18n()

const title = ref('')
const date = ref('')
const isPrivate = ref(false)

const isTitleMissing = computed(() => !title.value.trim())
const isDateMissing = computed(() => !date.value)

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
        date.value = formatDateOnly(new Date())
        isPrivate.value = false
      }
    }
  }
)

function addDays(days: number) {
  if (date.value) {
    const currentDate = parseDateOnly(date.value)
    currentDate.setDate(currentDate.getDate() + days)
    date.value = formatDateOnly(currentDate)
  }
}

function resetToToday() {
  date.value = formatDateOnly(new Date())
}

function handleSave() {
  if (props.isSubmitting || !title.value.trim() || !date.value) {
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
  if (props.isSubmitting) {
    return
  }
  emit('close')
}
</script>

<template>
  <BaseModal
    :is-open="isOpen"
    size="md"
    height="default"
    :close-on-backdrop="!isSubmitting"
    :close-on-escape="!isSubmitting"
    @close="handleClose"
  >
    <div class="modal-header">
      <h2>{{ dday ? t('duty.ddayModal.editTitle') : t('duty.ddayModal.addTitle') }}</h2>
      <button @click="handleClose" :disabled="isSubmitting" class="p-2 rounded-full hover-close-btn cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed">
        <X class="w-6 h-6 text-dp-text-primary" />
      </button>
    </div>

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
          :aria-invalid="isTitleMissing"
          :disabled="isSubmitting"
        />
      </div>

      <div>
        <label class="form-label">
          {{ t('duty.ddayModal.fields.date') }} <span class="text-dp-danger">*</span>
        </label>
        <DatePickerField
          v-model="date"
          :invalid="isDateMissing"
          :aria-label="t('duty.ddayModal.fields.date')"
          :disabled="isSubmitting"
        />
      </div>

      <div class="flex justify-center gap-2">
        <button
          @click="addDays(-7)"
          :disabled="isSubmitting"
          class="date-adjust-btn flex items-center justify-center gap-1 px-3 py-1.5 text-xs rounded"
        >
          <Minus class="w-3 h-3" />
          {{ t('duty.ddayModal.quick.minusWeek') }}
        </button>
        <button
          @click="addDays(-1)"
          :disabled="isSubmitting"
          class="date-adjust-btn flex items-center justify-center gap-1 px-3 py-1.5 text-xs rounded"
        >
          <Minus class="w-3 h-3" />
          {{ t('duty.ddayModal.quick.minusDay') }}
        </button>
        <button
          @click="resetToToday"
          :disabled="isSubmitting"
          class="date-adjust-btn date-adjust-btn--today flex items-center justify-center gap-1 px-3 py-1.5 text-xs rounded"
        >
          <RotateCcw class="w-3 h-3" />
          {{ t('duty.ddayModal.quick.today') }}
        </button>
        <button
          @click="addDays(1)"
          :disabled="isSubmitting"
          class="date-adjust-btn flex items-center justify-center gap-1 px-3 py-1.5 text-xs rounded"
        >
          <Plus class="w-3 h-3" />
          {{ t('duty.ddayModal.quick.plusDay') }}
        </button>
        <button
          @click="addDays(7)"
          :disabled="isSubmitting"
          class="date-adjust-btn flex items-center justify-center gap-1 px-3 py-1.5 text-xs rounded"
        >
          <Plus class="w-3 h-3" />
          {{ t('duty.ddayModal.quick.plusWeek') }}
        </button>
      </div>

      <div class="flex items-center justify-between p-3 rounded-lg bg-dp-bg-secondary">
        <div class="flex items-center gap-2">
          <component :is="isPrivate ? Lock : Unlock" class="w-5 h-5 text-dp-text-secondary" />
          <span class="text-sm text-dp-text-primary">{{ t('visibility.labels.private') }}</span>
        </div>
        <button
          @click="isPrivate = !isPrivate"
          :disabled="isSubmitting"
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

    <div class="modal-actions-compact modal-actions-end modal-footer-safe">
      <button
        @click="handleClose"
        :disabled="isSubmitting"
        class="flex-1 sm:flex-none px-4 py-2 rounded-lg transition btn-outline cursor-pointer"
      >
        {{ t('common.actions.close') }}
      </button>
      <button
        @click="handleSave"
        :disabled="isSubmitting || isTitleMissing || isDateMissing"
        class="flex-1 sm:flex-none px-4 py-2 bg-dp-accent text-dp-text-on-dark rounded-lg hover:bg-dp-accent-hover transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer flex items-center justify-center gap-2"
      >
        <Loader2 v-if="isSubmitting" class="w-4 h-4 animate-spin" />
        {{ isSubmitting ? t('duty.ddayModal.saving') : t('duty.ddayModal.save') }}
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
