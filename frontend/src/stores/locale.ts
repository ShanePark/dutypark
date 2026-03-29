import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { memberApi } from '@/api/member'
import {
  DEFAULT_LOCALE,
  SUPPORTED_LOCALES,
  clearHandledLocaleSuggestion,
  clearStoredLocalePreference,
  detectBrowserLocale,
  isSupportedLocale,
  markLocaleSuggestionHandled,
  normalizeLocale,
  readHandledLocaleSuggestion,
  readStoredLocalePreference,
  setI18nLanguage,
  type SupportedLocale,
} from '@/i18n'

export const useLocaleStore = defineStore('locale', () => {
  const locale = ref<SupportedLocale>(DEFAULT_LOCALE)
  const explicitLocale = ref<SupportedLocale | null>(null)
  const detectedLocale = ref<SupportedLocale>(DEFAULT_LOCALE)
  const handledSuggestionLocale = ref<SupportedLocale | null>(null)

  const shouldSuggestLocale = computed(() => {
    return (
      explicitLocale.value === null &&
      detectedLocale.value !== DEFAULT_LOCALE &&
      handledSuggestionLocale.value !== detectedLocale.value
    )
  })

  function initializeLocale() {
    explicitLocale.value = readStoredLocalePreference()
    detectedLocale.value = detectBrowserLocale()
    handledSuggestionLocale.value = readHandledLocaleSuggestion()

    locale.value = setI18nLanguage(
      explicitLocale.value ?? detectedLocale.value,
      { persist: explicitLocale.value !== null },
    )
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

      const normalizedLocale = normalizeLocale(preferredLocale)
      explicitLocale.value = normalizedLocale
      clearHandledLocaleSuggestion()
      handledSuggestionLocale.value = null
      locale.value = setI18nLanguage(normalizedLocale, { persist: true })
    } catch {
      // Keep the locally selected locale when the server preference is unavailable.
    }
  }

  async function setLocale(
    nextLocale: SupportedLocale,
    options: { persist?: boolean } = {},
  ) {
    const previousLocale = locale.value
    const previousExplicitLocale = explicitLocale.value
    const previousHandledSuggestionLocale = handledSuggestionLocale.value

    explicitLocale.value = nextLocale
    clearHandledLocaleSuggestion()
    handledSuggestionLocale.value = null
    locale.value = setI18nLanguage(nextLocale, { persist: true })

    if (!options.persist) {
      return
    }

    try {
      await memberApi.updatePreferredLocale(nextLocale)
    } catch (error) {
      explicitLocale.value = previousExplicitLocale
      if (previousExplicitLocale) {
        locale.value = setI18nLanguage(previousLocale, { persist: true })
      } else {
        clearStoredLocalePreference()
        locale.value = setI18nLanguage(previousLocale, { persist: false })
      }

      if (previousHandledSuggestionLocale) {
        markLocaleSuggestionHandled(previousHandledSuggestionLocale)
      } else {
        clearHandledLocaleSuggestion()
      }
      handledSuggestionLocale.value = previousHandledSuggestionLocale
      throw error
    }
  }

  async function confirmDetectedLocale(
    options: { persist?: boolean } = {},
  ) {
    if (explicitLocale.value !== null) {
      return
    }

    const previousLocale = locale.value
    const previousExplicitLocale = explicitLocale.value
    const previousHandledSuggestionLocale = handledSuggestionLocale.value

    explicitLocale.value = detectedLocale.value
    clearHandledLocaleSuggestion()
    handledSuggestionLocale.value = null
    locale.value = setI18nLanguage(detectedLocale.value, { persist: true })

    if (!options.persist) {
      return
    }

    try {
      await memberApi.updatePreferredLocale(detectedLocale.value)
    } catch (error) {
      explicitLocale.value = previousExplicitLocale
      if (previousExplicitLocale) {
        locale.value = setI18nLanguage(previousLocale, { persist: true })
      } else {
        clearStoredLocalePreference()
        locale.value = setI18nLanguage(previousLocale, { persist: false })
      }

      if (previousHandledSuggestionLocale) {
        markLocaleSuggestionHandled(previousHandledSuggestionLocale)
      } else {
        clearHandledLocaleSuggestion()
      }
      handledSuggestionLocale.value = previousHandledSuggestionLocale
      throw error
    }
  }

  function dismissLocaleSuggestion() {
    if (!shouldSuggestLocale.value) {
      return
    }

    markLocaleSuggestionHandled(detectedLocale.value)
    handledSuggestionLocale.value = detectedLocale.value
  }

  return {
    locale,
    explicitLocale,
    detectedLocale,
    shouldSuggestLocale,
    supportedLocales: SUPPORTED_LOCALES,
    initializeLocale,
    syncWithServerPreference,
    setLocale,
    confirmDetectedLocale,
    dismissLocaleSuggestion,
  }
})

export type { SupportedLocale }
