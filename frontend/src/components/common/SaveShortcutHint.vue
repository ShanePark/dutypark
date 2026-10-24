<script setup lang="ts">
import { isApplePlatform, saveShortcutModifierLabel } from '@/composables/useSaveShortcut'

const modifier = saveShortcutModifierLabel(isApplePlatform())
</script>

<template>
  <kbd class="save-shortcut-hint" aria-hidden="true">
    <span>{{ modifier }}</span>
    <span>↵</span>
  </kbd>
</template>

<style scoped>
/* A keyboard shortcut means nothing on a touch screen, so the hint only appears for a mouse. */
.save-shortcut-hint {
  display: none;
}

@media (hover: hover) and (pointer: fine) {
  .save-shortcut-hint {
    display: inline-flex;
    flex-shrink: 0;
    align-items: center;
    gap: 0.1875rem;
    min-height: 1.125rem;
    padding: 0 0.3125rem;
    border: 1px solid color-mix(in srgb, currentColor 35%, transparent);
    border-radius: 0.25rem;
    background-color: color-mix(in srgb, currentColor 14%, transparent);
    font-family: inherit;
    font-size: 0.6875rem;
    font-weight: 600;
    line-height: 1;
    opacity: 0.85;
    white-space: nowrap;
  }
}
</style>
