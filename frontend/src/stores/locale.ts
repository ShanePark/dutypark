import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import {
  DEFAULT_LOCALE,
  SUPPORTED_LOCALES,
  clearHandledLocaleSuggestion,
  detectBrowserLocale,
  markLocaleSuggestionHandled,
  readHandledLocaleSuggestion,
  readStoredLocalePreference,
  setI18nLanguage,
  type SupportedLocale,
} from '@/i18n'
import { syncServiceWorkerLocale } from '@/utils/serviceWorkerLocale'

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
    void syncServiceWorkerLocale(locale.value)
  }

  async function setLocale(
    nextLocale: SupportedLocale,
  ) {
    explicitLocale.value = nextLocale
    clearHandledLocaleSuggestion()
    handledSuggestionLocale.value = null
    locale.value = setI18nLanguage(nextLocale, { persist: true })
    await syncServiceWorkerLocale(nextLocale)
  }

  async function confirmDetectedLocale(
  ) {
    if (explicitLocale.value !== null) {
      return
    }

    explicitLocale.value = detectedLocale.value
    clearHandledLocaleSuggestion()
    handledSuggestionLocale.value = null
    locale.value = setI18nLanguage(detectedLocale.value, { persist: true })
    await syncServiceWorkerLocale(detectedLocale.value)
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
    setLocale,
    confirmDetectedLocale,
    dismissLocaleSuggestion,
  }
})

export type { SupportedLocale }
