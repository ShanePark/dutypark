<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { isLightColor } from '@/utils/color'
import { getCalendarGridSlice } from '@/utils/calendarGrid'
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
  clickable?: boolean
  isDayClickable?: (day: CalendarDay, index: number) => boolean
}

const props = withDefaults(defineProps<Props>(), {
  holidays: () => [],
  getDutyColor: () => null,
  highlightDay: null,
  selectedDay: null,
  focusedDay: null,
  clickable: true,
  isDayClickable: () => true,
})

const emit = defineEmits<{
  (e: 'day-click', day: CalendarDay, index: number): void
}>()

const calendarGridSlice = computed(() =>
  getCalendarGridSlice(props.days, props.currentYear, props.currentMonth),
)
const visibleDays = computed(() => calendarGridSlice.value.days)

function getSourceIndex(visibleIndex: number): number {
  return calendarGridSlice.value.startIndex + visibleIndex
}

const { locale, t } = useI18n()
const weekDays = computed(() => {
  const formatter = new Intl.DateTimeFormat(locale.value, { weekday: 'short' })
  return Array.from({ length: 7 }, (_, index) => formatter.format(new Date(2024, 0, 7 + index)))
})

function isCurrentMonth(day: CalendarDay): boolean {
  if (day.isCurrentMonth !== undefined) return day.isCurrentMonth
  return day.year === props.currentYear && day.month === props.currentMonth
}

function isToday(day: CalendarDay): boolean {
  if (day.isToday !== undefined) return day.isToday
  const today = new Date()
  return (
    day.year === today.getFullYear() &&
    day.month === today.getMonth() + 1 &&
    day.day === today.getDate()
  )
}

function isHighlighted(day: CalendarDay): boolean {
  if (!props.highlightDay) return false
  return (
    day.year === props.highlightDay.year &&
    day.month === props.highlightDay.month &&
    day.day === props.highlightDay.day
  )
}

function isSelected(day: CalendarDay): boolean {
  if (!props.selectedDay) return false
  return (
    day.year === props.selectedDay.year &&
    day.month === props.selectedDay.month &&
    day.day === props.selectedDay.day
  )
}

// The selection border wins over today's border; today stays recognisable by
// its filled date circle and label.
function hasSelectionBorder(day: CalendarDay): boolean {
  return !props.focusedDay && (isHighlighted(day) || isSelected(day))
}

function isFocused(day: CalendarDay): boolean {
  if (!props.focusedDay) return false
  return (
    day.year === props.focusedDay.year &&
    day.month === props.focusedDay.month &&
    day.day === props.focusedDay.day
  )
}

const OUTSIDE_DUTY_WEIGHT = 0.6

// Duty tiles look identical in light and dark, so out-of-month days fade their
// duty toward fixed white rather than a theme surface.
function fadeOutsideDuty(hexColor: string): string {
  const hex = hexColor.replace('#', '')
  if (!/^[0-9a-f]{6}$/i.test(hex)) return hexColor
  const channels = [0, 2, 4].map(offset => {
    const value = parseInt(hex.substring(offset, offset + 2), 16)
    return Math.round(value * OUTSIDE_DUTY_WEIGHT + 255 * (1 - OUTSIDE_DUTY_WEIGHT))
  })
  return `#${channels.map(value => value.toString(16).padStart(2, '0')).join('')}`
}

function getFillColor(day: CalendarDay): string | null {
  const dutyColor = props.getDutyColor(day)
  if (!dutyColor) return null
  return isCurrentMonth(day) ? dutyColor : fadeOutsideDuty(dutyColor)
}

function getDayStyle(day: CalendarDay): Record<string, string> {
  const fill = getFillColor(day)
  if (fill) return { backgroundColor: fill }
  return isCurrentMonth(day) ? { backgroundColor: 'var(--dp-calendar-cell-bg)' } : {}
}

// Slot content reads --calendar-ink* so its text stays legible on any fill.
function getInkClass(day: CalendarDay): string | null {
  const fill = getFillColor(day)
  if (!fill) return null
  return isLightColor(fill) ? 'calendar-day--on-light' : 'calendar-day--on-dark'
}

const WEEKEND_INK_ON_LIGHT_FILL = { sunday: '#991B1B', saturday: '#1E40AF' } as const
const WEEKEND_INK_ON_DARK_FILL = { sunday: '#FCA5A5', saturday: '#93C5FD' } as const

