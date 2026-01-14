<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useAuthStore } from '@/stores/auth'
import AppLayout from '@/components/layout/AppLayout.vue'
import { usePushNotification } from '@/composables/usePushNotification'

const authStore = useAuthStore()
const pushNotification = usePushNotification()
const hasAttemptedPush = ref(false)

const tryAutoSubscribe = async () => {
  if (hasAttemptedPush.value) return
  hasAttemptedPush.value = true

  pushNotification.checkSupport()
  if (!pushNotification.isSupported.value) return

  await pushNotification.checkEnabled()
  if (!pushNotification.isEnabled.value) return

  await pushNotification.subscribe()
}

onMounted(async () => {
  await authStore.initialize()
  if (authStore.isLoggedIn) {
    await tryAutoSubscribe()
  }
})

watch(
  () => authStore.isLoggedIn,
  async (isLoggedIn) => {
    if (!isLoggedIn) {
      hasAttemptedPush.value = false
      return
    }
    await tryAutoSubscribe()
  }
)
</script>

<template>
  <AppLayout>
    <RouterView />
  </AppLayout>
</template>
