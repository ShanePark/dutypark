<script setup lang="ts">
import { computed, toRef, type HTMLAttributes } from 'vue'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'

type ModalSize = 'sm' | 'md' | 'lg' | 'xl' | '2xl' | '3xl' | '5xl'
type ModalHeight = 'fit' | 'default' | 'search' | 'viewport' | 'schedule'
type ModalOverlayPadding = 'default' | 'compact' | 'nav-safe' | 'none'
type ModalZIndex = 'base' | 'detail' | 'admin'
type ModalBackdropEvent = 'click' | 'mousedown'

const props = withDefaults(defineProps<{
  isOpen: boolean
  size?: ModalSize
  height?: ModalHeight
  rounded?: boolean
  overlayPadding?: ModalOverlayPadding
  zIndex?: ModalZIndex
  closeOnBackdrop?: boolean
  closeOnEscape?: boolean
  backdropEvent?: ModalBackdropEvent
  overlayClass?: HTMLAttributes['class']
  panelClass?: HTMLAttributes['class']
  panelStyle?: HTMLAttributes['style']
}>(), {
  size: 'lg',
  height: 'default',
  rounded: false,
  overlayPadding: 'default',
  zIndex: 'base',
  closeOnBackdrop: true,
  closeOnEscape: true,
  backdropEvent: 'click',
  overlayClass: undefined,
  panelClass: undefined,
  panelStyle: undefined,
})

const emit = defineEmits<{
  close: []
}>()

useBodyScrollLock(toRef(props, 'isOpen'))
useEscapeKey(toRef(props, 'isOpen'), () => {
  if (props.closeOnEscape) {
    emit('close')
  }
})

const zIndexClassMap: Record<ModalZIndex, string> = {
  base: 'z-50',
  detail: 'z-[60]',
  admin: 'z-[70]',
}

const overlayClasses = computed(() => [
  'modal-overlay',
  `modal-overlay-padding-${props.overlayPadding}`,
  zIndexClassMap[props.zIndex],
  props.overlayClass,
])

const panelClasses = computed(() => [
  'modal-container',
  `modal-size-${props.size}`,
  `modal-height-${props.height}`,
  props.rounded ? 'modal-container-rounded' : null,
  props.panelClass,
])

// A text-selection drag that starts inside the panel and ends on the overlay
// makes the overlay the click event's target (the nearest common ancestor of the
// differing mousedown/mouseup targets). Track where the press began so a click that
// merely *ended* on the overlay does not count as a backdrop click.
let pressStartedOnOverlay = false

function handleBackdrop(eventType: ModalBackdropEvent) {
  if (!props.closeOnBackdrop || props.backdropEvent !== eventType) {
    return
  }

  emit('close')
}

function handleOverlayMousedown(event: MouseEvent) {
  pressStartedOnOverlay = event.target === event.currentTarget
  if (pressStartedOnOverlay) {
    handleBackdrop('mousedown')
  }
}

function handleOverlayClick(event: MouseEvent) {
  const pressedOnOverlay = pressStartedOnOverlay
  pressStartedOnOverlay = false
  if (event.target === event.currentTarget && pressedOnOverlay) {
    handleBackdrop('click')
  }
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      :class="overlayClasses"
      @mousedown="handleOverlayMousedown"
      @click="handleOverlayClick"
    >
      <div
        :class="panelClasses"
        :style="props.panelStyle"
        role="dialog"
        aria-modal="true"
      >
        <slot />
      </div>
    </div>
  </Teleport>
</template>
