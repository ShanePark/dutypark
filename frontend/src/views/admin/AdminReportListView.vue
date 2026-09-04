<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { adminApi } from '@/api/admin'
import { useSwal } from '@/composables/useSwal'
import { useAdminModerationCounts } from '@/composables/useAdminModerationCounts'
import { resolveApiErrorMessage } from '@/utils/resolveApiError'
import AdminNavTiles from '@/components/admin/AdminNavTiles.vue'
import AdminReportDetailModal from '@/components/admin/AdminReportDetailModal.vue'
import { createLatestRequestTracker, lastValidPage } from './moderationListState'
import {
  MEMBER_STATUS_LABEL_KEYS,
  REPORT_REASON_LABEL_KEYS,
  REPORT_STATUS_LABEL_KEYS,
  REPORT_TARGET_TYPE_LABEL_KEYS,
  memberStatusToneClass,
  reportStatusToneClass,
} from '@/components/admin/adminModerationLabels'
import type {
  AdminReportDetailDto,
  AdminReportSummaryDto,
  ReportResolutionStatus,
  ReportStatusFilter,
} from '@/types/adminModeration'
import { ChevronLeft, ChevronRight, Loader2 } from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const { t, locale } = useI18n()
const { confirm, confirmDelete, showError, toastSuccess } = useSwal()
const { loadReports } = useAdminModerationCounts()

const STATUS_FILTERS: { value: ReportStatusFilter; labelKey: string }[] = [
  { value: 'OPEN', labelKey: 'admin.reports.filters.open' },
  { value: 'RESOLVED', labelKey: 'admin.reports.filters.resolved' },
  { value: 'DISMISSED', labelKey: 'admin.reports.filters.dismissed' },
  { value: 'CANCELED', labelKey: 'admin.reports.filters.canceled' },
  { value: 'ALL', labelKey: 'admin.reports.filters.all' },
]

const statusFilter = ref<ReportStatusFilter>('OPEN')
const reports = ref<AdminReportSummaryDto[]>([])
const page = ref(0)
const pageSize = 10
const totalElements = ref(0)
const totalPages = ref(0)
const isLoading = ref(false)

const showDetailModal = ref(false)
const selectedReportId = ref<string | null>(null)
const selectedReport = ref<AdminReportDetailDto | null>(null)
const isDetailLoading = ref(false)
const detailError = ref<string | null>(null)
const isWorking = ref(false)
let detailRequestId = 0
const reportRequestTracker = createLatestRequestTracker()

const reportedMemberId = computed(() => selectedReport.value?.reportedMember?.id ?? null)

async function fetchReports() {
  const requestId = reportRequestTracker.start()
  const requestedStatus = statusFilter.value
  const requestedPage = page.value
  isLoading.value = true
  try {
    const res = await adminApi.getReports(requestedStatus, requestedPage, pageSize)
    if (!reportRequestTracker.isLatest(requestId)) return

    const validPage = lastValidPage(requestedPage, res.data.totalPages)
    if (validPage !== requestedPage) {
      page.value = validPage
      await fetchReports()
      return
    }

    reports.value = res.data.content
    totalElements.value = res.data.totalElements
    totalPages.value = res.data.totalPages
  } catch (error) {
    if (!reportRequestTracker.isLatest(requestId)) return
    console.error('Failed to fetch reports:', error)
    showError(t('admin.reports.messages.loadFailed'))
  } finally {
    if (reportRequestTracker.isLatest(requestId)) {
      isLoading.value = false
    }
  }
}

function selectStatusFilter(value: ReportStatusFilter) {
  if (statusFilter.value === value) return
  statusFilter.value = value
  page.value = 0
  fetchReports()
}

function goToPage(target: number) {
  if (target >= 0 && target < totalPages.value) {
    page.value = target
    fetchReports()
  }
}

async function fetchSelectedReport(reportId: string | null = selectedReportId.value) {
  if (!reportId) return

  const requestId = ++detailRequestId
  isDetailLoading.value = true
  detailError.value = null

  try {
    const res = await adminApi.getReport(reportId)
    if (requestId !== detailRequestId) return
    selectedReport.value = res.data
  } catch (error) {
    console.error('Failed to fetch report detail:', error)
    if (requestId !== detailRequestId) return
    selectedReport.value = null
    detailError.value = t('admin.reports.messages.loadDetailFailed')
  } finally {
    if (requestId === detailRequestId) {
      isDetailLoading.value = false
    }
  }
}

function openReportDetail(report: AdminReportSummaryDto) {
  selectedReportId.value = report.id
  selectedReport.value = null
  detailError.value = null
  showDetailModal.value = true
  fetchSelectedReport(report.id)
}

function closeReportDetail() {
  showDetailModal.value = false
  selectedReportId.value = null
  selectedReport.value = null
  detailError.value = null
  detailRequestId += 1
  isDetailLoading.value = false
}

async function handleUpdateStatus(status: ReportResolutionStatus, memo: string) {
  if (!selectedReportId.value) return

  isWorking.value = true
  try {
    // Always send the box contents: an emptied box must clear the stored memo, not be treated as "keep".
    const res = await adminApi.updateReportStatus(selectedReportId.value, {
      status,
      memo: memo.trim(),
    })
    selectedReport.value = res.data
    await loadReports(true)
    toastSuccess(t('admin.reports.messages.updateStatusSuccess'))
    await fetchReports()
  } catch (error) {
    console.error('Failed to update report status:', error)
    showError(resolveApiErrorMessage(error, { fallbackKey: 'admin.reports.messages.updateStatusFailed' }, t))
  } finally {
    isWorking.value = false
  }
}

