<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { Calendar, ChevronLeft, ChevronRight, Lock } from 'lucide-vue-next'
import { useEscapeKey } from '@/composables/useEscapeKey'
import { formatDateOnly } from '@/utils/date'
import {
  DAYS_PER_WEEK,
  addDaysIso,
  addMonthsIso,
  buildMonthGrid,
  buildWeekdayLabels,
  clampIsoToRange,
  countDaysInclusive,
  endOfWeekIso,
  formatDayLabel,
  formatFieldValue,
  formatMonthLabel,
  isDateDisabled,
  isIsoDate,
  maxPopoverWidth,
  resolveInitialMonth,
  resolvePopoverPosition,
  resolveRangeDayState,
  resolveRangeMin,
  startOfWeekIso,
  toMonth,
  type DatePickerMonth,
  type PopoverPosition,
} from './datePickerGrid'

// The trigger is the component's root so it can drop straight into a grid or flex row where an
// <input type="date"> used to sit; that leaves the Teleport as a second root, which turns off
// automatic fallthrough.
defineOptions({ inheritAttrs: false })

const props = withDefaults(
  defineProps<{
    /** ISO `YYYY-MM-DD`; `''` means empty. */
    modelValue: string
    /**
     * `'range'` turns the popover into a hotel-style check-in/check-out picker anchored at
     * `rangeStart`: days before the anchor are unreachable, the span paints as one block, and
     * nothing is emitted until the footer confirm is pressed.
     */
    mode?: 'single' | 'range'
    /** ISO anchor the range is measured from; required when `mode` is `'range'`. */
    rangeStart?: string
    /** ISO date, inclusive. */
    min?: string
    /** ISO date, inclusive. */
    max?: string
    disabled?: boolean
    /** Shows the value, opens nothing. */
    readonly?: boolean
    invalid?: boolean
    ariaLabel?: string
    placeholder?: string
  }>(),
  {
    mode: 'single',
    rangeStart: undefined,
    min: undefined,
    max: undefined,
    disabled: false,
    readonly: false,
    invalid: false,
    ariaLabel: undefined,
    placeholder: undefined,
  },
)

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const { t, locale } = useI18n()

const triggerRef = ref<HTMLButtonElement | null>(null)
const popoverRef = ref<HTMLElement | null>(null)

const isOpen = ref(false)
const todayIso = ref(formatDateOnly(new Date()))
const visibleMonth = ref<DatePickerMonth>(toMonth(todayIso.value))
const focusedDate = ref(todayIso.value)
const position = ref<PopoverPosition | null>(null)
const popoverMaxWidth = ref<number | null>(null)

/** Range mode only: the day a click has staged, still unemitted until confirm. */
const pendingDate = ref('')
const hoveredDate = ref('')
const isFocusInGrid = ref(false)

const canOpen = computed(() => !props.disabled && !props.readonly)
const hasValue = computed(() => isIsoDate(props.modelValue))
const displayValue = computed(() => formatFieldValue(props.modelValue, locale.value))
const placeholderText = computed(() => props.placeholder ?? t('common.datePicker.placeholder'))
const weekdayLabels = computed(() => buildWeekdayLabels(locale.value))
const monthLabel = computed(() =>
  formatMonthLabel(visibleMonth.value.year, visibleMonth.value.month, locale.value),
)

/** Empty unless the component is in a usable range mode, which makes it the mode switch too. */
const rangeAnchor = computed(() =>
  props.mode === 'range' && isIsoDate(props.rangeStart) ? props.rangeStart : '',
)
const isRange = computed(() => rangeAnchor.value !== '')
/**
 * The single lower bound the whole popover obeys. In range mode the anchor joins `min` here, so
 * disabling, keyboard movement and the previous-month arrow all stop at it from one place.
 */
const effectiveMin = computed(() =>
  isRange.value ? resolveRangeMin(props.min, rangeAnchor.value) : props.min,
)

const dialogLabel = computed(() =>
  t(isRange.value ? 'common.datePicker.rangeDialogLabel' : 'common.datePicker.dialogLabel'),
)

