<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { ChevronRight, LogOut, MoreHorizontal } from 'lucide-vue-next'
import PageHeader from '@/components/common/PageHeader.vue'
import { useAuthStore } from '@/stores/auth'
import { useNotificationStore } from '@/stores/notification'
import { useLogout } from '@/composables/useLogout'
import { buildMoreMenuGroups } from './moreMenu'

const { t } = useI18n()
const authStore = useAuthStore()
const notificationStore = useNotificationStore()
const { confirmAndLogout } = useLogout()

const menuGroups = computed(() => buildMoreMenuGroups({ isAdmin: authStore.isAdmin }))
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <PageHeader :title="t('more.title')" :icon="MoreHorizontal" />

    <section
      v-for="(group, groupIndex) in menuGroups"
      :key="groupIndex"
      class="mb-4 overflow-hidden rounded-xl border border-dp-border-primary bg-dp-bg-card shadow-sm"
    >
      <ul>
        <li
          v-for="item in group"
          :key="item.id"
          class="border-b border-dp-border-primary last:border-b-0"
        >
          <router-link
            :to="item.path"
            class="more-menu-item flex min-h-[56px] w-full items-center gap-3 px-4 py-3 transition-colors"
          >
            <component :is="item.icon" class="h-5 w-5 shrink-0 text-dp-text-secondary" />
            <span class="flex-1 truncate text-sm font-medium text-dp-text-primary">
              {{ t(item.labelKey) }}
            </span>
            <span
              v-if="item.showsFriendRequestBadge && notificationStore.hasFriendRequests"
              class="min-w-[18px] rounded-full bg-dp-danger px-1.5 py-0.5 text-center text-xs font-bold text-dp-text-on-dark"
            >
              {{ notificationStore.friendRequestCountDisplay }}
            </span>
            <ChevronRight class="h-4 w-4 shrink-0 text-dp-text-muted" />
          </router-link>
        </li>
      </ul>
    </section>

    <section class="overflow-hidden rounded-xl border border-dp-border-primary bg-dp-bg-card shadow-sm">
      <button
        type="button"
        class="more-menu-item more-menu-item--danger flex min-h-[56px] w-full items-center gap-3 px-4 py-3 transition-colors cursor-pointer"
        @click="confirmAndLogout"
      >
        <LogOut class="h-5 w-5 shrink-0" />
        <span class="flex-1 text-left text-sm font-medium">{{ t('member.logout') }}</span>
      </button>
    </section>
  </div>
</template>

<style scoped>
.more-menu-item:hover {
  background-color: var(--dp-bg-hover);
}

.more-menu-item:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: -2px;
}

.more-menu-item--danger {
  color: var(--dp-danger);
}

.more-menu-item--danger:hover {
  background-color: var(--dp-danger-bg);
  color: var(--dp-danger-hover);
}
</style>
