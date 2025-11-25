import { defineStore } from 'pinia'
import { ref, watch } from 'vue'

export type ThemeMode = 'light' | 'dark' | 'system'

export const useThemeStore = defineStore('theme', () => {
  const mode = ref<ThemeMode>(getStoredTheme())
  const isDark = ref(false)

  function getStoredTheme(): ThemeMode {
    const stored = localStorage.getItem('theme')
    if (stored === 'light' || stored === 'dark' || stored === 'system') {
      return stored
    }
    return 'system'
  }

  function getSystemPreference(): boolean {
    return window.matchMedia('(prefers-color-scheme: dark)').matches
  }

  function applyTheme() {
    let shouldBeDark = false

    if (mode.value === 'dark') {
      shouldBeDark = true
    } else if (mode.value === 'system') {
      shouldBeDark = getSystemPreference()
    }

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
    if (mode.value === 'light') {
      setTheme('dark')
    } else if (mode.value === 'dark') {
      setTheme('light')
    } else {
      // system mode - toggle to opposite of current
      setTheme(isDark.value ? 'light' : 'dark')
    }
  }

  // Watch for system preference changes
  function initializeTheme() {
    applyTheme()

    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    mediaQuery.addEventListener('change', () => {
      if (mode.value === 'system') {
        applyTheme()
      }
    })
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
