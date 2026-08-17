import { watch, onUnmounted, type Ref } from 'vue'

// A soft keyboard eats far more than 100px; smaller gaps come from browser chrome
// or pinch zoom, which must not move the modal.
const KEYBOARD_INSET_THRESHOLD_PX = 100

const VIEWPORT_HEIGHT_PROPERTY = '--dp-viewport-height'
const VIEWPORT_OFFSET_TOP_PROPERTY = '--dp-viewport-offset-top'

const viewportTrackerTokens = new Set<symbol>()

function clearViewportMetrics() {
  const root = document.documentElement
  root.style.removeProperty(VIEWPORT_HEIGHT_PROPERTY)
  root.style.removeProperty(VIEWPORT_OFFSET_TOP_PROPERTY)
}

function syncViewportMetrics() {
  const viewport = window.visualViewport
  if (!viewport) {
    return
  }

  if (window.innerHeight - viewport.height <= KEYBOARD_INSET_THRESHOLD_PX) {
    clearViewportMetrics()
    return
  }

  const root = document.documentElement
  root.style.setProperty(VIEWPORT_HEIGHT_PROPERTY, `${viewport.height}px`)
  root.style.setProperty(VIEWPORT_OFFSET_TOP_PROPERTY, `${viewport.offsetTop}px`)
}

function startTracking(token: symbol) {
  const viewport = window.visualViewport
  if (!viewport || viewportTrackerTokens.has(token)) {
    return
  }

  if (viewportTrackerTokens.size === 0) {
    viewport.addEventListener('resize', syncViewportMetrics)
    viewport.addEventListener('scroll', syncViewportMetrics)
  }

  viewportTrackerTokens.add(token)
  syncViewportMetrics()
}

function stopTracking(token: symbol) {
  const viewport = window.visualViewport
  if (!viewport || !viewportTrackerTokens.delete(token)) {
    return
  }

  if (viewportTrackerTokens.size > 0) {
    return
  }

  viewport.removeEventListener('resize', syncViewportMetrics)
  viewport.removeEventListener('scroll', syncViewportMetrics)
  clearViewportMetrics()
}

/**
 * Mirrors the visual viewport onto CSS custom properties while active, so fixed
 * overlays can stay inside the area the soft keyboard leaves visible.
 * No-op where `visualViewport` is unsupported.
 */
export function useVisualViewport(isActive: Ref<boolean> | (() => boolean)) {
  const token = Symbol('visual-viewport')

  watch(
    typeof isActive === 'function' ? isActive : () => isActive.value,
    (active) => {
      if (active) {
        startTracking(token)
      } else {
        stopTracking(token)
      }
    },
    { immediate: true }
  )

  onUnmounted(() => {
    stopTracking(token)
  })
}
