<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { ChevronRight } from 'lucide-vue-next'
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'
import 'dayjs/locale/es'
import 'dayjs/locale/ja'
import 'dayjs/locale/ko'
import 'dayjs/locale/zh-cn'
import { useNotificationStore } from '@/stores/notification'
import { useAuthStore } from '@/stores/auth'
import { useNotificationNavigation } from '@/composables/useNotificationNavigation'
import type { NotificationDto } from '@/types'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import {
  formatNotificationMessage,
  getNotificationActor,
} from '@/utils/notificationFormatter'

dayjs.extend(relativeTime)

interface Props {
  visible: boolean
}

defineProps<Props>()

const emit = defineEmits<{
  close: []
  navigate: []
}>()

const router = useRouter()
const notificationStore = useNotificationStore()
const authStore = useAuthStore()
const { navigateToNotification } = useNotificationNavigation()
const { locale, t } = useI18n()

const dayjsLocale = computed(() => {
  if (locale.value.startsWith('ja')) return 'ja'
  if (locale.value.startsWith('en')) return 'en'
  if (locale.value.startsWith('es')) return 'es'
  if (locale.value.startsWith('zh')) return 'zh-cn'
  return 'ko'
})

const displayNotifications = computed(() => {
  return notificationStore.recentNotifications.slice(0, 10)
})

function formatTimeAgo(dateString: string): string {
  return dayjs(dateString).locale(dayjsLocale.value).fromNow()
}

function getNotificationMessage(notification: NotificationDto): string {
  return formatNotificationMessage(notification, t)
}

function getAvatarProps(notification: NotificationDto) {
  const actor = getNotificationActor(notification)
  return {
    memberId: notification.actorId,
    name: actor?.name ?? '',
    hasProfilePhoto: actor?.hasProfilePhoto ?? false,
    profilePhotoVersion: actor?.profilePhotoVersion ?? 0,
  }
}

async function handleNotificationClick(notification: NotificationDto) {
  try {
    await notificationStore.markAsRead(notification.id)
  } catch {
    // Continue with navigation even if mark as read fails
  }

  const navigated = await navigateToNotification(notification, {
    onSamePage: () => {
      if (notification.referenceType === 'FRIEND_REQUEST') {
        notificationStore.triggerFriendsRefresh()
      }
    }
  })

  if (navigated) {
    emit('navigate')
  }
  emit('close')
}

function handleViewAll() {
  router.push('/notifications')
  emit('close')
}

function handleOverlayClick() {
  emit('close')
}
</script>

