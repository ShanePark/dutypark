<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { Bell, Trash2, CheckCheck } from 'lucide-vue-next'
import dayjs from 'dayjs'
import relativeTime from 'dayjs/plugin/relativeTime'
import 'dayjs/locale/ko'
import { notificationApi } from '@/api/notification'
import { useNotificationStore } from '@/stores/notification'
import { useNotificationNavigation } from '@/composables/useNotificationNavigation'
import { useSwal } from '@/composables/useSwal'
import type { NotificationDto, Page } from '@/types'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'

dayjs.extend(relativeTime)
dayjs.locale('ko')

const notificationStore = useNotificationStore()
const { navigateToNotification } = useNotificationNavigation()
const { toastSuccess, toastError, showInfo, confirm } = useSwal()

const notifications = ref<NotificationDto[]>([])
const isLoading = ref(false)
const currentPage = ref(0)
const totalPages = ref(0)
const pageSize = 20

const hasMorePages = computed(() => currentPage.value < totalPages.value - 1)

async function loadNotifications(page: number = 0) {
  isLoading.value = true
  try {
    const response: Page<NotificationDto> = await notificationApi.getNotifications(page, pageSize)
    if (page === 0) {
      notifications.value = response.content
    } else {
      notifications.value = [...notifications.value, ...response.content]
    }
    currentPage.value = response.number
    totalPages.value = response.totalPages
  } catch (error) {
    console.error('Failed to load notifications:', error)
    toastError('알림을 불러오는데 실패했습니다')
  } finally {
    isLoading.value = false
  }
}

async function loadMore() {
  if (hasMorePages.value && !isLoading.value) {
    await loadNotifications(currentPage.value + 1)
  }
}

function formatTimeAgo(dateString: string): string {
  return dayjs(dateString).fromNow()
}

function formatDate(dateString: string): string {
  return dayjs(dateString).format('YYYY.MM.DD HH:mm')
}

async function handleNotificationClick(notification: NotificationDto) {
  // Mark as read if not already
  if (!notification.isRead) {
    try {
      await notificationApi.markAsRead(notification.id)
      notification.isRead = true
      notificationStore.fetchUnreadCount()
    } catch {
      // Continue with navigation
    }
  }

  await navigateToNotification(notification, {
    onScheduleError: () => {
      toastError('스케줄 정보를 불러오는데 실패했습니다')
    }
  })
}

async function handleDeleteNotification(notification: NotificationDto, event: Event) {
  event.stopPropagation()

  const confirmed = await confirm('이 알림을 삭제하시겠습니까?', '알림 삭제')
  if (!confirmed) return

  try {
    await notificationApi.deleteNotification(notification.id)
    notifications.value = notifications.value.filter(n => n.id !== notification.id)
    toastSuccess('알림이 삭제되었습니다')
    notificationStore.fetchUnreadCount()
  } catch {
    toastError('알림 삭제에 실패했습니다')
  }
}

async function handleDeleteAllRead() {
  const readNotifications = notifications.value.filter(n => n.isRead)
  if (readNotifications.length === 0) {
    showInfo('삭제할 읽은 알림이 없습니다')
    return
  }

  const confirmed = await confirm(
    `읽은 알림 ${readNotifications.length}개를 모두 삭제하시겠습니까?`,
    '읽은 알림 삭제'
  )
  if (!confirmed) return

  try {
    const result = await notificationApi.deleteAllRead()
    notifications.value = notifications.value.filter(n => !n.isRead)
    toastSuccess(`${result.count}개의 알림이 삭제되었습니다`)
  } catch {
    toastError('알림 삭제에 실패했습니다')
  }
}

async function handleMarkAllAsRead() {
  const unreadNotifications = notifications.value.filter(n => !n.isRead)
  if (unreadNotifications.length === 0) {
    showInfo('읽지 않은 알림이 없습니다')
    return
  }

  try {
    await notificationApi.markAllAsRead()
    notifications.value.forEach(n => (n.isRead = true))
    notificationStore.fetchUnreadCount()
    toastSuccess('모든 알림을 읽음으로 표시했습니다')
  } catch {
    toastError('알림 처리에 실패했습니다')
  }
}

onMounted(() => {
  loadNotifications()
})
</script>

