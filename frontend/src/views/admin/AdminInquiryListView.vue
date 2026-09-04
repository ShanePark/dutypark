<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { adminApi } from '@/api/admin'
import { useSwal } from '@/composables/useSwal'
import { useAdminModerationCounts } from '@/composables/useAdminModerationCounts'
import { resolveApiErrorMessage } from '@/utils/resolveApiError'
import AdminNavTiles from '@/components/admin/AdminNavTiles.vue'
import AdminInquiryDetailModal from '@/components/admin/AdminInquiryDetailModal.vue'
import { INQUIRY_STATUS_LABEL_KEYS, inquiryStatusToneClass } from '@/components/admin/adminModerationLabels'
import { buildInquiryUpdateRequest } from './inquiryUpdateRequest'
import { createLatestRequestTracker, lastValidPage } from './moderationListState'
import type { AdminInquiryDto, InquiryStatus, InquiryStatusFilter } from '@/types/adminModeration'
import { ChevronLeft, ChevronRight, Loader2 } from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const { t, locale } = useI18n()
const { showError, toastSuccess } = useSwal()
const { loadInquiries } = useAdminModerationCounts()

const STATUS_FILTERS: { value: InquiryStatusFilter; labelKey: string }[] = [
  { value: 'OPEN', labelKey: 'admin.inquiries.filters.open' },
  { value: 'CLOSED', labelKey: 'admin.inquiries.filters.closed' },
  { value: 'ALL', labelKey: 'admin.inquiries.filters.all' },
]

const statusFilter = ref<InquiryStatusFilter>('OPEN')
const inquiries = ref<AdminInquiryDto[]>([])
const page = ref(0)
const pageSize = 10
const totalElements = ref(0)
const totalPages = ref(0)
const isLoading = ref(false)

const showDetailModal = ref(false)
const selectedInquiryId = ref<string | null>(null)
const selectedInquiry = ref<AdminInquiryDto | null>(null)
const isDetailLoading = ref(false)
const detailError = ref<string | null>(null)
const isWorking = ref(false)
let detailRequestId = 0
const inquiryRequestTracker = createLatestRequestTracker()

async function fetchInquiries() {
  const requestId = inquiryRequestTracker.start()
  const requestedStatus = statusFilter.value
  const requestedPage = page.value
  isLoading.value = true
  try {
    const res = await adminApi.getInquiries(requestedStatus, requestedPage, pageSize)
    if (!inquiryRequestTracker.isLatest(requestId)) return

    const validPage = lastValidPage(requestedPage, res.data.totalPages)
    if (validPage !== requestedPage) {
      page.value = validPage
      await fetchInquiries()
      return
    }

    inquiries.value = res.data.content
    totalElements.value = res.data.totalElements
    totalPages.value = res.data.totalPages
  } catch (error) {
    if (!inquiryRequestTracker.isLatest(requestId)) return
    console.error('Failed to fetch inquiries:', error)
    showError(t('admin.inquiries.messages.loadFailed'))
  } finally {
    if (inquiryRequestTracker.isLatest(requestId)) {
      isLoading.value = false
    }
  }
}

function selectStatusFilter(value: InquiryStatusFilter) {
  if (statusFilter.value === value) return
  statusFilter.value = value
  page.value = 0
  fetchInquiries()
}

function goToPage(target: number) {
  if (target >= 0 && target < totalPages.value) {
    page.value = target
    fetchInquiries()
  }
}

async function fetchSelectedInquiry(inquiryId: string | null = selectedInquiryId.value) {
  if (!inquiryId) return

  const requestId = ++detailRequestId
  isDetailLoading.value = true
  detailError.value = null

  try {
    const res = await adminApi.getInquiry(inquiryId)
    if (requestId !== detailRequestId) return
    selectedInquiry.value = res.data
  } catch (error) {
    console.error('Failed to fetch inquiry detail:', error)
    if (requestId !== detailRequestId) return
    selectedInquiry.value = null
    detailError.value = t('admin.inquiries.messages.loadDetailFailed')
  } finally {
    if (requestId === detailRequestId) {
      isDetailLoading.value = false
    }
  }
}

function openInquiryDetail(inquiry: AdminInquiryDto) {
  selectedInquiryId.value = inquiry.id
  selectedInquiry.value = null
  detailError.value = null
  showDetailModal.value = true
  fetchSelectedInquiry(inquiry.id)
}

function closeInquiryDetail() {
  showDetailModal.value = false
  selectedInquiryId.value = null
  selectedInquiry.value = null
  detailError.value = null
  detailRequestId += 1
  isDetailLoading.value = false
}

async function handleUpdateStatus(status: InquiryStatus, memo: string, answer: string) {
  if (!selectedInquiryId.value || !selectedInquiry.value) return

  const statusChanged = status !== selectedInquiry.value.status
  isWorking.value = true
  try {
    const request = buildInquiryUpdateRequest(status, memo, answer, selectedInquiry.value.answer)
    const res = await adminApi.updateInquiryStatus(selectedInquiryId.value, request)
    selectedInquiry.value = res.data
    if (statusChanged) await loadInquiries(true)
    toastSuccess(t(statusChanged
      ? 'admin.inquiries.messages.updateStatusSuccess'
      : 'admin.inquiries.messages.saveSuccess'))
    await fetchInquiries()
  } catch (error) {
    console.error('Failed to update inquiry status:', error)
    showError(resolveApiErrorMessage(error, {
      fallbackKey: statusChanged
        ? 'admin.inquiries.messages.updateStatusFailed'
        : 'admin.inquiries.messages.saveFailed',
    }, t))
  } finally {
    isWorking.value = false
  }
}

