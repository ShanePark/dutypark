import { watch, onUnmounted, type Ref } from 'vue'

// Global stack to track active escape handlers (most recent last)
const escapeHandlerStack: (() => void)[] = []

// Global keydown handler (registered once)
function globalKeyHandler(event: KeyboardEvent) {
  if (event.key === 'Escape' && escapeHandlerStack.length > 0) {
    // Only call the most recently registered handler (top of stack)
    const handler = escapeHandlerStack[escapeHandlerStack.length - 1]
    if (handler) {
      handler()
    }
  }
}

// Register global handler once
let isGlobalHandlerRegistered = false
function ensureGlobalHandler() {
  if (!isGlobalHandlerRegistered) {
    document.addEventListener('keydown', globalKeyHandler)
    isGlobalHandlerRegistered = true
  }
}

export function useEscapeKey(isActive: Ref<boolean>, onEscape: () => void) {
  ensureGlobalHandler()

  watch(
    () => isActive.value,
    (active) => {
      if (active) {
        // Add to stack when modal opens
        escapeHandlerStack.push(onEscape)
      } else {
        // Remove from stack when modal closes
        const index = escapeHandlerStack.indexOf(onEscape)
        if (index > -1) {
          escapeHandlerStack.splice(index, 1)
        }
      }
    },
    { immediate: true }
  )

  onUnmounted(() => {
    // Cleanup on unmount
    const index = escapeHandlerStack.indexOf(onEscape)
    if (index > -1) {
      escapeHandlerStack.splice(index, 1)
    }
  })
}
