<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { ChevronDown, CircleCheck, Clock, Loader2, ShieldCheck, ShieldOff } from 'lucide-vue-next'
import { reportApi } from '@/api/report'
import type { MyReport } from '@/types/report'
import {
  MY_REPORT_REASON_LABEL_KEYS,
  MY_REPORT_STATUS_DESCRIPTION_KEYS,
  MY_REPORT_STATUS_LABEL_KEYS,
  MY_REPORT_TARGET_TYPE_LABEL_KEYS,
  formatSupportDateTime,
  myReportStatusToneClass,
} from './supportHistory'

const PAGE_SIZE = 10

const STATUS_ICONS = {
  OPEN: Clock,
  RESOLVED: ShieldCheck,
  DISMISSED: ShieldOff,
} as const

const { t, locale } = useI18n()

const reports = ref<MyReport[]>([])
const currentPage = ref(0)
const totalPages = ref(0)
const totalElements = ref(0)
const isLoading = ref(false)
const loadError = ref('')
const expandedId = ref<string | null>(null)

const hasMorePages = computed(() => currentPage.value < totalPages.value - 1)
const isInitialLoading = computed(() => isLoading.value && reports.value.length === 0)
const isEmpty = computed(() => !isLoading.value && !loadError.value && reports.value.length === 0)

async function loadReports(page: number) {
  isLoading.value = true
  loadError.value = ''
  try {
    const response = await reportApi.fetchMine(page, PAGE_SIZE)
    reports.value = page === 0 ? response.content : [...reports.value, ...response.content]
    currentPage.value = response.number
    totalPages.value = response.totalPages
    totalElements.value = response.totalElements
  } catch (error) {
    console.error('Failed to load my reports:', error)
    loadError.value = t('support.reports.loadFailed')
  } finally {
    isLoading.value = false
  }
}

function loadMore() {
  if (hasMorePages.value && !isLoading.value) {
    loadReports(currentPage.value + 1)
  }
}

/** A failed first page restarts; a failed page N retries that same page. */
function retry() {
  loadReports(reports.value.length === 0 ? 0 : currentPage.value + 1)
}

function toggleExpanded(id: string) {
  expandedId.value = expandedId.value === id ? null : id
}

function formatDate(value: string): string {
  return formatSupportDateTime(value, locale.value)
}

onMounted(() => loadReports(0))
</script>