async function handleDeleteTarget() {
  const report = selectedReport.value
  if (!report || !selectedReportId.value) return

  if (!await confirmDelete(t('admin.reports.messages.deleteTargetConfirm', { name: report.reportedMemberName }))) return

  isWorking.value = true
  try {
    const res = await adminApi.deleteReportTarget(selectedReportId.value)
    selectedReport.value = res.data
    toastSuccess(t('admin.reports.messages.deleteTargetSuccess'))
    await fetchReports()
  } catch (error) {
    console.error('Failed to delete report target:', error)
    showError(resolveApiErrorMessage(error, { fallbackKey: 'admin.reports.messages.deleteTargetFailed' }, t))
  } finally {
    isWorking.value = false
  }
}

async function handleSuspend() {
  const report = selectedReport.value
  const memberId = reportedMemberId.value
  if (!report || memberId == null) return

  if (!await confirm(
    t('admin.memberDetail.suspension.suspendConfirm', { name: report.reportedMemberName }),
    t('admin.memberDetail.suspension.suspendConfirmTitle'),
  )) return

  isWorking.value = true
  try {
    await adminApi.suspendMember(memberId)
    toastSuccess(t('admin.memberDetail.suspension.suspendSuccess', { name: report.reportedMemberName }))
    await fetchSelectedReport()
    await fetchReports()
  } catch (error) {
    console.error('Failed to suspend member:', error)
    showError(resolveApiErrorMessage(error, { fallbackKey: 'admin.memberDetail.suspension.suspendFailed' }, t))
  } finally {
    isWorking.value = false
  }
}

async function handleUnsuspend() {
  const report = selectedReport.value
  const memberId = reportedMemberId.value
  if (!report || memberId == null) return

  if (!await confirm(
    t('admin.memberDetail.suspension.unsuspendConfirm', { name: report.reportedMemberName }),
    t('admin.memberDetail.suspension.unsuspendConfirmTitle'),
  )) return

  isWorking.value = true
  try {
    await adminApi.unsuspendMember(memberId)
    toastSuccess(t('admin.memberDetail.suspension.unsuspendSuccess', { name: report.reportedMemberName }))
    await fetchSelectedReport()
    await fetchReports()
  } catch (error) {
    console.error('Failed to lift member suspension:', error)
    showError(resolveApiErrorMessage(error, { fallbackKey: 'admin.memberDetail.suspension.unsuspendFailed' }, t))
  } finally {
    isWorking.value = false
  }
}

async function handleGoToCalendar() {
  const memberId = reportedMemberId.value
  if (memberId == null) return
  closeReportDetail()
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
  fetchReports()
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <AdminNavTiles active="reports" />

    <div class="rounded-xl bg-dp-bg-card border border-dp-border-primary">
      <div class="p-4 border-b border-dp-border-primary">
        <div class="flex flex-col gap-3">
          <div>
            <h2 class="text-lg font-semibold text-dp-text-primary">{{ t('admin.reports.title') }}</h2>
            <p class="text-sm text-dp-text-secondary">{{ t('admin.reports.totalReports', { count: totalElements }) }}</p>
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
            v-for="report in reports"
            :key="report.id"
            class="p-4 cursor-pointer transition border-b border-dp-border-secondary focus-visible:outline-none"
            role="button"
            tabindex="0"
            @click="openReportDetail(report)"
            @keydown.enter.prevent="openReportDetail(report)"
            @keydown.space.prevent="openReportDetail(report)"
            @mouseover="(e: Event) => setHoverBg(e)"
            @mouseleave="(e: Event) => clearHoverBg(e)"
          >
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <div class="flex flex-wrap items-center gap-1.5">
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
                  <span
                    v-if="report.reportedMember && report.reportedMember.status !== 'ACTIVE'"
                    class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold"
                    :class="memberStatusToneClass(report.reportedMember.status)"
                  >{{ t(MEMBER_STATUS_LABEL_KEYS[report.reportedMember.status]) }}</span>
                </div>
                <p class="mt-2 font-medium truncate text-dp-text-primary">
                  {{ t('admin.reports.row.reportedMember', { name: report.reportedMemberName }) }}
                </p>
                <p class="text-sm truncate text-dp-text-secondary">{{ report.snapshotPreview }}</p>
                <p class="mt-1 text-xs text-dp-text-muted">
                  {{ t('admin.reports.row.reporter', { name: report.reporterName }) }}
                </p>
              </div>
              <div class="flex flex-col items-end gap-1 flex-shrink-0 text-dp-text-muted">
                <span class="text-xs whitespace-nowrap">{{ formatDate(report.createdAt) }}</span>
                <ChevronRight class="w-4 h-4" />
              </div>
            </div>
          </div>

          <div v-if="reports.length === 0" class="p-8 text-center text-dp-text-muted">
            {{ t('admin.reports.empty') }}
          </div>
        </template>
      </div>

      <div v-if="totalPages > 1" class="p-4 flex items-center justify-between border-t border-dp-border-primary">
        <p class="text-sm text-dp-text-secondary">
          {{ t('admin.reports.pagination', {
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

    <AdminReportDetailModal
      :open="showDetailModal"
      :report="selectedReport"
      :loading="isDetailLoading"
      :load-error="detailError"
      :working="isWorking"
      @close="closeReportDetail"
      @retry="fetchSelectedReport()"
      @update-status="handleUpdateStatus"
      @delete-target="handleDeleteTarget"
      @suspend="handleSuspend"
      @unsuspend="handleUnsuspend"
      @go-to-calendar="handleGoToCalendar"
    />
  </div>
</template>
