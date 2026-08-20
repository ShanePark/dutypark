<script setup lang="ts">
import type { Component } from 'vue'

// `step` numbers the block, and is only worth setting when the blocks describe an
// ordered procedure; a screen whose blocks stand on their own leaves it out.
defineProps<{
  icon: Component
  title: string
  text: string
  step?: number
}>()
</script>

<template>
  <section class="help-section">
    <h3 class="help-section-title">
      <span v-if="step" class="help-section-step" aria-hidden="true">{{ step }}</span>
      <component :is="icon" class="help-section-icon" />
      {{ title }}
    </h3>
    <p class="help-section-text">{{ text }}</p>
  </section>
</template>

<style scoped>
.help-section-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.9375rem;
  font-weight: 600;
  color: var(--dp-text-primary);
  margin-bottom: 0.5rem;
}

.help-section-step {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.625rem;
  height: 1.625rem;
  flex-shrink: 0;
  border-radius: 9999px;
  border: 1px solid var(--dp-accent-border);
  background-color: var(--dp-bg-tertiary);
  color: var(--dp-accent);
  font-size: 0.8125rem;
  font-weight: 700;
}

.help-section-icon {
  width: 1.125rem;
  height: 1.125rem;
  flex-shrink: 0;
  color: var(--dp-text-secondary);
}

.help-section-text {
  font-size: 0.875rem;
  color: var(--dp-text-secondary);
  line-height: 1.6;
}
</style>
