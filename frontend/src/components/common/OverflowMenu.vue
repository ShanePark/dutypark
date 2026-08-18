<script setup lang="ts">
import { ref } from 'vue'
import { MoreHorizontal } from 'lucide-vue-next'
import { useEscapeKey } from '@/composables/useEscapeKey'

defineProps<{
  menuLabel: string
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
  <div class="relative flex-shrink-0">
    <button
      type="button"
      class="calendar-nav-btn flex min-h-11 min-w-11 cursor-pointer items-center justify-center rounded-full p-1 sm:p-2"
      :aria-label="menuLabel"
      :aria-expanded="isOpen"
      aria-haspopup="menu"
      @click="toggle"
    >
      <MoreHorizontal class="h-5 w-5 sm:h-6 sm:w-6" />
    </button>

    <template v-if="isOpen">
      <!-- Full-screen catcher so a tap anywhere else dismisses the menu. -->
      <div class="fixed inset-0 z-[9998]" @click="close"></div>
      <div
        class="overflow-menu absolute right-0 top-full z-[9999] mt-1 w-44 overflow-hidden rounded-xl text-left"
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