// Duty fills are theme-independent, so their weekend ink is fixed; only empty
// tiles follow the theme's weekend colours.
function getWeekendColor(day: CalendarDay, weekend: 'sunday' | 'saturday'): string {
  const fill = getFillColor(day)
  if (!fill) return `var(--dp-${weekend})`
  return isLightColor(fill) ? WEEKEND_INK_ON_LIGHT_FILL[weekend] : WEEKEND_INK_ON_DARK_FILL[weekend]
}

function getDayNumberColor(day: CalendarDay, dayOfWeek: number): string {
  if (!isCurrentMonth(day)) return 'var(--calendar-ink-muted)'
  if (dayOfWeek === 0) return getWeekendColor(day, 'sunday')
  if (dayOfWeek === 6) return getWeekendColor(day, 'saturday')
  return 'var(--calendar-ink)'
}

function getHolidayColor(day: CalendarDay, holiday: HolidayDto): string {
  if (holiday.isHoliday) return getWeekendColor(day, 'sunday')
  return 'var(--calendar-ink-muted)'
}

const todayWeekdayIndex = computed(() => {
  const index = visibleDays.value.findIndex(day => isToday(day) && isCurrentMonth(day))
  return index === -1 ? -1 : index % 7
})

function handleDayClick(day: CalendarDay, index: number) {
  if (!props.isDayClickable(day, index)) return
  emit('day-click', day, index)
}
</script>

<template>
  <div class="calendar-grid mb-2">
    <div
      v-for="(weekDay, idx) in weekDays"
      :key="weekDay"
      class="calendar-weekday"
      :class="{ 'calendar-weekday--today': idx === todayWeekdayIndex }"
      :style="{ color: idx === 0 ? 'var(--dp-sunday)' : idx === 6 ? 'var(--dp-saturday)' : 'var(--dp-text-secondary)' }"
    >
      {{ weekDay }}
    </div>

    <div
      v-for="(day, idx) in visibleDays"
      :key="idx"
      @click="handleDayClick(day, getSourceIndex(idx))"
      :aria-current="isToday(day) ? 'date' : undefined"
      class="calendar-day"
      :class="[
        getInkClass(day),
        clickable && isDayClickable(day, getSourceIndex(idx)) ? 'cursor-pointer calendar-day-hoverable' : '',
        {
          'calendar-day--outside': !isCurrentMonth(day),
          'calendar-day--today': isToday(day),
          'calendar-day--highlighted': !focusedDay && isHighlighted(day),
          'highlight-pulse-glow': !focusedDay && isHighlighted(day),
          'ring-2 ring-dp-accent ring-inset': !focusedDay && isSelected(day) && !isHighlighted(day),
          'duty-day-focused': isFocused(day),
        }
      ]"
      :style="getDayStyle(day)"
    >
      <span
        v-if="isToday(day) && !hasSelectionBorder(day)"
        class="calendar-day-today-border"
        aria-hidden="true"
      />
      <span
        v-if="!focusedDay && isHighlighted(day)"
        class="calendar-day-highlight-border"
        aria-hidden="true"
      />
      <div class="calendar-day-top">
        <span
          class="calendar-day-number"
          :style="{ color: getDayNumberColor(day, idx % 7) }"
        >
          <template v-if="isToday(day)">
            <span class="calendar-day-today-circle">{{ day.day }}</span>
            <span class="calendar-day-today-label">{{ t('common.calendar.today') }}</span>
          </template>
          <template v-else>{{ day.day }}</template>
        </span>
        <slot name="day-header" :day="day" :index="getSourceIndex(idx)" />
      </div>

      <div
        v-for="holiday in (holidays[getSourceIndex(idx)] ?? [])"
        :key="holiday.localDate + holiday.dateName"
        class="calendar-day-holiday"
        :title="holiday.dateName"
        :style="{ color: getHolidayColor(day, holiday) }"
      >
        {{ holiday.dateName }}
      </div>

      <slot name="day-content" :day="day" :index="getSourceIndex(idx)" />
    </div>
  </div>
</template>

<style scoped>
/* Flat month grid: the gutters between tiles are the only separators, so equal
   duty colours on neighbouring days still read as separate days. */
.calendar-grid {
  --calendar-gutter: var(--dp-border-primary);
  --calendar-surface: var(--dp-calendar-cell-prev-next);
  --calendar-today: var(--dp-danger-hover);
  --calendar-gap: 2px;
  --calendar-pad-x: 3px;

  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
  gap: var(--calendar-gap);
  border: 1px solid var(--calendar-gutter);
  border-radius: 8px;
  overflow: hidden;
  background: var(--calendar-gutter);
}

