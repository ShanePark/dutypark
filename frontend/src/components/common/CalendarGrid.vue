<script setup lang="ts" generic="TSpan">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
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
  /** Rendered under the date in the week-shared header row, above the multi-day lanes. */
  'day-pinned'?: (props: { day: CalendarDay; index: number }) => unknown
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

const { locale } = useI18n()
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

// The lit day is a hole cut in the dim overlay rather than a raised tile, so
// a multi-day band crossing it stays visible and lit there. The hole follows the
// day while the grid or the day resizes.
const spotlightHole = ref<{ left: number; top: number; right: number; bottom: number } | null>(null)
let spotlightTracking: { grid: HTMLElement; cell: HTMLElement; observer: ResizeObserver } | null = null

const spotlightStyle = computed(() => {
  const hole = spotlightHole.value
  if (!hole) return undefined
  const { left: l, top: t, right: r, bottom: b } = hole
  return {
    clipPath: `polygon(evenodd, 0 0, 100% 0, 100% 100%, 0 100%, 0 0, ${l}px ${t}px, ${l}px ${b}px, ${r}px ${b}px, ${r}px ${t}px, ${l}px ${t}px)`,
  }
})

// In the overlay's own coordinates: the grid's padding box, inside its border.
function measureSpotlightHole() {
  if (!spotlightTracking) return
  const { grid, cell } = spotlightTracking
  const gridRect = grid.getBoundingClientRect()
  const cellRect = cell.getBoundingClientRect()
  const originX = gridRect.left + grid.clientLeft
  const originY = gridRect.top + grid.clientTop
  spotlightHole.value = {
    left: cellRect.left - originX,
    top: cellRect.top - originY,
    right: cellRect.right - originX,
    bottom: cellRect.bottom - originY,
  }
}

function stopSpotlightTracking() {
  spotlightTracking?.observer.disconnect()
  spotlightTracking = null
  spotlightHole.value = null
}

function startSpotlight(event: AnimationEvent) {
  const grid = (event.currentTarget as HTMLElement).parentElement
  const cell = grid?.querySelector<HTMLElement>('.calendar-day--highlighted')
  if (!grid || !cell) return
  stopSpotlightTracking()
  const observer = new ResizeObserver(measureSpotlightHole)
  spotlightTracking = { grid, cell, observer }
  measureSpotlightHole()
  observer.observe(grid)
  observer.observe(cell)
  revealSpotlightCell(cell)
}

// The lit day may sit below the fold (on a phone); bring it on screen as the dim starts.
function revealSpotlightCell(cell: HTMLElement) {
  const { top, bottom } = cell.getBoundingClientRect()
  if (top >= 0 && bottom <= window.innerHeight) return
  cell.scrollIntoView({ behavior: 'smooth', block: 'center' })
}

onBeforeUnmount(stopSpotlightTracking)

// A highlight is a one-off spotlight: every new highlightDay value, even the
// same date again, replays it, and it clears itself when the animation ends.
const flashDay = ref<Props['highlightDay']>(null)
const flashKey = ref(0)

watch(() => props.highlightDay, day => {
  stopSpotlightTracking()
  flashDay.value = day
  flashKey.value += 1
}, { immediate: true })

function endFlash() {
  stopSpotlightTracking()
  flashDay.value = null
}

function isHighlighted(day: CalendarDay): boolean {
  if (!flashDay.value) return false
  return (
    day.year === flashDay.value.year &&
    day.month === flashDay.value.month &&
    day.day === flashDay.value.day
  )
}

const hasSpotlight = computed(() => !props.focusedDay && visibleDays.value.some(isHighlighted))
watch(hasSpotlight, shown => {
  if (!shown) stopSpotlightTracking()
})

function isSelected(day: CalendarDay): boolean {
  if (!props.selectedDay) return false
  return (
    day.year === props.selectedDay.year &&
    day.month === props.selectedDay.month &&
    day.day === props.selectedDay.day
  )
}

