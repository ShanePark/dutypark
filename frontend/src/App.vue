<script setup lang="ts">
import { onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import AppLayout from '@/components/layout/AppLayout.vue'

const authStore = useAuthStore()

onMounted(async () => {
  await authStore.initialize()
})
</script>

<template>
  <AppLayout>
    <RouterView />
  </AppLayout>
</template>
