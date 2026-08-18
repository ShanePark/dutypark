<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import BaseModal from '@/components/common/BaseModal.vue'
import type { AdminReportDetailDto, ReportResolutionStatus } from '@/types/adminModeration'
import {
  MEMBER_STATUS_LABEL_KEYS,
  REPORT_REASON_LABEL_KEYS,
  REPORT_STATUS_LABEL_KEYS,
  REPORT_TARGET_TYPE_LABEL_KEYS,
  memberStatusToneClass,
  reportStatusToneClass,
} from './adminModerationLabels'
import { ChevronRight, Loader2, X } from 'lucide-vue-next'

const props = defineProps<{
  open: boolean
  report: AdminReportDetailDto | null
  loading: boolean
  loadError: string | null
  working: boolean
}>()

const emit = defineEmits<{
  close: []
  retry: []
  updateStatus: [status: ReportResolutionStatus, memo: string]
  deleteTarget: []
  suspend: []
  unsuspend: []
  goToCalendar: []
}>()

const { t, locale } = useI18n()

const memo = ref('')

// Keyed on the id, not the object: suspending a member or deleting the reported content replaces the
// report object with a refreshed copy of the SAME report, and that must not discard a memo being typed.
watch(
  () => props.report?.id ?? null,
  () => {
    memo.value = props.report?.adminMemo ?? ''
  },
  { immediate: true },
)

const reportedMember = computed(() => props.report?.reportedMember ?? null)
const isMemberTarget = computed(() => props.report?.targetType === 'MEMBER')
const canDeleteTarget = computed(() => !!props.report && !isMemberTarget.value && props.report.targetExists)
const isSuspended = computed(() => reportedMember.value?.status === 'SUSPENDED')