// Today's date strip would cover the inset selection ring, so a selected today
// redraws the ring above it.
function hasTodaySelectionBorder(day: CalendarDay): boolean {
  return !props.focusedDay && isToday(day) && isSelected(day) && !isHighlighted(day)
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

// White glass over a tile: strong on light fills, faint on dark ones; empty
// tiles take the theme's tint (--calendar-span-empty-*).
function getSpanGlass(day: CalendarDay, surface?: string): string {
  const fill = getFillColor(day)
  if (fill) return `color-mix(in srgb, #fff ${isLightColor(fill) ? 45 : 10}%, ${surface ?? fill})`
  const tile = surface ?? (isCurrentMonth(day) ? 'var(--dp-calendar-cell-bg)' : 'var(--calendar-surface)')
  return `color-mix(in srgb, var(--calendar-span-empty-tint) var(--calendar-span-empty-glass), ${tile})`
}

// The ink of a covered day, as the tile's ink classes would set it.
function getSpanInk(day: CalendarDay): string {
  const fill = getFillColor(day)
  if (!fill) return 'var(--dp-text-primary)'
  return isLightColor(fill) ? 'var(--dp-text-on-light)' : 'var(--dp-text-on-dark)'
}

// Offsets inside a band are in band coordinates, where one day plus its gutter
// is (band width + insets + gap) / days, so they land on the grid's own gutters.
function getSpanGutterOffset(n: number, days: number, gapShare: string): string {
  const day = `(100% + var(--calendar-span-start) + var(--calendar-span-end) + var(--calendar-gap)) / ${days}`
  return `calc(${n} * ${day} - var(--calendar-span-start) - ${gapShare})`
}

// The band is opaque: each day's stretch is the glass over that day's tile, and
// neighbouring days meet in the middle of the gutter between them, under its
// divider. The rim takes each day's ink the same way.
function getSpanStyle(firstIndex: number, days: number): Record<string, string | number> {
  const covered = visibleDays.value.slice(firstIndex, firstIndex + days)
  const glasses = covered.map(day => getSpanGlass(day))
  const inks = covered.map(getSpanInk)
  const perDay: Record<string, string> = {}
  inks.forEach((ink, n) => { perDay[`--calendar-span-ink-${n}`] = ink })
  glasses.forEach((glass, n) => { perDay[`--calendar-span-glass-${n}`] = glass })
  covered.forEach((day, n) => { perDay[`--calendar-span-gutter-glass-${n}`] = getSpanGlass(day, 'var(--calendar-gutter)') })
  const seam = (n: number) => getSpanGutterOffset(n, days, 'var(--calendar-gap) / 2')
  const gradient = (colors: string[]) => `linear-gradient(to right, ${colors.map((color, n) =>
    `${color} ${n === 0 ? '0' : seam(n)} ${n === colors.length - 1 ? '100%' : seam(n + 1)}`).join(', ')})`
  return {
    '--calendar-span-days': days,
    '--calendar-span-fill': gradient(glasses),
    '--calendar-span-outline': gradient(inks.map(ink =>
      `color-mix(in srgb, ${ink} var(--calendar-span-outline-strength), transparent)`)),
    // Tags read the ink and glass of the day each one sits over (CalendarSpanTags);
    // the end time and chevron always sit on the last day.
    ...perDay,
    '--calendar-span-end-ink': getSpanInk(covered[covered.length - 1]!),
    '--calendar-span-ring': glasses[glasses.length - 1]!,
  }
}

// The divider over the gutter before covered day n is a box, not a gradient
// stop, so it snaps to device pixels exactly like the gutter it covers.
function getSpanDividerStyle(n: number, days: number): Record<string, string> {
  return {
    left: getSpanGutterOffset(n, days, 'var(--calendar-gap)'),
    '--calendar-span-before-ink': `var(--calendar-span-ink-${n - 1})`,
    '--calendar-span-before-glass': `var(--calendar-span-glass-${n - 1})`,
    '--calendar-span-after-ink': `var(--calendar-span-ink-${n})`,
    '--calendar-span-after-glass': `var(--calendar-span-glass-${n})`,
    '--calendar-span-before-gutter': `var(--calendar-span-gutter-glass-${n - 1})`,
    '--calendar-span-after-gutter': `var(--calendar-span-gutter-glass-${n})`,
  }
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
  // Today's date strip sets its own (white) ink.
  if (isToday(day)) return 'var(--calendar-ink)'
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
          'ring-2 ring-dp-accent ring-inset': !focusedDay && isSelected(day) && !isHighlighted(day),
          'duty-day-focused': isFocused(day),
        }
      ]"
      :style="getDayStyle(day)"
    >
      <span
        v-if="hasTodaySelectionBorder(day)"
        class="calendar-day-selection-border"
        aria-hidden="true"
      />
      <div class="calendar-day-head">
        <div class="calendar-day-top">
          <span
            class="calendar-day-number"
            :style="{ color: getDayNumberColor(day, idx % 7) }"
          >
            {{ day.day }}
          </span>
          <slot name="day-header" :day="day" :index="getSourceIndex(idx)" />
        </div>
        <slot name="day-pinned" :day="day" :index="getSourceIndex(idx)" />
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
              :style="getSpanStyle(idx, lane.segment.days)"
            >
              <span
                v-for="n in lane.segment.days - 1"
                :key="n"
                class="calendar-span__divider"
                :style="getSpanDividerStyle(n, lane.segment.days)"
                aria-hidden="true"
              />
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

    <span
      v-if="hasSpotlight"
      :key="flashKey"
      class="calendar-grid-spotlight"
      :style="spotlightStyle"
      aria-hidden="true"
      @animationstart="startSpotlight"
      @animationend="endFlash"
    />
  </div>
