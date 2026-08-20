<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { Bell, ChevronDown, Clock, Inbox, Loader2, MessageSquareText } from 'lucide-vue-next'
import { inquiryApi } from '@/api/inquiry'
import type { MyInquiry } from '@/types/inquiry'
import { formatSupportDateTime } from './supportHistory'

const PAGE_SIZE = 10

const emit = defineEmits<{ goToForm: [] }>()

const { t, locale } = useI18n()

const inquiries = ref<MyInquiry[]>([])
const currentPage = ref(0)
const totalPages = ref(0)
const totalElements = ref(0)
const isLoading = ref(false)
const loadError = ref('')
const expandedId = ref<string | null>(null)

const hasMorePages = computed(() => currentPage.value < totalPages.value - 1)
const isInitialLoading = computed(() => isLoading.value && inquiries.value.length === 0)
const isEmpty = computed(() => !isLoading.value && !loadError.value && inquiries.value.length === 0)

async function loadInquiries(page: number) {
  isLoading.value = true
  loadError.value = ''
  try {
    const response = await inquiryApi.fetchMine(page, PAGE_SIZE)
    inquiries.value = page === 0 ? response.content : [...inquiries.value, ...response.content]
    currentPage.value = response.number
    totalPages.value = response.totalPages
    totalElements.value = response.totalElements
  } catch (error) {
    console.error('Failed to load my inquiries:', error)
    loadError.value = t('support.history.loadFailed')
  } finally {
    isLoading.value = false
  }
}

function loadMore() {
  if (hasMorePages.value && !isLoading.value) {
    loadInquiries(currentPage.value + 1)
  }
}

/** A failed first page restarts; a failed page N retries that same page. */
function retry() {
  loadInquiries(inquiries.value.length === 0 ? 0 : currentPage.value + 1)
}

function toggleExpanded(id: string) {
  expandedId.value = expandedId.value === id ? null : id
}

function hasAnswer(inquiry: MyInquiry): boolean {
  return Boolean(inquiry.answer?.trim())
}

function formatDate(value: string): string {
  return formatSupportDateTime(value, locale.value)
}

onMounted(() => loadInquiries(0))
</script>

