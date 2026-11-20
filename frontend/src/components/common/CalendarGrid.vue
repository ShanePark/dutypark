<script setup lang="ts" generic="TSpan">
import { computed } from 'vue'
import { ChevronRight } from '@lucide/vue'
import { useI18n } from 'vue-i18n'
import { getTimeChipColors, isLightColor } from '@/utils/color'
import { getCalendarGridSlice } from '@/utils/calendarGrid'
import type { CalendarSpanLanes, CalendarSpanSegment } from '@/utils/calendarSpanLanes'
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
  /** Multi-day lanes per source day, from assignCalendarSpanLanes. */
  spanLanes?: CalendarSpanLanes<TSpan>[]
}

const props = withDefaults(defineProps<Props>(), {
  holidays: () => [],
  getDutyColor: () => null,
  highlightDay: null,
  selectedDay: null,
  focusedDay: null,
  clickable: true,
  isDayClickable: () => true,
  spanLanes: () => [],
})

defineSlots<{
  'day-header'?: (props: { day: CalendarDay; index: number }) => unknown
  'day-content'?: (props: { day: CalendarDay; index: number }) => unknown
  span?: (props: { segment: CalendarSpanSegment<TSpan> }) => unknown
}>()

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

// The time chip is a tone-on-tone shade of the fill; without one it falls back
// to the neutral ink chip in CSS.
function getDayStyle(day: CalendarDay): Record<string, string> {
  const fill = getFillColor(day)
  if (fill) {
    const chip = getTimeChipColors(fill)
    if (!chip) return { backgroundColor: fill }
    return { backgroundColor: fill, '--calendar-time-bg': chip.background, '--calendar-time-ink': chip.color }
  }
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

      <div class="calendar-day-body">
        <!-- A band lives in the first cell of its week segment and reaches over the
             following cells; they keep an empty lane of the same height beneath it. -->
        <div v-if="spanLanes[getSourceIndex(idx)]?.length" class="calendar-span-lanes">
          <div
            v-for="(lane, laneIndex) in spanLanes[getSourceIndex(idx)]"
            :key="laneIndex"
            class="calendar-span-lane"
          >
            <div
              v-if="lane?.isFirstDay"
              class="calendar-span"
              :class="{
                'calendar-span--start': lane.segment.isStart,
                'calendar-span--end': lane.segment.isEnd,
              }"
              :style="{ '--calendar-span-days': lane.segment.days }"
            >
              <slot name="span" :segment="lane.segment" />
              <ChevronRight v-if="!lane.segment.isEnd" class="calendar-span__more" aria-hidden="true" />
            </div>
          </div>
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

  position: relative;
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

  /* Each day spans a header row and a body row of its week, shared through
     subgrid, so the multi-day lanes under the date line up across the week even
     when one day's header wraps. */
  position: relative;
  display: grid;
  grid-row: span 2;
  grid-template-rows: subgrid;
  row-gap: 0;
  min-width: 0;
  padding: 4px var(--calendar-pad-x) 5px;
  color: var(--calendar-ink);
}

/* A subgrid ignores its own min-height, so the body carries the tile's minimum. */
.calendar-day-body {
  min-width: 0;
  min-height: 35px;
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
  container: calendar-day-header / inline-size;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 2px;
  min-height: 18px;
  margin-bottom: 2px;
}

