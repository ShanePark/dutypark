<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { Bell } from 'lucide-vue-next'
import { useNotificationStore } from '@/stores/notification'
import { useAuthStore } from '@/stores/auth'

const emit = defineEmits<{
  toggle: [visible: boolean]
}>()

const notificationStore = useNotificationStore()
const authStore = useAuthStore()
const { t } = useI18n()
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
    :aria-label="t('notifications.common.ariaLabel')"
  >
    <Bell class="w-5 h-5 bell-icon" />
    <span
      v-if="notificationStore.hasUnread"
      class="notification-badge absolute top-1 right-1 min-w-[18px] h-[18px] px-1 flex items-center justify-center text-xs font-bold rounded-full"
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

.notification-bell:hover .bell-icon {
  animation: bell-ring 0.5s ease-in-out;
  transform-origin: top center;
}

@keyframes bell-ring {
  0% { transform: rotate(0deg); }
  20% { transform: rotate(15deg); }
  40% { transform: rotate(-15deg); }
  60% { transform: rotate(10deg); }
  80% { transform: rotate(-10deg); }
  100% { transform: rotate(0deg); }
}

.notification-badge {
  background-color: var(--dp-danger);
  color: var(--dp-text-on-dark);
  font-size: 10px;
  line-height: 1;
  box-shadow:
    0 0 0 2px var(--dp-bg-card),
    var(--dp-shadow-sm);
}
</style>