</template>

<style scoped>
/* Flat month grid: the gutters between tiles are the only separators, so equal
   duty colours on neighbouring days still read as separate days. */
.calendar-grid {
  --calendar-gutter: var(--dp-border-primary);
  --calendar-surface: var(--dp-calendar-cell-prev-next);
  --calendar-today: var(--dp-danger-hover);
  /* Phones use the 1pt iOS gutter. */
  --calendar-gap: 1px;
  --calendar-pad-x: 1.5px;
  /* White glass would vanish on a light empty tile, so it takes a faint ink tint. */
  --calendar-span-empty-tint: var(--dp-text-primary);
  --calendar-span-empty-glass: 6%;

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
:global(.dark .calendar-grid) {
  --calendar-span-empty-tint: #fff;
  --calendar-span-empty-glass: 10%;
}

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

/* The header row holds the date and pinned content; the tallest header of the
   week sets where every day's lanes start. */
.calendar-day-head {
  min-width: 0;
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

.calendar-day--today {
  z-index: 1;
}

.calendar-day-top {
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

/* Today: the date row becomes a red strip bled to the tile's top and sides,
   cancelling the tile's padding, with white ink for the date and a pinned
   D-Day label. */
.calendar-day--today .calendar-day-top {
  --calendar-ink: #fff;
  --calendar-ink-muted: #fff;

  margin: -4px calc(-1 * var(--calendar-pad-x)) 2px;
  padding: 4px calc(var(--calendar-pad-x) + 2px) 2px;
  background: var(--calendar-today);
  box-shadow: 0 1px 0 rgb(0 0 0 / 20%);
}

.calendar-day-selection-border {
  position: absolute;
  inset: 0;
  border: 2px solid var(--dp-accent);
  pointer-events: none;
  z-index: 1;
}

/* Spotlight: one overlay dims the whole grid, multi-day bands (z-index 2)
   included, except the lit day clipped out of it (spotlightStyle), for 0.25s
   in, a hold until 1.05s and 0.9s out, as on iOS. The grid's overflow keeps it
   inside the rounded corners. It rests invisible, so nothing lingers even
   before animationend removes it. Dimming is not motion, so reduced motion
   keeps it. */
.calendar-grid-spotlight {
  position: absolute;
  inset: 0;
  z-index: 3;
  background: rgb(0 0 0 / 40%);
  opacity: 0;
  pointer-events: none;
  animation: calendar-grid-spotlight 1.95s ease-in;
}

@keyframes calendar-grid-spotlight {
  0% { opacity: 0; }
  12.8205% { opacity: 1; }
  53.8462% { opacity: 1; animation-timing-function: ease-out; }
  100% { opacity: 0; }
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

:slotted(.calendar-item__line--dday) {
  display: block;
  overflow: visible;
  -webkit-line-clamp: none;
  line-clamp: none;
  overflow-wrap: anywhere;
}

/* Only overflowing titles retain a clamped box, keeping their time visible.
   Titles that fit two lines flow inline so the time can use their final line.
   The line contains the floated time chip, so a wrapped chip adds to its height. */
:slotted(.calendar-item__line--chip) {
  display: flow-root;
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

:slotted(.calendar-item__line--chip > .calendar-item__text--flow) {
  display: inline;
  overflow: visible;
  vertical-align: baseline;
}

/* The gap before the chip, as on iOS: a preserved space takes room when the chip
   shares the title's last line, but hangs at a line end, so it neither wraps the
   title nor narrows a chip on its own line. */
:slotted(.calendar-item__line--chip > .calendar-item__text--flow)::after {
  content: ' ';
  white-space: pre-wrap;
}

/* Floated after the title, the whole pill sits at the right edge of the title's
   last line when it fits beside it, and at the right edge of the next line
   otherwise. Only a range wider than the line breaks inside it, at the <wbr>
   after "~", with both lines flush right. On a duty fill the tile sets a
   tone-on-tone pair; otherwise the chip is a neutral ink tint. On phones a short
   box with the iOS tracking and a hairline of side room fits a narrow row. */
:slotted(.calendar-item__time) {
  display: inline-block;
  float: right;
  max-width: 100%;
  margin-top: 1px;
  margin-left: 0;
  padding: 0 1px;
  border-radius: 2.5px;
  background: var(--calendar-time-bg, color-mix(in srgb, var(--calendar-ink) 8.5%, transparent));
  color: var(--calendar-time-ink, color-mix(in srgb, var(--calendar-ink) 82%, transparent));
  font-size: 0.77em;
  font-weight: 700;
  line-height: 1.2;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.36px;
  text-align: right;
}

/* A lone time has room to spare on a phone row, so it stops short of the edge;
   a range keeps the whole row. */
:slotted(.calendar-item__time--single) {
  margin-right: 2px;
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

/* One soft-glass ribbon per week segment. It spans its days and the gutters
   between them, is inset with rounded ends only at the schedule's true start
   and end, and runs square to the row edge where the schedule continues into
   another week. Clicks fall through to the day underneath. Its fill is glass
   over each covered day (getSpanStyle), rimmed in each day's ink. Its title
   follows the tile it starts in; each tag follows the tile under it, and the
   end time and chevron the tile it ends in. */
.calendar-span {
  --calendar-span-inset: 2px;
  --calendar-span-radius: 4px;
  --calendar-span-start: 0px;
  --calendar-span-end: 0px;
  --calendar-span-outline-strength: 34%;
  --calendar-span-shadow: 0 1px 2px rgb(15 23 42 / 16%);

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
  background: var(--calendar-span-fill);
  box-shadow: var(--calendar-span-shadow);
  color: var(--calendar-ink);
  font-size: 10px;
  line-height: 1.2;
  letter-spacing: -0.03em;
  white-space: nowrap;
  pointer-events: none;
  container-type: inline-size;
}

:global(.dark) .calendar-span {
  --calendar-span-shadow: 0 1px 2px rgb(0 0 0 / 40%);
}

/* The rim: a transparent 1px border shows the per-day ink outline over the
   band's fill while the padding box repaints the fill, so it follows the
   rounded ends. */
.calendar-span::before {
  content: '';
  position: absolute;
  inset: 0;
  z-index: -1;
  border: 1px solid transparent;
  border-radius: inherit;
  background: var(--calendar-span-fill) padding-box, var(--calendar-span-outline) border-box;
  background-origin: border-box;
}

/* Light gutters show through each side's glass, keeping their light polarity
   through the band. The opaque divider covers the fill's seam inside the rim. */
.calendar-span__divider {
  position: absolute;
  z-index: -1;
  top: 1px;
  bottom: 1px;
  width: var(--calendar-gap);
  background: linear-gradient(to right, var(--calendar-span-before-gutter) 50%, var(--calendar-span-after-gutter) 50%);
}

:global(.dark .calendar-span__divider) {
  --calendar-span-divider-strength: 18%;

  background:
    linear-gradient(
      to right,
      color-mix(in srgb, var(--calendar-span-before-ink) var(--calendar-span-divider-strength), transparent) 50%,
      color-mix(in srgb, var(--calendar-span-after-ink) var(--calendar-span-divider-strength), transparent) 50%
    ),
    linear-gradient(to right, var(--calendar-span-before-glass) 50%, var(--calendar-span-after-glass) 50%);
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
  color: color-mix(in srgb, var(--calendar-ink) 62%, transparent);
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

:slotted(.calendar-span__time--end) {
  color: color-mix(in srgb, var(--calendar-span-end-ink) 62%, transparent);
}

.calendar-span__more {
  flex: none;
  width: 0.9em;
  height: 0.9em;
  color: color-mix(in srgb, var(--calendar-span-end-ink) 45%, transparent);
  stroke-width: 2.5;
}

@media (min-width: 640px) {
  .calendar-grid {
    --calendar-gap: 2px;
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

  .calendar-day--today .calendar-day-top {
    margin: -7px calc(-1 * var(--calendar-pad-x)) 4px;
    padding: 6px var(--calendar-pad-x) 4px;
  }

  .calendar-day-holiday {
    font-size: 12px;
  }

  :slotted(.calendar-items) {
    gap: 4px;
  }

  :slotted(.calendar-item) {
    padding: 0;
    font-size: 12px;
    line-height: 1.38;
    letter-spacing: normal;
  }

  /* Center the rule in the 4px gap instead of hugging the next item. */
  :slotted(.calendar-item + .calendar-item) {
    margin-top: -2px;
    padding-top: 2px;
  }

  :slotted(.calendar-item__time) {
    margin-top: 0;
    margin-left: 0.25em;
    padding: 1px 5px;
    border-radius: 5px;
    font-size: 0.84em;
    line-height: 1.4;
    letter-spacing: normal;
  }

  :slotted(.calendar-item__time--single) {
    margin-right: 0;
  }

  :slotted(.calendar-item__line--chip > .calendar-item__text--flow)::after {
    content: none;
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
