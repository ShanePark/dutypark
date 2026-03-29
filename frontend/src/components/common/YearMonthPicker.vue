<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { ChevronLeft, ChevronRight } from 'lucide-vue-next'
import BaseModal from '@/components/common/BaseModal.vue'

const props = defineProps<{
  isOpen: boolean
  currentYear: number
  currentMonth: number
}>()

const emit = defineEmits<{
  close: []
  select: [year: number, month: number]
  goToThisMonth: []
}>()

const { t, locale } = useI18n()
const pickerYear = ref(props.currentYear)
const monthFormatter = computed(() => new Intl.DateTimeFormat(locale.value, { month: 'long' }))
const dateFormatter = computed(() => new Intl.DateTimeFormat(locale.value, { year: 'numeric', month: 'long' }))
const monthNames = computed(() =>
  Array.from({ length: 12 }, (_, index) => monthFormatter.value.format(new Date(2024, index, 1))),
)

// Sync pickerYear when modal opens
watch(() => props.isOpen, (open) => {
  if (open) {
    pickerYear.value = props.currentYear
  }
})

function selectYearMonth(month: number) {
  emit('select', pickerYear.value, month)
}

function handleGoToThisMonth() {
  emit('goToThisMonth')
}
</script>

<template>
  <BaseModal
    :is-open="isOpen"
    size="sm"
    height="fit"
    rounded
    panel-class="border border-dp-border-primary"
    @close="emit('close')"
  >
    <div class="modal-header">
      <button
        @click="pickerYear--"
        class="calendar-nav-btn p-2 rounded-full cursor-pointer"
        :aria-label="t('common.calendar.previousYear')"
      >
        <ChevronLeft class="w-6 h-6 sm:w-5 sm:h-5" />
      </button>
      <span class="text-xl font-bold text-dp-text-primary">{{ t('common.calendar.yearLabel', { year: pickerYear }) }}</span>
      <button
        @click="pickerYear++"
        class="calendar-nav-btn p-2 rounded-full cursor-pointer"
        :aria-label="t('common.calendar.nextYear')"
      >
        <ChevronRight class="w-6 h-6 sm:w-5 sm:h-5" />
      </button>
    </div>

    <div class="modal-body-form-compact !space-y-0">
      <div class="grid grid-cols-4 gap-1.5 sm:gap-2">
        <button
          v-for="(name, idx) in monthNames"
          :key="idx"
          @click="selectYearMonth(idx + 1)"
          class="py-2.5 sm:py-3 px-1.5 sm:px-2 rounded-lg text-sm font-medium transition cursor-pointer"
          :class="
            pickerYear === currentYear && idx + 1 === currentMonth
              ? 'bg-dp-accent text-dp-text-on-dark'
              : 'month-btn'
          "
          :style="
            pickerYear === currentYear && idx + 1 === currentMonth
              ? {}
              : { color: 'var(--dp-text-secondary)' }
          "
        >
          {{ name }}
        </button>
      </div>
    </div>

    <div class="modal-actions modal-footer-safe">
      <button
        @click="handleGoToThisMonth"
        class="flex-[3] px-3 sm:px-4 py-2 bg-dp-accent hover:bg-dp-accent-hover rounded-lg text-dp-text-on-dark font-medium transition text-sm cursor-pointer"
      >
        {{ t('common.calendar.thisMonth', { date: dateFormatter.format(new Date()) }) }}
      </button>
      <button
        @click="emit('close')"
        class="close-btn flex-1 px-3 sm:px-4 py-2 rounded-lg font-medium transition text-sm cursor-pointer bg-dp-bg-tertiary text-dp-text-secondary"
      >
        {{ t('common.actions.close') }}
      </button>
    </div>
  </BaseModal>
</template>
