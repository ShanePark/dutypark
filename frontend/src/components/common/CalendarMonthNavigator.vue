<script setup lang="ts">
import { onBeforeUnmount } from 'vue'
import { useI18n } from 'vue-i18n'
import { ChevronLeft, ChevronRight } from 'lucide-vue-next'

defineProps<{
  currentYear: number
  currentMonth: number
}>()

const emit = defineEmits<{
  (e: 'prev-month'): void
  (e: 'next-month'): void
  (e: 'open-year-month-picker'): void
}>()

const { t } = useI18n()

const MONTH_SWIPE_THRESHOLD = 44
const MONTH_SWIPE_VERTICAL_TOLERANCE = 28

let monthTouchStartX = 0
let monthTouchStartY = 0
let monthTouchLastX = 0
let monthTouchLastY = 0
let isMonthTouching = false
let suppressMonthPickerClick = false
let suppressClickTimer: number | null = null

function resetMonthTouch() {
  monthTouchStartX = 0
  monthTouchStartY = 0
  monthTouchLastX = 0
  monthTouchLastY = 0
  isMonthTouching = false
}

function scheduleSuppressClickReset() {
  if (suppressClickTimer !== null) {
    window.clearTimeout(suppressClickTimer)
  }

  suppressClickTimer = window.setTimeout(() => {
    suppressMonthPickerClick = false
    suppressClickTimer = null
  }, 250)
}

function handleMonthTouchStart(event: TouchEvent) {
  const touch = event.touches[0]
  if (!touch) return

  monthTouchStartX = touch.clientX
  monthTouchStartY = touch.clientY
  monthTouchLastX = touch.clientX
  monthTouchLastY = touch.clientY
  isMonthTouching = true
}

function handleMonthTouchMove(event: TouchEvent) {
  if (!isMonthTouching) return

  const touch = event.touches[0]
  if (!touch) return

  monthTouchLastX = touch.clientX
  monthTouchLastY = touch.clientY
}

function handleMonthTouchEnd(event: TouchEvent) {
  if (!isMonthTouching) return

  const touch = event.changedTouches[0]
  const endX = touch?.clientX ?? monthTouchLastX
  const endY = touch?.clientY ?? monthTouchLastY
  const deltaX = endX - monthTouchStartX
  const deltaY = Math.abs(endY - monthTouchStartY)
  const isHorizontalSwipe =
    Math.abs(deltaX) >= MONTH_SWIPE_THRESHOLD &&
    Math.abs(deltaX) > deltaY + MONTH_SWIPE_VERTICAL_TOLERANCE

  resetMonthTouch()

  if (!isHorizontalSwipe) return

  if (event.cancelable) {
    event.preventDefault()
  }
  event.stopPropagation()
  suppressMonthPickerClick = true

  if (deltaX > 0) {
    emit('prev-month')
  } else {
    emit('next-month')
  }

  scheduleSuppressClickReset()
}

function handleMonthButtonClick(event: MouseEvent) {
  if (suppressMonthPickerClick) {
    event.preventDefault()
    event.stopPropagation()
    suppressMonthPickerClick = false
    return
  }

  emit('open-year-month-picker')
}

onBeforeUnmount(() => {
  if (suppressClickTimer !== null) {
    window.clearTimeout(suppressClickTimer)
  }
})
</script>

<template>
  <div class="flex items-center justify-center">
    <button
      type="button"
      @click="emit('prev-month')"
      class="calendar-nav-btn flex min-h-11 min-w-11 flex-shrink-0 cursor-pointer items-center justify-center rounded-full p-1 sm:p-2"
      :aria-label="t('common.calendar.previousMonth')"
    >
      <ChevronLeft class="h-5 w-5 sm:h-6 sm:w-6" />
    </button>
    <button
      type="button"
      @click="handleMonthButtonClick"
      @touchstart.passive="handleMonthTouchStart"
      @touchmove.passive="handleMonthTouchMove"
      @touchend="handleMonthTouchEnd"
      @touchcancel="resetMonthTouch"
      class="calendar-nav-btn flex min-h-11 min-w-[5.5rem] touch-pan-y select-none items-center justify-center whitespace-nowrap rounded px-1 py-1 text-lg font-semibold cursor-pointer sm:min-w-[6.75rem] sm:px-3 sm:text-2xl"
    >
      {{ currentYear }}-{{ String(currentMonth).padStart(2, '0') }}
    </button>
    <button
      type="button"
      @click="emit('next-month')"
      class="calendar-nav-btn flex min-h-11 min-w-11 flex-shrink-0 cursor-pointer items-center justify-center rounded-full p-1 sm:p-2"
      :aria-label="t('common.calendar.nextMonth')"
    >
      <ChevronRight class="h-5 w-5 sm:h-6 sm:w-6" />
    </button>
  </div>
</template>
