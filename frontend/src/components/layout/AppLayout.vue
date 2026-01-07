<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import AppFooter from './AppFooter.vue'
import ImpersonationBanner from '@/components/common/ImpersonationBanner.vue'

const route = useRoute()
const authStore = useAuthStore()

const showLayout = computed(() => {
  return !route.meta.hideLayout
})
</script>

<template>
  <div class="min-h-screen flex flex-col" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
    <!-- Impersonation Banner -->
    <ImpersonationBanner v-if="authStore.isImpersonating" />
    <!-- pb-20: 80px for footer (64px) + safe area (~34px on iPhone), only when logged in -->
    <main
      class="flex-1"
      :class="authStore.isLoggedIn ? 'pb-20 sm:pb-16' : ''"
      :style="authStore.isLoggedIn ? { paddingBottom: 'max(5rem, calc(4rem + env(safe-area-inset-bottom)))' } : {}"
    >
      <slot />
    </main>
    <AppFooter v-if="showLayout && authStore.isLoggedIn" />
  </div>
</template>
