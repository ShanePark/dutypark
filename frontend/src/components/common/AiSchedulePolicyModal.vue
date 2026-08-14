<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import BaseModal from '@/components/common/BaseModal.vue'
import type { PolicyDto } from '@/api/policy'
import { renderPolicyMarkdown } from '@/utils/policyMarkdown'

const props = withDefaults(defineProps<{
  isOpen: boolean
  policy: (PolicyDto & { policyType: 'AI_SCHEDULE_PARSING' }) | null
  mode?: 'read' | 'consent'
  isSaving?: boolean
  error?: string
}>(), {
  mode: 'read',
  isSaving: false,
  error: '',
})

const emit = defineEmits<{
  close: []
  consent: []
}>()
const { t } = useI18n()
const content = computed(() => props.policy?.content ? renderPolicyMarkdown(props.policy.content) : '')
const agreed = ref(false)
const isConsentMode = computed(() => props.mode === 'consent')

watch(
  [() => props.isOpen, () => props.mode],
  () => {
    agreed.value = false
  },
)

function close() {
  if (!props.isSaving) emit('close')
}
</script>

<template>
  <BaseModal
    :is-open="isOpen"
    size="3xl"
    height="viewport"
    z-index="admin"
    :close-on-backdrop="!isSaving"
    :close-on-escape="!isSaving"
    aria-labelledby="ai-schedule-policy-title"
    :aria-describedby="isConsentMode ? 'ai-schedule-data-flow' : undefined"
    @close="close"
  >
    <div class="modal-header">
      <div>
        <h2 id="ai-schedule-policy-title">{{ t('aiScheduleConsent.policyTitle') }}</h2>
        <p v-if="policy" class="mt-1 text-xs text-dp-text-muted">
          {{ t('aiScheduleConsent.policyMeta', { version: policy.version, date: policy.effectiveDate }) }}
        </p>
      </div>
      <button
        type="button"
        class="min-h-11 min-w-11 rounded-full hover-close-btn"
        :aria-label="t('common.actions.close')"
        :disabled="isSaving"
        @click="close"
      >
        ×
      </button>
    </div>
    <div class="min-h-0 flex-1 overflow-y-auto p-4 sm:p-5">
      <section
        v-if="isConsentMode"
        id="ai-schedule-data-flow"
        class="mb-5 rounded-xl border border-dp-accent-border bg-dp-accent-soft p-4 text-sm leading-6 text-dp-text-secondary"
      >
        <h3 class="font-semibold text-dp-text-primary">{{ t('aiScheduleConsent.dataFlowTitle') }}</h3>
        <p class="mt-1">{{ t('aiScheduleConsent.dataFlow') }}</p>
        <p class="mt-1 text-dp-text-muted">{{ t('aiScheduleConsent.optionalDescription') }}</p>
      </section>
      <div class="prose prose-sm max-w-none text-dp-text-secondary sm:prose-base">
        <div v-if="content" v-html="content"></div>
        <p v-else>{{ t('policy.unavailable') }}</p>
      </div>
    </div>
    <div class="modal-footer-safe shrink-0 border-t border-dp-border-primary p-4">
      <template v-if="isConsentMode">
        <label
          v-if="policy"
          class="flex min-h-11 cursor-pointer items-center gap-3 rounded-lg px-2 py-2 text-sm font-medium text-dp-text-primary hover:bg-dp-bg-hover"
        >
          <input
            v-model="agreed"
            type="checkbox"
            class="h-5 w-5 shrink-0 cursor-pointer rounded border-dp-border-input text-dp-accent focus:ring-2 focus:ring-dp-accent-ring"
            :disabled="isSaving"
          />
          <span>{{ t('aiScheduleConsent.consentAcknowledgement') }}</span>
        </label>
        <p
          v-if="error"
          class="mt-2 rounded-lg border border-dp-danger-border bg-dp-danger-soft p-3 text-sm text-dp-danger"
          role="alert"
        >
          {{ error }}
        </p>
        <div class="mt-3 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <button
            type="button"
            class="min-h-11 rounded-lg bg-dp-bg-tertiary px-4 font-medium text-dp-text-primary hover:bg-dp-bg-hover disabled:cursor-not-allowed disabled:opacity-50 sm:min-w-28"
            :disabled="isSaving"
            @click="close"
          >
            {{ t('common.actions.cancel') }}
          </button>
          <button
            type="button"
            class="min-h-11 rounded-lg bg-dp-accent px-4 font-semibold text-dp-text-on-dark transition hover:bg-dp-accent-hover disabled:cursor-not-allowed disabled:opacity-50 sm:min-w-40"
            :disabled="!policy || !agreed || isSaving"
            @click="emit('consent')"
          >
            {{ isSaving ? t('aiScheduleConsent.consentSaving') : t('aiScheduleConsent.consentAction') }}
          </button>
        </div>
      </template>
      <button
        v-else
        type="button"
        class="min-h-11 w-full rounded-lg bg-dp-bg-tertiary px-4 font-medium text-dp-text-primary hover:bg-dp-bg-hover"
        @click="close"
      >
        {{ t('common.actions.close') }}
      </button>
    </div>
  </BaseModal>
</template>
