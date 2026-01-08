<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useNotificationStore } from '@/stores/notification'
import { useSwal } from '@/composables/useSwal'
import { Menu, Home, Calendar, Users, UserPlus, Bell, Shield, Settings, LogOut, Sun, Moon } from 'lucide-vue-next'
import NotificationBell from '@/components/common/NotificationBell.vue'
import NotificationDropdown from '@/components/common/NotificationDropdown.vue'
import { useThemeStore } from '@/stores/theme'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()
const notificationStore = useNotificationStore()
const themeStore = useThemeStore()
const { confirm } = useSwal()

function isActiveRoute(path: string): boolean {
  if (path === '/') {
    return route.path === '/'
  }
  if (path.startsWith('/duty/')) {
    return route.path.startsWith('/duty/')
  }
  return route.path.startsWith(path)
}

const isNotificationDropdownVisible = ref(false)
const isMenuDropdownVisible = ref(false)
const bellRef = ref<InstanceType<typeof NotificationBell> | null>(null)
const menuRef = ref<HTMLDivElement | null>(null)

const myDutyPath = computed(() => {
  return authStore.user?.id ? `/duty/${authStore.user.id}` : '/duty'
})

function handleNotificationToggle(visible: boolean) {
  isNotificationDropdownVisible.value = visible
  if (visible) {
    isMenuDropdownVisible.value = false
  }
}

function handleNotificationClose() {
  isNotificationDropdownVisible.value = false
  bellRef.value?.closeDropdown()
}

function handleNotificationNavigate() {
  isNotificationDropdownVisible.value = false
  bellRef.value?.closeDropdown()
}

function toggleMenuDropdown() {
  isMenuDropdownVisible.value = !isMenuDropdownVisible.value
  if (isMenuDropdownVisible.value) {
    isNotificationDropdownVisible.value = false
    bellRef.value?.closeDropdown()
  }
}

function handleClickOutside(event: MouseEvent) {
  if (menuRef.value && !menuRef.value.contains(event.target as Node)) {
    isMenuDropdownVisible.value = false
  }
}

function navigateTo(path: string) {
  isMenuDropdownVisible.value = false
  router.push(path)
}

const handleLogout = async () => {
  isMenuDropdownVisible.value = false
  const confirmed = await confirm('정말 로그아웃 하시겠습니까?', '로그아웃')
  if (confirmed) {
    authStore.logout()
  }
}

onMounted(() => {
  document.addEventListener('click', handleClickOutside)
})

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
})
</script>

