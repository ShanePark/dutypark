<script setup lang="ts">
import { computed } from 'vue'
import { X, ChevronLeft, ChevronRight, Calendar, Paperclip } from 'lucide-vue-next'

interface SearchResult {
  id: string
  content: string
  description?: string
  startDateTime: string
  endDateTime: string
  hasAttachments: boolean
}

interface PageInfo {
  pageNumber: number
  pageSize: number
  totalPages: number
  totalElements: number
}

interface Props {
  isOpen: boolean
  query: string
  results: SearchResult[]
  pageInfo: PageInfo
}

const props = defineProps<Props>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'goToDate', result: SearchResult): void
  (e: 'changePage', page: number): void
}>()

const currentPage = computed(() => props.pageInfo.pageNumber + 1)

const pagesToShow = computed(() => {
  const pages: number[] = []
  const start = Math.max(1, currentPage.value - 5)
  const end = Math.min(props.pageInfo.totalPages, currentPage.value + 5)
  for (let i = start; i <= end; i++) {
    pages.push(i)
  }
  return pages
})

function formatDateTime(dateTimeStr: string) {
  const date = new Date(dateTimeStr)
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  const hours = String(date.getHours()).padStart(2, '0')
  const minutes = String(date.getMinutes()).padStart(2, '0')
  return `${year}-${month}-${day} ${hours}:${minutes}`
}

function formatDateRange(start: string, end: string) {
  const startDate = new Date(start)
  const endDate = new Date(end)

  const startStr = formatDateTime(start)

  if (startDate.toDateString() === endDate.toDateString()) {
    const endTime = `${String(endDate.getHours()).padStart(2, '0')}:${String(endDate.getMinutes()).padStart(2, '0')}`
    if (endTime === '00:00') {
      return startStr
    }
    return `${startStr} ~ ${endTime}`
  }

  return `${startStr} ~ ${formatDateTime(end)}`
}
</script>

<style scoped>
.hover-bg:hover {
  background-color: var(--dp-bg-secondary);
}

.result-item:hover {
  background-color: var(--dp-bg-secondary);
}
</style>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @click.self="emit('close')"
    >
      <div class="rounded-lg shadow-xl w-full max-w-[95vw] sm:max-w-2xl max-h-[90dvh] sm:max-h-[90vh] overflow-hidden mx-2 sm:mx-4" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
        <!-- Header -->
        <div class="flex items-center justify-between p-3 sm:p-4 border-b" :style="{ borderColor: 'var(--dp-border-primary)' }">
          <div class="min-w-0 flex-1 mr-2">
            <h2 class="text-base sm:text-lg font-bold" :style="{ color: 'var(--dp-text-primary)' }">검색 결과</h2>
            <p class="text-sm truncate" :style="{ color: 'var(--dp-text-muted)' }">
              "{{ query }}" 검색 결과 {{ pageInfo.totalElements }}건
            </p>
          </div>
          <button @click="emit('close')" class="p-2 rounded-full transition flex-shrink-0 hover-bg">
            <X class="w-6 h-6" :style="{ color: 'var(--dp-text-primary)' }" />
          </button>
        </div>

        <!-- Content -->
        <div class="p-3 sm:p-4 overflow-y-auto max-h-[calc(90dvh-180px)] sm:max-h-[calc(90vh-180px)]">
          <div v-if="results.length === 0" class="text-center py-8" :style="{ color: 'var(--dp-text-muted)' }">
            검색 결과가 없습니다.
          </div>

          <div v-else class="space-y-3">
            <div
              v-for="result in results"
              :key="result.id"
              @click="emit('goToDate', result)"
              class="p-4 border rounded-lg cursor-pointer transition result-item"
              :style="{ borderColor: 'var(--dp-border-primary)' }"
            >
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <div class="flex items-center gap-2">
                    <span class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">{{ result.content }}</span>
                    <Paperclip
                      v-if="result.hasAttachments"
                      class="w-4 h-4"
                      :style="{ color: 'var(--dp-text-muted)' }"
                    />
                  </div>
                  <p
                    v-if="result.description"
                    class="text-sm mt-1 line-clamp-2"
                    :style="{ color: 'var(--dp-text-secondary)' }"
                  >
                    {{ result.description }}
                  </p>
                  <div class="flex items-center gap-1 mt-2 text-sm" :style="{ color: 'var(--dp-text-muted)' }">
                    <Calendar class="w-4 h-4" />
                    {{ formatDateRange(result.startDateTime, result.endDateTime) }}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Pagination -->
        <div
          v-if="pageInfo.totalPages > 1"
          class="p-3 sm:p-4 border-t flex items-center justify-center gap-0.5 sm:gap-1 overflow-x-auto"
          :style="{ borderColor: 'var(--dp-border-primary)' }"
        >
          <button
            @click="emit('changePage', currentPage - 2)"
            :disabled="currentPage === 1"
            class="p-2 rounded disabled:opacity-50 disabled:cursor-not-allowed transition hover-bg"
            :style="{ color: 'var(--dp-text-primary)' }"
          >
            <ChevronLeft class="w-5 h-5 sm:w-4 sm:h-4" />
          </button>

          <button
            v-for="page in pagesToShow"
            :key="page"
            @click="emit('changePage', page - 1)"
            class="px-2 sm:px-3 py-1 text-sm rounded transition"
            :class="[
              page === currentPage
                ? 'bg-blue-600 text-white'
                : 'hover-bg'
            ]"
            :style="page !== currentPage ? { color: 'var(--dp-text-primary)' } : {}"
          >
            {{ page }}
          </button>

          <button
            @click="emit('changePage', currentPage)"
            :disabled="currentPage === pageInfo.totalPages"
            class="p-2 rounded disabled:opacity-50 disabled:cursor-not-allowed transition hover-bg"
            :style="{ color: 'var(--dp-text-primary)' }"
          >
            <ChevronRight class="w-5 h-5 sm:w-4 sm:h-4" />
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
