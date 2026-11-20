<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useThemeStore, type ThemeMode } from '@/stores/theme'
import { useSwal } from '@/composables/useSwal'
import { usePushNotification } from '@/composables/usePushNotification'
import PageHeader from '@/components/common/PageHeader.vue'
import { Info, Loader2, Sun, Moon, Bell, Settings } from '@lucide/vue'

const themeStore = useThemeStore()
const { t } = useI18n()
const { showError, toastSuccess } = useSwal()

// Push notification settings
const pushNotification = usePushNotification()
const togglingPush = ref(false)

const isIOSPWA = computed(() => {
  const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !(window as any).MSStream
  const isStandalone = window.matchMedia('(display-mode: standalone)').matches ||
    (window.navigator as any).standalone === true
  return isIOS && isStandalone
})

const showPushSettings = computed(() => {
  return pushNotification.isSupported.value && pushNotification.isEnabled.value
})

const isPushOn = computed(() => {
  return pushNotification.permission.value === 'granted' && pushNotification.isSubscribed.value
})

const isPushBlocked = computed(() => pushNotification.permission.value === 'denied')

async function togglePushNotification() {
  if (togglingPush.value) return
  togglingPush.value = true

  try {
    if (isPushOn.value) {
      await pushNotification.unsubscribe()
      toastSuccess(t('member.push.messages.disabled'))
    } else {
      const success = await pushNotification.subscribe()
      if (success) {
        toastSuccess(t('member.push.messages.enabled'))
      } else if (pushNotification.permission.value === 'denied') {
        showError(t('member.push.messages.deniedHelp'))
      }
    }
  } catch (error) {
    console.error('Failed to toggle push notification:', error)
    showError(t('member.push.messages.updateFailed'))
  } finally {
    togglingPush.value = false
  }
}

async function initPushNotification() {
  pushNotification.checkSupport()
  if (pushNotification.isSupported.value) {
    await pushNotification.checkEnabled()
  }
}

// Theme settings
const themeOptions = computed<{ value: ThemeMode; label: string; icon: typeof Sun }[]>(() => [
  { value: 'light', label: t('member.theme.options.light'), icon: Sun },
  { value: 'dark', label: t('member.theme.options.dark'), icon: Moon },
])

const currentThemeLabel = computed(() => {
  return themeStore.mode === 'dark'
    ? t('member.theme.options.dark')
    : t('member.theme.options.light')
})

function setTheme(mode: ThemeMode) {
  themeStore.setTheme(mode)
}

// Loading states
const loading = ref(false)
// Initialize data
onMounted(async () => {
  loading.value = true
  try {
    await initPushNotification()
  } catch (error) {
    console.error('Failed to initialize:', error)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <PageHeader :title="t('header.menu.settings')" :icon="Settings" show-back back-fallback="/more" />

    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center py-20">
      <Loader2 class="w-8 h-8 animate-spin text-dp-accent" />
    </div>

    <template v-else>
      <!-- Theme Settings Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4 bg-dp-bg-card border border-dp-border-primary">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2 text-dp-text-primary">
          <Sun class="w-5 h-5 text-dp-text-secondary" />
          {{ t('member.theme.sectionTitle') }}
        </h2>
        <div class="flex flex-col sm:flex-row gap-3">
          <button
            v-for="option in themeOptions"
            :key="option.value"
            @click="setTheme(option.value)"
            class="flex-1 px-4 py-3 rounded-lg font-medium flex items-center justify-center gap-2 hover-lift cursor-pointer"
            :style="{
              borderWidth: '2px',
              borderColor: themeStore.mode === option.value ? 'var(--dp-accent)' : 'var(--dp-border-primary)',
              backgroundColor: themeStore.mode === option.value ? 'var(--dp-accent-bg)' : 'var(--dp-bg-secondary)',
              color: themeStore.mode === option.value ? 'var(--dp-accent)' : 'var(--dp-text-primary)'
            }"
          >
            <component :is="option.icon" class="w-5 h-5" />
            {{ option.label }}
          </button>
        </div>
        <p class="text-sm mt-3 text-dp-text-muted">
          {{ t('member.theme.current', { theme: currentThemeLabel }) }}
        </p>
      </section>

      <!-- Push Notification Settings Section -->
      <section v-if="showPushSettings" class="rounded-xl shadow-sm p-6 mb-4 bg-dp-bg-card border border-dp-border-primary">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2 text-dp-text-primary">
          <Bell class="w-5 h-5 text-dp-text-secondary" />
          {{ t('member.push.sectionTitle') }}
        </h2>
        <button
          type="button"
          role="switch"
          :aria-checked="isPushOn"
          :disabled="togglingPush || isPushBlocked"
          @click="togglePushNotification"
          class="push-toggle-row w-full min-h-11 flex items-center justify-between gap-4 p-3 -mx-3 rounded-lg text-left cursor-pointer disabled:cursor-not-allowed"
        >
          <span class="min-w-0">
            <span class="block font-medium text-dp-text-primary">{{ t('member.push.toggleLabel') }}</span>
            <span class="block text-sm mt-1 text-dp-text-secondary">{{ t('member.push.toggleDescription') }}</span>
          </span>
          <span
            class="push-switch"
            :class="{ 'push-switch-on': isPushOn, 'push-switch-blocked': isPushBlocked }"
            aria-hidden="true"
          >
            <span class="push-switch-thumb">
              <Loader2 v-if="togglingPush" class="w-3.5 h-3.5 animate-spin text-dp-accent" />
            </span>
          </span>
        </button>
        <p v-if="isPushBlocked" class="flex items-start gap-1.5 text-sm mt-3 text-dp-warning">
          <Info class="w-4 h-4 shrink-0 mt-0.5" />
          <span>{{ t('member.push.messages.deniedHelp') }}</span>
        </p>
        <p v-if="isIOSPWA && isPushBlocked" class="text-sm mt-2 text-dp-text-muted">
          {{ t('member.push.iosHint') }}
        </p>
      </section>
    </template>
  </div>
</template>

<style scoped>
.push-toggle-row {
  transition: background-color 0.15s ease;
}

.push-toggle-row:hover:not(:disabled) {
  background-color: var(--dp-bg-hover);
}

.push-toggle-row:hover:not(:disabled) .push-switch {
  box-shadow: 0 0 0 4px var(--dp-accent-bg);
}

.push-switch {
  position: relative;
  display: inline-flex;
  flex-shrink: 0;
  width: 3rem;
  height: 1.75rem;
  border-radius: 9999px;
  background-color: var(--dp-border-secondary);
  transition: background-color 0.2s ease, box-shadow 0.15s ease;
}

.push-switch-on {
  background-color: var(--dp-accent);
}

.push-switch-blocked {
  opacity: 0.5;
}

.push-switch-thumb {
  position: absolute;
  top: 0.25rem;
  left: 0.25rem;
  width: 1.25rem;
  height: 1.25rem;
  border-radius: 9999px;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: var(--dp-text-on-dark);
  box-shadow: var(--dp-shadow-sm);
  transition: transform 0.2s ease;
}

.push-switch-on .push-switch-thumb {
  transform: translateX(1.25rem);
}
</style>
