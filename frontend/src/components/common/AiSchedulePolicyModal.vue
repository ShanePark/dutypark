<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { marked } from 'marked'
import BaseModal from '@/components/common/BaseModal.vue'
import type { PolicyDto } from '@/api/policy'

marked.setOptions({ breaks: true })

const props = defineProps<{
  isOpen: boolean
  policy: (PolicyDto & { policyType: 'AI_SCHEDULE_PARSING' }) | null
}>()

const emit = defineEmits<{ close: [] }>()
const { t } = useI18n()
const content = computed(() => props.policy?.content ? String(marked(props.policy.content)) : '')
</script>

<template>
  <BaseModal :is-open="isOpen" size="3xl" height="viewport" z-index="admin" @close="emit('close')">
    <div class="modal-header">
      <div>
        <h2>{{ t('aiScheduleConsent.policyTitle') }}</h2>
        <p v-if="policy" class="mt-1 text-xs text-dp-text-muted">
          {{ t('aiScheduleConsent.policyMeta', { version: policy.version, date: policy.effectiveDate }) }}
        </p>
      </div>
      <button
        type="button"
        class="min-h-11 min-w-11 rounded-full hover-close-btn"
        :aria-label="t('common.actions.close')"
        @click="emit('close')"
      >
        ×
      </button>
    </div>
    <div class="flex-1 overflow-y-auto p-5 prose prose-sm sm:prose-base max-w-none text-dp-text-secondary">
      <div v-if="content" v-html="content"></div>
      <p v-else>{{ t('policy.unavailable') }}</p>
    </div>
    <div class="modal-footer-safe border-t border-dp-border-primary p-4">
      <button type="button" class="min-h-11 w-full rounded-lg bg-dp-bg-tertiary px-4 font-medium text-dp-text-primary" @click="emit('close')">
        {{ t('common.actions.close') }}
      </button>
    </div>
  </BaseModal>
</template>
