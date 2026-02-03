<script setup lang="ts">
import { computed } from 'vue'
import { ChevronLeft, ChevronRight, FileSpreadsheet, Loader2, Users } from 'lucide-vue-next'
import { isLightColor } from '@/utils/color'
import type { DutyType, DutyTypeWithCount } from '@/views/duty/dutyViewTypes'

const props = defineProps<{
  batchEditMode: boolean
  dutyTypes: DutyType[]
  dutyTypesWithCount: DutyTypeWithCount[]
  isLoadingDuties: boolean
  focusedDay: number | null
  focusedDayDutyType: string | null
  lastDayInMonth: number
  canEdit: boolean
  canEditMyCalendar: boolean
  otherDutyCount: number
  isOtherDutyActive: boolean
  teamHasDutyBatchTemplate: boolean
}>()

const emit = defineEmits<{
  (e: 'toggle-other-duties'): void
  (e: 'show-batch-update-modal'): void
  (e: 'toggle-batch-edit', value: boolean): void
  (e: 'show-excel-upload-modal'): void
  (e: 'quick-duty-change', dutyTypeId: number | null): void
  (e: 'update:focusedDay', value: number): void
}>()

const focusedDayValue = computed(() => props.focusedDay ?? 1)

function moveFocusDay(delta: number) {
  const next = Math.min(props.lastDayInMonth, Math.max(1, focusedDayValue.value + delta))
  emit('update:focusedDay', next)
}

function toggleBatchEdit() {
  emit('toggle-batch-edit', !props.batchEditMode)
}
</script>

<template>
  <div class="flex flex-wrap items-center justify-between gap-1 mb-1.5">
    <div class="flex flex-wrap items-center gap-2 sm:gap-3">
      <!-- Edit mode: Clickable duty type buttons for quick input -->
      <template v-if="batchEditMode && dutyTypes.length > 0">
        <!-- Current focus indicator with navigation -->
        <div class="flex items-center rounded-md border" :style="{ backgroundColor: 'var(--dp-bg-tertiary)', borderColor: 'var(--dp-border-secondary)' }">
          <button
            @click="moveFocusDay(-1)"
            :disabled="focusedDayValue === 1"
            class="p-1 rounded-l-md transition-all cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed hover:bg-gray-500/10"
          >
            <ChevronLeft class="w-4 h-4" :style="{ color: 'var(--dp-text-secondary)' }" />
          </button>
          <span class="px-1 text-xs sm:text-sm font-bold text-orange-500">{{ focusedDayValue }}일</span>
          <button
            @click="moveFocusDay(1)"
            :disabled="focusedDayValue === lastDayInMonth"
            class="p-1 rounded-r-md transition-all cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed hover:bg-gray-500/10"
          >
            <ChevronRight class="w-4 h-4" :style="{ color: 'var(--dp-text-secondary)' }" />
          </button>
        </div>
        <button
          v-for="dutyType in dutyTypes"
          :key="dutyType.id ?? 'off'"
          @click="emit('quick-duty-change', dutyType.id)"
          class="duty-quick-btn"
          :class="{ 'duty-quick-btn-active': focusedDayDutyType === dutyType.name || (!focusedDayDutyType && dutyType.id === null) }"
          :style="{
            '--duty-color': dutyType.color || '#6c757d',
            '--duty-text': isLightColor(dutyType.color) ? '#000' : '#fff'
          } as any"
        >
          <span class="duty-quick-btn-inner">
            {{ dutyType.name }}
          </span>
        </button>
      </template>

      <!-- Normal mode: Duty type badges with counts -->
      <template v-else-if="dutyTypesWithCount.length > 0">
        <div v-for="dutyType in dutyTypesWithCount" :key="dutyType.name" class="flex items-center gap-1">
          <span
            class="w-4 h-4 rounded border-2"
            :style="{ backgroundColor: dutyType.color || '#6c757d', borderColor: 'var(--dp-border-primary)' }"
          ></span>
          <span class="text-xs sm:text-sm" :style="{ color: 'var(--dp-text-secondary)' }">{{ dutyType.name }}</span>
          <span class="text-xs sm:text-sm font-bold" :style="{ color: 'var(--dp-text-primary)' }">{{ dutyType.cnt }}</span>
        </div>
      </template>
      <span v-else-if="isLoadingDuties" class="text-sm" :style="{ color: 'var(--dp-text-muted)' }">
        <Loader2 class="w-4 h-4 animate-spin inline mr-1" />
        로딩 중...
      </span>
      <span v-else class="text-sm" :style="{ color: 'var(--dp-text-muted)' }">
        근무 타입 정보 없음
      </span>
    </div>
    <div class="inline-flex rounded-lg border overflow-hidden ml-auto" :style="{ borderColor: 'var(--dp-border-secondary)' }">
      <button
        v-if="!batchEditMode"
        @click="emit('toggle-other-duties')"
        class="px-2 sm:px-3 py-1.5 min-h-[36px] text-xs sm:text-sm transition-colors duration-150 flex items-center gap-1 border-r cursor-pointer"
        :style="{ borderColor: 'var(--dp-border-secondary)' }"
        :class="isOtherDutyActive ? 'bg-blue-50/70 text-blue-700 hover:bg-blue-50' : 'hover:bg-gray-500/10 dark:hover:bg-gray-400/10'"
      >
        <Users class="w-4 h-4" />
        <span class="hidden xs:inline">함께보기</span>
        <span v-if="isOtherDutyActive" class="text-xs">({{ otherDutyCount }})</span>
      </button>
      <button
        v-if="canEditMyCalendar && batchEditMode"
        @click="emit('show-batch-update-modal')"
        class="px-2 sm:px-3 py-1.5 min-h-[36px] text-xs sm:text-sm transition-colors duration-150 border-r cursor-pointer hover:bg-gray-500/10 dark:hover:bg-gray-400/10"
        :style="{ borderColor: 'var(--dp-border-secondary)' }"
      >
        일괄수정
      </button>
      <button
        v-if="canEdit"
        @click="toggleBatchEdit"
        class="px-2 sm:px-3 py-1.5 min-h-[36px] text-xs sm:text-sm transition-colors duration-150 border-r last:border-r-0 cursor-pointer"
        :style="{ borderColor: 'var(--dp-border-secondary)' }"
        :class="batchEditMode ? 'bg-orange-50/70 text-orange-700 hover:bg-orange-50' : 'hover:bg-gray-500/10 dark:hover:bg-gray-400/10'"
      >
        편집모드
      </button>
      <button
        v-if="canEditMyCalendar && teamHasDutyBatchTemplate && !batchEditMode"
        @click="emit('show-excel-upload-modal')"
        class="px-2 sm:px-3 py-1.5 min-h-[36px] text-xs sm:text-sm transition-colors duration-150 flex items-center gap-1 cursor-pointer hover:bg-gray-500/10 dark:hover:bg-gray-400/10"
      >
        <FileSpreadsheet class="w-4 h-4" />
        <span class="hidden sm:inline">엑셀</span>
      </button>
    </div>
  </div>
</template>
