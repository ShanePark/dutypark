<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { AlertTriangle, Check, Loader2, RefreshCw } from 'lucide-vue-next'
import { accountDeletionApi, type AccountDeletionStatus, type AccountDeletionStatusResponse } from '@/api/accountDeletion'
import {
  clearAccountDeletionReceipt,
  hasStoredAccountDeletionReceiptEntry,
  isAccountDeletionReceiptWithinProvisionalGrace,
  readAccountDeletionReceipt,
  type AccountDeletionReceipt,
} from '@/utils/accountDeletionReceipt'

const STATUS_POLL_INTERVAL_MS = 5_000

type StatusViewState = 'loading' | 'processing' | 'completed' | 'failed' | 'unavailable' | 'empty'

const { t, locale } = useI18n()
const router = useRouter()
const receipt = ref<AccountDeletionReceipt | null>(null)
const storedReceiptNeedsReset = ref(false)
const response = ref<AccountDeletionStatusResponse | null>(null)
const viewState = ref<StatusViewState>('loading')
const requestFailed = ref(false)
const checking = ref(false)
let pollTimer: number | null = null
let polling = false

const status = computed<AccountDeletionStatus | null>(() => response.value?.status ?? null)
const isTerminal = computed(() => ['COMPLETED', 'FAILED'].includes(status.value ?? '') || viewState.value === 'unavailable')
const estimatedCompletionAt = computed(() => response.value?.estimatedCompletionAt || receipt.value?.estimatedCompletionAt || '')
const formattedEstimatedCompletionAt = computed(() => formatDateTime(estimatedCompletionAt.value))

function formatDateTime(value: string): string {
  if (!value) return ''
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return ''
  return new Intl.DateTimeFormat(locale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date)
}

function stopPolling() {
  polling = false
  if (pollTimer !== null) {
    window.clearTimeout(pollTimer)
    pollTimer = null
  }
}

function schedulePoll() {
  if (!polling || isTerminal.value || pollTimer !== null) return
  pollTimer = window.setTimeout(() => {
    pollTimer = null
    void refreshStatus()
  }, STATUS_POLL_INTERVAL_MS)
}

function isNotFound(error: unknown): boolean {
  return (error as { response?: { status?: number } }).response?.status === 404
}

function isProvisionalReceiptWithinGrace(): boolean {
  return receipt.value !== null
    && isAccountDeletionReceiptWithinProvisionalGrace(receipt.value)
}

function isValidStatusResponse(value: unknown): value is AccountDeletionStatusResponse {
  if (!value || typeof value !== 'object') return false
  const candidate = value as Record<string, unknown>
  return (candidate.status === 'PROCESSING'
    || candidate.status === 'COMPLETED'
    || candidate.status === 'FAILED')
    && typeof candidate.estimatedCompletionAt === 'string'
}

async function refreshStatus() {
  if (!receipt.value || checking.value) return
  checking.value = true
  requestFailed.value = false
  try {
    const result = await accountDeletionApi.getStatus(receipt.value.receiptToken)
    if (!isValidStatusResponse(result.data)) throw new Error('Invalid account deletion status response')
    response.value = result.data
    if (result.data.status === 'PROCESSING') {
      viewState.value = 'processing'
      schedulePoll()
    } else {
      viewState.value = result.data.status === 'COMPLETED' ? 'completed' : 'failed'
      stopPolling()
    }
  } catch (error) {
    if (isNotFound(error)) {
      if (isProvisionalReceiptWithinGrace()) {
        // A provisional receipt can legitimately race the server's first commit.
        // Keep the page quiet while polling through the advertised ETA.
        requestFailed.value = false
        viewState.value = 'processing'
        schedulePoll()
      } else {
        response.value = null
        viewState.value = 'unavailable'
        stopPolling()
      }
    } else {
      requestFailed.value = true
      viewState.value = 'processing'
      schedulePoll()
    }
  } finally {
    checking.value = false
  }
}

function startPolling() {
  polling = true
  void refreshStatus()
}

function resetStoredReceipt() {
  if (viewState.value !== 'empty' || !storedReceiptNeedsReset.value) return
  stopPolling()
  clearAccountDeletionReceipt()
  storedReceiptNeedsReset.value = false
  void router.replace('/')
}

async function dismissTerminalResult() {
  if (!isTerminal.value) return
  stopPolling()
  clearAccountDeletionReceipt()
  receipt.value = null
  response.value = null
  storedReceiptNeedsReset.value = false
  viewState.value = 'empty'
  await router.replace('/')
}

onMounted(() => {
  receipt.value = readAccountDeletionReceipt()
  if (!receipt.value) {
    storedReceiptNeedsReset.value = hasStoredAccountDeletionReceiptEntry()
    viewState.value = 'empty'
    return
  }
  viewState.value = 'processing'
  startPolling()
})

onUnmounted(stopPolling)
</script>