async function handleCopyEmail(email: string) {
  try {
    await navigator.clipboard.writeText(email)
    toastSuccess(t('admin.inquiries.messages.copyEmailSuccess'))
  } catch (error) {
    console.error('Failed to copy inquiry email:', error)
    showError(t('admin.inquiries.messages.copyEmailFailed'))
  }
}

async function handleGoToCalendar(memberId: number) {
  closeInquiryDetail()
  await router.push({ name: 'duty', params: { id: String(memberId) } })
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat(locale.value, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(new Date(value))
}

function setHoverBg(e: Event) {
  if (e.currentTarget) {
    (e.currentTarget as HTMLElement).style.backgroundColor = 'var(--dp-bg-hover)'
  }
}

function clearHoverBg(e: Event, bgColor = 'transparent') {
  if (e.currentTarget) {
    (e.currentTarget as HTMLElement).style.backgroundColor = bgColor
  }
}

onMounted(() => {
  if (!authStore.isAdmin) {
    router.replace('/')
    return
  }
  fetchInquiries()
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <AdminNavTiles active="inquiries" />

    <div class="rounded-xl bg-dp-bg-card border border-dp-border-primary">
      <div class="p-4 border-b border-dp-border-primary">
        <div class="flex flex-col gap-3">
          <div>
            <h2 class="text-lg font-semibold text-dp-text-primary">{{ t('admin.inquiries.title') }}</h2>
            <p class="text-sm text-dp-text-secondary">{{ t('admin.inquiries.totalInquiries', { count: totalElements }) }}</p>
          </div>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="option in STATUS_FILTERS"
              :key="option.value"
              class="px-3 py-1.5 text-sm font-medium rounded-lg transition cursor-pointer"
              :class="statusFilter === option.value
                ? 'bg-dp-surface-strong text-dp-text-on-dark'
                : 'bg-dp-bg-tertiary text-dp-text-secondary hover-interactive'"
              :aria-pressed="statusFilter === option.value"
              @click="selectStatusFilter(option.value)"
            >
              {{ t(option.labelKey) }}
            </button>
          </div>
        </div>
      </div>

      <div class="border-t border-dp-border-secondary">
        <div v-if="isLoading" class="flex items-center justify-center py-12">
          <Loader2 class="w-6 h-6 animate-spin text-dp-text-muted" />
        </div>

        <template v-else>
          <div
            v-for="inquiry in inquiries"
            :key="inquiry.id"
            class="p-4 cursor-pointer transition border-b border-dp-border-secondary focus-visible:outline-none"
            role="button"
            tabindex="0"
            @click="openInquiryDetail(inquiry)"
            @keydown.enter.prevent="openInquiryDetail(inquiry)"
            @keydown.space.prevent="openInquiryDetail(inquiry)"
            @mouseover="(e: Event) => setHoverBg(e)"
            @mouseleave="(e: Event) => clearHoverBg(e)"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <div class="flex flex-wrap items-center gap-1.5">
                  <span
                    class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold"
                    :class="inquiryStatusToneClass(inquiry.status)"
                  >{{ t(INQUIRY_STATUS_LABEL_KEYS[inquiry.status]) }}</span>
                  <span
                    v-if="!inquiry.memberId"
                    class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold bg-dp-bg-tertiary text-dp-text-secondary"
                  >{{ t('admin.inquiries.row.guest') }}</span>
                </div>
                <p class="mt-2 font-medium truncate text-dp-text-primary">
                  {{ inquiry.subject || t('admin.inquiries.row.noSubject') }}
                </p>
                <p class="text-sm truncate text-dp-text-secondary">{{ inquiry.content }}</p>
                <p class="mt-1 text-xs truncate text-dp-text-muted">
                  {{ inquiry.memberName || inquiry.email }}
                </p>
              </div>
              <div class="flex flex-col items-end gap-1 flex-shrink-0 text-dp-text-muted">
                <span class="text-xs whitespace-nowrap">{{ formatDate(inquiry.createdAt) }}</span>
                <ChevronRight class="w-4 h-4" />
              </div>
            </div>
          </div>

          <div v-if="inquiries.length === 0" class="p-8 text-center text-dp-text-muted">
            {{ t('admin.inquiries.empty') }}
          </div>
        </template>
      </div>

      <div v-if="totalPages > 1" class="p-4 flex items-center justify-between border-t border-dp-border-primary">
        <p class="text-sm text-dp-text-secondary">
          {{ t('admin.inquiries.pagination', {
            total: totalElements,
            start: page * pageSize + 1,
            end: Math.min((page + 1) * pageSize, totalElements),
          }) }}
        </p>
        <div class="flex items-center gap-2">
          <button
            :disabled="page === 0"
            class="p-2 rounded-lg transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed bg-dp-bg-tertiary"
            @click="goToPage(page - 1)"
          >
            <ChevronLeft class="w-4 h-4 text-dp-text-secondary" />
          </button>
          <span class="text-sm px-2 text-dp-text-primary">{{ page + 1 }} / {{ totalPages }}</span>
          <button
            :disabled="page >= totalPages - 1"
            class="p-2 rounded-lg transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed bg-dp-bg-tertiary"
            @click="goToPage(page + 1)"
          >
            <ChevronRight class="w-4 h-4 text-dp-text-secondary" />
          </button>
        </div>
      </div>
    </div>

    <AdminInquiryDetailModal
      :open="showDetailModal"
      :inquiry="selectedInquiry"
      :loading="isDetailLoading"
      :load-error="detailError"
      :working="isWorking"
      @close="closeInquiryDetail"
      @retry="fetchSelectedInquiry()"
      @update-status="handleUpdateStatus"
      @copy-email="handleCopyEmail"
      @go-to-calendar="handleGoToCalendar"
    />
  </div>
</template>
