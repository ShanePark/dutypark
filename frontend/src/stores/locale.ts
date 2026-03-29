import { defineStore } from 'pinia'
import { ref } from 'vue'
import { memberApi } from '@/api/member'
import {
  DEFAULT_LOCALE,
  SUPPORTED_LOCALES,
  isSupportedLocale,
  normalizeLocale,
  setI18nLanguage,
  readStoredLocale,
  type SupportedLocale,
} from '@/i18n'

export const useLocaleStore = defineStore('locale', () => {
  const locale = ref<SupportedLocale>(DEFAULT_LOCALE)

  function initializeLocale() {
    locale.value = setI18nLanguage(readStoredLocale())
  }

  async function syncWithServerPreference() {
    try {
      const response = await memberApi.getPreferredLocale()
      const preferredLocale = typeof response.data === 'string'
        ? response.data
        : response.data?.preferredLocale

      if (!preferredLocale || !isSupportedLocale(preferredLocale)) {
        return
      }

      locale.value = setI18nLanguage(normalizeLocale(preferredLocale))
    } catch {
      // Keep the locally selected locale when the server preference is unavailable.
    }
  }

  async function setLocale(
    nextLocale: SupportedLocale,
    options: { persist?: boolean } = {},
  ) {
    const previousLocale = locale.value
    locale.value = setI18nLanguage(nextLocale)

    if (!options.persist) return

    try {
      await memberApi.updatePreferredLocale(nextLocale)
    } catch (error) {
      locale.value = setI18nLanguage(previousLocale)
      throw error
    }
  }

  return {
    locale,
    supportedLocales: SUPPORTED_LOCALES,
    initializeLocale,
    syncWithServerPreference,
    setLocale,
  }
})

export type { SupportedLocale }
