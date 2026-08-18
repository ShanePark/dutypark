<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { ChevronDown, Loader2 } from 'lucide-vue-next'
import { inquiryApi } from '@/api/inquiry'
import type { MyInquiry } from '@/types/inquiry'

const PAGE_SIZE = 10

const emit = defineEmits<{ goToForm: [] }>()

const { t, locale } = useI18n()

const inquiries = ref<MyInquiry[]>([])
const currentPage = ref(0)
const totalPages = ref(0)
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
  return new Intl.DateTimeFormat(locale.value, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(new Date(value))
}

onMounted(() => loadInquiries(0))
</script>

<template>
  <div>
    <div v-if="isInitialLoading" class="flex min-h-40 items-center justify-center gap-3 text-sm text-dp-text-secondary">
      <Loader2 class="h-5 w-5 animate-spin" />
      {{ t('support.history.loading') }}
    </div>

    <template v-else>
      <div v-if="isEmpty" class="py-10 text-center">
        <p class="text-sm text-dp-text-secondary">{{ t('support.history.empty') }}</p>
        <button
          type="button"
          class="mt-4 inline-flex min-h-11 items-center rounded-lg border border-dp-border-primary px-4 py-2 text-sm font-medium text-dp-text-secondary transition-colors hover:bg-dp-bg-hover"
          @click="emit('goToForm')"
        >
          {{ t('support.history.emptyAction') }}
        </button>
      </div>

      <ul v-else class="divide-y divide-dp-border-secondary">
        <li v-for="inquiry in inquiries" :key="inquiry.id">
          <button
            type="button"
            class="flex w-full items-start gap-3 px-1 py-4 text-left transition-colors hover:bg-dp-bg-hover"
            :aria-expanded="expandedId === inquiry.id"
            @click="toggleExpanded(inquiry.id)"
          >
            <span class="min-w-0 flex-1">
              <span class="flex flex-wrap items-center gap-1.5">
                <span
                  class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold"
                  :class="inquiry.status === 'CLOSED'
                    ? 'bg-dp-bg-tertiary text-dp-text-secondary'
                    : 'bg-dp-accent-soft text-dp-accent'"
                >{{ inquiry.status === 'CLOSED' ? t('support.history.status.closed') : t('support.history.status.open') }}</span>
                <span
                  class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-bold"
                  :class="hasAnswer(inquiry)
                    ? 'bg-dp-success-soft text-dp-success'
                    : 'bg-dp-bg-tertiary text-dp-text-muted'"
                >{{ hasAnswer(inquiry) ? t('support.history.answered') : t('support.history.awaiting') }}</span>
              </span>
              <span class="mt-2 block truncate font-medium text-dp-text-primary">
                {{ inquiry.subject || t('support.history.noSubject') }}
              </span>
              <span class="mt-1 block text-xs text-dp-text-muted">
                {{ t('support.history.submittedAt') }} · {{ formatDate(inquiry.createdAt) }}
              </span>
            </span>
            <ChevronDown
              class="mt-1 h-4 w-4 shrink-0 text-dp-text-muted transition-transform"
              :class="expandedId === inquiry.id ? 'rotate-180' : ''"
            />
          </button>

          <div v-if="expandedId === inquiry.id" class="pb-4 space-y-3">
            <div>
              <h3 class="text-xs font-semibold text-dp-text-muted">{{ t('support.history.contentTitle') }}</h3>
              <p class="mt-1 rounded-xl bg-dp-bg-tertiary p-3 text-sm whitespace-pre-wrap break-words">{{ inquiry.content }}</p>
            </div>

            <div v-if="hasAnswer(inquiry)">
              <h3 class="text-xs font-semibold text-dp-text-muted">{{ t('support.history.answerTitle') }}</h3>
              <p class="mt-1 rounded-xl border border-dp-accent-border bg-dp-accent-soft p-3 text-sm whitespace-pre-wrap break-words">{{ inquiry.answer }}</p>
              <p v-if="inquiry.answeredAt" class="mt-1 text-xs text-dp-text-muted">
                {{ t('support.history.answeredAt') }} · {{ formatDate(inquiry.answeredAt) }}
              </p>
            </div>
            <p v-else class="text-sm text-dp-text-secondary">{{ t('support.history.awaitingDescription') }}</p>
          </div>
        </li>
      </ul>

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
  </div>
</template>
