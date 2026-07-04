<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { Check, ChevronDown, Languages, Sparkles, X } from 'lucide-vue-next'
import { getLocaleNativeLabel } from '@/i18n'
import { useLocaleStore, type SupportedLocale } from '@/stores/locale'

const localeStore = useLocaleStore()
const { t } = useI18n()

const isOpen = ref(false)
const isSuggestionDismissedLocally = ref(false)
const switcherRef = ref<HTMLDivElement | null>(null)
const isSaving = ref(false)

const localeOptions = computed(() => {
  return localeStore.supportedLocales.map((value) => ({
    value,
    label: getLocaleNativeLabel(value),
  }))
})

const currentLocaleCode = computed(() => localeStore.locale.toUpperCase())
const detectedLocaleLabel = computed(() => getLocaleNativeLabel(localeStore.detectedLocale))
const showSuggestion = computed(() => {
  return localeStore.shouldSuggestLocale && !isOpen.value && !isSuggestionDismissedLocally.value
})

function toggleDropdown() {
  isOpen.value = !isOpen.value
}

function closeDropdown() {
  isOpen.value = false
}

function dismissSuggestion() {
  localeStore.dismissLocaleSuggestion()
  isSuggestionDismissedLocally.value = false
}

function chooseAnotherLanguage() {
  isSuggestionDismissedLocally.value = true
  isOpen.value = false
  void nextTick(() => {
    isOpen.value = true
  })
}

async function acceptSuggestedLanguage() {
  if (isSaving.value) {
    return
  }

  isSaving.value = true
  try {
    await localeStore.confirmDetectedLocale()
    isSuggestionDismissedLocally.value = false
    closeDropdown()
  } finally {
    isSaving.value = false
  }
}

async function changeLocale(nextLocale: SupportedLocale) {
  if (isSaving.value || (localeStore.locale === nextLocale && localeStore.explicitLocale)) {
    closeDropdown()
    return
  }

  isSaving.value = true
  try {
    await localeStore.setLocale(nextLocale)
    isSuggestionDismissedLocally.value = false
    closeDropdown()
  } finally {
    isSaving.value = false
  }
}

