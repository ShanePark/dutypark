<script setup lang="ts">
import type { Component } from 'vue'

defineProps<{
  title: string
  icon?: Component
}>()
</script>

<template>
  <header class="mb-4 flex min-h-11 flex-wrap items-center justify-between gap-3">
    <div class="flex min-w-0 items-center gap-2.5">
      <span
        v-if="icon"
        class="grid h-9 w-9 shrink-0 place-items-center rounded-xl border border-dp-border-primary bg-dp-bg-tertiary"
      >
        <component :is="icon" class="h-[18px] w-[18px] text-dp-text-secondary" />
      </span>
      <h1 class="truncate text-lg font-bold text-dp-text-primary">{{ title }}</h1>
    </div>
    <div v-if="$slots.default" class="flex flex-wrap items-center justify-end gap-2">
      <slot />
    </div>
  </header>
</template>