<template>
  <main class="flex min-h-screen items-center justify-center bg-dp-bg-secondary px-4 py-8">
    <section
      class="w-full max-w-lg rounded-2xl border border-dp-border-primary bg-dp-bg-card p-6 text-center shadow-sm sm:p-8"
      aria-live="polite"
    >
      <div
        v-if="viewState === 'completed'"
        class="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-dp-success-soft text-dp-success"
      >
        <Check class="h-7 w-7" aria-hidden="true" />
      </div>
      <div
        v-else-if="viewState === 'failed' || viewState === 'unavailable' || viewState === 'empty'"
        class="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-dp-warning/15 text-dp-warning"
      >
        <AlertTriangle class="h-7 w-7" aria-hidden="true" />
      </div>
      <div v-else class="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-dp-accent-soft text-dp-accent">
        <Loader2 class="h-7 w-7" :class="checking ? 'animate-spin' : ''" aria-hidden="true" />
      </div>

      <h1 class="mt-4 text-xl font-bold text-dp-text-primary">
        <template v-if="viewState === 'completed'">{{ t('member.accountDeletion.status.completedTitle') }}</template>
        <template v-else-if="viewState === 'failed'">{{ t('member.accountDeletion.status.failedTitle') }}</template>
        <template v-else-if="viewState === 'unavailable'">{{ t('member.accountDeletion.status.unavailable') }}</template>
        <template v-else-if="viewState === 'empty'">{{ t('member.accountDeletion.status.noReceiptTitle') }}</template>
        <template v-else>{{ t('member.accountDeletion.status.processingTitle') }}</template>
      </h1>

      <p v-if="viewState === 'completed'" class="mt-3 text-sm leading-6 text-dp-text-secondary">
        {{ t('member.accountDeletion.status.completedMessage') }}
      </p>
      <p v-else-if="viewState === 'failed'" class="mt-3 text-sm leading-6 text-dp-text-secondary">
        {{ t('member.accountDeletion.status.failedMessage') }}
      </p>
      <p v-else-if="viewState === 'unavailable'" class="mt-3 text-sm leading-6 text-dp-text-secondary">
        {{ t('member.accountDeletion.status.unavailableMessage') }}
      </p>
      <p v-else-if="viewState === 'empty'" class="mt-3 text-sm leading-6 text-dp-text-secondary">
        {{ t(storedReceiptNeedsReset
          ? 'member.accountDeletion.status.storedReceiptInvalidMessage'
          : 'member.accountDeletion.status.noReceiptMessage') }}
      </p>
      <p v-else class="mt-3 text-sm leading-6 text-dp-text-secondary">
        {{ t('member.accountDeletion.status.processingMessage') }}
      </p>

      <p
        v-if="viewState === 'processing' && formattedEstimatedCompletionAt"
        class="mt-3 text-sm font-medium text-dp-text-primary"
      >
        {{ t('member.accountDeletion.status.estimatedAt', { time: formattedEstimatedCompletionAt }) }}
      </p>
      <p v-if="viewState === 'processing'" class="mt-2 text-xs leading-5 text-dp-text-muted">
        {{ t('member.accountDeletion.status.signedOut') }}
      </p>
      <p v-if="requestFailed" class="mt-3 text-sm text-dp-warning" role="status">
        {{ t('member.accountDeletion.status.retryMessage') }}
      </p>

      <div class="mt-5 rounded-xl border border-dp-border-primary bg-dp-bg-secondary p-4 text-left">
        <p class="text-sm leading-6 text-dp-text-secondary">
          {{ t('member.accountDeletion.retentionNotice') }}
        </p>
        <RouterLink
          to="/privacy"
          class="mt-2 inline-flex text-sm font-semibold text-dp-accent hover:underline"
        >
          {{ t('policy.privacy.title') }}
        </RouterLink>
      </div>

      <div v-if="viewState === 'processing'" class="mt-6 flex flex-col gap-3">
        <button
          type="button"
          class="inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-lg bg-dp-accent px-4 font-medium text-dp-text-on-dark transition hover:bg-dp-accent-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring disabled:cursor-not-allowed disabled:opacity-60"
          :disabled="checking"
          @click="refreshStatus"
        >
          <RefreshCw class="h-4 w-4" :class="checking ? 'animate-spin' : ''" aria-hidden="true" />
          {{ checking ? t('member.accountDeletion.status.checking') : t('member.accountDeletion.status.refresh') }}
        </button>
      </div>
      <div v-else-if="viewState === 'failed' || viewState === 'unavailable' || viewState === 'empty'" class="mt-6 flex flex-col gap-3">
        <RouterLink
          to="/support"
          class="inline-flex min-h-11 w-full items-center justify-center rounded-lg bg-dp-accent-soft px-4 font-medium text-dp-accent transition hover:bg-dp-accent-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
        >
          {{ t('member.accountDeletion.status.support') }}
        </RouterLink>
        <button
          v-if="viewState === 'empty' && storedReceiptNeedsReset"
          type="button"
          class="inline-flex min-h-11 w-full items-center justify-center rounded-lg bg-dp-accent px-4 font-medium text-dp-text-on-dark transition hover:bg-dp-accent-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
          @click="resetStoredReceipt"
        >
          {{ t('member.accountDeletion.status.resetStoredReceipt') }}
        </button>
        <button
          v-if="isTerminal"
          type="button"
          class="min-h-11 w-full rounded-lg bg-dp-accent px-4 font-medium text-dp-text-on-dark transition hover:bg-dp-accent-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
          @click="dismissTerminalResult"
        >
          {{ t('member.accountDeletion.status.dismiss') }}
        </button>
      </div>
      <button
        v-else-if="viewState === 'completed'"
        type="button"
        class="mt-6 min-h-11 w-full rounded-lg bg-dp-accent px-4 font-medium text-dp-text-on-dark transition hover:bg-dp-accent-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
        @click="dismissTerminalResult"
      >
        {{ t('member.accountDeletion.status.dismiss') }}
      </button>
    </section>
  </main>
</template>