/** First day of the visible month, the anchor every month-level bound is derived from. */
const visibleMonthStart = computed(
  () => `${visibleMonth.value.year}-${String(visibleMonth.value.month).padStart(2, '0')}-01`,
)
const canGoPrevious = computed(
  () =>
    !isIsoDate(effectiveMin.value) || addDaysIso(visibleMonthStart.value, -1) >= effectiveMin.value,
)
const canGoNext = computed(
  () => !isIsoDate(props.max) || addMonthsIso(visibleMonthStart.value, 1) <= props.max,
)
const canGoToToday = computed(() => !isDateDisabled(todayIso.value, effectiveMin.value, props.max))

/**
 * The end the grid paints right now. Hover wins over the keyboard cursor, and both win over the
 * staged day, so moving over the grid previews a span before anything is clicked; with the mouse
 * away and focus outside the grid it settles back on what confirm would actually commit.
 */
const previewEnd = computed(() => {
  if (!isRange.value) return ''
  if (hoveredDate.value !== '') return hoveredDate.value
  return isFocusInGrid.value ? focusedDate.value : pendingDate.value
})

const canConfirm = computed(() => isRange.value && pendingDate.value !== '')

const pendingRange = computed(() => {
  if (!canConfirm.value) return null
  return {
    end: formatFieldValue(pendingDate.value, locale.value),
    days: countDaysInclusive(rangeAnchor.value, pendingDate.value),
  }
})

const anchorLabel = computed(() => formatFieldValue(rangeAnchor.value, locale.value))

const gridCells = computed(() =>
  buildMonthGrid(visibleMonth.value.year, visibleMonth.value.month).map((cell) => {
    const rangeState = isRange.value
      ? resolveRangeDayState(cell.date, rangeAnchor.value, previewEnd.value)
      : 'none'
    return {
      ...cell,
      label: formatDayLabel(cell.date, locale.value),
      isDisabled: isDateDisabled(cell.date, effectiveMin.value, props.max),
      isToday: cell.date === todayIso.value,
      isSelected: isRange.value
        ? cell.date === pendingDate.value
        : cell.date === props.modelValue,
      rangeClass: rangeState === 'none' ? '' : `date-picker-day--range-${rangeState}`,
    }
  }),
)

const weeks = computed(() => {
  const cells = gridCells.value
  return Array.from({ length: cells.length / DAYS_PER_WEEK }, (_, index) =>
    cells.slice(index * DAYS_PER_WEEK, (index + 1) * DAYS_PER_WEEK),
  )
})

// Roving tabindex: exactly one day is tabbable. The focused day normally is, but a month the
// user paged to may not contain it, so fall back to a day that can actually take focus.
const rovingDate = computed(() => {
  const cells = gridCells.value
  if (cells.some((cell) => cell.date === focusedDate.value && !cell.isDisabled)) {
    return focusedDate.value
  }
  const fallback =
    cells.find((cell) => cell.isCurrentMonth && !cell.isDisabled) ??
    cells.find((cell) => !cell.isDisabled)
  return fallback?.date ?? ''
})

const popoverStyle = computed(() => ({
  top: `${position.value?.top ?? 0}px`,
  left: `${position.value?.left ?? 0}px`,
  maxWidth: popoverMaxWidth.value === null ? undefined : `${popoverMaxWidth.value}px`,
}))

function updatePosition() {
  const trigger = triggerRef.value
  const popover = popoverRef.value
  if (!trigger || !popover) return

  const rect = trigger.getBoundingClientRect()
  position.value = resolvePopoverPosition(
    { top: rect.top, bottom: rect.bottom, left: rect.left, width: rect.width },
    { width: popover.offsetWidth, height: popover.offsetHeight },
    { width: window.innerWidth, height: window.innerHeight },
  )
}

async function focusRovingDay() {
  await nextTick()
  popoverRef.value
    ?.querySelector<HTMLButtonElement>(`[data-date="${rovingDate.value}"]`)
    ?.focus()
}

/**
 * Where the grid cursor starts. Range mode opens on the staged end when there is one and on the
 * anchor otherwise, so the popover always opens showing the day the span is measured from.
 */
