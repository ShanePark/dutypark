import { ref, onMounted, onUnmounted, type Ref } from 'vue'

export interface ScrollProgressOptions {
  // Progress range to map to 0-1
  start?: number
  end?: number
  // Clamp values between 0 and 1
  clamp?: boolean
}

export function useScrollProgress(
  elementRef: Ref<HTMLElement | null>,
  containerRef: Ref<HTMLElement | null>,
  options: ScrollProgressOptions = {}
) {
  const progress = ref(0)
  const isInView = ref(false)
  let rafId: number | null = null

  const {
    start = 0,
    end = 1,
    clamp = true
  } = options

  const calculateProgress = () => {
    if (!elementRef.value || !containerRef.value) return

    const container = containerRef.value
    const element = elementRef.value
    const containerRect = container.getBoundingClientRect()
    const elementRect = element.getBoundingClientRect()

    // Calculate element position relative to container's viewport
    const elementTop = elementRect.top - containerRect.top
    const viewportHeight = containerRect.height

    // Progress: 0 when element bottom enters viewport from below
    //          1 when element top reaches top of viewport
    // When elementTop = viewportHeight, element is just entering (progress = 0)
    // When elementTop = 0, element is at top (progress = 1)
    let rawProgress = 1 - (elementTop / viewportHeight)

    // Apply start/end range
    rawProgress = (rawProgress - start) / (end - start)

    if (clamp) {
      rawProgress = Math.max(0, Math.min(1, rawProgress))
    }

    progress.value = rawProgress
    isInView.value = rawProgress > 0 && rawProgress < 1
  }

  const onScroll = () => {
    if (rafId) return
    rafId = requestAnimationFrame(() => {
      calculateProgress()
      rafId = null
    })
  }

  onMounted(() => {
    if (!containerRef.value) return

    containerRef.value.addEventListener('scroll', onScroll, { passive: true })
    // Initial calculation
    calculateProgress()
  })

  onUnmounted(() => {
    if (containerRef.value) {
      containerRef.value.removeEventListener('scroll', onScroll)
    }
    if (rafId) {
      cancelAnimationFrame(rafId)
    }
  })

  return { progress, isInView }
}
