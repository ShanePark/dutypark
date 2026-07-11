<script setup lang="ts">
import { computed } from 'vue'
import { ChevronLeft, ChevronRight, FileSpreadsheet, Loader2, PencilLine, RotateCcw, Users, X } from 'lucide-vue-next'
import { useI18n } from 'vue-i18n'
import { isLightColor } from '@/utils/color'
import type { DutyType, DutyTypeWithCount } from '@/views/duty/dutyViewTypes'
import type { DutySource } from '@/types'
import { dutySourcePatternLabelKey, isInheritedDutySource } from '@/utils/dutySource'

const props = defineProps<{
  batchEditMode: boolean
  dutyTypes: DutyType[]
  dutyTypesWithCount: DutyTypeWithCount[]
  isLoadingDuties: boolean
  focusedDay: number | null
  focusedDayDutyType: string | null
  focusedDayDutySource: DutySource | null
  lastDayInMonth: number
  canEdit: boolean
  canEditMyCalendar: boolean
  otherDutyCount: number
  isOtherDutyActive: boolean
  teamHasDutyBatchTemplate: boolean
}>()

const emit = defineEmits<{
  (e: 'toggle-other-duties'): void
  (e: 'clear-other-duties'): void
  (e: 'show-batch-update-modal'): void
  (e: 'toggle-batch-edit', value: boolean): void
  (e: 'show-excel-upload-modal'): void
  (e: 'quick-duty-change', dutyTypeId: number | null): void
  (e: 'restore-pattern'): void
  (e: 'update:focusedDay', value: number): void
}>()

const { t } = useI18n()

const focusedDayValue = computed(() => props.focusedDay ?? 1)
const patternButtonLabel = computed(() => t(dutySourcePatternLabelKey(props.focusedDayDutySource)))

function moveFocusDay(delta: number) {
  const next = Math.min(props.lastDayInMonth, Math.max(1, focusedDayValue.value + delta))
  emit('update:focusedDay', next)
}

function toggleBatchEdit() {
  emit('toggle-batch-edit', !props.batchEditMode)
}
</script>

