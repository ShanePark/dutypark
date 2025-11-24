<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import AppHeader from './AppHeader.vue'
import AppFooter from './AppFooter.vue'

const route = useRoute()
const authStore = useAuthStore()

const showLayout = computed(() => {
  return !route.meta.hideLayout
})
</script>

<template>
  <div class="min-h-screen flex flex-col bg-gray-50">
    <AppHeader v-if="showLayout" />
    <main class="flex-1 pb-16">
      <slot />
    </main>
    <AppFooter v-if="showLayout && authStore.isLoggedIn" />
  </div>
</template>
