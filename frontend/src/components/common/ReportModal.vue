<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { X } from 'lucide-vue-next'
import BaseModal from '@/components/common/BaseModal.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import {
  REPORT_DETAIL_MAX_LENGTH,
  REPORT_REASONS,
  type ReportReason,
  type ReportSubmission,
  type ReportTarget,
} from '@/types/report'

const props = withDefaults(defineProps<{
  isOpen: boolean
  target: ReportTarget | null
  isSubmitting?: boolean
}>(), {
  isSubmitting: false,
})

const emit = defineEmits<{
  close: []
  submit: [submission: ReportSubmission]
}>()

const { t } = useI18n()

const REASON_LABEL_KEYS: Record<ReportReason, string> = {
  SPAM: 'report.reasons.spam',
  HARASSMENT: 'report.reasons.harassment',
  INAPPROPRIATE_CONTENT: 'report.reasons.inappropriateContent',
  IMPERSONATION: 'report.reasons.impersonation',
  OTHER: 'report.reasons.other',
}

const TARGET_LABEL_KEYS = {
  MEMBER: 'report.targets.member',
  SCHEDULE: 'report.targets.schedule',
  TODO: 'report.targets.todo',
} as const

const reason = ref<ReportReason | null>(null)
const detail = ref('')
const alsoBlock = ref(false)
const showValidation = ref(false)

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      reason.value = null
      detail.value = ''
      alsoBlock.value = false
      showValidation.value = false
    }
  }
)

const reasonOptions = computed(() =>
  REPORT_REASONS.map((value) => ({ value, label: t(REASON_LABEL_KEYS[value]) }))
)

const targetLabel = computed(() => {
  if (!props.target) return ''
  return t(TARGET_LABEL_KEYS[props.target.targetType], { name: props.target.targetName })
})

const isDetailRequired = computed(() => reason.value === 'OTHER')
const isDetailMissing = computed(() => isDetailRequired.value && !detail.value.trim())
const isSubmitDisabled = computed(
  () => !reason.value || isDetailMissing.value || props.isSubmitting
)

function handleClose() {
  if (props.isSubmitting) return
  emit('close')
}

function handleSubmit() {
  showValidation.value = true
  if (!reason.value || isDetailMissing.value || props.isSubmitting) return

  emit('submit', {
    reason: reason.value,
    detail: detail.value.trim(),
    alsoBlock: alsoBlock.value,
  })
}
</script>

<template>
  <BaseModal
    :is-open="isOpen && !!target"
    size="lg"
    height="fit"
    z-index="admin"
    :close-on-backdrop="!isSubmitting"
    :close-on-escape="!isSubmitting"
    aria-labelledby="report-modal-title"
    @close="handleClose"
  >
    <div class="modal-header">
      <h2 id="report-modal-title">{{ t('report.modal.title') }}</h2>
      <button
        type="button"
        class="p-2 hover-close-btn rounded-full transition flex-shrink-0 cursor-pointer"
        :aria-label="t('common.actions.close')"
        :disabled="isSubmitting"
        @click="handleClose"
      >
        <X class="w-6 h-6 text-dp-text-primary" />
      </button>
    </div>

    <div class="modal-body-form-compact report-modal-body">
      <p class="rounded-lg bg-dp-bg-tertiary px-3 py-2 text-sm break-all text-dp-text-primary">
        {{ targetLabel }}
      </p>

      <fieldset>
        <legend class="form-label">
          {{ t('report.modal.reasonLabel') }} <span class="text-dp-danger">*</span>
        </legend>
        <div class="space-y-1">
          <label
            v-for="option in reasonOptions"
            :key="option.value"
            class="flex min-h-11 cursor-pointer items-center gap-3 rounded-lg px-2 text-sm text-dp-text-primary hover:bg-dp-bg-hover"
          >
            <input
              v-model="reason"
              type="radio"
              name="report-reason"
              :value="option.value"
              class="h-4 w-4 shrink-0 cursor-pointer rounded-full text-dp-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
              :disabled="isSubmitting"
            />
            <span>{{ option.label }}</span>
          </label>
        </div>
        <p v-if="showValidation && !reason" class="mt-1 text-xs text-dp-danger" role="alert">
          {{ t('report.modal.reasonRequired') }}
        </p>
      </fieldset>

      <div>
        <label class="form-label" for="report-detail">
          {{ t('report.modal.detailLabel') }}
          <span v-if="isDetailRequired" class="text-dp-danger">*</span>
          <CharacterCounter :current="detail.length" :max="REPORT_DETAIL_MAX_LENGTH" />
        </label>
        <textarea
          id="report-detail"
          v-model="detail"
          rows="4"
          :maxlength="REPORT_DETAIL_MAX_LENGTH"
          :placeholder="t('report.modal.detailPlaceholder')"
          class="form-control"
          :aria-invalid="showValidation && isDetailMissing"
          :disabled="isSubmitting"
        ></textarea>
        <p v-if="showValidation && isDetailMissing" class="mt-1 text-xs text-dp-danger" role="alert">
          {{ t('report.modal.detailRequired') }}
        </p>
      </div>

      <div>
        <label class="flex min-h-11 cursor-pointer items-center gap-3 rounded-lg px-2 text-sm text-dp-text-primary hover:bg-dp-bg-hover">
          <input
            v-model="alsoBlock"
            type="checkbox"
            class="h-5 w-5 shrink-0 cursor-pointer rounded border-dp-border-input text-dp-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
            :disabled="isSubmitting"
          />
          <span>{{ t('report.modal.alsoBlock') }}</span>
        </label>
        <!-- Always laid out so ticking the box reveals the notice without reflowing the form. -->
        <p
          class="mt-1 px-2 text-xs text-dp-text-muted"
          :class="{ invisible: !alsoBlock }"
        >
          {{ t('report.block.message') }}
        </p>
      </div>
    </div>

    <div class="modal-footer-safe modal-actions-compact modal-actions-end">
      <button
        type="button"
        class="flex-1 sm:flex-none px-4 py-2 rounded-lg transition btn-outline cursor-pointer"
        :disabled="isSubmitting"
        @click="handleClose"
      >
        {{ t('common.actions.cancel') }}
      </button>
      <button
        type="button"
        class="flex-1 sm:flex-none px-4 py-2 bg-dp-danger text-dp-text-on-dark rounded-lg hover:bg-dp-danger-hover transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
        :disabled="isSubmitDisabled"
        @click="handleSubmit"
      >
        {{ isSubmitting ? t('report.modal.submitting') : t('report.modal.submit') }}
      </button>
    </div>
  </BaseModal>
</template>

<style scoped>
/* The shared body class caps at a fixed 580px, a hair under this form's natural height,
   which leaves the block notice stranded behind a scrollbar. The modal container already
   caps itself to the viewport, so this form only needs the fixed cap lifted. */
.report-modal-body {
  max-height: none;
}
</style>