<template>
  <div
    v-if="batchEditMode"
    role="status"
    class="mb-2 flex flex-col gap-3 rounded-xl border border-dp-warning-border bg-dp-warning-soft px-3 py-3 shadow-sm sm:flex-row sm:items-center sm:justify-between sm:px-4"
  >
    <div class="flex min-w-0 items-start gap-2.5">
      <span class="grid size-9 shrink-0 place-items-center rounded-full bg-dp-bg-primary text-dp-warning shadow-sm">
        <PencilLine class="size-4.5" aria-hidden="true" />
      </span>
      <div class="min-w-0 pt-0.5">
        <p class="text-sm font-bold text-dp-text-primary">
          {{ t('duty.typesBar.editModeActive') }}
        </p>
        <p class="mt-0.5 text-xs leading-relaxed text-dp-text-secondary sm:text-sm">
          {{ t('duty.typesBar.editModeDescription') }}
        </p>
      </div>
    </div>
    <button
      type="button"
      @click="toggleBatchEdit"
      class="flex min-h-[44px] shrink-0 items-center justify-center gap-1.5 rounded-lg border border-dp-warning-border bg-dp-bg-primary px-3.5 py-2 text-sm font-bold text-dp-warning-hover shadow-sm transition-colors hover:bg-dp-bg-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dp-warning cursor-pointer sm:self-center"
    >
      <X class="size-4" aria-hidden="true" />
      {{ t('duty.typesBar.exitEditMode') }}
    </button>
  </div>

  <div class="flex flex-wrap items-center justify-between gap-1 mb-1.5">
    <div class="flex flex-wrap items-center gap-2 sm:gap-3">
      <!-- Edit mode: Clickable duty type buttons for quick input -->
      <template v-if="batchEditMode && dutyTypes.length > 0">
        <!-- Current focus indicator with navigation -->
        <div class="flex items-center rounded-md border bg-dp-bg-tertiary border-dp-border-secondary">
          <button
            @click="moveFocusDay(-1)"
            :disabled="focusedDayValue === 1"
            class="p-1 rounded-l-md transition-all cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed hover:bg-dp-bg-hover"
          >
            <ChevronLeft class="w-4 h-4 text-dp-text-secondary" />
          </button>
          <span class="px-1 text-xs sm:text-sm font-bold text-dp-warning">{{ t('duty.typesBar.focusedDay', { day: focusedDayValue }) }}</span>
          <button
            @click="moveFocusDay(1)"
            :disabled="focusedDayValue === lastDayInMonth"
            class="p-1 rounded-r-md transition-all cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed hover:bg-dp-bg-hover"
          >
            <ChevronRight class="w-4 h-4 text-dp-text-secondary" />
          </button>
        </div>
        <button
          type="button"
          class="duty-quick-btn min-h-11"
          :class="{ 'duty-quick-btn-active': isInheritedDutySource(focusedDayDutySource) }"
          @click="emit('restore-pattern')"
        >
          <span class="duty-quick-btn-inner flex items-center gap-1">
            <RotateCcw class="w-3.5 h-3.5" />
            {{ patternButtonLabel }}
          </span>
        </button>
        <button
          v-for="dutyType in dutyTypes"
          :key="dutyType.id ?? 'off'"
          @click="emit('quick-duty-change', dutyType.id)"
          class="duty-quick-btn"
          :class="{ 'duty-quick-btn-active': focusedDayDutySource === 'OVERRIDE' && (focusedDayDutyType === dutyType.name || (!focusedDayDutyType && dutyType.id === null)) }"
          :style="{
            '--duty-color': dutyType.color || 'var(--dp-duty-fallback)',
            '--duty-text': isLightColor(dutyType.color) ? 'var(--dp-text-on-light)' : 'var(--dp-text-on-dark)'
          } as any"
        >
          <span class="duty-quick-btn-inner">
            {{ dutyType.name }}
          </span>
        </button>
      </template>

      <!-- Normal mode: Duty type badges with counts -->
      <template v-else-if="dutyTypesWithCount.length > 0">
        <div v-for="dutyType in dutyTypesWithCount" :key="dutyType.id ?? 'off'" class="flex items-center gap-1">
          <span
            class="w-4 h-4 rounded border-2"
            :style="{ backgroundColor: dutyType.color || 'var(--dp-duty-fallback)', borderColor: 'var(--dp-border-primary)' }"
          ></span>
          <span class="text-xs sm:text-sm text-dp-text-secondary">{{ dutyType.name }}</span>
          <span class="text-xs sm:text-sm font-bold text-dp-text-primary">{{ dutyType.cnt }}</span>
        </div>
      </template>
      <span v-else-if="isLoadingDuties" class="text-sm text-dp-text-muted">
        <Loader2 class="w-4 h-4 animate-spin inline mr-1" />
        {{ t('duty.typesBar.loading') }}
      </span>
      <span v-else class="text-sm text-dp-text-muted">
        {{ t('duty.typesBar.empty') }}
      </span>
    </div>
    <div class="inline-flex rounded-lg border overflow-hidden ml-auto border-dp-border-secondary">
      <div
        v-if="!batchEditMode && isOtherDutyActive"
        class="flex min-h-[44px] items-stretch border-r border-dp-border-secondary bg-dp-accent-soft text-dp-accent-hover"
      >
        <button
          type="button"
          @click="emit('toggle-other-duties')"
          class="flex items-center gap-1.5 px-2.5 sm:px-3 py-1.5 text-xs sm:text-sm transition-colors duration-150 cursor-pointer hover:bg-dp-accent-soft-hover"
        >
          <Users class="w-4 h-4" />
          <span class="hidden sm:inline font-medium">{{ t('duty.typesBar.compare') }}</span>
          <span
            class="inline-flex min-w-[22px] items-center justify-center rounded-full border border-dp-accent-border bg-dp-bg-primary px-1.5 py-0.5 text-[11px] font-semibold leading-none text-dp-accent-hover shadow-sm"
          >
            {{ otherDutyCount }}
          </span>
        </button>
        <div class="my-2 w-px bg-dp-accent-border/80"></div>
        <button
          type="button"
          @click="emit('clear-other-duties')"
          class="grid min-w-[44px] place-items-center px-2 text-dp-accent-hover transition-colors duration-150 cursor-pointer hover:bg-dp-accent-soft-hover"
          :aria-label="t('duty.otherDuties.turnOff')"
          :title="t('duty.otherDuties.turnOff')"
        >
          <X class="w-4 h-4" />
        </button>
      </div>
      <button
        v-else-if="!batchEditMode"
        @click="emit('toggle-other-duties')"
        class="px-2.5 sm:px-3 py-1.5 min-h-[44px] text-xs sm:text-sm transition-colors duration-150 flex items-center gap-1.5 border-r cursor-pointer border-dp-border-secondary hover:bg-dp-bg-hover dark:hover:bg-dp-bg-hover text-dp-text-secondary"
      >
        <Users class="w-4 h-4" />
        <span class="hidden sm:inline font-medium">{{ t('duty.typesBar.compare') }}</span>
      </button>
      <button
        v-if="canEditMyCalendar && batchEditMode"
        @click="emit('show-batch-update-modal')"
        class="px-2 sm:px-3 py-1.5 min-h-[44px] text-xs sm:text-sm transition-colors duration-150 border-r cursor-pointer hover:bg-dp-bg-hover dark:hover:bg-dp-bg-hover border-dp-border-secondary"
      >
        {{ t('duty.typesBar.batchUpdate') }}
      </button>
      <button
        v-if="canEdit && !batchEditMode"
        @click="toggleBatchEdit"
        class="px-2 sm:px-3 py-1.5 min-h-[44px] text-xs sm:text-sm transition-colors duration-150 border-r last:border-r-0 cursor-pointer border-dp-border-secondary hover:bg-dp-bg-hover dark:hover:bg-dp-bg-hover"
      >
        {{ t('duty.typesBar.editMode') }}
      </button>
      <button
        v-if="canEditMyCalendar && teamHasDutyBatchTemplate && !batchEditMode"
        @click="emit('show-excel-upload-modal')"
        class="px-2 sm:px-3 py-1.5 min-h-[44px] text-xs sm:text-sm transition-colors duration-150 flex items-center gap-1 cursor-pointer hover:bg-dp-bg-hover dark:hover:bg-dp-bg-hover"
      >
        <FileSpreadsheet class="w-4 h-4" />
        <span class="hidden sm:inline">{{ t('duty.typesBar.excel') }}</span>
      </button>
    </div>
  </div>
</template>
