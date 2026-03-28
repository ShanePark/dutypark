<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { getVisibilityDescription, getVisibilityIcon, getVisibilityLabel, type CalendarVisibility } from '@/utils/visibility'

type VisibilityHintSize = 'xs' | 'sm'
type VisibilityHintAlign = 'start' | 'end'
type TooltipPlacement = 'top' | 'bottom'

const props = withDefaults(defineProps<{
  visibility: CalendarVisibility
  size?: VisibilityHintSize
  align?: VisibilityHintAlign
}>(), {
  size: 'sm',
  align: 'start',
})

const rootRef = ref<HTMLElement | null>(null)
const buttonRef = ref<HTMLButtonElement | null>(null)
const tooltipRef = ref<HTMLElement | null>(null)
const isPinnedOpen = ref(false)
const isHovered = ref(false)
const isFocused = ref(false)
const prefersHover = ref(false)

const label = computed(() => getVisibilityLabel(props.visibility))
const description = computed(() => getVisibilityDescription(props.visibility))
const Icon = computed(() => getVisibilityIcon(props.visibility))

const accentColor = computed(() => {
  switch (props.visibility) {
    case 'PUBLIC':
      return 'var(--dp-success-hover)'
    case 'FRIENDS':
      return 'var(--dp-accent-hover)'
    case 'FAMILY':
      return 'var(--dp-warning-hover)'
    case 'PRIVATE':
      return 'var(--dp-danger-hover)'
    default:
      return 'var(--dp-accent-hover)'
  }
})

const sizeClass = computed(() => {
  return props.size === 'xs'
    ? 'visibility-hint-button--xs'
    : 'visibility-hint-button--sm'
})

const buttonStyle = computed(() => ({
  '--visibility-hint-accent': accentColor.value,
}))

const isTooltipVisible = computed(() => isPinnedOpen.value || isHovered.value || isFocused.value)

const tooltipPosition = ref<{
  top: number
  left: number
  placement: TooltipPlacement
  ready: boolean
}>({
  top: 0,
  left: 0,
  placement: 'bottom',
  ready: false,
})

const tooltipStyle = computed(() => ({
  top: `${tooltipPosition.value.top}px`,
  left: `${tooltipPosition.value.left}px`,
  visibility: tooltipPosition.value.ready ? 'visible' : 'hidden',
}))

let mediaQuery: MediaQueryList | null = null
let mediaQueryHandler: ((event: MediaQueryListEvent) => void) | null = null

function updatePointerMode() {
  prefersHover.value = mediaQuery?.matches ?? false
}

function handleDocumentPointerDown(event: PointerEvent) {
  const target = event.target as Node | null
  if (target && rootRef.value?.contains(target)) {
    return
  }
  isPinnedOpen.value = false
}

function updateTooltipPosition() {
  if (!buttonRef.value || !tooltipRef.value || typeof window === 'undefined') {
    return
  }

  const buttonRect = buttonRef.value.getBoundingClientRect()
  const tooltipRect = tooltipRef.value.getBoundingClientRect()
  const viewportWidth = window.innerWidth
  const viewportHeight = window.innerHeight
  const gutter = 12
  const gap = 10

  let left = props.align === 'end'
    ? buttonRect.right - tooltipRect.width
    : buttonRect.left

  left = Math.min(Math.max(left, gutter), viewportWidth - tooltipRect.width - gutter)

  let top = buttonRect.bottom + gap
  let placement: TooltipPlacement = 'bottom'

  if (top + tooltipRect.height + gutter > viewportHeight && buttonRect.top - tooltipRect.height - gap >= gutter) {
    top = buttonRect.top - tooltipRect.height - gap
    placement = 'top'
  }

  if (top + tooltipRect.height + gutter > viewportHeight) {
    top = Math.max(gutter, viewportHeight - tooltipRect.height - gutter)
  }

  tooltipPosition.value = {
    top,
    left,
    placement,
    ready: true,
  }
}

function handleMouseEnter() {
  if (prefersHover.value) {
    isHovered.value = true
  }
}

function handleMouseLeave() {
  isHovered.value = false
}

function handleFocusIn() {
  isFocused.value = true
}

function handleFocusOut(event: FocusEvent) {
  const relatedTarget = event.relatedTarget as Node | null
  if (relatedTarget && rootRef.value?.contains(relatedTarget)) {
    return
  }
  isFocused.value = false
}

function handleButtonClick(event: MouseEvent) {
  event.stopPropagation()
  isPinnedOpen.value = !isPinnedOpen.value
}

watch(isTooltipVisible, async (visible) => {
  if (!visible) {
    tooltipPosition.value.ready = false
    return
  }

  tooltipPosition.value.ready = false
  await nextTick()
  updateTooltipPosition()
})

onMounted(() => {
  if (typeof window !== 'undefined' && 'matchMedia' in window) {
    mediaQuery = window.matchMedia('(hover: hover) and (pointer: fine)')
    updatePointerMode()

    mediaQueryHandler = () => {
      updatePointerMode()
      if (!prefersHover.value) {
        isHovered.value = false
      }
    }

    if ('addEventListener' in mediaQuery) {
      mediaQuery.addEventListener('change', mediaQueryHandler)
    } else {
      mediaQuery.addListener(mediaQueryHandler)
    }

    window.addEventListener('resize', updateTooltipPosition)
    window.addEventListener('scroll', updateTooltipPosition, true)
  }

  document.addEventListener('pointerdown', handleDocumentPointerDown)
})