function initialFocusDate(): string {
  if (isRange.value) {
    const start = isIsoDate(props.modelValue) ? props.modelValue : rangeAnchor.value
    return clampIsoToRange(start, effectiveMin.value, props.max)
  }
  return isIsoDate(props.modelValue)
    ? props.modelValue
    : clampIsoToRange(todayIso.value, props.min, props.max)
}

async function open() {
  if (!canOpen.value || isOpen.value) return

  todayIso.value = formatDateOnly(new Date())
  const initialFocus = initialFocusDate()
  focusedDate.value = initialFocus
  visibleMonth.value = isRange.value
    ? toMonth(initialFocus)
    : resolveInitialMonth(props.modelValue, props.min, props.max, todayIso.value)
  pendingDate.value =
    isRange.value && isIsoDate(props.modelValue) && !isDateDisabled(props.modelValue, effectiveMin.value, props.max)
      ? props.modelValue
      : ''
  hoveredDate.value = ''
  isFocusInGrid.value = false
  position.value = null
  popoverMaxWidth.value = maxPopoverWidth(window.innerWidth)
  isOpen.value = true

  await nextTick()
  updatePosition()
  await focusRovingDay()
}

/** Closing is also how a range is discarded: nothing has been emitted until confirm runs. */
function close(options: { restoreFocus?: boolean } = {}) {
  if (!isOpen.value) return
  isOpen.value = false
  pendingDate.value = ''
  hoveredDate.value = ''
  isFocusInGrid.value = false
  if (options.restoreFocus) {
    triggerRef.value?.focus()
  }
}

function toggle() {
  if (isOpen.value) {
    close()
    return
  }
  void open()
}

/** The one and only place a value leaves this component. */
function commit(iso: string) {
  emit('update:modelValue', iso)
  close({ restoreFocus: true })
}

function selectDate(iso: string) {
  if (isDateDisabled(iso, effectiveMin.value, props.max)) return
  if (isRange.value) {
    pendingDate.value = iso
    focusedDate.value = iso
    return
  }
  commit(iso)
}

function confirmRange() {
  if (!canConfirm.value) return
  commit(pendingDate.value)
}

/**
 * Navigation only, in both modes: it moves the view and the cursor to today and never selects,
 * so it cannot slip a value past the confirm step in range mode.
 */
function goToToday() {
  if (!canGoToToday.value) return
  visibleMonth.value = toMonth(todayIso.value)
  focusedDate.value = todayIso.value
  void focusRovingDay()
}

function shiftMonth(delta: number) {
  visibleMonth.value = toMonth(addMonthsIso(visibleMonthStart.value, delta))
  // Keep the roving target inside the month on screen without stealing focus from the nav button.
  focusedDate.value = clampIsoToRange(
    addMonthsIso(focusedDate.value, delta),
    effectiveMin.value,
    props.max,
  )
}

function moveFocusTo(iso: string) {
  if (isDateDisabled(iso, effectiveMin.value, props.max)) return
  focusedDate.value = iso
  visibleMonth.value = toMonth(iso)
  void focusRovingDay()
}

const gridKeyMoves: Record<string, (iso: string) => string> = {
  ArrowLeft: (iso) => addDaysIso(iso, -1),
  ArrowRight: (iso) => addDaysIso(iso, 1),
  ArrowUp: (iso) => addDaysIso(iso, -DAYS_PER_WEEK),
  ArrowDown: (iso) => addDaysIso(iso, DAYS_PER_WEEK),
  Home: startOfWeekIso,
  End: endOfWeekIso,
  PageUp: (iso) => addMonthsIso(iso, -1),
  PageDown: (iso) => addMonthsIso(iso, 1),
}

function handleGridKeydown(event: KeyboardEvent) {
  const move = gridKeyMoves[event.key]
  if (!move) return
  event.preventDefault()
  moveFocusTo(move(focusedDate.value))
}

function handleDayFocus(iso: string) {
  focusedDate.value = iso
  isFocusInGrid.value = true
}

// Only a move that leaves the grid entirely ends the keyboard preview; day-to-day moves inside it
// fire focusout too, and clearing on those would make the span blink on every arrow key.
function handleGridFocusOut(event: FocusEvent) {
  const grid = event.currentTarget
  const next = event.relatedTarget
  if (grid instanceof Node && next instanceof Node && grid.contains(next)) return
  isFocusInGrid.value = false
}

