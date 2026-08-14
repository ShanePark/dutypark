<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import AppHeader from './AppHeader.vue'
import AppFooter from './AppFooter.vue'
import ImpersonationBanner from '@/components/common/ImpersonationBanner.vue'
import PWAInstallGuide from '@/components/common/PWAInstallGuide.vue'
import PushPermissionGuide from '@/components/common/PushPermissionGuide.vue'

const route = useRoute()
const authStore = useAuthStore()

const showLayout = computed(() => {
  return !route.meta.hideLayout
})
</script>

<template>
  <div class="min-h-screen flex flex-col bg-dp-bg-secondary">
    <ImpersonationBanner v-if="authStore.isImpersonating" />
    <AppHeader v-if="showLayout && authStore.isLoggedIn" />
    <div
      v-if="showLayout && authStore.sessionCheckFailed"
      class="border-b border-dp-warning/30 bg-dp-warning/10 px-4 py-3 text-sm text-dp-text-primary"
      role="status"
      aria-live="polite"
    >
      <div class="mx-auto flex max-w-4xl flex-wrap items-center justify-between gap-2">
        <span>{{ $t('sessionRecovery.checkFailed') }}</span>
        <RouterLink
          v-if="route.name !== 'login'"
          to="/auth/login"
          class="font-semibold text-dp-accent hover:underline"
        >
          {{ $t('sessionRecovery.signIn') }}
        </RouterLink>
      </div>
    </div>
    <main
      class="flex-1"
      :class="[
        authStore.isLoggedIn ? 'app-layout__main--authed' : '',
        authStore.isLoggedIn && authStore.isImpersonating ? 'pt-[5.5rem] sm:pt-24' : '',
        authStore.isLoggedIn && !authStore.isImpersonating ? 'pt-12 sm:pt-14' : ''
      ]"
    >
      <slot />
    </main>
    <AppFooter v-if="showLayout && authStore.isLoggedIn" />
    <PWAInstallGuide v-if="authStore.isLoggedIn" />
    <PushPermissionGuide v-if="authStore.isLoggedIn" />
  </div>
</template>

<style scoped>
.app-layout__main--authed {
  padding-bottom: calc(3.5rem + max(0.375rem, calc(env(safe-area-inset-bottom) - 0.5rem)));
}

@media (min-width: 640px) {
  .app-layout__main--authed {
    padding-bottom: 5rem;
  }
}
</style>
