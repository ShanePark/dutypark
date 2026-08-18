<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import BaseModal from '@/components/common/BaseModal.vue'
import type { AdminInquiryDto, InquiryStatus } from '@/types/adminModeration'
import { INQUIRY_STATUS_LABEL_KEYS, inquiryStatusToneClass } from './adminModerationLabels'
import { ChevronRight, Copy, Loader2, X } from 'lucide-vue-next'

const props = defineProps<{
  open: boolean
  inquiry: AdminInquiryDto | null
  loading: boolean
  loadError: string | null
  working: boolean
}>()

const emit = defineEmits<{
  close: []
  retry: []
  updateStatus: [status: InquiryStatus, memo: string]
  copyEmail: [email: string]
  goToCalendar: [memberId: number]
}>()

const { t, locale } = useI18n()

const memo = ref('')

watch(
  () => props.inquiry,
  (inquiry) => {
    memo.value = inquiry?.adminMemo ?? ''
  },
  { immediate: true },
)

const isClosed = computed(() => props.inquiry?.status === 'CLOSED')
const mailtoHref = computed(() => {
  if (!props.inquiry) return '#'
  const subject = props.inquiry.subject ?? ''
  return `mailto:${props.inquiry.email}?subject=${encodeURIComponent(subject)}`
})