<template>
  <section>
    <div v-if="isInitialLoading" class="card card-body flex min-h-40 items-center justify-center gap-3 text-sm text-dp-text-secondary">
      <Loader2 class="h-5 w-5 animate-spin" />
      {{ t('support.reports.loading') }}
    </div>

    <template v-else>
      <div v-if="isEmpty" class="card card-body py-10 text-center">
        <ShieldCheck class="mx-auto h-10 w-10 text-dp-text-muted opacity-60" />
        <p class="mt-3 text-sm text-dp-text-secondary">{{ t('support.reports.empty') }}</p>
        <p class="mt-1.5 text-xs leading-relaxed text-dp-text-muted">{{ t('support.reports.emptyDescription') }}</p>
      </div>

      <template v-else>
        <p class="mb-2 px-1 text-xs font-medium text-dp-text-muted">
          {{ t('support.reports.countSummary', { total: totalElements }) }}
        </p>

        <ul class="space-y-3">
          <li
            v-for="report in reports"
            :key="report.id"
            class="overflow-hidden rounded-xl border border-dp-border-primary bg-dp-bg-card shadow-sm transition-colors"
            :class="expandedId === report.id ? 'border-dp-accent-border' : ''"
          >
            <button
              type="button"
              class="flex w-full items-start gap-3 p-4 text-left transition-colors hover:bg-dp-bg-hover"
              :aria-expanded="expandedId === report.id"
              :aria-label="expandedId === report.id ? t('support.reports.collapse') : t('support.reports.expand')"
              @click="toggleExpanded(report.id)"
            >
              <span class="min-w-0 flex-1">
                <span class="flex items-center gap-2">
                  <span
                    class="inline-flex shrink-0 items-center gap-1 rounded-full px-2.5 py-1 text-xs font-bold"
                    :class="myReportStatusToneClass(report.status)"
                  >
                    <component :is="STATUS_ICONS[report.status]" class="h-3 w-3" />
                    {{ t(MY_REPORT_STATUS_LABEL_KEYS[report.status]) }}
                  </span>
                  <span
                    class="inline-flex shrink-0 items-center rounded-full bg-dp-bg-tertiary px-2.5 py-1 text-xs font-medium text-dp-text-secondary"
                  >{{ t(MY_REPORT_TARGET_TYPE_LABEL_KEYS[report.targetType]) }}</span>
                </span>
                <span class="mt-2 block truncate text-base font-semibold text-dp-text-primary">
                  {{ report.reportedMemberName }}
                </span>
                <span class="mt-1 block truncate text-sm text-dp-text-secondary">
                  {{ t(MY_REPORT_REASON_LABEL_KEYS[report.reason]) }}
                </span>
                <span class="mt-1.5 block text-xs text-dp-text-muted">
                  {{ t('support.reports.reportedAt') }} · {{ formatDate(report.createdAt) }}
                </span>
              </span>
              <ChevronDown
                class="mt-1 h-4 w-4 shrink-0 text-dp-text-muted transition-transform"
                :class="expandedId === report.id ? 'rotate-180' : ''"
              />
            </button>

            <div v-if="expandedId === report.id" class="space-y-4 border-t border-dp-border-primary px-4 py-4">
              <dl class="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1.5 text-sm">
                <dt class="text-dp-text-muted">{{ t('support.reports.targetLabel') }}</dt>
                <dd class="font-medium break-words text-dp-text-primary">
                  {{ report.reportedMemberName }} · {{ t(MY_REPORT_TARGET_TYPE_LABEL_KEYS[report.targetType]) }}
                </dd>
                <dt class="text-dp-text-muted">{{ t('support.reports.reasonLabel') }}</dt>
                <dd class="font-medium break-words text-dp-text-primary">{{ t(MY_REPORT_REASON_LABEL_KEYS[report.reason]) }}</dd>
              </dl>

              <div v-if="report.detail">
                <h3 class="text-xs font-semibold tracking-wide text-dp-text-muted uppercase">{{ t('support.reports.detailLabel') }}</h3>
                <p class="mt-1.5 rounded-xl bg-dp-bg-tertiary p-3 text-sm leading-relaxed whitespace-pre-wrap break-words text-dp-text-primary">{{ report.detail }}</p>
              </div>

              <div class="rounded-xl bg-dp-bg-tertiary p-3">
                <p class="flex items-start gap-2 text-sm leading-relaxed text-dp-text-secondary">
                  <CircleCheck v-if="report.status !== 'OPEN'" class="mt-0.5 h-4 w-4 shrink-0 text-dp-text-muted" />
                  <Clock v-else class="mt-0.5 h-4 w-4 shrink-0 text-dp-text-muted" />
                  {{ t(MY_REPORT_STATUS_DESCRIPTION_KEYS[report.status]) }}
                </p>
                <p v-if="report.resolvedAt" class="mt-1.5 text-xs text-dp-text-muted">
                  {{ t('support.reports.handledAt') }} · {{ formatDate(report.resolvedAt) }}
                </p>
                <p v-if="report.status !== 'OPEN'" class="mt-1.5 text-xs leading-relaxed text-dp-text-muted">
                  {{ t('support.reports.privacyNotice') }}
                </p>
              </div>
            </div>
          </li>
        </ul>
      </template>

      <div v-if="loadError" class="mt-4 flex flex-col items-center gap-3 text-center">
        <p role="alert" class="text-sm text-dp-danger">{{ loadError }}</p>
        <button
          type="button"
          class="inline-flex min-h-11 items-center rounded-lg border border-dp-border-primary px-4 py-2 text-sm font-medium text-dp-text-secondary transition-colors hover:bg-dp-bg-hover"
          @click="retry"
        >
          {{ t('support.reports.retry') }}
        </button>
      </div>

      <div v-else-if="hasMorePages" class="mt-4 text-center">
        <button
          type="button"
          :disabled="isLoading"
          class="inline-flex min-h-11 items-center rounded-lg border border-dp-border-primary px-6 py-2 text-sm font-medium text-dp-text-secondary transition-colors hover:bg-dp-bg-hover disabled:cursor-not-allowed disabled:opacity-50"
          @click="loadMore"
        >
          {{ isLoading ? t('support.reports.loading') : t('support.reports.loadMore') }}
        </button>
      </div>
    </template>
  </section>
</template>