<template>
  <div class="notification-list-view max-w-2xl mx-auto px-4 py-6">
    <!-- Header -->
    <div class="notification-list-header flex items-center justify-between mb-4">
      <div class="flex items-center gap-3">
        <Bell class="w-6 h-6" />
        <h1 class="text-xl font-bold">알림</h1>
      </div>
      <div class="flex items-center gap-2">
        <button
          type="button"
          class="notification-action-btn cursor-pointer flex items-center gap-1.5 text-sm px-3 py-2 rounded-lg transition-all duration-150 min-h-[44px]"
          @click="handleMarkAllAsRead"
        >
          <CheckCheck class="w-4 h-4" />
          <span class="hidden sm:inline">전체 읽음</span>
        </button>
        <button
          type="button"
          class="notification-delete-btn cursor-pointer flex items-center gap-1.5 text-sm px-3 py-2 rounded-lg transition-all duration-150 min-h-[44px]"
          @click="handleDeleteAllRead"
        >
          <Trash2 class="w-4 h-4" />
          <span class="hidden sm:inline">읽은 알림 삭제</span>
        </button>
      </div>
    </div>

    <!-- Retention Notice -->
    <p class="notification-retention-notice text-xs mb-4">
      알림은 30일간 보관됩니다.
    </p>

    <!-- Notification List -->
    <div class="notification-list-container card">
      <div v-if="isLoading && notifications.length === 0" class="p-8 text-center">
        <span class="notification-loading-text text-sm">불러오는 중...</span>
      </div>

      <div v-else-if="notifications.length === 0" class="p-12 text-center">
        <Bell class="w-12 h-12 mx-auto mb-4 notification-empty-icon" />
        <p class="notification-empty-text text-sm">알림이 없습니다</p>
      </div>

      <template v-else>
        <button
          v-for="notification in notifications"
          :key="notification.id"
          type="button"
          class="notification-list-item cursor-pointer w-full flex items-start gap-3 px-4 py-4 text-left transition-all duration-150"
          :class="{ 'notification-unread': !notification.isRead }"
          @click="handleNotificationClick(notification)"
        >
          <ProfileAvatar
            :member-id="notification.actorId"
            :name="notification.actorName || ''"
            :has-profile-photo="notification.actorHasProfilePhoto ?? false"
            :profile-photo-version="notification.actorProfilePhotoVersion ?? 0"
            size="md"
          />
          <div class="flex-1 min-w-0">
            <div class="flex items-start justify-between gap-2">
              <p class="notification-list-item-title text-sm font-medium">
                {{ notification.title }}
              </p>
              <button
                type="button"
                class="notification-delete-icon-btn cursor-pointer p-1.5 rounded-full transition-all duration-150 flex-shrink-0"
                @click="handleDeleteNotification(notification, $event)"
                aria-label="삭제"
              >
                <Trash2 class="w-4 h-4" />
              </button>
            </div>
            <p v-if="notification.content" class="notification-list-item-content text-sm mt-1 line-clamp-2">
              {{ notification.content }}
            </p>
            <div class="flex items-center gap-2 mt-1.5">
              <span class="notification-list-item-time text-xs">
                {{ formatTimeAgo(notification.createdAt) }}
              </span>
              <span class="notification-list-item-date text-xs">
                ({{ formatDate(notification.createdAt) }})
              </span>
            </div>
          </div>
        </button>

        <!-- Load More Button -->
        <div v-if="hasMorePages" class="p-4 text-center border-t notification-list-footer">
          <button
            type="button"
            class="notification-load-more-btn cursor-pointer px-6 py-2.5 rounded-lg text-sm font-medium transition-all duration-150 min-h-[44px]"
            :disabled="isLoading"
            @click="loadMore"
          >
            {{ isLoading ? '불러오는 중...' : '더보기' }}
          </button>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
.notification-list-header {
  color: var(--dp-text-primary);
}

.notification-retention-notice {
  color: var(--dp-text-muted);
}

.notification-action-btn {
  color: var(--dp-text-secondary);
  background-color: var(--dp-bg-tertiary);
}

.notification-action-btn:hover {
  color: var(--dp-text-primary);
  background-color: var(--dp-bg-hover);
}

.notification-delete-btn {
  color: var(--dp-text-muted);
  background-color: var(--dp-bg-tertiary);
}

.notification-delete-btn:hover {
  color: #dc2626;
  background-color: #fee2e2;
}

.dark .notification-delete-btn:hover {
  color: #f87171;
  background-color: rgba(220, 38, 38, 0.2);
}

.notification-list-container {
  overflow: hidden;
}

.notification-loading-text {
  color: var(--dp-text-muted);
}

.notification-empty-icon {
  color: var(--dp-text-muted);
  opacity: 0.5;
}

.notification-empty-text {
  color: var(--dp-text-muted);
}

.notification-list-item {
  border-bottom: 1px solid var(--dp-border-primary);
}

.notification-list-item:last-child {
  border-bottom: none;
}

.notification-list-item:hover {
  background-color: var(--dp-bg-hover);
}

.notification-unread {
  background-color: var(--dp-bg-secondary);
}

.notification-unread .notification-list-item-title {
  font-weight: 600;
}

.notification-list-item-title {
  color: var(--dp-text-primary);
}

.notification-list-item-content {
  color: var(--dp-text-secondary);
}

.notification-list-item-time {
  color: var(--dp-text-muted);
}

.notification-list-item-date {
  color: var(--dp-text-muted);
  opacity: 0.7;
}

.notification-delete-icon-btn {
  color: var(--dp-text-muted);
  opacity: 0;
}

.notification-list-item:hover .notification-delete-icon-btn {
  opacity: 1;
}

.notification-delete-icon-btn:hover {
  color: #dc2626;
  background-color: #fee2e2;
}

.dark .notification-delete-icon-btn:hover {
  color: #f87171;
  background-color: rgba(220, 38, 38, 0.2);
}

.notification-list-footer {
  border-color: var(--dp-border-primary);
}

.notification-load-more-btn {
  color: var(--dp-text-secondary);
  background-color: var(--dp-bg-tertiary);
}

.notification-load-more-btn:hover:not(:disabled) {
  color: var(--dp-text-primary);
  background-color: var(--dp-bg-hover);
}

.notification-load-more-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
