<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, watch, type CSSProperties } from 'vue'
import { useEscapeKey } from '@/composables/useEscapeKey'

const props = withDefaults(defineProps<{
  menuLabel: string
  triggerClass: string
  disabled?: boolean
  align?: 'left' | 'right'
  placement?: 'below' | 'above'
}>(), {
  align: 'left',
  placement: 'below',
  disabled: false,
})

const isOpen = ref(false)
let openedWithKeyboard = false
const triggerRef = ref<HTMLButtonElement | null>(null)
const panelRef = ref<HTMLElement | null>(null)
const panelPosition = ref<{ top: number; left: number } | null>(null)

const panelStyle = computed<CSSProperties>(() => ({
  position: 'fixed',
  top: `${panelPosition.value?.top ?? 0}px`,
  left: `${panelPosition.value?.left ?? 0}px`,
  maxWidth: 'calc(100vw - 1rem)',
  maxHeight: 'calc(100dvh - 1rem)',
  overflowY: 'auto',
  visibility: panelPosition.value ? 'visible' : 'hidden',
}))

const VIEWPORT_MARGIN = 8
const PANEL_GAP = 8

function clamp(value: number, min: number, max: number) {
  return Math.min(Math.max(value, min), max)
}

function updatePanelPosition() {
  const trigger = triggerRef.value
  const panel = panelRef.value
  if (!trigger || !panel) return

  const anchor = trigger.getBoundingClientRect()
  const viewportWidth = window.innerWidth
  const viewportHeight = window.innerHeight
  const outsideViewport = anchor.bottom < 0
    || anchor.top > viewportHeight
    || anchor.right < 0
    || anchor.left > viewportWidth
  if (outsideViewport) {
    close()
    return
  }

  const panelWidth = panel.offsetWidth
  const panelHeight = panel.offsetHeight
  const belowTop = anchor.bottom + PANEL_GAP
  const aboveTop = anchor.top - PANEL_GAP - panelHeight
  const fitsBelow = belowTop + panelHeight <= viewportHeight - VIEWPORT_MARGIN
  const fitsAbove = aboveTop >= VIEWPORT_MARGIN
  const spaceBelow = viewportHeight - anchor.bottom - PANEL_GAP - VIEWPORT_MARGIN
  const spaceAbove = anchor.top - PANEL_GAP - VIEWPORT_MARGIN

  let placement = props.placement
  if (placement === 'below' && !fitsBelow && (fitsAbove || spaceAbove > spaceBelow)) {
    placement = 'above'
  } else if (placement === 'above' && !fitsAbove && (fitsBelow || spaceBelow > spaceAbove)) {
    placement = 'below'
  }

  const preferredTop = placement === 'above' ? aboveTop : belowTop
  const maxTop = Math.max(VIEWPORT_MARGIN, viewportHeight - panelHeight - VIEWPORT_MARGIN)
  const preferredLeft = props.align === 'right' ? anchor.right - panelWidth : anchor.left
  const maxLeft = Math.max(VIEWPORT_MARGIN, viewportWidth - panelWidth - VIEWPORT_MARGIN)

  panelPosition.value = {
    top: clamp(preferredTop, VIEWPORT_MARGIN, maxTop),
    left: clamp(preferredLeft, VIEWPORT_MARGIN, maxLeft),
  }
}

function stopTrackingPosition() {
  window.removeEventListener('scroll', updatePanelPosition, true)
  window.removeEventListener('resize', updatePanelPosition)
}

function startTrackingPosition() {
  window.addEventListener('scroll', updatePanelPosition, true)
  window.addEventListener('resize', updatePanelPosition)
}

useEscapeKey(isOpen, () => {
  close()
  triggerRef.value?.focus()
})
watch(() => props.disabled, (disabled) => disabled && close())
watch(isOpen, async (open) => {
  if (open) {
    updatePanelPosition()
    if (isOpen.value) {
      startTrackingPosition()
      await nextTick()
      if (isOpen.value && openedWithKeyboard) panelRef.value?.querySelector<HTMLElement>('[role="menuitem"]:not(:disabled)')?.focus()
    }
    return
  }

  stopTrackingPosition()
  panelPosition.value = null
}, { flush: 'post' })

onBeforeUnmount(stopTrackingPosition)

function toggle(event?: MouseEvent) {
  if (props.disabled) return
  openedWithKeyboard = event?.detail === 0
  isOpen.value = !isOpen.value
}

function close() {
  isOpen.value = false
}

defineExpose({ close })
</script>

<template>
  <div class="relative min-w-0">
    <button
      ref="triggerRef"
      type="button"
      :class="triggerClass"
      :aria-label="menuLabel"
      :aria-expanded="isOpen"
      :data-open="isOpen"
      :disabled="disabled"
      aria-haspopup="menu"
      @click="toggle"
    >
      <slot name="trigger" />
    </button>

    <Teleport to="body">
      <template v-if="isOpen">
        <!-- Full-screen catcher so a tap anywhere else dismisses the menu. -->
        <div class="fixed inset-0 z-[9998]" @click="close"></div>
        <div
          ref="panelRef"
          class="overflow-menu fixed z-[9999] w-44 overflow-hidden rounded-xl text-left"
          :style="panelStyle"
          role="menu"
          @click="close"
        >
          <slot />
        </div>
      </template>
    </Teleport>
  </div>
</template>

<style scoped>
.overflow-menu {
  background-color: var(--dp-bg-card);
  border: 1px solid var(--dp-border-primary);
  box-shadow: var(--dp-shadow-lg);
}
</style>