function handleClickOutside(event: MouseEvent) {
  if (switcherRef.value && !switcherRef.value.contains(event.target as Node)) {
    closeDropdown()
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
  <div ref="switcherRef" class="relative">
    <button
      type="button"
      class="locale-toggle-btn cursor-pointer rounded-full transition-all duration-150 min-h-[44px] min-w-[44px] px-2 sm:px-3 flex items-center justify-center gap-1 sm:gap-1.5"
      :aria-label="t('header.actions.changeLanguage')"
      @click.stop="toggleDropdown"
    >
      <span class="locale-toggle-code text-[11px] sm:text-xs font-semibold">{{ currentLocaleCode }}</span>
      <ChevronDown class="w-3.5 h-3.5 locale-toggle-chevron" :class="{ 'rotate-180': isOpen }" />
    </button>

    <div
      v-if="showSuggestion"
      class="locale-suggestion absolute right-0 top-full mt-2 w-[18rem] max-w-[calc(100vw-1.5rem)] sm:w-80 rounded-2xl shadow-lg border z-50 p-3"
    >
      <div class="flex items-start gap-3">
        <div class="locale-suggestion-icon-shell flex-shrink-0">
          <Languages class="w-4 h-4" />
        </div>
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-1.5 text-sm font-semibold locale-suggestion-title">
            <Sparkles class="w-3.5 h-3.5 flex-shrink-0" />
            <span>{{ t('locales.suggestion.title', { language: detectedLocaleLabel }) }}</span>
          </div>
          <p class="mt-1 text-xs sm:text-sm locale-suggestion-description">
            {{ t('locales.suggestion.description', { language: detectedLocaleLabel }) }}
          </p>
          <div class="mt-3 flex flex-wrap gap-2">
            <button
              type="button"
              class="locale-suggestion-primary px-3 py-2 rounded-xl text-xs sm:text-sm font-semibold cursor-pointer"
              @click.stop="acceptSuggestedLanguage"
            >
              {{ t('locales.suggestion.accept', { language: detectedLocaleLabel }) }}
            </button>
            <button
              type="button"
              class="locale-suggestion-secondary px-3 py-2 rounded-xl text-xs sm:text-sm cursor-pointer"
              @click.stop="chooseAnotherLanguage"
            >
              {{ t('locales.suggestion.chooseOther') }}
            </button>
          </div>
        </div>
        <button
          type="button"
          class="locale-suggestion-close p-1.5 rounded-full cursor-pointer flex-shrink-0"
          :aria-label="t('locales.suggestion.dismiss')"
          @click.stop="dismissSuggestion"
        >
          <X class="w-4 h-4" />
        </button>
      </div>
    </div>

    <div
      v-if="isOpen"
      class="locale-dropdown absolute right-0 top-full mt-2 w-36 sm:w-40 rounded-xl shadow-lg border z-50 py-1"
    >
      <button
        v-for="option in localeOptions"
        :key="option.value"
        type="button"
        class="locale-dropdown-item w-full px-3 py-2.5 flex items-center justify-between gap-3 text-sm cursor-pointer"
        :class="{ 'locale-dropdown-item-active': localeStore.locale === option.value }"
        @click="changeLocale(option.value)"
      >
        <span>{{ option.label }}</span>
        <Check v-if="localeStore.locale === option.value" class="w-4 h-4 flex-shrink-0" />
      </button>
    </div>
  </div>
</template>

<style scoped>
.locale-toggle-btn {
  color: var(--dp-text-muted);
}

.locale-toggle-btn:hover {
  color: var(--dp-text-primary);
  background-color: var(--dp-bg-hover);
}

.locale-toggle-code {
  letter-spacing: 0.02em;
}

.locale-toggle-chevron {
  transition: transform 0.15s ease;
}

.locale-dropdown {
  background-color: var(--dp-bg-card);
  border-color: var(--dp-border-primary);
}

.locale-suggestion {
  right: 0;
  width: min(18rem, calc(100vw - 1rem));
  background:
    linear-gradient(180deg, color-mix(in srgb, var(--dp-bg-card) 92%, var(--dp-accent-bg)) 0%, var(--dp-bg-card) 100%);
  border-color: color-mix(in srgb, var(--dp-border-primary) 70%, var(--dp-accent) 30%);
}

.locale-suggestion-icon-shell {
  width: 2rem;
  height: 2rem;
  border-radius: 999px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--dp-accent);
  background-color: var(--dp-accent-bg);
}

.locale-suggestion-title {
  color: var(--dp-text-primary);
}

.locale-suggestion-description {
  color: var(--dp-text-secondary);
}

.locale-suggestion-primary {
  color: var(--dp-text-on-dark);
  background-color: var(--dp-accent);
}

.locale-suggestion-primary:hover {
  background-color: var(--dp-accent-hover);
}

.locale-suggestion-secondary,
.locale-suggestion-close {
  color: var(--dp-text-secondary);
  background-color: var(--dp-bg-hover);
}

.locale-suggestion-secondary:hover,
.locale-suggestion-close:hover {
  color: var(--dp-text-primary);
  background-color: var(--dp-bg-tertiary);
}

@media (max-width: 639px) {
  .locale-suggestion {
    right: -9.5rem;
  }
}

.locale-dropdown-item {
  color: var(--dp-text-secondary);
}

.locale-dropdown-item:hover {
  background-color: var(--dp-bg-hover);
  color: var(--dp-text-primary);
}

.locale-dropdown-item-active {
  color: var(--dp-accent);
  background-color: var(--dp-accent-bg);
  font-weight: 600;
}

.locale-dropdown-item-active:hover {
  background-color: var(--dp-accent-bg-hover);
  color: var(--dp-accent-hover);
}
</style>
