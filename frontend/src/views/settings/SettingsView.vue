<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { useThemeStore, type ThemeMode } from '@/stores/theme'
import { useAiScheduleConsentStore } from '@/stores/aiScheduleConsent'
import { friendApi, memberApi } from '@/api/member'
import { useSwal } from '@/composables/useSwal'
import { usePushNotification } from '@/composables/usePushNotification'
import type { CalendarVisibility, FriendDto } from '@/types'
import { VISIBILITY_COLORS } from '@/utils/visibility'
import BaseModal from '@/components/common/BaseModal.vue'
import PageHeader from '@/components/common/PageHeader.vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import AiSchedulePolicyModal from '@/components/common/AiSchedulePolicyModal.vue'
import { canReenableAiScheduleConsentWithoutPrompt } from '@/utils/aiScheduleConsentFlow'
import {
  Eye,
  Info,
  Check,
  X,
  ChevronRight,
  Loader2,
  Sun,
  Moon,
  Bell,
  Settings,
  BrainCircuit,
} from 'lucide-vue-next'

const authStore = useAuthStore()
const themeStore = useThemeStore()
const aiConsentStore = useAiScheduleConsentStore()
const { t } = useI18n()
const { showError, toastSuccess } = useSwal()

const showAiPolicyModal = ref(false)
const aiPolicyModalMode = ref<'read' | 'consent'>('read')
const aiConsentError = ref('')
const aiConsentOn = computed(() => aiConsentStore.isCurrent)
const AI_CONSENT_REFRESH_INTERVAL_MS = 30_000

async function loadAiConsent(force = false) {
  const id = authStore.user?.id
  if (!id) {
    aiConsentStore.reset()
    return
  }
  try {
    await aiConsentStore.loadForMember(id, force)
  } catch (error) {
    console.error('Failed to load AI schedule parsing consent:', error)
  }
}

async function toggleAiConsent() {
  const id = authStore.user?.id
  if (!id || aiConsentStore.isSaving) return

  if (aiConsentOn.value) {
    try {
      await aiConsentStore.revoke(id)
      toastSuccess(t('aiScheduleConsent.messages.revoked'))
    } catch (error) {
      console.error('Failed to revoke AI schedule parsing consent:', error)
      showError(t('aiScheduleConsent.messages.updateFailed'))
    }
    return
  }

  if (canReenableAiScheduleConsentWithoutPrompt(aiConsentStore.consent)) {
    try {
      await aiConsentStore.grant(id)
      toastSuccess(t('aiScheduleConsent.messages.granted'))
    } catch (error) {
      console.error('Failed to re-enable AI schedule parsing consent:', error)
      showError(t('aiScheduleConsent.messages.updateFailed'))
    }
    return
  }

  aiPolicyModalMode.value = 'consent'
  aiConsentError.value = ''
  showAiPolicyModal.value = true
}

function openAiPolicy() {
  aiPolicyModalMode.value = 'read'
  aiConsentError.value = ''
  showAiPolicyModal.value = true
}

function closeAiPolicy() {
  if (aiConsentStore.isSaving) return
  showAiPolicyModal.value = false
  aiConsentError.value = ''
}

async function grantAiConsent() {
  const id = authStore.user?.id
  if (!id || aiConsentStore.isSaving || aiPolicyModalMode.value !== 'consent') return

  aiConsentError.value = ''
  try {
    await aiConsentStore.grant(id)
    showAiPolicyModal.value = false
    toastSuccess(t('aiScheduleConsent.messages.granted'))
  } catch (error) {
    console.error('Failed to grant AI schedule parsing consent:', error)
    aiConsentError.value = t('aiScheduleConsent.messages.updateFailed')
  }
}

function refreshAiConsentOnReturn() {
  const id = authStore.user?.id
  if (document.visibilityState !== 'visible' || !id) return
  void aiConsentStore.refreshIfStaleForMember(id, AI_CONSENT_REFRESH_INTERVAL_MS).catch((error) => {
    console.error('Failed to refresh AI schedule parsing consent:', error)
  })
}

watch(
  () => authStore.user?.id ?? null,
  (id, previousId) => {
    if (id === previousId) return
    if (id === null) aiConsentStore.reset()
    else void loadAiConsent()
  },
)

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
const savingVisibility = ref(false)

// Visibility settings
const calendarVisibility = ref<CalendarVisibility>('FRIENDS')
const showVisibilityModal = ref(false)
const memberModalPanelStyle = { backgroundColor: 'var(--dp-bg-card)' }

