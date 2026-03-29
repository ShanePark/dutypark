<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
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
  focusedDay?: { year: number; month: number; day: number } | null
  useAdaptiveBorder?: boolean
  clickable?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  holidays: () => [],
  getDutyColor: () => null,
  highlightDay: null,
  selectedDay: null,
  focusedDay: null,
  useAdaptiveBorder: false,
  clickable: true,
})

const emit = defineEmits<{
  (e: 'day-click', day: CalendarDay, index: number): void
}>()

type HolidayLabelVariant = 'full' | 'short'

const { locale, t } = useI18n()
const weekDays = computed(() => {
  const formatter = new Intl.DateTimeFormat(locale.value, { weekday: 'short' })
  return Array.from({ length: 7 }, (_, index) => formatter.format(new Date(2024, 0, 7 + index)))
})

function translateHolidayName(dateName: string, variant: HolidayLabelVariant = 'full'): string {
  const normalized = dateName.trim()
  const substituteHoliday = normalized.match(/^대체공휴일\((.+)\)$/)
  const messageNamespace = variant === 'short' ? 'holidayNamesShort' : 'holidayNames'
  if (substituteHoliday) {
    return t(`${messageNamespace}.substituteHolidayWithName`, {
      name: translateHolidayName(substituteHoliday[1] ?? '', variant),
    })
  }

  const holidayMap: Record<string, string> = {
    신정: `${messageNamespace}.newYear`,
    설날: `${messageNamespace}.lunarNewYear`,
    삼일절: `${messageNamespace}.independenceMovementDay`,
    어린이날: `${messageNamespace}.childrenDay`,
    부처님오신날: `${messageNamespace}.buddhaBirthday`,
    현충일: `${messageNamespace}.memorialDay`,
    광복절: `${messageNamespace}.liberationDay`,
    개천절: `${messageNamespace}.nationalFoundationDay`,
    한글날: `${messageNamespace}.hangulDay`,
    크리스마스: `${messageNamespace}.christmas`,
    성탄절: `${messageNamespace}.christmas`,
    추석: `${messageNamespace}.chuseok`,
    대체공휴일: `${messageNamespace}.substituteHoliday`,
  }

  const messageKey = holidayMap[normalized]
  return messageKey ? t(messageKey) : normalized
}

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

// Check if a day is focused (for quick duty input)
function isFocused(day: CalendarDay): boolean {
  if (!props.focusedDay) return false
  return (
    day.year === props.focusedDay.year &&
    day.month === props.focusedDay.month &&
    day.day === props.focusedDay.day
  )
}

// Get border color based on background brightness
function getBorderColor(day: CalendarDay): string {
  if (!props.useAdaptiveBorder) return 'var(--dp-border-secondary)'
  const bgColor = props.getDutyColor(day)
  if (!bgColor) return 'var(--dp-border-secondary)'
  return isLightColor(bgColor)
    ? 'color-mix(in srgb, var(--dp-border-on-light) 100%, transparent)'
    : 'color-mix(in srgb, var(--dp-border-on-dark) 70%, transparent)'
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
  if (dayOfWeek === 0) return 'var(--dp-sunday)'
  if (dayOfWeek === 6) return 'var(--dp-saturday)'
  if (bgColor) {
    return isLightColor(bgColor) ? 'var(--dp-text-on-light)' : 'var(--dp-text-on-dark)'
  }
  return 'var(--dp-text-primary)'
}

// Get holiday text color
function getHolidayColor(day: CalendarDay, holiday: HolidayDto): string {
  if (holiday.isHoliday) return 'var(--dp-sunday)'
  const bgColor = props.getDutyColor(day)
  if (bgColor) {
    return isLightColor(bgColor) ? 'var(--dp-text-muted)' : 'var(--dp-text-on-dark-muted)'
  }
  return 'var(--dp-text-muted)'
}

function handleDayClick(day: CalendarDay, index: number) {
  emit('day-click', day, index)
}
</script>

<template>
  <div class="rounded-lg border overflow-hidden mb-2 shadow-sm bg-dp-bg-card border-dp-border-secondary">
    <!-- Week Days Header -->
    <div class="grid grid-cols-7" :style="{ backgroundColor: 'var(--dp-calendar-header-bg)' }">
      <div
        v-for="(day, idx) in weekDays"
        :key="day"
        class="py-2 text-center font-bold border-b-2 text-sm"
        :style="{ borderColor: 'var(--dp-border-secondary)', color: idx === 0 ? 'var(--dp-sunday)' : idx === 6 ? 'var(--dp-saturday)' : 'var(--dp-text-primary)' }"
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
        class="min-h-[60px] sm:min-h-[80px] md:min-h-[100px] border-b border-r p-0.5 sm:p-1 transition-all duration-150 relative"
        :class="[
          clickable ? 'cursor-pointer hover:brightness-95 hover:shadow-inner' : '',
          {
            'highlight-pulse-glow': !focusedDay && isHighlighted(day),
            'ring-2 ring-dp-danger ring-inset': !focusedDay && isToday(day) && !isHighlighted(day),
            'ring-2 ring-dp-accent ring-inset': !focusedDay && isSelected(day) && !isToday(day) && !isHighlighted(day),
            'duty-day-focused': isFocused(day),
            'rounded-bl-lg': idx === days.length - 7,
            'rounded-br-lg': idx === days.length - 1,
          }
        ]"
        :style="{
          borderColor: getBorderColor(day),
          backgroundColor: getBackgroundColor(day),
          opacity: isCurrentMonth(day) ? 1 : 0.5
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
          class="block truncate text-[10px] sm:text-sm leading-snug px-0.5"
          :title="translateHolidayName(holiday.dateName)"
          :style="{ color: getHolidayColor(day, holiday) }"
        >
          {{ translateHolidayName(holiday.dateName, 'short') }}
        </div>

        <!-- Slot for day content (schedules, D-Days, etc.) -->
        <slot name="day-content" :day="day" :index="idx" />
      </div>
    </div>
  </div>
</template>