function formatDateTime(value: string | null) {
  if (!value) return t('admin.inquiries.detail.values.none')
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
        <h2>{{ t('admin.inquiries.detail.title') }}</h2>
        <p class="mt-1 text-xs sm:text-sm text-dp-text-secondary">{{ t('admin.inquiries.detail.subtitle') }}</p>
      </div>
      <button
        class="p-2 rounded-full hover-close-btn cursor-pointer text-dp-text-muted"
        :aria-label="t('admin.inquiries.detail.closeAria')"
        @click="emit('close')"
      >
        <X class="w-5 h-5" />
      </button>
    </div>

    <div class="modal-body p-4 sm:p-5">
      <div v-if="loading" class="flex min-h-48 items-center justify-center">
        <div class="flex items-center gap-3 text-dp-text-secondary">
          <Loader2 class="w-5 h-5 animate-spin" />
          <span>{{ t('admin.inquiries.detail.loadingMessage') }}</span>
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
          {{ t('admin.inquiries.detail.retry') }}
        </button>
      </div>

      <div v-else-if="inquiry" class="space-y-3">
        <section class="rounded-2xl border border-dp-border-primary bg-dp-bg-card p-4">
          <div class="flex flex-wrap items-center gap-2">
            <span
              class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold"
              :class="inquiryStatusToneClass(inquiry.status)"
            >{{ t(INQUIRY_STATUS_LABEL_KEYS[inquiry.status]) }}</span>
            <h3 class="min-w-0 text-base font-semibold break-words text-dp-text-primary">
              {{ inquiry.subject || t('admin.inquiries.detail.values.noSubject') }}
            </h3>
          </div>

          <dl class="mt-3 grid gap-2 sm:grid-cols-2">
            <div class="rounded-xl border border-dp-border-primary px-3 py-2.5">
              <dt class="text-xs font-semibold text-dp-text-muted">{{ t('admin.inquiries.detail.fields.email') }}</dt>
              <dd class="mt-1 flex flex-wrap items-center gap-2">
                <span class="text-sm font-bold break-all text-dp-text-primary">{{ inquiry.email }}</span>
                <button
                  class="inline-flex items-center gap-1 rounded-lg px-2 py-1 text-xs font-medium transition cursor-pointer bg-dp-bg-tertiary text-dp-text-primary hover-interactive"
                  @click="emit('copyEmail', inquiry.email)"
                >
                  <Copy class="w-3.5 h-3.5" />
                  {{ t('admin.inquiries.detail.actions.copyEmail') }}
                </button>
              </dd>
            </div>
            <div class="rounded-xl border border-dp-border-primary px-3 py-2.5">
              <dt class="text-xs font-semibold text-dp-text-muted">{{ t('admin.inquiries.detail.fields.member') }}</dt>
              <dd class="mt-1 flex flex-wrap items-center gap-2 text-sm font-bold text-dp-text-primary">
                <template v-if="inquiry.memberId">
                  <span>{{ inquiry.memberName || t('admin.inquiries.detail.values.none') }}</span>
                  <button
                    class="inline-flex items-center gap-1 rounded-lg px-2 py-1 text-xs font-medium transition cursor-pointer bg-dp-bg-tertiary text-dp-text-primary hover-interactive"
                    @click="emit('goToCalendar', inquiry.memberId)"
                  >
                    {{ t('admin.inquiries.detail.actions.viewCalendar') }}
                    <ChevronRight class="w-3.5 h-3.5" />
                  </button>
                </template>
                <span v-else class="text-dp-text-secondary">{{ t('admin.inquiries.detail.values.guest') }}</span>
              </dd>
            </div>
            <div class="rounded-xl border border-dp-border-primary px-3 py-2.5">
              <dt class="text-xs font-semibold text-dp-text-muted">{{ t('admin.inquiries.detail.fields.createdAt') }}</dt>
              <dd class="mt-1 text-sm font-bold text-dp-text-primary">{{ formatDateTime(inquiry.createdAt) }}</dd>
            </div>
            <div class="rounded-xl border border-dp-border-primary px-3 py-2.5">
              <dt class="text-xs font-semibold text-dp-text-muted">{{ t('admin.inquiries.detail.fields.closedAt') }}</dt>
              <dd class="mt-1 text-sm font-bold text-dp-text-primary">{{ formatDateTime(inquiry.closedAt) }}</dd>
            </div>
          </dl>
        </section>

        <section class="rounded-2xl border border-dp-border-primary bg-dp-bg-card p-4">
          <h3 class="text-base font-semibold text-dp-text-primary">{{ t('admin.inquiries.detail.fields.content') }}</h3>
          <p class="mt-2 rounded-xl bg-dp-bg-tertiary p-3 text-sm whitespace-pre-wrap break-words text-dp-text-primary">{{ inquiry.content }}</p>
          <p class="mt-2 text-sm text-dp-text-muted">{{ t('admin.inquiries.detail.replyHint') }}</p>
        </section>

        <section class="rounded-2xl border border-dp-border-primary bg-dp-bg-card p-4">
          <h3 class="text-base font-semibold text-dp-text-primary">{{ t('admin.inquiries.detail.fields.memo') }}</h3>
          <textarea
            v-model="memo"
            rows="3"
            maxlength="1000"
            class="form-control-neutral mt-2"
            :placeholder="t('admin.inquiries.detail.memoPlaceholder')"
          ></textarea>
        </section>

        <section class="rounded-2xl border border-dp-border-primary bg-dp-bg-card p-4">
          <h3 class="text-base font-semibold text-dp-text-primary">{{ t('admin.inquiries.detail.actionsTitle') }}</h3>
          <div class="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-3">
            <a
              :href="mailtoHref"
              class="min-h-11 px-4 py-2 text-sm font-medium rounded-lg transition cursor-pointer inline-flex items-center justify-center bg-dp-bg-tertiary text-dp-text-primary hover-interactive"
            >
              {{ t('admin.inquiries.detail.actions.replyByEmail') }}
            </a>
            <button
              v-if="!isClosed"
              class="min-h-11 px-4 py-2 text-sm font-medium rounded-lg transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed text-dp-text-on-dark bg-dp-surface-strong hover:bg-dp-surface-strong-hover"
              :disabled="working"
              @click="emit('updateStatus', 'CLOSED', memo)"
            >
              {{ t('admin.inquiries.detail.actions.markClosed') }}
            </button>
            <button
              v-else
              class="min-h-11 px-4 py-2 text-sm font-medium rounded-lg transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed bg-dp-warning-soft text-dp-warning hover:bg-dp-warning-soft-hover"
              :disabled="working"
              @click="emit('updateStatus', 'OPEN', memo)"
            >
              {{ t('admin.inquiries.detail.actions.reopen') }}
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
