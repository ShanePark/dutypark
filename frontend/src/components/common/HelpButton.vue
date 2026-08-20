<script setup lang="ts">
import { Info } from 'lucide-vue-next'

// The label names the panel this opens: the glyph alone cannot say which screen
// the help is about.
defineProps<{
  label: string
}>()

const emit = defineEmits<{
  click: []
}>()
</script>

<template>
  <button
    type="button"
    class="help-button"
    :aria-label="label"
    @click="emit('click')"
  >
    <Info />
  </button>
</template>

<style scoped>
.help-button {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2.75rem;
  min-height: 44px;
  border-radius: 0.75rem;
  border: 1px solid var(--dp-accent-border);
  background-color: var(--dp-accent-bg);
  color: var(--dp-accent);
  cursor: pointer;
  transition: all 0.15s ease;
  flex-shrink: 0;
}

.help-button:hover {
  background-color: var(--dp-accent-bg-hover);
}

.help-button:focus-visible {
  outline: none;
  box-shadow: 0 0 0 3px var(--dp-accent-ring);
}

.help-button svg {
  width: 1.25rem;
  height: 1.25rem;
}
</style>