function formatDateTime(value: string | null) {
  if (!value) return t('admin.reports.detail.values.none')
  return new Intl.DateTimeFormat(locale.value, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(new Date(value))
}
</script>

<template>
  <BaseModal
    :is-open="open"
    size="3xl"
    height="default"
    rounded
    z-index="admin"
    @close="emit('close')"
  >
    <div class="modal-header">
      <div class="min-w-0">
        <h2>{{ t('admin.reports.detail.title') }}</h2>
        <p class="mt-1 text-xs sm:text-sm text-dp-text-secondary">{{ t('admin.reports.detail.subtitle') }}</p>
      </div>
      <button
        class="p-2 rounded-full hover-close-btn cursor-pointer text-dp-text-muted"
        :aria-label="t('admin.reports.detail.closeAria')"
        @click="emit('close')"
      >
        <X class="w-5 h-5" />
      </button>
    </div>

    <div class="modal-body p-4 sm:p-5">
      <div v-if="loading" class="flex min-h-48 items-center justify-center">
        <div class="flex items-center gap-3 text-dp-text-secondary">
          <Loader2 class="w-5 h-5 animate-spin" />
          <span>{{ t('admin.reports.detail.loadingMessage') }}</span>
        </div>
      </div>

      <div
        v-else-if="loadError"
        class="rounded-2xl border border-dp-border-primary bg-dp-bg-card p-4 flex min-h-48 flex-col items-center justify-center gap-4 text-center"
      >
        <p class="max-w-md text-sm sm:text-base text-dp-text-secondary">{{ loadError }}</p>
        <button
          class="min-h-11 rounded-lg bg-dp-surface-strong px-4 py-2 text-sm font-medium text-dp-text-on-dark transition hover:bg-dp-surface-strong-hover cursor-pointer"
          @click="emit('retry')"
        >
          {{ t('admin.reports.detail.retry') }}
        </button>
      </div>

      <div v-else-if="report" class="space-y-3">
        <section class="rounded-2xl border border-dp-border-primary bg-dp-bg-card p-4">
          <div class="flex flex-wrap items-center gap-2">
            <span
              class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold"
              :class="reportStatusToneClass(report.status)"
            >{{ t(REPORT_STATUS_LABEL_KEYS[report.status]) }}</span>
            <span class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold bg-dp-accent-soft text-dp-accent">
              {{ t(REPORT_REASON_LABEL_KEYS[report.reason]) }}
            </span>
            <span class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold bg-dp-bg-tertiary text-dp-text-secondary">
              {{ t(REPORT_TARGET_TYPE_LABEL_KEYS[report.targetType]) }}
            </span>
          </div>

          <dl class="mt-3 grid gap-2 sm:grid-cols-2">
            <div class="rounded-xl border border-dp-border-primary px-3 py-2.5">
              <dt class="text-xs font-semibold text-dp-text-muted">{{ t('admin.reports.detail.fields.reportedAt') }}</dt>
              <dd class="mt-1 text-sm font-bold text-dp-text-primary">{{ formatDateTime(report.createdAt) }}</dd>
            </div>
            <div class="rounded-xl border border-dp-border-primary px-3 py-2.5">
              <dt class="text-xs font-semibold text-dp-text-muted">{{ t('admin.reports.detail.fields.targetId') }}</dt>
              <dd class="mt-1 text-sm font-bold break-all text-dp-text-primary">{{ report.targetId }}</dd>
            </div>
            <div class="rounded-xl border border-dp-border-primary px-3 py-2.5">
              <dt class="text-xs font-semibold text-dp-text-muted">{{ t('admin.reports.detail.fields.reporter') }}</dt>
              <dd class="mt-1 text-sm font-bold text-dp-text-primary">
                {{ report.reporterName }}
                <span v-if="!report.reporter" class="ml-1 text-xs font-semibold text-dp-text-muted">
                  {{ t('admin.reports.detail.values.withdrawnMember') }}
                </span>
              </dd>
            </div>
            <div class="rounded-xl border border-dp-border-primary px-3 py-2.5">
              <dt class="text-xs font-semibold text-dp-text-muted">{{ t('admin.reports.detail.fields.reportedMember') }}</dt>
              <dd class="mt-1 flex flex-wrap items-center gap-2 text-sm font-bold text-dp-text-primary">
                <span>{{ report.reportedMemberName }}</span>
                <span
                  v-if="reportedMember"
                  class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold"
                  :class="memberStatusToneClass(reportedMember.status)"
                >{{ t(MEMBER_STATUS_LABEL_KEYS[reportedMember.status]) }}</span>
                <span v-else class="text-xs font-semibold text-dp-text-muted">
                  {{ t('admin.reports.detail.values.withdrawnMember') }}
                </span>
              </dd>
            </div>
          </dl>
        </section>

        <section class="rounded-2xl border border-dp-border-primary bg-dp-bg-card p-4">
          <h3 class="text-base font-semibold text-dp-text-primary">{{ t('admin.reports.detail.fields.detail') }}</h3>
          <p v-if="report.detail" class="mt-2 text-sm whitespace-pre-wrap break-words text-dp-text-primary">{{ report.detail }}</p>
          <p v-else class="mt-2 text-sm text-dp-text-muted">{{ t('admin.reports.detail.values.noDetail') }}</p>
        </section>

        <section class="rounded-2xl border border-dp-border-primary bg-dp-bg-card p-4">
          <h3 class="text-base font-semibold text-dp-text-primary">{{ t('admin.reports.detail.fields.snapshot') }}</h3>
          <p class="mt-2 rounded-xl bg-dp-bg-tertiary p-3 text-sm whitespace-pre-wrap break-words text-dp-text-primary">{{ report.contentSnapshot }}</p>
          <p v-if="isMemberTarget" class="mt-2 text-sm text-dp-text-muted">
            {{ t('admin.reports.detail.memberTargetNotDeletable') }}
          </p>
          <p v-else-if="!report.targetExists" class="mt-2 text-sm text-dp-text-muted">
            {{ t('admin.reports.detail.targetDeleted') }}
          </p>
        </section>

        <section class="rounded-2xl border border-dp-border-primary bg-dp-bg-card p-4">
          <h3 class="text-base font-semibold text-dp-text-primary">{{ t('admin.reports.detail.fields.memo') }}</h3>
          <textarea
            v-model="memo"
            rows="3"
            maxlength="1000"
            class="form-control-neutral mt-2"
            :placeholder="t('admin.reports.detail.memoPlaceholder')"
          ></textarea>
          <dl v-if="report.resolvedAt" class="mt-3 grid gap-2 sm:grid-cols-2">
            <div class="rounded-xl border border-dp-border-primary px-3 py-2.5">
              <dt class="text-xs font-semibold text-dp-text-muted">{{ t('admin.reports.detail.fields.resolvedAt') }}</dt>
              <dd class="mt-1 text-sm font-bold text-dp-text-primary">{{ formatDateTime(report.resolvedAt) }}</dd>
            </div>
            <div class="rounded-xl border border-dp-border-primary px-3 py-2.5">
              <dt class="text-xs font-semibold text-dp-text-muted">{{ t('admin.reports.detail.fields.resolvedBy') }}</dt>
              <dd class="mt-1 text-sm font-bold text-dp-text-primary">{{ report.resolvedByName || t('admin.reports.detail.values.none') }}</dd>
            </div>
          </dl>
        </section>

        <section class="rounded-2xl border border-dp-border-primary bg-dp-bg-card p-4">
          <h3 class="text-base font-semibold text-dp-text-primary">{{ t('admin.reports.detail.actionsTitle') }}</h3>
          <div class="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-3">
            <button
              class="min-h-11 px-4 py-2 text-sm font-medium rounded-lg transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed text-dp-text-on-dark bg-dp-surface-strong hover:bg-dp-surface-strong-hover"
              :disabled="working"
              @click="emit('updateStatus', 'RESOLVED', memo)"
            >
              {{ t('admin.reports.detail.actions.resolve') }}
            </button>
            <button
              class="min-h-11 px-4 py-2 text-sm font-medium rounded-lg transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed bg-dp-bg-tertiary text-dp-text-primary hover-interactive"
              :disabled="working"
              @click="emit('updateStatus', 'DISMISSED', memo)"
            >
              {{ t('admin.reports.detail.actions.dismiss') }}
            </button>
            <button
              v-if="!isMemberTarget"
              class="min-h-11 px-4 py-2 text-sm font-medium rounded-lg transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed bg-dp-danger-soft text-dp-danger hover:bg-dp-danger-soft-hover"
              :disabled="working || !canDeleteTarget"
              @click="emit('deleteTarget')"
            >
              {{ t('admin.reports.detail.actions.deleteTarget') }}
            </button>
            <button
              v-if="reportedMember && !isSuspended"
              class="min-h-11 px-4 py-2 text-sm font-medium rounded-lg transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed bg-dp-danger-soft text-dp-danger hover:bg-dp-danger-soft-hover"
              :disabled="working"
              @click="emit('suspend')"
            >
              {{ t('admin.memberDetail.suspension.suspend') }}
            </button>
            <button
              v-if="reportedMember && isSuspended"
              class="min-h-11 px-4 py-2 text-sm font-medium rounded-lg transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed bg-dp-warning-soft text-dp-warning hover:bg-dp-warning-soft-hover"
              :disabled="working"
              @click="emit('unsuspend')"
            >
              {{ t('admin.memberDetail.suspension.unsuspend') }}
            </button>
            <button
              v-if="reportedMember"
              class="min-h-11 px-4 py-2 text-sm font-medium rounded-lg transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed bg-dp-bg-tertiary text-dp-text-primary hover-interactive"
              :disabled="working"
              @click="emit('goToCalendar')"
            >
              <span class="inline-flex items-center gap-1.5">
                {{ t('admin.reports.detail.actions.viewCalendar') }}
                <ChevronRight class="w-4 h-4" />
              </span>
            </button>
          </div>
          <p v-if="working" class="mt-3 flex items-center gap-2 text-sm text-dp-text-secondary">
            <Loader2 class="w-4 h-4 animate-spin" />
            {{ t('admin.memberDetail.suspension.working') }}
          </p>
        </section>
      </div>
    </div>
  </BaseModal>
</template>
