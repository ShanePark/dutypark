<script setup lang="ts">
import {computed} from 'vue'
import {useRoute} from 'vue-router'
import {useAuthStore} from '@/stores/auth'

const route = useRoute()
const authStore = useAuthStore()

const navItems = computed(() => {
  const items: Array<{ path: string; icon: string; label: string }> = [
    {path: '/', icon: 'home', label: '홈'},
    {
      path: authStore.user ? `/duty/${authStore.user.id}` : '/',
      icon: 'calendar',
      label: '내 달력',
    },
    {path: '/team', icon: 'users', label: '내 팀'},
    {path: '/member', icon: 'settings', label: '설정'},
  ]
  return items
})

const isActive = (path: string) => {
  if (path === '/') return route.path === '/'
  return route.path.startsWith(path)
}

function handleNavClick(item: { path: string; icon: string; label: string }, event: MouseEvent) {
  if (item.icon === 'calendar' && isActive(item.path)) {
    event.preventDefault()
    window.dispatchEvent(new CustomEvent('duty-go-to-today'))
  }
}
</script>

<template>
  <footer
      class="fixed bottom-0 left-0 right-0 border-t z-50"
      :style="{
      backgroundColor: 'var(--dp-bg-footer)',
      borderColor: 'var(--dp-border-secondary)',
      paddingBottom: 'env(safe-area-inset-bottom)',
      paddingLeft: 'env(safe-area-inset-left)',
      paddingRight: 'env(safe-area-inset-right)'
    }"
  >
    <nav class="max-w-lg mx-auto px-2 sm:px-4">
      <ul class="flex justify-around py-1 sm:py-2">
        <li v-for="item in navItems" :key="item.path" class="flex-1">
          <router-link
              :to="item.path"
              @click="handleNavClick(item, $event)"
              class="flex flex-col items-center px-2 sm:px-3 py-2 sm:py-3 text-xs sm:text-sm rounded-xl transition-colors min-h-[56px] sm:min-h-[64px]"
              :style="{
              backgroundColor: isActive(item.path) ? 'rgba(255, 255, 255, 0.25)' : 'transparent',
              color: isActive(item.path) ? '#ffffff' : 'rgba(255, 255, 255, 0.55)',
              fontWeight: isActive(item.path) ? '600' : '400'
            }"
          >
            <svg
                v-if="item.icon === 'home'"
                class="w-6 h-6 sm:w-7 sm:h-7 mb-0.5 sm:mb-1"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
            >
              <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"
              />
            </svg>
            <svg
                v-else-if="item.icon === 'calendar'"
                class="w-6 h-6 sm:w-7 sm:h-7 mb-0.5 sm:mb-1"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
            >
              <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
              />
            </svg>
            <svg
                v-else-if="item.icon === 'users'"
                class="w-6 h-6 sm:w-7 sm:h-7 mb-0.5 sm:mb-1"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
            >
              <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
              />
            </svg>
            <svg
                v-else-if="item.icon === 'settings'"
                class="w-6 h-6 sm:w-7 sm:h-7 mb-0.5 sm:mb-1"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
            >
              <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
              />
              <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
              />
            </svg>
            <svg
                v-else-if="item.icon === 'admin'"
                class="w-6 h-6 sm:w-7 sm:h-7 mb-0.5 sm:mb-1"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
            >
              <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
              />
            </svg>
            <span>{{ item.label }}</span>
          </router-link>
        </li>
      </ul>
    </nav>
  </footer>
</template>
