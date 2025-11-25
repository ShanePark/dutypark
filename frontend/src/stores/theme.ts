import { defineStore } from 'pinia'
import { ref, watch } from 'vue'

export type ThemeMode = 'light' | 'dark'

export const useThemeStore = defineStore('theme', () => {
  const mode = ref<ThemeMode>(getStoredTheme())
  const isDark = ref(false)

  function getStoredTheme(): ThemeMode {
    const stored = localStorage.getItem('theme')
    if (stored === 'light' || stored === 'dark') {
      return stored
    }
    return 'light'
  }

  function applyTheme() {
    const shouldBeDark = mode.value === 'dark'
    isDark.value = shouldBeDark

    if (shouldBeDark) {
      document.documentElement.classList.add('dark')
    } else {
      document.documentElement.classList.remove('dark')
    }
  }

  function setTheme(newMode: ThemeMode) {
    mode.value = newMode
    localStorage.setItem('theme', newMode)
    applyTheme()
  }

  function toggleTheme() {
    setTheme(mode.value === 'light' ? 'dark' : 'light')
  }

  function initializeTheme() {
    applyTheme()
  }

  watch(mode, applyTheme)

  return {
    mode,
    isDark,
    setTheme,
    toggleTheme,
    initializeTheme,
  }
})
