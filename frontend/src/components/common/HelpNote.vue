<script setup lang="ts">
import { computed, type Component } from 'vue'
import { Info } from 'lucide-vue-next'

// The aside a help panel closes with: a tips list, or a single caveat the sections
// above should not interrupt. A titled note bullets its lines; an untitled one is a
// single remark and stays beside its icon.
const props = withDefaults(defineProps<{
  messages: string[]
  icon?: Component
  title?: string
  tone?: 'muted' | 'warning'
}>(), {
  icon: undefined,
  title: undefined,
  tone: 'muted',
})

const noteIcon = computed(() => props.icon ?? Info)

const toneStyle = computed(() => ({
  '--help-note-tone': props.tone === 'warning' ? 'var(--dp-warning-hover)' : 'var(--dp-text-muted)',
}))
</script>

<template>
  <aside class="help-note" :style="toneStyle">
    <template v-if="title">
      <h3 class="help-note-title">
        <component :is="noteIcon" class="help-note-icon" />
        {{ title }}
      </h3>
      <ul class="help-note-list">
        <li v-for="message in messages" :key="message">{{ message }}</li>
      </ul>
    </template>

    <template v-else>
      <p v-for="message in messages" :key="message" class="help-note-remark">
        <component :is="noteIcon" class="help-note-icon" />
        <span>{{ message }}</span>
      </p>
    </template>
  </aside>
</template>

<style scoped>
.help-note {
  padding: 0.75rem;
  border-radius: 0.75rem;
  background-color: var(--dp-bg-tertiary);
}

.help-note-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.9375rem;
  font-weight: 600;
  color: var(--help-note-tone);
  margin-bottom: 0.5rem;
}

.help-note-icon {
  width: 1.125rem;
  height: 1.125rem;
  flex-shrink: 0;
  color: var(--help-note-tone);
}

.help-note-list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.help-note-list li {
  font-size: 0.875rem;
  color: var(--dp-text-secondary);
  line-height: 1.5;
  padding-left: 1.25rem;
  position: relative;
}

.help-note-list li::before {
  content: '•';
  position: absolute;
  left: 0;
  color: var(--help-note-tone);
  font-weight: bold;
}

.help-note-remark {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  font-size: 0.8125rem;
  color: var(--dp-text-secondary);
  line-height: 1.6;
}
</style>