/* The dark prev/next surface is the page colour, so the header sits on the card instead. */
:global(.dark) .calendar-grid {
  --calendar-header-surface: var(--dp-calendar-cell-bg);
}

.calendar-weekday {
  padding: 5px 0;
  background: var(--calendar-header-surface, var(--calendar-surface));
  text-align: center;
  font-size: 11px;
  font-weight: 700;
  line-height: 1.2;
}

.calendar-weekday--today {
  background: var(--calendar-today);
  color: #fff !important;
}

.calendar-day {
  --calendar-ink: var(--dp-text-primary);
  --calendar-ink-muted: var(--dp-text-muted);
  --calendar-rule: var(--dp-border-primary);

  position: relative;
  min-width: 0;
  min-height: 64px;
  padding: 4px var(--calendar-pad-x) 5px;
  color: var(--calendar-ink);
}

.calendar-day--on-light {
  --calendar-ink: var(--dp-text-on-light);
  --calendar-ink-muted: color-mix(in srgb, var(--dp-text-on-light) 72%, transparent);
  --calendar-rule: color-mix(in srgb, var(--dp-text-on-light) 22%, transparent);
}

.calendar-day--on-dark {
  --calendar-ink: var(--dp-text-on-dark);
  --calendar-ink-muted: var(--dp-text-on-dark-muted);
  --calendar-rule: color-mix(in srgb, var(--dp-text-on-dark) 30%, transparent);
}

.calendar-day--outside {
  background: var(--calendar-surface);
}

/* Softer ink marks out-of-month duty tiles as "not this month" in both themes. */
.calendar-day--outside.calendar-day--on-light {
  --calendar-ink: color-mix(in srgb, var(--dp-text-on-light) 82%, transparent);
  --calendar-ink-muted: color-mix(in srgb, var(--dp-text-on-light) 58%, transparent);
}

.calendar-day--today,
.calendar-day--highlighted {
  z-index: 1;
}

.calendar-day-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 2px;
  min-height: 18px;
  margin-bottom: 2px;
}

.calendar-day-number {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  font-weight: 700;
  line-height: 1;
  font-variant-numeric: tabular-nums;
}

.calendar-day--outside .calendar-day-number {
  font-weight: 600;
}

/* Today: a ring over the gutter (unless the day is selected), a filled date
   circle, and (on wider screens) a label. */
.calendar-day-today-border {
  position: absolute;
  inset: -2px;
  border: 2px solid var(--calendar-today);
  border-radius: 3px;
  box-shadow: 0 0 0 1px var(--calendar-gutter), inset 0 0 0 1.5px #fff;
  pointer-events: none;
  z-index: 2;
}

.calendar-day-today-circle {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 19px;
  height: 19px;
  margin-left: -1px;
  border-radius: 9999px;
  background: var(--calendar-today);
  color: #fff;
  font-size: 11.5px;
}

/* A filled pill rather than red text keeps the label legible on any fill. */
.calendar-day-today-label {
  display: none;
  padding: 3px 6px;
  border-radius: 9999px;
  background: var(--calendar-today);
  color: #fff;
  font-size: 11px;
  font-weight: 700;
  line-height: 1;
}

.calendar-day-highlight-border {
  position: absolute;
  inset: 0;
  border: 2px solid var(--dp-warning);
  pointer-events: none;
  z-index: 1;
}

