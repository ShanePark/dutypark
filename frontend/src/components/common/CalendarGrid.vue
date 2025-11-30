<script setup lang="ts">
import { computed } from 'vue'
import { isLightColor } from '@/utils/color'
import type { HolidayDto } from '@/types'

interface CalendarDay {
  year: number
  month: number
  day: number
  isCurrentMonth?: boolean
  isToday?: boolean
}

interface Props {
  days: CalendarDay[]
  currentYear: number
  currentMonth: number
  holidays?: HolidayDto[][]
  getDutyColor?: (day: CalendarDay) => string | null
  highlightDay?: { year: number; month: number; day: number } | null
  selectedDay?: { year: number; month: number; day: number } | null
  useAdaptiveBorder?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  holidays: () => [],
  getDutyColor: () => null,
  highlightDay: null,
  selectedDay: null,
  useAdaptiveBorder: false,
})

const emit = defineEmits<{
  (e: 'day-click', day: CalendarDay, index: number): void
}>()

const weekDays = ['일', '월', '화', '수', '목', '금', '토']

// Determine if a day is the current month
function isCurrentMonth(day: CalendarDay): boolean {
  if (day.isCurrentMonth !== undefined) return day.isCurrentMonth
  return day.year === props.currentYear && day.month === props.currentMonth
}

// Check if a day is today
function isToday(day: CalendarDay): boolean {
  if (day.isToday !== undefined) return day.isToday
  const today = new Date()
  return (
    day.year === today.getFullYear() &&
    day.month === today.getMonth() + 1 &&
    day.day === today.getDate()
  )
}

// Check if a day is highlighted (search result, etc.)
function isHighlighted(day: CalendarDay): boolean {
  if (!props.highlightDay) return false
  return (
    day.year === props.highlightDay.year &&
    day.month === props.highlightDay.month &&
    day.day === props.highlightDay.day
  )
}

// Check if a day is selected
function isSelected(day: CalendarDay): boolean {
  if (!props.selectedDay) return false
  return (
    day.year === props.selectedDay.year &&
    day.month === props.selectedDay.month &&
    day.day === props.selectedDay.day
  )
}

// Get border color based on background brightness
function getBorderColor(day: CalendarDay): string {
  if (!props.useAdaptiveBorder) return 'var(--dp-border-secondary)'
  const bgColor = props.getDutyColor(day)
  if (!bgColor) return 'var(--dp-border-secondary)'
  return isLightColor(bgColor) ? 'rgba(0, 0, 0, 0.2)' : 'rgba(255, 255, 255, 0.2)'
}

// Get background color for a day
function getBackgroundColor(day: CalendarDay): string {
  const dutyColor = props.getDutyColor(day)
  if (dutyColor) return dutyColor
  return isCurrentMonth(day) ? 'var(--dp-calendar-cell-bg)' : 'var(--dp-calendar-cell-prev-next)'
}

// Get text color based on background and day of week
function getDayNumberColor(day: CalendarDay, dayOfWeek: number): string {
  const bgColor = props.getDutyColor(day)
  if (dayOfWeek === 0) return '#dc2626' // Sunday - red
  if (dayOfWeek === 6) return '#2563eb' // Saturday - blue
  if (bgColor) {
    return isLightColor(bgColor) ? '#1f2937' : '#ffffff'
  }
  return 'var(--dp-text-primary)'
}

// Get holiday text color
function getHolidayColor(day: CalendarDay, holiday: HolidayDto): string {
  if (holiday.isHoliday) return '#dc2626'
  const bgColor = props.getDutyColor(day)
  if (bgColor) {
    return isLightColor(bgColor) ? '#6b7280' : 'rgba(255,255,255,0.7)'
  }
  return 'var(--dp-text-muted)'
}

function handleDayClick(day: CalendarDay, index: number) {
  emit('day-click', day, index)
}
</script>

<template>
  <div class="rounded-lg border overflow-hidden mb-2 shadow-sm" :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-secondary)' }">
    <!-- Week Days Header -->
    <div class="grid grid-cols-7" :style="{ backgroundColor: 'var(--dp-calendar-header-bg)' }">
      <div
        v-for="(day, idx) in weekDays"
        :key="day"
        class="py-2 text-center font-bold border-b-2 text-sm"
        :style="{ borderColor: 'var(--dp-border-secondary)', color: idx === 0 ? '#dc2626' : idx === 6 ? '#2563eb' : 'var(--dp-text-primary)' }"
        :class="{ 'border-r': idx < 6 }"
      >
        {{ day }}
      </div>
    </div>

    <!-- Calendar Days -->
    <div class="grid grid-cols-7">
      <div
        v-for="(day, idx) in days"
        :key="idx"
        @click="handleDayClick(day, idx)"
        class="min-h-[70px] sm:min-h-[80px] md:min-h-[100px] border-b border-r p-0.5 sm:p-1 transition-all duration-150 relative cursor-pointer hover:brightness-95 hover:shadow-inner"
        :style="{
          borderColor: getBorderColor(day),
          backgroundColor: getBackgroundColor(day),
          opacity: isCurrentMonth(day) ? 1 : 0.5
        }"
        :class="{
          'ring-2 ring-red-500 ring-inset': isToday(day) || isHighlighted(day),
          'ring-2 ring-blue-500 ring-inset': isSelected(day) && !isToday(day),
          'rounded-bl-lg': idx === days.length - 7,
          'rounded-br-lg': idx === days.length - 1,
        }"
      >
        <!-- Day Number -->
        <div class="flex items-center justify-between">
          <span
            class="text-xs sm:text-sm font-medium"
            :class="{ 'font-bold': isToday(day) }"
            :style="{ color: getDayNumberColor(day, idx % 7) }"
          >
            {{ day.day }}
          </span>
          <!-- Slot for day number area (D-Day indicator, etc.) -->
          <slot name="day-header" :day="day" :index="idx" />
        </div>

        <!-- Holidays -->
        <div
          v-for="holiday in (holidays[idx] ?? [])"
          :key="holiday.localDate + holiday.dateName"
          class="text-[10px] sm:text-sm leading-snug px-0.5"
          :style="{ color: getHolidayColor(day, holiday) }"
        >
          {{ holiday.dateName }}
        </div>

        <!-- Slot for day content (schedules, D-Days, etc.) -->
        <slot name="day-content" :day="day" :index="idx" />
      </div>
    </div>
  </div>
</template>
