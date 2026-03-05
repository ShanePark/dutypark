<script setup lang="ts">
import { CalendarCheck, Lock, Plus, Star } from 'lucide-vue-next'
import type { LocalDDay } from '@/views/duty/dutyViewTypes'

defineProps<{
  dDays: LocalDDay[]
  pinnedDDayId: number | null
  isMyCalendar: boolean
}>()

const emit = defineEmits<{
  (e: 'open-detail', dday: LocalDDay): void
  (e: 'toggle-pin', dday: LocalDDay): void
  (e: 'add'): void
}>()

function getDDayBadgeClass(calc: number): string {
  if (calc === 0) {
    return 'dday-badge-today'
  } else if (calc < 0) {
    return 'dday-badge-past'
  } else if (calc === 1) {
    return 'dday-badge-upcoming-1'
  } else if (calc === 2) {
    return 'dday-badge-upcoming-2'
  } else if (calc === 3) {
    return 'dday-badge-upcoming-3'
  }
  return 'dday-badge-future'
}
</script>

<template>
  <div class="grid grid-cols-2 lg:grid-cols-3 gap-2 sm:gap-3">
    <div
      v-for="dday in dDays"
      :key="dday.id"
      class="relative overflow-hidden rounded-xl sm:rounded-2xl cursor-pointer transition-all duration-300 hover:scale-[1.02] hover:shadow-lg border"
      :class="[
        pinnedDDayId === dday.id
          ? 'ring-2 ring-dp-warning shadow-md'
          : 'shadow-sm',
        dday.calc <= 0
          ? 'dday-card-past'
          : 'dday-card-future'
      ]"
      @click="emit('open-detail', dday)"
    >
      <div class="p-2.5 sm:p-4">
        <!-- D-Day badge and pin star -->
        <div class="flex justify-between items-start mb-2 sm:mb-3">
          <div
            class="inline-flex items-center px-2 py-1 sm:px-3 sm:py-1.5 rounded-full text-xs sm:text-sm font-bold shadow-sm"
            :class="getDDayBadgeClass(dday.calc)"
          >
            {{ dday.dDayText }}
          </div>
          <!-- Pin star -->
          <button
            @click.stop="emit('toggle-pin', dday)"
            class="p-1 sm:p-1.5 rounded-full transition hover:scale-110 cursor-pointer"
            :class="pinnedDDayId === dday.id ? 'hover:bg-dp-warning-soft' : 'hover:bg-dp-bg-hover'"
            :title="pinnedDDayId === dday.id ? '고정 해제' : '캘린더에 고정'"
          >
            <Star
              class="w-4 h-4 sm:w-5 sm:h-5 transition-colors"
              :class="pinnedDDayId === dday.id ? 'text-dp-warning fill-dp-warning' : 'text-dp-text-muted hover:text-dp-warning'"
            />
          </button>
        </div>

        <!-- Title -->
        <p class="text-sm sm:text-base font-medium mb-1 sm:mb-2 flex items-start gap-1 sm:gap-1.5 text-dp-text-primary">
          <Lock v-if="dday.isPrivate" class="w-3.5 h-3.5 sm:w-4 sm:h-4 flex-shrink-0 mt-0.5 text-dp-text-muted" />
          <span class="line-clamp-2">{{ dday.title }}</span>
        </p>

        <!-- Date -->
        <p class="text-xs sm:text-sm flex items-center gap-1 text-dp-text-muted">
          <CalendarCheck class="w-3.5 h-3.5 sm:w-4 sm:h-4" />
          {{ dday.date }}
        </p>
      </div>
    </div>

    <!-- Add D-Day Button (only for my calendar) -->
    <div
      v-if="isMyCalendar"
      @click="emit('add')"
      class="rounded-xl sm:rounded-2xl border-2 border-dashed cursor-pointer hover:border-dp-accent-border hover:bg-dp-accent-soft/50 transition-all duration-300 flex flex-col items-center justify-center min-h-[100px] sm:min-h-[120px] group border-dp-border-secondary"
    >
      <div class="w-10 h-10 sm:w-12 sm:h-12 rounded-full group-hover:bg-dp-accent-soft flex items-center justify-center mb-1.5 sm:mb-2 transition-colors bg-dp-bg-tertiary">
        <Plus class="w-5 h-5 sm:w-6 sm:h-6 group-hover:text-dp-accent transition-colors text-dp-text-muted" />
      </div>
      <span class="text-xs sm:text-sm group-hover:text-dp-accent transition-colors font-medium text-dp-text-muted">디데이 추가</span>
    </div>
  </div>
</template>