.calendar-day-holiday {
  overflow: hidden;
  padding-inline: 1px;
  font-size: 10px;
  line-height: 1.35;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Hover: an ink-tinted veil plus a quiet inset frame, legible on any fill. */
.calendar-day-hoverable::before,
.calendar-day-hoverable::after {
  content: '';
  position: absolute;
  inset: 0;
  opacity: 0;
  pointer-events: none;
  transition: opacity 150ms ease;
}

.calendar-day-hoverable::before {
  background: var(--calendar-ink);
}

.calendar-day-hoverable::after {
  border: 2px solid color-mix(in srgb, var(--calendar-ink) 45%, transparent);
}

@media (hover: hover) and (pointer: fine) {
  .calendar-day-hoverable:hover::before {
    opacity: 0.07;
  }

  .calendar-day-hoverable:hover::after {
    opacity: 1;
  }
}

/* Day items rendered by the slot owners share one quiet text style. */
:slotted(.calendar-items) {
  display: flex;
  flex-direction: column;
}

:slotted(.calendar-item) {
  position: relative;
  min-width: 0;
  padding: 2px 0;
  font-size: 10px;
  line-height: 1.3;
  letter-spacing: -0.03em;
}

:slotted(.calendar-item + .calendar-item) {
  border-top: 1px solid var(--calendar-rule);
}

:slotted(.calendar-item__line) {
  display: -webkit-box;
  overflow: hidden;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  overflow-wrap: anywhere;
}

:slotted(.calendar-item__time) {
  display: none;
}

:slotted(.calendar-item__part) {
  margin-left: 3px;
  color: var(--calendar-ink-muted);
  font-size: 0.9em;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

/* A multi-day schedule draws an underline that runs to the tile edges, so the
   days of one schedule visually join across the week. */
:slotted(.calendar-item--span) {
  padding-bottom: 5px;
}

:slotted(.calendar-item--span)::after {
  content: '';
  position: absolute;
  right: calc(-1 * var(--calendar-pad-x));
  bottom: 0;
  left: calc(-1 * var(--calendar-pad-x));
  height: 2.5px;
  background: var(--calendar-ink);
}

:slotted(.calendar-item--span-start)::after {
  left: 0;
  border-top-left-radius: 2px;
  border-bottom-left-radius: 2px;
}

:slotted(.calendar-item--span-end)::after {
  right: 0;
  border-top-right-radius: 2px;
  border-bottom-right-radius: 2px;
}

/* Narrow tiles keep a multi-day title to one line so the bar below it lines up
   across neighbouring days. The joined bar already shows the run, so the day
   count is dropped. */
@media (max-width: 639.98px) {
  :slotted(.calendar-item--span .calendar-item__line) {
    display: block;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  :slotted(.calendar-item--span .calendar-item__part) {
    display: none;
  }
}

@media (min-width: 640px) {
  .calendar-grid {
    --calendar-pad-x: 8px;

    border-width: 2px;
    border-radius: 12px;
  }

  .calendar-weekday {
    padding: 7px 0;
    font-size: 12px;
  }

  .calendar-day {
    min-height: 84px;
    padding: 7px var(--calendar-pad-x) 8px;
  }

  .calendar-day-top {
    min-height: 24px;
    margin-bottom: 4px;
  }

  .calendar-day-number {
    font-size: 17px;
  }

  .calendar-day-today-border {
    border-width: 3px;
    border-radius: 4px;
    box-shadow: 0 0 0 2px var(--calendar-gutter), inset 0 0 0 2px #fff;
  }

  .calendar-day-today-circle {
    width: 26px;
    height: 26px;
    margin: -1px 0 0 -3px;
    font-size: 15px;
  }

  .calendar-day-today-label {
    display: inline-block;
  }

  .calendar-day-holiday {
    font-size: 12px;
  }

  :slotted(.calendar-items) {
    gap: 4px;
  }

  :slotted(.calendar-item) {
    padding: 0 0 0 10px;
    font-size: 12px;
    line-height: 1.38;
    letter-spacing: normal;
  }

  :slotted(.calendar-item + .calendar-item) {
    border-top: 0;
  }

  :slotted(.calendar-item)::before {
    content: '';
    position: absolute;
    top: 0.5em;
    left: 1px;
    width: 4px;
    height: 4px;
    border-radius: 9999px;
    background: var(--calendar-ink-muted);
  }

  :slotted(.calendar-item__line--split) {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 4px;
  }

  :slotted(.calendar-item__line--split .calendar-item__text) {
    display: -webkit-box;
    flex: 1 1 auto;
    min-width: 0;
    overflow: hidden;
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 2;
    line-clamp: 2;
  }

  :slotted(.calendar-item--span .calendar-item__text) {
    display: block;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  :slotted(.calendar-item__time) {
    display: inline;
    margin-right: 4px;
    color: var(--calendar-ink-muted);
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }

  :slotted(.calendar-item__part) {
    flex: none;
    font-size: 11px;
  }

  :slotted(.calendar-item--span) {
    padding-left: 0;
    padding-bottom: 5px;
  }

  :slotted(.calendar-item--span)::before {
    content: none;
  }

  :slotted(.calendar-item--span)::after {
    height: 3px;
  }
}

@media (min-width: 768px) {
  .calendar-day {
    min-height: 108px;
  }
}
</style>
