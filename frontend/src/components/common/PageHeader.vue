<script setup lang="ts">
import type { Component } from 'vue'
import { ChevronLeft } from 'lucide-vue-next'
import { useI18n } from 'vue-i18n'
import type { RouteLocationRaw } from 'vue-router'
import { useNavigateBack } from '@/composables/useNavigateBack'

const props = withDefaults(defineProps<{
  title: string
  icon?: Component
  showBack?: boolean
  backFallback?: RouteLocationRaw
}>(), {
  showBack: false,
  backFallback: '/',
})

const { t } = useI18n()
const { goBack } = useNavigateBack()
</script>

<template>
  <header class="mb-4 flex min-h-11 flex-wrap items-center justify-between gap-3">
    <div class="flex min-w-0 items-center gap-2.5">
      <button
        v-if="showBack"
        type="button"
        :aria-label="t('common.navigation.back')"
        class="grid h-11 w-11 shrink-0 cursor-pointer place-items-center rounded-xl border border-dp-border-primary bg-dp-bg-tertiary transition-colors hover:bg-dp-bg-hover"
        @click="goBack(props.backFallback)"
      >
        <ChevronLeft class="h-5 w-5 text-dp-text-secondary" />
      </button>
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
