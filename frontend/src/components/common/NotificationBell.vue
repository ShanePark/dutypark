<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { Bell } from 'lucide-vue-next'
import { useNotificationStore } from '@/stores/notification'
import { useAuthStore } from '@/stores/auth'

const emit = defineEmits<{
  toggle: [visible: boolean]
}>()

const notificationStore = useNotificationStore()
const authStore = useAuthStore()
const isDropdownVisible = ref(false)

function toggleDropdown() {
  isDropdownVisible.value = !isDropdownVisible.value
  emit('toggle', isDropdownVisible.value)

  // Fetch recent notifications when opening dropdown
  if (isDropdownVisible.value) {
    notificationStore.fetchRecentNotifications()
  }
}

function closeDropdown() {
  isDropdownVisible.value = false
  emit('toggle', false)
}

// Expose close method for parent component
defineExpose({ closeDropdown })

onMounted(() => {
  if (authStore.isLoggedIn) {
    notificationStore.startPolling()
  }
})

onUnmounted(() => {
  notificationStore.stopPolling()
})
</script>

<template>
  <button
    type="button"
    class="notification-bell cursor-pointer relative p-2 rounded-full transition-all duration-150 min-h-[44px] min-w-[44px] flex items-center justify-center"
    @click="toggleDropdown"
    aria-label="알림"
  >
    <Bell class="w-5 h-5" />
    <span
      v-if="notificationStore.hasUnread"
      class="notification-badge absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] px-1 flex items-center justify-center text-xs font-bold rounded-full"
    >
      {{ notificationStore.unreadCountDisplay }}
    </span>
  </button>
</template>

<style scoped>
.notification-bell {
  color: var(--dp-text-muted);
}

.notification-bell:hover {
  color: var(--dp-text-primary);
  background-color: var(--dp-bg-hover);
}

.notification-badge {
  background-color: var(--dp-danger);
  color: var(--dp-text-inverse);
  font-size: 10px;
  line-height: 1;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
}
</style>