<template>
  <header
    class="fixed top-0 left-0 right-0 z-50 shadow-sm border-b header-bg"
  >
    <div class="max-w-4xl mx-auto px-4">
      <div class="flex justify-between items-center h-12 sm:h-14">
        <router-link to="/" class="text-xl font-bold header-title">
          Dutypark
        </router-link>
        <nav class="flex items-center gap-1">
          <!-- Theme Toggle (always visible) -->
          <button
            type="button"
            class="theme-toggle-btn cursor-pointer p-2 rounded-full transition-all duration-150 min-h-[44px] min-w-[44px] flex items-center justify-center"
            @click="themeStore.toggleTheme()"
            :aria-label="themeStore.isDark ? '라이트 모드로 전환' : '다크 모드로 전환'"
          >
            <Moon v-if="!themeStore.isDark" class="w-5 h-5" />
            <Sun v-else class="w-5 h-5 text-amber-400" />
          </button>

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
            <div ref="menuRef" class="relative">
              <button
                type="button"
                class="menu-btn cursor-pointer p-2 rounded-full transition-all duration-150 min-h-[44px] min-w-[44px] flex items-center justify-center"
                @click.stop="toggleMenuDropdown"
                aria-label="메뉴"
              >
                <Menu class="w-5 h-5" />
              </button>
              <div
                v-if="isMenuDropdownVisible"
                class="menu-dropdown absolute right-0 top-full mt-2 w-44 rounded-lg shadow-lg border z-50 py-1"
              >
                <!-- Navigation -->
                <button
                  :class="['menu-item w-full px-4 py-2.5 flex items-center gap-3 text-sm cursor-pointer', { 'menu-item-active': isActiveRoute('/') }]"
                  @click="navigateTo('/')"
                >
                  <Home class="w-4 h-4" />
                  홈
                </button>
                <button
                  :class="['menu-item w-full px-4 py-2.5 flex items-center gap-3 text-sm cursor-pointer', { 'menu-item-active': isActiveRoute(myDutyPath) }]"
                  @click="navigateTo(myDutyPath)"
                >
                  <Calendar class="w-4 h-4" />
                  내 달력
                </button>
                <button
                  :class="['menu-item w-full px-4 py-2.5 flex items-center gap-3 text-sm cursor-pointer', { 'menu-item-active': isActiveRoute('/team') }]"
                  @click="navigateTo('/team')"
                >
                  <Users class="w-4 h-4" />
                  내 팀
                </button>
                <button
                  :class="['menu-item w-full px-4 py-2.5 flex items-center gap-3 text-sm cursor-pointer', { 'menu-item-active': isActiveRoute('/friends') }]"
                  @click="navigateTo('/friends')"
                >
                  <UserPlus class="w-4 h-4" />
                  친구 관리
                  <span
                    v-if="notificationStore.hasFriendRequests"
                    class="ml-auto px-1.5 py-0.5 text-xs font-bold bg-red-500 text-white rounded-full min-w-[18px] text-center"
                  >
                    {{ notificationStore.friendRequestCountDisplay }}
                  </span>
                </button>
                <button
                  :class="['menu-item w-full px-4 py-2.5 flex items-center gap-3 text-sm cursor-pointer', { 'menu-item-active': isActiveRoute('/notifications') }]"
                  @click="navigateTo('/notifications')"
                >
                  <Bell class="w-4 h-4" />
                  알림
                </button>

                <!-- Divider -->
                <div class="menu-divider my-1"></div>

                <!-- Admin (conditional) -->
                <button
                  v-if="authStore.isAdmin"
                  :class="['menu-item w-full px-4 py-2.5 flex items-center gap-3 text-sm cursor-pointer', { 'menu-item-active': isActiveRoute('/admin') }]"
                  @click="navigateTo('/admin')"
                >
                  <Shield class="w-4 h-4" />
                  관리
                </button>

                <button
                  :class="['menu-item w-full px-4 py-2.5 flex items-center gap-3 text-sm cursor-pointer', { 'menu-item-active': isActiveRoute('/member') }]"
                  @click="navigateTo('/member')"
                >
                  <Settings class="w-4 h-4" />
                  설정
                </button>

                <!-- Divider -->
                <div class="menu-divider my-1"></div>

                <button
                  class="menu-item menu-item-danger w-full px-4 py-2.5 flex items-center gap-3 text-sm cursor-pointer"
                  @click="handleLogout"
                >
                  <LogOut class="w-4 h-4" />
                  로그아웃
                </button>
              </div>
            </div>
          </template>
          <template v-else>
            <router-link
              to="/auth/login"
              class="login-link text-xs sm:text-sm px-3 py-2 rounded-md transition-colors min-h-[44px] flex items-center"
            >
              로그인
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

.theme-toggle-btn {
  color: var(--dp-text-muted);
}

.theme-toggle-btn:hover {
  color: var(--dp-text-primary);
  background-color: var(--dp-bg-hover);
}

.menu-btn {
  color: var(--dp-text-muted);
}

.menu-btn:hover {
  color: var(--dp-text-primary);
  background-color: var(--dp-bg-hover);
}

.menu-dropdown {
  background-color: var(--dp-bg-card);
  border-color: var(--dp-border-primary);
}

.menu-item {
  color: var(--dp-text-secondary);
}

.menu-item:hover {
  background-color: var(--dp-bg-hover);
  color: var(--dp-text-primary);
}

.menu-item-active {
  background-color: #eff6ff;
  color: #2563eb;
  font-weight: 600;
  border-left: 3px solid #2563eb;
  padding-left: calc(1rem - 3px);
}

.menu-item-active:hover {
  background-color: #dbeafe;
  color: #2563eb;
}

.dark .menu-item-active {
  background-color: rgba(59, 130, 246, 0.15);
  color: #60a5fa;
  border-left-color: #60a5fa;
}

.dark .menu-item-active:hover {
  background-color: rgba(59, 130, 246, 0.25);
  color: #60a5fa;
}

.menu-item-danger {
  color: #ef4444;
}

.menu-item-danger:hover {
  background-color: #fef2f2;
  color: #dc2626;
}

.dark .menu-item-danger:hover {
  background-color: rgba(239, 68, 68, 0.1);
}

.menu-divider {
  height: 1px;
  background-color: var(--dp-border-primary);
}

.login-link {
  color: var(--dp-accent);
}

.login-link:hover {
  background-color: var(--dp-bg-hover);
}
</style>
