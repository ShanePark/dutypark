<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import NotificationBell from '@/components/common/NotificationBell.vue'
import NotificationDropdown from '@/components/common/NotificationDropdown.vue'
import LocaleSwitcher from '@/components/layout/LocaleSwitcher.vue'
import ThemeSwitcher from '@/components/layout/ThemeSwitcher.vue'

const authStore = useAuthStore()
const { t } = useI18n()

const isNotificationDropdownVisible = ref(false)
const bellRef = ref<InstanceType<typeof NotificationBell> | null>(null)

function handleNotificationToggle(visible: boolean) {
  isNotificationDropdownVisible.value = visible
}

function handleNotificationClose() {
  isNotificationDropdownVisible.value = false
  bellRef.value?.closeDropdown()
}

function handleNotificationNavigate() {
  isNotificationDropdownVisible.value = false
  bellRef.value?.closeDropdown()
}
</script>

<template>
  <header
    :class="['fixed left-0 right-0 z-40 shadow-sm border-b header-bg', authStore.isImpersonating ? 'top-10' : 'top-0']"
  >
    <div class="max-w-4xl mx-auto px-3 sm:px-4">
      <div class="flex justify-between items-center h-12 sm:h-14">
        <router-link
          to="/"
          class="header-brand min-h-[44px] flex items-center gap-2 rounded-xl pr-2 transition-colors"
          aria-label="Dutypark"
        >
          <img
            src="/android-chrome-192x192-v20260517b.png"
            alt=""
            class="header-brand-icon"
            width="36"
            height="36"
            aria-hidden="true"
          />
          <span class="text-lg sm:text-xl font-bold header-title">Dutypark</span>
        </router-link>
        <nav class="flex items-center gap-0.5 sm:gap-1">
          <LocaleSwitcher />
          <ThemeSwitcher />

          <template v-if="authStore.isLoggedIn">
            <div class="relative">
              <NotificationBell
                ref="bellRef"
                @toggle="handleNotificationToggle"
              />
              <NotificationDropdown
                :visible="isNotificationDropdownVisible"
                @close="handleNotificationClose"
                @navigate="handleNotificationNavigate"
              />
            </div>
          </template>
          <template v-else>
            <router-link
              to="/guide"
              class="guide-link hidden sm:flex text-sm px-2 py-2 rounded-md transition-colors min-h-[44px] items-center"
            >
              {{ t('header.menu.guide') }}
            </router-link>
            <router-link
              to="/auth/login"
              class="login-link text-xs sm:text-sm px-3 py-2 rounded-md transition-colors min-h-[44px] flex items-center"
            >
              {{ t('header.actions.login') }}
            </router-link>
          </template>
        </nav>
      </div>
    </div>
  </header>
</template>

<style scoped>
.header-bg {
  background-color: var(--dp-bg-card);
  border-color: var(--dp-border-primary);
}

.header-title {
  color: var(--dp-text-primary);
}

.header-brand:hover .header-title {
  color: var(--dp-accent-hover);
}

.header-brand:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: 2px;
}

.header-brand-icon {
  width: 2rem;
  height: 2rem;
  border-radius: 0.7rem;
  box-shadow: var(--dp-shadow-sm);
  flex-shrink: 0;
}

@media (min-width: 640px) {
  .header-brand-icon {
    width: 2.25rem;
    height: 2.25rem;
    border-radius: 0.8rem;
  }
}

.guide-link {
  color: var(--dp-text-secondary);
}

.guide-link:hover {
  background-color: var(--dp-bg-hover);
  color: var(--dp-text-primary);
}

.login-link {
  color: var(--dp-accent);
}

.login-link:hover {
  background-color: var(--dp-bg-hover);
}
</style>