const visibilityLabel = computed(() => {
  const labels: Record<CalendarVisibility, string> = {
    PUBLIC: t('member.visibility.options.public.label'),
    FRIENDS: t('member.visibility.options.friends.label'),
    FAMILY: t('member.visibility.options.family.label'),
    PRIVATE: t('member.visibility.options.private.label'),
  }
  return labels[calendarVisibility.value]
})

interface VisibilityAudience {
  viewers: FriendDto[]
  countLabel: string
  emptyText: string
}

const AUDIENCE_MAX_AVATARS = 5
const AUDIENCE_MAX_NAMES = 3

const audienceFriends = ref<FriendDto[]>([])
const audienceLoading = ref(false)
const audienceLoaded = ref(false)

function openVisibilityModal() {
  showVisibilityModal.value = true
  loadVisibilityAudience()
}

async function loadVisibilityAudience() {
  if (audienceLoading.value) return
  audienceLoading.value = true
  try {
    const response = await friendApi.getFriends()
    audienceFriends.value = response.data
    audienceLoaded.value = true
  } catch (error) {
    console.error('Failed to load visibility audience:', error)
  } finally {
    audienceLoading.value = false
  }
}

function audienceNames(viewers: FriendDto[]): string {
  const names = viewers
    .slice(0, AUDIENCE_MAX_NAMES)
    .map((viewer) => viewer.name)
    .join(t('member.visibility.audience.nameSeparator'))
  const rest = viewers.length - AUDIENCE_MAX_NAMES
  return rest > 0 ? t('member.visibility.audience.moreNames', { names, count: rest }) : names
}

const visibilityOptions = computed<
  {
    value: CalendarVisibility
    label: string
    color: string
    description: string
    audience?: VisibilityAudience
  }[]
>(() => {
  const friends = audienceFriends.value
  const family = friends.filter((friend) => friend.isFamily)
  return [
    {
      value: 'PUBLIC',
      label: t('member.visibility.options.public.label'),
      color: VISIBILITY_COLORS.PUBLIC,
      description: t('member.visibility.options.public.description'),
    },
    {
      value: 'FRIENDS',
      label: t('member.visibility.options.friends.label'),
      color: VISIBILITY_COLORS.FRIENDS,
      description: t('member.visibility.options.friends.description'),
      audience: {
        viewers: friends,
        countLabel: t(
          'member.visibility.audience.friendsCount',
          { count: friends.length },
          friends.length
        ),
        emptyText: t('member.visibility.audience.emptyFriends'),
      },
    },
    {
      value: 'FAMILY',
      label: t('member.visibility.options.family.label'),
      color: VISIBILITY_COLORS.FAMILY,
      description: t('member.visibility.options.family.description'),
      audience: {
        viewers: family,
        countLabel: t(
          'member.visibility.audience.familyCount',
          { count: family.length },
          family.length
        ),
        emptyText: t('member.visibility.audience.emptyFamily'),
      },
    },
    {
      value: 'PRIVATE',
      label: t('member.visibility.options.private.label'),
      color: VISIBILITY_COLORS.PRIVATE,
      description: t('member.visibility.options.private.description'),
    },
  ]
})

const visibilityColorClass = computed(() => VISIBILITY_COLORS[calendarVisibility.value] ?? 'bg-dp-accent')

async function setVisibility(value: CalendarVisibility) {
  if (!authStore.user) return

  savingVisibility.value = true
  try {
    await memberApi.updateVisibility(authStore.user.id, value)
    calendarVisibility.value = value
    showVisibilityModal.value = false
  } catch (error) {
    console.error('Failed to update visibility:', error)
    showError(t('member.visibility.updateFailed'))
  } finally {
    savingVisibility.value = false
  }
}

async function fetchCalendarVisibility() {
  try {
    const response = await memberApi.getMyInfo()
    calendarVisibility.value = response.data.calendarVisibility
  } catch (error) {
    console.error('Failed to fetch member info:', error)
    showError(t('member.errors.loadFailed'))
  }
}

// Initialize data
onMounted(async () => {
  window.addEventListener('focus', refreshAiConsentOnReturn)
  document.addEventListener('visibilitychange', refreshAiConsentOnReturn)
  loading.value = true
  try {
    await Promise.all([
      fetchCalendarVisibility(),
      initPushNotification(),
      loadAiConsent(),
    ])
  } catch (error) {
    console.error('Failed to initialize:', error)
  } finally {
    loading.value = false
  }
})