function handlePointerDownOutside(event: PointerEvent) {
  const target = event.target
  if (!(target instanceof Node)) return
  if (triggerRef.value?.contains(target) || popoverRef.value?.contains(target)) return
  close()
}

function stopListening() {
  document.removeEventListener('pointerdown', handlePointerDownOutside, true)
  window.removeEventListener('resize', updatePosition)
  window.removeEventListener('scroll', updatePosition, true)
}

watch(isOpen, (open) => {
  if (open) {
    document.addEventListener('pointerdown', handlePointerDownOutside, true)
    window.addEventListener('resize', updatePosition)
    // Capture, because the field may live inside a scrolling modal body rather than the page.
    window.addEventListener('scroll', updatePosition, true)
    return
  }
  stopListening()
})

watch(
  () => [props.disabled, props.readonly] as const,
  () => {
    if (!canOpen.value) {
      close()
    }
  },
)

// An anchor that moves under an open popover must not leave a staged day behind it.
watch(effectiveMin, () => {
  if (pendingDate.value !== '' && isDateDisabled(pendingDate.value, effectiveMin.value, props.max)) {
    pendingDate.value = ''
  }
})

useEscapeKey(isOpen, () => close({ restoreFocus: true }))

onBeforeUnmount(stopListening)
</script>