onBeforeUnmount(() => {
  document.removeEventListener('pointerdown', handleDocumentPointerDown)

  if (typeof window !== 'undefined') {
    window.removeEventListener('resize', updateTooltipPosition)
    window.removeEventListener('scroll', updateTooltipPosition, true)
  }

  if (mediaQuery && mediaQueryHandler) {
    if ('removeEventListener' in mediaQuery) {
      mediaQuery.removeEventListener('change', mediaQueryHandler)
    } else {
      mediaQuery.removeListener(mediaQueryHandler)
    }
  }
})
</script>

<template>
  <span
    ref="rootRef"
    class="visibility-hint"
    @mouseenter="handleMouseEnter"
    @mouseleave="handleMouseLeave"
    @focusin="handleFocusIn"
    @focusout="handleFocusOut"
  >
    <button
      ref="buttonRef"
      type="button"
      class="visibility-hint-button"
      :class="sizeClass"
      :style="buttonStyle"
      :aria-expanded="isTooltipVisible"
      :aria-label="`${label}. ${description}`"
      @click="handleButtonClick"
    >
      <component :is="Icon" class="visibility-hint-icon" />
    </button>

    <Teleport to="body">
      <Transition name="visibility-hint-popover">
        <span
          v-if="isTooltipVisible"
          ref="tooltipRef"
          class="visibility-hint-popover"
          :class="`visibility-hint-popover--${tooltipPosition.placement}`"
          :style="tooltipStyle"
          role="tooltip"
        >
          <span class="visibility-hint-popover__label">{{ label }}</span>
          <span class="visibility-hint-popover__description">{{ description }}</span>
        </span>
      </Transition>
    </Teleport>
  </span>
</template>

<style scoped>
.visibility-hint {
  display: inline-flex;
  flex-shrink: 0;
  vertical-align: middle;
}

.visibility-hint-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border: 1px solid transparent;
  background-color: transparent;
  color: var(--visibility-hint-accent);
  box-shadow: none;
  transition:
    background-color 0.15s ease,
    border-color 0.15s ease,
    color 0.15s ease,
    transform 0.15s ease,
    opacity 0.15s ease;
  cursor: pointer;
  appearance: none;
}

.visibility-hint-button:hover {
  background-color: var(--dp-bg-hover);
}

.visibility-hint-button:focus-visible {
  outline: none;
  box-shadow: 0 0 0 3px var(--dp-accent-ring);
}

.visibility-hint-button:active {
  transform: translateY(1px);
}

.visibility-hint-button--xs {
  border-radius: 9999px;
  border-color: color-mix(in srgb, var(--visibility-hint-accent) 24%, var(--dp-border-primary));
  background-color: color-mix(in srgb, var(--visibility-hint-accent) 10%, var(--dp-bg-card));
  width: 1rem;
  height: 1rem;
}

.visibility-hint-button--sm {
  border-radius: 0.5rem;
  color: color-mix(in srgb, var(--visibility-hint-accent) 76%, var(--dp-text-muted));
  width: 1.875rem;
  height: 1.875rem;
}

.visibility-hint-icon {
  width: 0.7rem;
  height: 0.7rem;
}

.visibility-hint-button--sm .visibility-hint-icon {
  width: 1rem;
  height: 1rem;
}

.visibility-hint-popover {
  position: fixed;
  z-index: 1200;
  display: grid;
  gap: 0.2rem;
  width: min(14rem, calc(100vw - 1.25rem));
  border-radius: 0.9rem;
  border: 1px solid var(--dp-border-primary);
  background: color-mix(in srgb, var(--dp-bg-modal) 97%, transparent);
  box-shadow: var(--dp-shadow-dropdown);
  padding: 0.65rem 0.75rem;
  pointer-events: none;
  backdrop-filter: blur(10px);
}

.visibility-hint-popover__label {
  font-size: 0.82rem;
  font-weight: 700;
  color: var(--dp-text-primary);
}

.visibility-hint-popover__description {
  font-size: 0.74rem;
  line-height: 1.45;
  color: var(--dp-text-secondary);
}

.visibility-hint-popover-enter-active,
.visibility-hint-popover-leave-active {
  transition:
    opacity 0.14s ease,
    transform 0.14s ease;
}

.visibility-hint-popover-enter-from,
.visibility-hint-popover-leave-to {
  opacity: 0;
}

.visibility-hint-popover--top.visibility-hint-popover-enter-from,
.visibility-hint-popover--top.visibility-hint-popover-leave-to {
  transform: translateY(4px);
}

.visibility-hint-popover--bottom.visibility-hint-popover-enter-from,
.visibility-hint-popover--bottom.visibility-hint-popover-leave-to {
  transform: translateY(-4px);
}

@media (max-width: 639px) {
  .visibility-hint-button--sm {
    width: 1.75rem;
    height: 1.75rem;
  }

  .visibility-hint-button--sm .visibility-hint-icon {
    width: 0.95rem;
    height: 0.95rem;
  }
}

@media (prefers-reduced-motion: reduce) {
  .visibility-hint-button,
  .visibility-hint-popover-enter-active,
  .visibility-hint-popover-leave-active {
    transition: none;
  }
}
</style>