.calendar-day-number {
  display: inline-flex;
  flex: none;
  white-space: nowrap;
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
  flex: none;
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

/* A filled pill keeps the optional label legible on any fill. */
.calendar-day-today-label {
  display: none;
  white-space: nowrap;
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

/* A schedule line clamps only its title, so a long title never hides the time
   chip that follows it. The title box shrinks to its text, letting a short title
   share its line with the chip; top alignment keeps an overflow-clipped box from
   lifting the line's baseline to its bottom edge. */
:slotted(.calendar-item__line--chip) {
  display: block;
  overflow: visible;
  -webkit-line-clamp: none;
  line-clamp: none;
}

:slotted(.calendar-item__line--chip > .calendar-item__text) {
  display: -webkit-inline-box;
  max-width: 100%;
  overflow: hidden;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  vertical-align: top;
}

/* An atomic pill moves to the next line whole; only a range wider than the
   line breaks inside it, at the <wbr> after "~". On a duty fill the tile sets a
   tone-on-tone pair; otherwise the chip is a neutral ink tint. */
:slotted(.calendar-item__time) {
  display: inline-block;
  max-width: 100%;
  margin-top: 1px;
  padding: 1px 3px;
  border-radius: 4px;
  background: var(--calendar-time-bg, color-mix(in srgb, var(--calendar-ink) 8.5%, transparent));
  color: var(--calendar-time-ink, color-mix(in srgb, var(--calendar-ink) 82%, transparent));
  font-size: 0.84em;
  font-weight: 700;
  line-height: 1.4;
  font-variant-numeric: tabular-nums;
  letter-spacing: normal;
}

:slotted(.calendar-item__time-part) {
  white-space: nowrap;
  overflow-wrap: normal;
}

/* Multi-day lanes sit under the date, above every other item of the day. */
.calendar-span-lanes {
  display: flex;
  flex-direction: column;
  gap: 2px;
  margin-bottom: 2px;
}

.calendar-span-lane {
  position: relative;
  height: 16px;
}

/* One white ribbon per week segment. It spans its days and the gutters between
   them, is inset with rounded ends only at the schedule's true start and end,
   and runs square to the row edge where the schedule continues into another
   week. Clicks fall through to the day underneath. The ribbon is fixed-colour,
   so it reads the same on any duty fill and in either theme. */
.calendar-span {
  --calendar-span-inset: 2px;
  --calendar-span-radius: 4px;
  --calendar-span-start: 0px;
  --calendar-span-end: 0px;

  position: absolute;
  z-index: 2;
  top: 0;
  bottom: 0;
  left: calc(var(--calendar-span-start) - var(--calendar-pad-x));
  width: calc(
    var(--calendar-span-days) * (100% + 2 * var(--calendar-pad-x))
    + (var(--calendar-span-days) - 1) * var(--calendar-gap)
    - var(--calendar-span-start) - var(--calendar-span-end)
  );
  display: flex;
  align-items: center;
  gap: 3px;
  padding: 0 4px;
  overflow: hidden;
  background: rgba(255, 255, 255, 0.84);
  box-shadow: inset 0 0 0 1px rgba(31, 41, 55, 0.14), 0 1px 2px rgba(31, 41, 55, 0.08);
  color: #1f2937;
  font-size: 10px;
  line-height: 1.2;
  letter-spacing: -0.03em;
  white-space: nowrap;
  pointer-events: none;
  container-type: inline-size;
}

.calendar-span--start {
  --calendar-span-start: var(--calendar-span-inset);

  border-top-left-radius: var(--calendar-span-radius);
  border-bottom-left-radius: var(--calendar-span-radius);
}

.calendar-span--end {
  --calendar-span-end: var(--calendar-span-inset);

  border-top-right-radius: var(--calendar-span-radius);
  border-bottom-right-radius: var(--calendar-span-radius);
}

:slotted(.calendar-span__title) {
  min-width: 0;
  overflow: hidden;
  font-weight: 700;
  text-overflow: ellipsis;
}

:slotted(.calendar-span__time) {
  flex: none;
  color: rgba(31, 41, 55, 0.62);
  font-size: 0.84em;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  letter-spacing: normal;
}

/* A one-day mobile segment cannot hold the title and a time, so the title wins. */
@container (max-width: 7em) {
  :slotted(.calendar-span__time) {
    display: none;
  }
}

:slotted(.calendar-span__time--end),
.calendar-span__more {
  margin-left: auto;
}

.calendar-span__more {
  flex: none;
  width: 0.9em;
  height: 0.9em;
  color: rgba(31, 41, 55, 0.5);
  stroke-width: 2.5;
}

/* Use the tile's available width: the date and full D-Day label can wrap
   onto separate header lines before either is squeezed or clipped. */
@container calendar-day-header (min-width: 6rem) {
  .calendar-day-today-label {
    display: inline-block;
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
    padding: 7px var(--calendar-pad-x) 8px;
  }

  .calendar-day-body {
    min-height: 41px;
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

  :slotted(.calendar-item__time) {
    margin-top: 0;
    padding: 1px 5px;
    border-radius: 5px;
  }

  .calendar-span-lanes {
    gap: 3px;
    margin-bottom: 3px;
  }

  .calendar-span-lane {
    height: 23px;
  }

  .calendar-span {
    --calendar-span-inset: 4px;
    --calendar-span-radius: 7px;

    gap: 5px;
    padding: 0 8px;
    font-size: 12px;
    letter-spacing: normal;
  }
}

@media (min-width: 768px) {
  .calendar-day-body {
    min-height: 65px;
  }
}
</style>