<template>
  <button
    ref="triggerRef"
    type="button"
    class="date-picker-field form-control"
    :class="{
      'date-picker-field--readonly': readonly,
      'date-picker-field--empty': !hasValue,
    }"
    :disabled="disabled"
    :aria-label="ariaLabel"
    :aria-invalid="invalid ? 'true' : undefined"
    :aria-readonly="readonly ? 'true' : undefined"
    :aria-haspopup="canOpen ? 'dialog' : undefined"
    :aria-expanded="canOpen ? isOpen : undefined"
    :title="readonly ? t('common.datePicker.locked') : undefined"
    @click="toggle"
    v-bind="$attrs"
  >
    <span class="date-picker-field__value">{{ hasValue ? displayValue : placeholderText }}</span>
    <!-- The lock is the only signal that survives every theme, so unlike the calendar it is never
         dropped on a narrow row. -->
    <Lock v-if="readonly" class="date-picker-field__icon date-picker-field__icon--lock" aria-hidden="true" />
    <Calendar v-else class="date-picker-field__icon date-picker-field__icon--calendar" aria-hidden="true" />
  </button>

  <Teleport to="body">
    <div
      v-if="isOpen"
      ref="popoverRef"
      class="date-picker-popover"
      :class="{ 'date-picker-popover--placed': position !== null }"
      :style="popoverStyle"
      role="dialog"
      :aria-label="dialogLabel"
    >
      <div class="date-picker-popover__header">
        <span class="date-picker-popover__title" aria-live="polite">{{ monthLabel }}</span>
        <div class="date-picker-popover__controls">
          <button
            type="button"
            class="date-picker-popover__today"
            :aria-label="t('common.datePicker.goToToday')"
            :disabled="!canGoToToday"
            @click="goToToday"
          >
            {{ t('common.datePicker.today') }}
          </button>
          <button
            type="button"
            class="date-picker-popover__nav"
            :aria-label="t('common.calendar.previousMonth')"
            :disabled="!canGoPrevious"
            @click="shiftMonth(-1)"
          >
            <ChevronLeft class="h-4 w-4" />
          </button>
          <button
            type="button"
            class="date-picker-popover__nav"
            :aria-label="t('common.calendar.nextMonth')"
            :disabled="!canGoNext"
            @click="shiftMonth(1)"
          >
            <ChevronRight class="h-4 w-4" />
          </button>
        </div>
      </div>

      <div
        class="date-picker-popover__grid"
        role="grid"
        :aria-label="monthLabel"
        @keydown="handleGridKeydown"
        @focusout="handleGridFocusOut"
        @mouseleave="hoveredDate = ''"
      >
        <div class="date-picker-popover__row" role="row">
          <span
            v-for="(label, index) in weekdayLabels"
            :key="index"
            role="columnheader"
            class="date-picker-popover__weekday"
            :class="{
              'date-picker-popover__weekday--sunday': index === 0,
              'date-picker-popover__weekday--saturday': index === 6,
            }"
          >{{ label }}</span>
        </div>
        <div v-for="(week, weekIndex) in weeks" :key="weekIndex" class="date-picker-popover__row" role="row">
          <!-- A disabled button still fires mouseenter, so the hover has to be dropped by hand;
               without that, sweeping over a day before the anchor previews a span running
               backwards out of it, over the very days that are supposed to be unreachable. -->
          <button
            v-for="cell in week"
            :key="cell.date"
            type="button"
            role="gridcell"
            class="date-picker-day"
            :class="[
              {
                'date-picker-day--outside': !cell.isCurrentMonth,
                'date-picker-day--today': cell.isToday,
                'date-picker-day--selected': cell.isSelected && !isRange,
              },
              cell.rangeClass,
            ]"
            :data-date="cell.date"
            :disabled="cell.isDisabled"
            :tabindex="cell.date === rovingDate ? 0 : -1"
            :aria-selected="cell.isSelected"
            :aria-current="cell.isToday ? 'date' : undefined"
            :aria-label="cell.label"
            @click="selectDate(cell.date)"
            @focus="handleDayFocus(cell.date)"
            @mouseenter="hoveredDate = cell.isDisabled ? '' : cell.date"
          >{{ cell.day }}</button>
        </div>
      </div>

      <div v-if="isRange" class="date-picker-popover__footer">
        <div class="date-picker-popover__summary">
          <span class="date-picker-popover__summary-leg">
            <span class="date-picker-popover__summary-label">{{ t('common.datePicker.rangeStart') }}</span>
            <span class="date-picker-popover__summary-value">{{ anchorLabel }}</span>
          </span>
          <span class="date-picker-popover__summary-arrow" aria-hidden="true">→</span>
          <span class="date-picker-popover__summary-leg">
            <span class="date-picker-popover__summary-label">{{ t('common.datePicker.rangeEnd') }}</span>
            <span
              class="date-picker-popover__summary-value"
              :class="{ 'date-picker-popover__summary-value--empty': !pendingRange }"
            >{{ pendingRange ? pendingRange.end : '—' }}</span>
          </span>
        </div>
        <p
          class="date-picker-popover__duration"
          :class="{ 'date-picker-popover__duration--hint': !pendingRange }"
          aria-live="polite"
        >{{
          pendingRange
            ? t('common.datePicker.rangeDuration', { count: pendingRange.days }, pendingRange.days)
            : t('common.datePicker.rangeHint')
        }}</p>
        <div class="date-picker-popover__actions">
          <button
            type="button"
            class="date-picker-popover__action"
            @click="close({ restoreFocus: true })"
          >
            {{ t('common.datePicker.cancel') }}
          </button>
          <button
            type="button"
            class="date-picker-popover__action date-picker-popover__action--primary"
            :disabled="!canConfirm"
            @click="confirmRange"
          >
            {{ t('common.datePicker.confirm') }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.date-picker-field {
  display: flex;
  width: 100%;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  text-align: left;
  cursor: pointer;
  /* Lets the icon react to the width of this field rather than the width of the window: the
     same field is roomy full-width and cramped in the schedule modal's half-row column.
     Safe here because the field always takes its width from its parent, never from its text. */
  container-type: inline-size;
}

.date-picker-field:disabled {
  cursor: not-allowed;
}

/* A read-only field is not a control. It keeps the exact box of an editable one so the row it
   sits in stays aligned, and differentiates itself by state alone: a lock, muted text, a dashed
   edge and no press affordance. Background cannot carry this on its own — in the dark theme
   --dp-bg-tertiary and --dp-bg-input are the same colour, so it would be invisible there. */
.date-picker-field--readonly {
  background-color: var(--dp-bg-tertiary);
  border-style: dashed;
  border-color: var(--dp-border-secondary);
  color: var(--dp-text-muted);
  cursor: default;
}

/* Kills the .form-control focus ring and its transparent border along with every press cue,
   so nothing about the field suggests it opens something. */
.date-picker-field--readonly:hover,
.date-picker-field--readonly:focus,
.date-picker-field--readonly:active {
  border-color: var(--dp-border-secondary);
  background-color: var(--dp-bg-tertiary);
  box-shadow: none;
  outline: none;
}

/* Keyboard users still have to be able to see where they are; muted rather than accent, so it
   reads as text that can be reached, not as a control that can be pressed. */
.date-picker-field--readonly:focus-visible {
  outline: 2px solid var(--dp-text-muted);
  outline-offset: 1px;
}

.date-picker-field--empty .date-picker-field__value {
  color: var(--dp-text-muted);
}

.date-picker-field__value {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.date-picker-field--readonly .date-picker-field__value {
  color: var(--dp-text-muted);
}

.date-picker-field__icon {
  width: 1rem;
  height: 1rem;
  flex-shrink: 0;
  color: var(--dp-text-muted);
}

.date-picker-field__icon--lock {
  width: 0.875rem;
  height: 0.875rem;
}

/* Below this the icon's 1rem plus the gap is the difference between a whole date and an
   ellipsis, and the whole field is the click target anyway. The app's schedule form drops the
   native picker indicator on narrow rows for the same reason. The lock is exempt: it is what
   tells the user the field is locked, which matters more than the last few pixels of date. */
@container (max-width: 9rem) {
  .date-picker-field__icon--calendar {
    display: none;
  }
}

.date-picker-popover {
  position: fixed;
  z-index: 9999;
  width: 18rem;
  max-height: calc(100dvh - 1rem);
  overflow: auto;
  padding: 0.5rem;
  border: 1px solid var(--dp-border-primary);
  border-radius: 0.75rem;
  background-color: var(--dp-bg-card);
  box-shadow: var(--dp-shadow-dropdown);
  /* Hidden until measured, so the first paint never lands at the top-left corner. */
  opacity: 0;
}

.date-picker-popover--placed {
  opacity: 1;
}

/* The whole selector is global on purpose. Written as `:global(.dark) .date-picker-popover`,
   the scoped-style compiler drops the descendant and emits a bare `.dark { box-shadow }`,
   which paints the shadow on <html> and leaves the popover on the light one. */
:global(.dark .date-picker-popover) {
  box-shadow: var(--dp-shadow-dropdown-dark);
}

.date-picker-popover__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.25rem;
  padding: 0.125rem 0.25rem 0.375rem;
}

.date-picker-popover__title {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.9375rem;
  font-weight: 600;
  color: var(--dp-text-primary);
}

/* Today sits with the month arrows, where a calendar is expected to keep it, instead of at the
   bottom of the popover where it read as one more footer action. */
.date-picker-popover__controls {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  gap: 0.125rem;
}

.date-picker-popover__nav {
  display: flex;
  height: 2rem;
  width: 2rem;
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  border-radius: 9999px;
  color: var(--dp-text-secondary);
  cursor: pointer;
  transition: background-color 0.15s ease;
}

.date-picker-popover__nav:hover:not(:disabled) {
  background-color: var(--dp-bg-hover);
}

.date-picker-popover__nav:disabled {
  opacity: 0.35;
  cursor: not-allowed;
}

.date-picker-popover__today {
  display: inline-flex;
  height: 2rem;
  flex-shrink: 0;
  align-items: center;
  border-radius: 9999px;
  padding: 0 0.625rem;
  background-color: var(--dp-accent-bg);
  font-size: 0.75rem;
  font-weight: 700;
  white-space: nowrap;
  color: var(--dp-accent);
  cursor: pointer;
  transition: background-color 0.15s ease;
}

.date-picker-popover__today:hover:not(:disabled) {
  background-color: var(--dp-accent-bg-hover);
}

.date-picker-popover__today:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.date-picker-popover__today:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: 1px;
}

