<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { Moon, Sun } from 'lucide-vue-next'
import { useThemeStore } from '@/stores/theme'

const themeStore = useThemeStore()
const { t } = useI18n()

const themeToggleAriaLabel = computed(() => {
  return themeStore.isDark
    ? t('header.actions.switchToLightMode')
    : t('header.actions.switchToDarkMode')
})
</script>

<template>
  <button
    type="button"
    class="theme-toggle-btn cursor-pointer p-2 rounded-full transition-all duration-150 min-h-[44px] min-w-[44px] flex items-center justify-center"
    @click="themeStore.toggleTheme()"
    :aria-label="themeToggleAriaLabel"
  >
    <Moon v-if="!themeStore.isDark" class="w-5 h-5 theme-icon" />
    <Sun v-else class="w-5 h-5 text-dp-warning theme-icon" />
  </button>
</template>

<style scoped>
.theme-toggle-btn {
  color: var(--dp-text-muted);
}

.theme-toggle-btn:hover {
  color: var(--dp-text-primary);
  background-color: var(--dp-bg-hover);
}

.theme-toggle-btn:hover .theme-icon {
  animation: theme-rotate 0.5s ease-in-out;
}

@keyframes theme-rotate {
  0% { transform: rotate(0deg); }
  50% { transform: rotate(-20deg); }
  100% { transform: rotate(0deg); }
}
</style>
