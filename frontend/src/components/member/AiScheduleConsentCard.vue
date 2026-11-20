<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { useAiScheduleConsentStore } from '@/stores/aiScheduleConsent'
import { useSwal } from '@/composables/useSwal'
import AiSchedulePolicyModal from '@/components/common/AiSchedulePolicyModal.vue'
import { canReenableAiScheduleConsentWithoutPrompt } from '@/utils/aiScheduleConsentFlow'
import { BrainCircuit, Loader2 } from '@lucide/vue'

const authStore = useAuthStore()
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

onMounted(() => {
  window.addEventListener('focus', refreshAiConsentOnReturn)
  document.addEventListener('visibilitychange', refreshAiConsentOnReturn)
  void loadAiConsent()
})

onUnmounted(() => {
  window.removeEventListener('focus', refreshAiConsentOnReturn)
  document.removeEventListener('visibilitychange', refreshAiConsentOnReturn)
})
</script>

<template>
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

  <AiSchedulePolicyModal
    :is-open="showAiPolicyModal"
    :policy="aiConsentStore.consent?.policy ?? null"
    :mode="aiPolicyModalMode"
    :is-saving="aiConsentStore.isSaving"
    :error="aiConsentError"
    @close="closeAiPolicy"
    @consent="grantAiConsent"
  />
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