.date-picker-popover__row {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
}

.date-picker-popover__weekday {
  padding-bottom: 0.25rem;
  text-align: center;
  font-size: 0.6875rem;
  font-weight: 600;
  color: var(--dp-text-muted);
}

.date-picker-popover__weekday--sunday {
  color: var(--dp-sunday);
}

.date-picker-popover__weekday--saturday {
  color: var(--dp-saturday);
}

.date-picker-day {
  display: flex;
  aspect-ratio: 1;
  align-items: center;
  justify-content: center;
  border-radius: 0.5rem;
  border: 1px solid transparent;
  font-size: 0.8125rem;
  color: var(--dp-text-primary);
  cursor: pointer;
  transition: background-color 0.15s ease;
}

.date-picker-day:hover:not(:disabled) {
  background-color: var(--dp-bg-hover);
}

.date-picker-day:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: -2px;
}

.date-picker-day--outside {
  color: var(--dp-text-muted);
}

.date-picker-day:disabled {
  opacity: 0.3;
  cursor: not-allowed;
}

.date-picker-day--today {
  border-color: var(--dp-accent-border);
  font-weight: 700;
}

.date-picker-day--selected,
.date-picker-day--selected.date-picker-day--outside {
  border-color: var(--dp-accent);
  background-color: var(--dp-accent);
  color: var(--dp-text-on-dark);
  font-weight: 700;
}

