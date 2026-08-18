<script setup lang="ts">
import { ref } from 'vue'
import { useEscapeKey } from '@/composables/useEscapeKey'

defineProps<{
  menuLabel: string
  triggerClass: string
}>()

const isOpen = ref(false)

useEscapeKey(isOpen, () => close())

function toggle() {
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
      aria-haspopup="menu"
      @click="toggle"
    >
      <slot name="trigger" />
    </button>

    <template v-if="isOpen">
      <!-- Full-screen catcher so a tap anywhere else dismisses the menu. -->
      <div class="fixed inset-0 z-[9998]" @click="close"></div>
      <div
        class="overflow-menu absolute left-0 top-full z-[9999] mt-2 w-44 overflow-hidden rounded-xl text-left"
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