<template>
  <Teleport to="body">
    <!-- Overlay for closing on outside click -->
    <Transition name="overlay">
      <div
        v-if="visible"
        class="notification-overlay fixed inset-0 z-40"
        @click="handleOverlayClick"
      />
    </Transition>
  </Teleport>

  <Teleport to="body">
    <Transition name="dropdown">
      <div
        v-if="visible"
        :class="[
          'notification-dropdown fixed right-4 sm:right-4 md:right-auto md:left-1/2 md:translate-x-[min(calc(50vw-12rem),8rem)] w-[calc(100vw-2rem)] sm:w-96 max-w-96 rounded-lg shadow-lg z-50 overflow-hidden',
          authStore.isImpersonating ? 'top-[6.5rem]' : 'top-16'
        ]"
        @click.stop
      >
      <!-- Header -->
      <div class="notification-dropdown-header flex items-center justify-between px-4 py-3">
        <h3 class="text-sm font-semibold">{{ t('notifications.dropdown.title') }}</h3>
      </div>

      <!-- Notification List -->
      <div class="notification-dropdown-body max-h-80 overflow-y-auto">
        <div v-if="notificationStore.isLoading" class="p-4 text-center">
          <span class="notification-loading-text text-sm">{{ t('notifications.common.loading') }}</span>
        </div>

        <div v-else-if="displayNotifications.length === 0" class="p-8 text-center">
          <span class="notification-empty-text text-sm">{{ t('notifications.common.empty') }}</span>
        </div>

        <template v-else>
          <button
            v-for="notification in displayNotifications"
            :key="notification.id"
            type="button"
            class="notification-item cursor-pointer w-full flex items-start gap-3 px-4 py-3 text-left transition-all duration-150"
            :class="{ 'notification-item-unread': !notification.isRead }"
            @click="handleNotificationClick(notification)"
          >
            <div class="relative">
              <ProfileAvatar
                v-bind="getAvatarProps(notification)"
                size="sm"
              />
              <span
                v-if="!notification.isRead"
                class="unread-dot absolute -top-0.5 -right-0.5 w-2.5 h-2.5 rounded-full"
              />
            </div>
            <div class="flex-1 min-w-0">
              <p
                class="text-sm truncate"
                :class="notification.isRead ? 'notification-item-title-read' : 'notification-item-title'"
              >
                {{ getNotificationMessage(notification) }}
              </p>
              <p class="notification-item-time text-xs mt-0.5">
                {{ formatTimeAgo(notification.createdAt) }}
              </p>
            </div>
          </button>
        </template>
      </div>

      <!-- Footer -->
      <div class="notification-dropdown-footer px-4 py-2.5">
        <button
          type="button"
          class="notification-view-all-btn cursor-pointer w-full flex items-center justify-center gap-1 text-sm py-2 rounded transition-all duration-150"
          @click="handleViewAll"
        >
          {{ t('notifications.dropdown.viewAll') }}
          <ChevronRight class="w-4 h-4" />
        </button>
      </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
/* Overlay for mobile - adds dim background to make dropdown stand out */
.notification-overlay {
  background-color: var(--dp-overlay-scrim-soft);
}

@media (min-width: 640px) {
  .notification-overlay {
    background-color: transparent;
  }
}

.notification-dropdown {
  background-color: var(--dp-bg-card);
  border: 1px solid var(--dp-border-secondary);
  box-shadow: var(--dp-shadow-dropdown);
}

/* Stronger shadow for dark mode */
:global(.dark) .notification-dropdown {
  box-shadow: var(--dp-shadow-dropdown-dark);
}

.notification-dropdown-header {
  background-color: var(--dp-bg-tertiary);
  border-bottom: 1px solid var(--dp-border-primary);
  color: var(--dp-text-primary);
}

.notification-dropdown-body {
  background-color: var(--dp-bg-card);
}

.notification-loading-text,
.notification-empty-text {
  color: var(--dp-text-muted);
}

.notification-item {
  border-bottom: 1px solid var(--dp-border-primary);
}

.notification-item:last-child {
  border-bottom: none;
}

.notification-item:hover {
  background-color: var(--dp-bg-hover);
}

.notification-item-unread {
  background-color: var(--dp-bg-tertiary);
}

.notification-item-title {
  color: var(--dp-text-primary);
  font-weight: 600;
}

.notification-item-title-read {
  color: var(--dp-text-secondary);
  font-weight: 400;
}

.notification-item-time {
  color: var(--dp-text-muted);
}

.unread-dot {
  background-color: var(--dp-accent);
  border: 2px solid var(--dp-bg-card);
}

.notification-dropdown-footer {
  background-color: var(--dp-bg-tertiary);
  border-top: 1px solid var(--dp-border-primary);
}

.notification-view-all-btn {
  color: var(--dp-text-secondary);
}

.notification-view-all-btn:hover {
  color: var(--dp-text-primary);
  background-color: var(--dp-bg-hover);
}

/* Overlay transition */
.overlay-enter-active,
.overlay-leave-active {
  transition: opacity 0.2s ease;
}

.overlay-enter-from,
.overlay-leave-to {
  opacity: 0;
}

/* Dropdown transition */
.dropdown-enter-active,
.dropdown-leave-active {
  transition: all 0.2s ease;
}

.dropdown-enter-from,
.dropdown-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}
</style>
