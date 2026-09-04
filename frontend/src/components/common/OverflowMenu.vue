<script setup lang="ts">
import { computed, ref, watch } from 'vue'
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

// A trigger at the right edge of a row, or one sitting in a modal footer, has no
// room the default way round: the panel would run off the side or out of the modal.
const panelPositionClass = computed(() => [
  props.align === 'right' ? 'right-0' : 'left-0',
  props.placement === 'above' ? 'bottom-full mb-2' : 'top-full mt-2',
])

useEscapeKey(isOpen, () => close())
watch(() => props.disabled, (disabled) => disabled && close())

function toggle() {
  if (props.disabled) return
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

    <template v-if="isOpen">
      <!-- Full-screen catcher so a tap anywhere else dismisses the menu. -->
      <div class="fixed inset-0 z-[9998]" @click="close"></div>
      <div
        class="overflow-menu absolute z-[9999] w-44 overflow-hidden rounded-xl text-left"
        :class="panelPositionClass"
        role="menu"
        @click="close"
      >
        <slot />
      </div>
    </template>
  </div>
</template>

<style scoped>
.overflow-menu {
  background-color: var(--dp-bg-card);
  border: 1px solid var(--dp-border-primary);
  box-shadow: var(--dp-shadow-lg);
}
</style>
