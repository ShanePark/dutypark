<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  current: number
  max: number
}>()

const percentage = computed(() => (props.current / props.max) * 100)

const colorClass = computed(() => {
  if (percentage.value >= 100) return 'text-dp-danger'
  if (percentage.value >= 95) return 'text-dp-warning-hover'
  if (percentage.value >= 90) return 'text-dp-warning'
  return 'char-counter-normal'
})
</script>

<template>
  <span class="text-xs font-normal ml-1" :class="colorClass">
    ({{ current }}/{{ max }})
  </span>
</template>

<style scoped>
.char-counter-normal {
  color: var(--dp-text-muted);
}
</style>
