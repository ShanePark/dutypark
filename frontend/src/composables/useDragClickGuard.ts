import { onScopeDispose, readonly, ref } from 'vue'

interface DragClickGuardOptions {
  resetDelay?: number
}

type GuardedClickEvent = Pick<MouseEvent, 'detail' | 'preventDefault' | 'stopPropagation'>
  & Partial<Pick<MouseEvent, 'stopImmediatePropagation'>>

const DEFAULT_RESET_DELAY = 100

/**
 * Separates a drag or swipe gesture from the pointer click some browsers emit after it.
 * Attach handleClick to a shared ancestor with @click.capture so future actions inside
 * the draggable area are protected without adding guards to every click handler.
 */
export function useDragClickGuard(options: DragClickGuardOptions = {}) {
  const isDragging = ref(false)
  const isClickSuppressed = ref(false)
  const resetDelay = options.resetDelay ?? DEFAULT_RESET_DELAY
  let resetTimer: ReturnType<typeof setTimeout> | null = null

  function clearResetTimer() {
    if (resetTimer === null) return
    clearTimeout(resetTimer)
    resetTimer = null
  }

  function clearSuppression() {
    clearResetTimer()
    isClickSuppressed.value = false
  }

  function scheduleSuppressionReset() {
    clearResetTimer()
    resetTimer = setTimeout(() => {
      isClickSuppressed.value = false
      resetTimer = null
    }, resetDelay)
  }

  function startDrag() {
    clearResetTimer()
    isDragging.value = true
    isClickSuppressed.value = true
  }

  function endDrag() {
    isDragging.value = false
    isClickSuppressed.value = true
    scheduleSuppressionReset()
  }

  function cancelDrag() {
    isDragging.value = false
    clearSuppression()
  }

  function suppressNextClick() {
    isClickSuppressed.value = true
    scheduleSuppressionReset()
  }

  function handlePointerDown() {
    // A real follow-up interaction starts with a new pointerdown. The browser-generated
    // click after a drag does not, so clearing here avoids swallowing a deliberate click.
    if (!isDragging.value) {
      clearSuppression()
    }
  }

  function handleClick(event: GuardedClickEvent): boolean {
    // Keyboard and assistive-technology activation uses detail=0 and must stay available.
    if (!isClickSuppressed.value || event.detail === 0) {
      return false
    }

    event.preventDefault()
    event.stopPropagation()
    event.stopImmediatePropagation?.()
    clearSuppression()
    return true
  }

  onScopeDispose(() => {
    isDragging.value = false
    clearSuppression()
  })

  return {
    isDragging: readonly(isDragging),
    isClickSuppressed: readonly(isClickSuppressed),
    startDrag,
    endDrag,
    cancelDrag,
    suppressNextClick,
    handlePointerDown,
    handleClick,
  }
}
