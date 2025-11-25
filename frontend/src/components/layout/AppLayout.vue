<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import AppFooter from './AppFooter.vue'

const route = useRoute()
const authStore = useAuthStore()

const showLayout = computed(() => {
  return !route.meta.hideLayout
})
</script>

<template>
  <div class="min-h-screen flex flex-col" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
    <!-- pb-20: 80px for footer (64px) + safe area (~34px on iPhone) -->
    <main class="flex-1 pb-20 sm:pb-16" style="padding-bottom: max(5rem, calc(4rem + env(safe-area-inset-bottom)));">
      <slot />
    </main>
    <AppFooter v-if="showLayout && authStore.isLoggedIn" />
  </div>
</template>
