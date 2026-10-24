<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { ChevronDown, ChevronLeft, ChevronRight, Undo2 } from '@lucide/vue'
import { useDragClickGuard } from '@/composables/useDragClickGuard'

const props = withDefaults(defineProps<{
  currentYear: number
  currentMonth: number
  compact?: boolean
}>(), {
  compact: false,
})

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
  <div
    class="calendar-nav-group"
    :class="{ 'calendar-nav-group-compact': props.compact }"
  >
    <button
      type="button"
      @click="emit('prev-month')"
      class="calendar-nav-arrow calendar-nav-arrow-prev"
      :aria-label="t('common.calendar.previousMonth')"
    >
      <ChevronLeft class="calendar-nav-arrow-icon" />
    </button>
    <span class="relative inline-flex self-stretch">
      <button
        type="button"
        @click="handleMonthButtonClick"
        @touchstart.passive="handleMonthTouchStart"
        @touchmove.passive="handleMonthTouchMove"
        @touchend="handleMonthTouchEnd"
        @touchcancel="resetMonthTouch"
        @pointerdown.capture="dragClickGuard.handlePointerDown"
        @click.capture="dragClickGuard.handleClick"
        class="calendar-nav-month touch-pan-y select-none whitespace-nowrap font-semibold cursor-pointer"
      >
        <span>{{ currentYear }}-{{ String(currentMonth).padStart(2, '0') }}</span>
        <ChevronDown class="calendar-nav-month-chevron" aria-hidden="true" />
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
      class="calendar-nav-arrow calendar-nav-arrow-next"
      :aria-label="t('common.calendar.nextMonth')"
    >
      <ChevronRight class="calendar-nav-arrow-icon" />
    </button>
  </div>
</template>
