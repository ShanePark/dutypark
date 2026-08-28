<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { ChevronLeft, ChevronRight, Undo2 } from 'lucide-vue-next'
import { useDragClickGuard } from '@/composables/useDragClickGuard'

const props = defineProps<{
  currentYear: number
  currentMonth: number
}>()

const emit = defineEmits<{
  (e: 'prev-month'): void
  (e: 'next-month'): void
  (e: 'open-year-month-picker'): void
  (e: 'go-to-this-month'): void
}>()

const isCurrentMonth = computed(() => {
  const today = new Date()
  return props.currentYear === today.getFullYear() && props.currentMonth === today.getMonth() + 1
})

const { t } = useI18n()
const dragClickGuard = useDragClickGuard({ resetDelay: 250 })

const MONTH_SWIPE_THRESHOLD = 44
const MONTH_SWIPE_VERTICAL_TOLERANCE = 28

let monthTouchStartX = 0
let monthTouchStartY = 0
let monthTouchLastX = 0
let monthTouchLastY = 0
let isMonthTouching = false

function resetMonthTouch() {
  monthTouchStartX = 0
  monthTouchStartY = 0
  monthTouchLastX = 0
  monthTouchLastY = 0
  isMonthTouching = false
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
  dragClickGuard.suppressNextClick()

  if (deltaX > 0) {
    emit('prev-month')
  } else {
    emit('next-month')
  }
}

function handleMonthButtonClick() {
  emit('open-year-month-picker')
}
</script>

<template>
  <div class="flex items-center justify-center gap-1 sm:gap-2">
    <button
      type="button"
      @click="emit('prev-month')"
      class="calendar-nav-arrow"
      :aria-label="t('common.calendar.previousMonth')"
    >
      <ChevronLeft class="h-6 w-6 sm:h-7 sm:w-7" />
    </button>
    <span class="relative inline-flex">
      <button
        type="button"
        @click="handleMonthButtonClick"
        @touchstart.passive="handleMonthTouchStart"
        @touchmove.passive="handleMonthTouchMove"
        @touchend="handleMonthTouchEnd"
        @touchcancel="resetMonthTouch"
        @pointerdown.capture="dragClickGuard.handlePointerDown"
        @click.capture="dragClickGuard.handleClick"
        class="calendar-nav-btn flex min-h-11 min-w-[5.5rem] touch-pan-y select-none items-center justify-center whitespace-nowrap rounded px-1 py-1 text-lg font-semibold cursor-pointer sm:min-w-[6.75rem] sm:px-3 sm:text-2xl"
      >
        {{ currentYear }}-{{ String(currentMonth).padStart(2, '0') }}
      </button>
      <button
        v-if="!isCurrentMonth"
        type="button"
        @click.stop="emit('go-to-this-month')"
        :aria-label="t('common.calendar.goToThisMonth')"
        class="this-month-bubble"
      >
        <Undo2 class="this-month-bubble-icon" />
        <span>{{ t('common.calendar.goToThisMonth') }}</span>
        <i class="this-month-bubble-tail" aria-hidden="true"></i>
      </button>
    </span>
    <button
      type="button"
      @click="emit('next-month')"
      class="calendar-nav-arrow"
      :aria-label="t('common.calendar.nextMonth')"
    >
      <ChevronRight class="h-6 w-6 sm:h-7 sm:w-7" />
    </button>
  </div>
</template>
