<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  current: number
  max: number
}>()

const percentage = computed(() => (props.current / props.max) * 100)

const colorClass = computed(() => {
  if (percentage.value >= 100) return 'text-red-500'
  if (percentage.value >= 95) return 'text-orange-500'
  if (percentage.value >= 90) return 'text-yellow-600'
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