onUnmounted(() => {
  window.removeEventListener('focus', refreshAiConsentOnReturn)
  document.removeEventListener('visibilitychange', refreshAiConsentOnReturn)
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
      <!-- Privacy Settings Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4 bg-dp-bg-card border border-dp-border-primary">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2 text-dp-text-primary">
          <Eye class="w-5 h-5 text-dp-text-secondary" />
          {{ t('member.visibility.sectionTitle') }}
        </h2>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div>
            <p class="text-dp-text-primary">{{ t('member.visibility.currentLabel') }}</p>
            <p class="text-sm mt-1 text-dp-text-secondary">{{ t('member.visibility.description') }}</p>
          </div>
          <button
            @click="openVisibilityModal"
            class="px-4 py-3 sm:py-2 min-h-11 rounded-lg font-medium flex items-center justify-center gap-2 hover-lift cursor-pointer bg-dp-bg-tertiary text-dp-text-primary"
          >
            <span
              class="w-2 h-2 rounded-full"
              :class="visibilityColorClass"
            ></span>
            {{ visibilityLabel }}
            <ChevronRight class="w-4 h-4" />
          </button>
        </div>
      </section>

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

      <!-- Optional AI Schedule Parsing Settings Section -->
      <section class="rounded-xl shadow-sm p-4 sm:p-6 mb-4 bg-dp-bg-card border border-dp-border-primary">
        <h2 class="text-lg font-semibold mb-3 flex items-center gap-2 text-dp-text-primary">
          <BrainCircuit class="w-5 h-5 text-dp-text-secondary" />
          {{ t('aiScheduleConsent.settingsTitle') }}
        </h2>
        <p class="text-sm leading-6 text-dp-text-secondary">
          {{ t('aiScheduleConsent.dataFlow') }}
        </p>
        <p class="mt-1 text-sm leading-6 text-dp-text-secondary">
          {{ t('aiScheduleConsent.optionalDescription') }}
        </p>
        <div v-if="aiConsentStore.loadFailed" class="mt-3 rounded-lg bg-dp-warning-soft p-3 text-sm text-dp-warning">
          <p>{{ t('aiScheduleConsent.messages.loadFailed') }}</p>
          <button type="button" class="mt-2 min-h-11 rounded-lg px-3 font-medium hover:bg-dp-bg-hover" @click="loadAiConsent(true)">
            {{ t('common.actions.retry') }}
          </button>
        </div>
        <button
          v-else
          type="button"
          role="switch"
          :aria-checked="aiConsentOn"
          :disabled="aiConsentStore.isLoading || aiConsentStore.isSaving || !aiConsentStore.consent?.policy"
          class="push-toggle-row mt-3 w-full min-h-11 flex items-center justify-between gap-4 rounded-lg p-3 text-left disabled:cursor-not-allowed"
          @click="toggleAiConsent"
        >
          <span class="min-w-0">
            <span class="block font-medium text-dp-text-primary">{{ t('aiScheduleConsent.toggleLabel') }}</span>
            <span class="block text-sm mt-1 text-dp-text-muted">
              {{ aiConsentStore.consent?.needsRenewal ? t('aiScheduleConsent.renewalRequired') : (aiConsentOn ? t('aiScheduleConsent.statusOn') : t('aiScheduleConsent.statusOff')) }}
            </span>
          </span>
          <span class="push-switch" :class="{ 'push-switch-on': aiConsentOn }" aria-hidden="true">
            <span class="push-switch-thumb">
              <Loader2 v-if="aiConsentStore.isLoading || aiConsentStore.isSaving" class="w-3.5 h-3.5 animate-spin text-dp-accent" />
            </span>
          </span>
        </button>
        <button
          type="button"
          :disabled="!aiConsentStore.consent?.policy"
          class="mt-2 min-h-11 rounded-lg px-3 text-sm font-medium text-dp-accent hover:bg-dp-accent-soft disabled:opacity-50"
          @click="openAiPolicy"
        >
          {{ t('aiScheduleConsent.viewPolicy') }}
        </button>
      </section>
    </template>

    <AiSchedulePolicyModal
      :is-open="showAiPolicyModal"
      :policy="aiConsentStore.consent?.policy ?? null"
      :mode="aiPolicyModalMode"
      :is-saving="aiConsentStore.isSaving"
      :error="aiConsentError"
      @close="closeAiPolicy"
      @consent="grantAiConsent"
    />

    <!-- Visibility Modal -->
    <BaseModal
      :is-open="showVisibilityModal"
      size="md"
      height="fit"
      rounded
      :panel-style="memberModalPanelStyle"
      @close="showVisibilityModal = false"
    >
      <div class="modal-header">
        <h2>{{ t('member.visibility.modalTitle') }}</h2>
        <button @click="showVisibilityModal = false" class="p-1.5 rounded-full hover-close-btn cursor-pointer text-dp-text-muted">
          <X class="w-5 h-5" />
        </button>
      </div>
      <div class="modal-body-form-lg">
        <p class="text-dp-text-secondary">{{ t('member.visibility.modalDescription') }}</p>
        <p class="text-sm text-dp-text-muted">{{ t('member.visibility.modalHint') }}</p>
        <div class="space-y-2">
          <button
            v-for="option in visibilityOptions"
            :key="option.value"
            @click="setVisibility(option.value)"
            :disabled="savingVisibility"
            class="w-full p-4 min-h-16 rounded-lg text-left disabled:opacity-50 disabled:cursor-not-allowed hover-lift cursor-pointer"
            :style="{
              borderWidth: '2px',
              borderColor: calendarVisibility === option.value ? 'var(--dp-accent)' : 'var(--dp-border-primary)',
              backgroundColor: calendarVisibility === option.value ? 'var(--dp-accent-bg)' : 'var(--dp-bg-secondary)'
            }"
          >
            <div class="flex items-center gap-3">
              <span class="w-3 h-3 rounded-full" :class="option.color"></span>
              <span class="font-medium text-dp-text-primary">{{ option.label }}</span>
              <Check
                v-if="calendarVisibility === option.value"
                class="w-5 h-5 text-dp-accent ml-auto"
              />
              <Loader2
                v-if="savingVisibility && calendarVisibility !== option.value"
                class="w-5 h-5 animate-spin ml-auto text-dp-text-muted"
              />
            </div>
            <p class="text-sm mt-1 ml-6 text-dp-text-secondary">{{ option.description }}</p>
            <div v-if="option.audience" class="mt-2.5 ml-6">
              <div v-if="audienceLoading && !audienceLoaded" class="flex items-center min-h-6">
                <Loader2 class="w-4 h-4 animate-spin text-dp-text-muted" />
              </div>
              <template v-else-if="audienceLoaded">
                <div
                  v-if="option.audience.viewers.length > 0"
                  class="flex items-center gap-2.5"
                >
                  <div class="flex shrink-0">
                    <ProfileAvatar
                      v-for="viewer in option.audience.viewers.slice(0, AUDIENCE_MAX_AVATARS)"
                      :key="viewer.id"
                      :member-id="viewer.id"
                      :name="viewer.name"
                      :has-profile-photo="viewer.hasProfilePhoto"
                      :profile-photo-version="viewer.profilePhotoVersion"
                      size="sm"
                      class="audience-avatar"
                      :title="viewer.name"
                    />
                    <span
                      v-if="option.audience.viewers.length > AUDIENCE_MAX_AVATARS"
                      class="audience-avatar audience-overflow-badge w-6 h-6 sm:w-8 sm:h-8 rounded-full flex items-center justify-center text-[10px] sm:text-xs font-semibold"
                    >
                      +{{ option.audience.viewers.length - AUDIENCE_MAX_AVATARS }}
                    </span>
                  </div>
                  <div class="min-w-0">
                    <p class="text-xs font-medium text-dp-text-primary">
                      {{ option.audience.countLabel }}
                    </p>
                    <p class="text-xs mt-0.5 text-dp-text-muted truncate">
                      {{ audienceNames(option.audience.viewers) }}
                    </p>
                  </div>
                </div>
                <p v-else class="flex items-center gap-1.5 text-xs text-dp-warning">
                  <Info class="w-3.5 h-3.5 shrink-0" />
                  {{ option.audience.emptyText }}
                </p>
              </template>
            </div>
          </button>
        </div>
      </div>
      <div class="modal-actions modal-footer-safe sm:px-6 sm:py-6">
        <button
          @click="showVisibilityModal = false"
          class="w-full px-4 py-3 sm:py-2 min-h-11 rounded-lg font-medium hover-interactive cursor-pointer bg-dp-bg-tertiary text-dp-text-primary"
        >
          {{ t('member.visibility.closeButton') }}
        </button>
      </div>
    </BaseModal>
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

.audience-avatar + .audience-avatar {
  margin-left: -0.375rem;
}

.audience-overflow-badge {
  background-color: var(--dp-bg-tertiary);
  border: 2px solid var(--dp-border-primary);
  color: var(--dp-text-secondary);
}
</style>