.date-picker-day--selected:hover:not(:disabled) {
  background-color: var(--dp-accent-hover);
}

/* The span is one continuous bar: the days between the ends lose their corners so consecutive
   cells butt together, and only the outer corner of each end stays rounded. */
.date-picker-day--range-middle,
.date-picker-day--range-middle.date-picker-day--outside {
  border-radius: 0;
  background-color: var(--dp-accent-bg);
  color: var(--dp-text-primary);
}

.date-picker-day--range-middle:hover:not(:disabled) {
  background-color: var(--dp-accent-bg-hover);
}

.date-picker-day--range-start,
.date-picker-day--range-end,
.date-picker-day--range-single,
.date-picker-day--range-start.date-picker-day--outside,
.date-picker-day--range-end.date-picker-day--outside,
.date-picker-day--range-single.date-picker-day--outside {
  border-color: var(--dp-accent);
  background-color: var(--dp-accent);
  color: var(--dp-text-on-dark);
  font-weight: 700;
}

.date-picker-day--range-start {
  border-radius: 0.5rem 0 0 0.5rem;
}

.date-picker-day--range-end {
  border-radius: 0 0.5rem 0.5rem 0;
}

.date-picker-day--range-start:hover:not(:disabled),
.date-picker-day--range-end:hover:not(:disabled),
.date-picker-day--range-single:hover:not(:disabled) {
  background-color: var(--dp-accent-hover);
}

.date-picker-popover__footer {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
  margin-top: 0.5rem;
  padding-top: 0.5rem;
  border-top: 1px solid var(--dp-border-primary);
}

.date-picker-popover__summary {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0 0.125rem;
}

.date-picker-popover__summary-leg {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}

.date-picker-popover__summary-label {
  font-size: 0.6875rem;
  font-weight: 600;
  color: var(--dp-text-muted);
}

.date-picker-popover__summary-value {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.8125rem;
  font-weight: 700;
  color: var(--dp-text-primary);
}

.date-picker-popover__summary-value--empty {
  color: var(--dp-text-muted);
}

.date-picker-popover__summary-arrow {
  flex-shrink: 0;
  color: var(--dp-text-muted);
}

.date-picker-popover__duration {
  text-align: center;
  font-size: 0.75rem;
  font-weight: 700;
  color: var(--dp-accent);
}

.date-picker-popover__duration--hint {
  font-weight: 500;
  color: var(--dp-text-muted);
}

.date-picker-popover__actions {
  display: flex;
  gap: 0.375rem;
}

.date-picker-popover__action {
  flex: 1;
  min-height: 2.25rem;
  border-radius: 0.5rem;
  border: 1px solid var(--dp-border-input);
  padding: 0.4375rem 0.75rem;
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--dp-text-secondary);
  cursor: pointer;
  transition: background-color 0.15s ease;
}

.date-picker-popover__action:hover:not(:disabled) {
  background-color: var(--dp-bg-hover);
}

.date-picker-popover__action:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: 1px;
}

.date-picker-popover__action--primary {
  border-color: var(--dp-accent);
  background-color: var(--dp-accent);
  color: var(--dp-text-on-dark);
}

.date-picker-popover__action--primary:hover:not(:disabled) {
  border-color: var(--dp-accent-hover);
  background-color: var(--dp-accent-hover);
}

.date-picker-popover__action:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}
</style>