<template>
  <section>
    <div v-if="isInitialLoading" class="card card-body flex min-h-40 items-center justify-center gap-3 text-sm text-dp-text-secondary">
      <Loader2 class="h-5 w-5 animate-spin" />
      {{ t('support.history.loading') }}
    </div>

    <template v-else>
      <div v-if="isEmpty" class="card card-body py-10 text-center">
        <Inbox class="mx-auto h-10 w-10 text-dp-text-muted opacity-60" />
        <p class="mt-3 text-sm text-dp-text-secondary">{{ t('support.history.empty') }}</p>
        <button
          type="button"
          class="mt-4 inline-flex min-h-11 items-center rounded-lg border border-dp-border-primary px-4 py-2 text-sm font-medium text-dp-text-secondary transition-colors hover:bg-dp-bg-hover"
          @click="emit('goToForm')"
        >
          {{ t('support.history.emptyAction') }}
        </button>
      </div>

      <template v-else>
        <p class="mb-2 px-1 text-xs font-medium text-dp-text-muted">
          {{ t('support.history.countSummary', { total: totalElements }) }}
        </p>

        <ul class="space-y-3">
          <li
            v-for="inquiry in inquiries"
            :key="inquiry.id"
            class="overflow-hidden rounded-xl border border-dp-border-primary bg-dp-bg-card shadow-sm transition-colors"
            :class="expandedId === inquiry.id ? 'border-dp-accent-border' : ''"
          >
            <button
              type="button"
              class="flex w-full items-start gap-3 p-4 text-left transition-colors hover:bg-dp-bg-hover"
              :aria-expanded="expandedId === inquiry.id"
              :aria-label="expandedId === inquiry.id ? t('support.history.collapse') : t('support.history.expand')"
              @click="toggleExpanded(inquiry.id)"
            >
              <span class="min-w-0 flex-1">
                <span class="flex items-center gap-2">
                  <span
                    class="inline-flex shrink-0 items-center gap-1 rounded-full px-2.5 py-1 text-xs font-bold"
                    :class="hasAnswer(inquiry)
                      ? 'bg-dp-success-soft text-dp-success'
                      : 'bg-dp-warning-soft text-dp-warning'"
                  >
                    <component :is="hasAnswer(inquiry) ? MessageSquareText : Clock" class="h-3 w-3" />
                    {{ hasAnswer(inquiry) ? t('support.history.answered') : t('support.history.awaiting') }}
                  </span>
                  <span
                    v-if="inquiry.status === 'CLOSED'"
                    class="inline-flex shrink-0 items-center rounded-full bg-dp-bg-tertiary px-2.5 py-1 text-xs font-medium text-dp-text-secondary"
                  >{{ t('support.history.status.closed') }}</span>
                </span>
                <span class="mt-2 block truncate text-base font-semibold text-dp-text-primary">
                  {{ inquiry.subject || t('support.history.noSubject') }}
                </span>
                <span class="mt-1 block truncate text-sm text-dp-text-secondary">{{ inquiry.content }}</span>
                <span class="mt-1.5 block text-xs text-dp-text-muted">
                  {{ t('support.history.submittedAt') }} · {{ formatDate(inquiry.createdAt) }}
                </span>
              </span>
              <ChevronDown
                class="mt-1 h-4 w-4 shrink-0 text-dp-text-muted transition-transform"
                :class="expandedId === inquiry.id ? 'rotate-180' : ''"
              />
            </button>

            <div v-if="expandedId === inquiry.id" class="space-y-4 border-t border-dp-border-primary px-4 py-4">
              <div>
                <h3 class="text-xs font-semibold tracking-wide text-dp-text-muted uppercase">{{ t('support.history.contentTitle') }}</h3>
                <p class="mt-1.5 rounded-xl bg-dp-bg-tertiary p-3 text-sm leading-relaxed whitespace-pre-wrap break-words text-dp-text-primary">{{ inquiry.content }}</p>
              </div>

              <div v-if="hasAnswer(inquiry)">
                <h3 class="text-xs font-semibold tracking-wide text-dp-text-muted uppercase">{{ t('support.history.answerTitle') }}</h3>
                <p class="mt-1.5 rounded-xl border-l-4 border-dp-accent bg-dp-accent-soft p-3 text-sm leading-relaxed whitespace-pre-wrap break-words text-dp-text-primary">{{ inquiry.answer }}</p>
                <p v-if="inquiry.answeredAt" class="mt-1.5 text-xs text-dp-text-muted">
                  {{ t('support.history.answeredAt') }} · {{ formatDate(inquiry.answeredAt) }}
                </p>
              </div>
              <div v-else class="rounded-xl bg-dp-bg-tertiary p-3">
                <p class="flex items-start gap-2 text-sm leading-relaxed text-dp-text-secondary">
                  <Clock class="mt-0.5 h-4 w-4 shrink-0 text-dp-text-muted" />
                  {{ t('support.history.awaitingDescription') }}
                </p>
                <p class="mt-1.5 flex items-start gap-2 text-xs leading-relaxed text-dp-text-muted">
                  <Bell class="mt-0.5 h-3.5 w-3.5 shrink-0" />
                  {{ t('support.history.answeredNotice') }}
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
          {{ t('support.history.retry') }}
        </button>
      </div>

      <div v-else-if="hasMorePages" class="mt-4 text-center">
        <button
          type="button"
          :disabled="isLoading"
          class="inline-flex min-h-11 items-center rounded-lg border border-dp-border-primary px-6 py-2 text-sm font-medium text-dp-text-secondary transition-colors hover:bg-dp-bg-hover disabled:cursor-not-allowed disabled:opacity-50"
          @click="loadMore"
        >
          {{ isLoading ? t('support.history.loading') : t('support.history.loadMore') }}
        </button>
      </div>
    </template>
  </section>
</template>
