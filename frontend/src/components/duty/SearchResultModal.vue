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

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @click.self="emit('close')"
    >
      <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] overflow-hidden">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-gray-200">
          <div>
            <h2 class="text-lg font-bold">검색 결과</h2>
            <p class="text-sm text-gray-500">
              "{{ query }}" 검색 결과 {{ pageInfo.totalElements }}건
            </p>
          </div>
          <button @click="emit('close')" class="p-1 hover:bg-gray-100 rounded-full transition">
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- Content -->
        <div class="p-4 overflow-y-auto max-h-[calc(90vh-180px)]">
          <div v-if="results.length === 0" class="text-center py-8 text-gray-400">
            검색 결과가 없습니다.
          </div>

          <div v-else class="space-y-3">
            <div
              v-for="result in results"
              :key="result.id"
              @click="emit('goToDate', result)"
              class="p-4 border border-gray-200 rounded-lg hover:bg-gray-50 cursor-pointer transition"
            >
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <div class="flex items-center gap-2">
                    <span class="font-medium">{{ result.content }}</span>
                    <Paperclip
                      v-if="result.hasAttachments"
                      class="w-4 h-4 text-gray-400"
                    />
                  </div>
                  <p
                    v-if="result.description"
                    class="text-sm text-gray-600 mt-1 line-clamp-2"
                  >
                    {{ result.description }}
                  </p>
                  <div class="flex items-center gap-1 mt-2 text-sm text-gray-500">
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
          class="p-4 border-t border-gray-200 flex items-center justify-center gap-1"
        >
          <button
            @click="emit('changePage', currentPage - 2)"
            :disabled="currentPage === 1"
            class="p-2 rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed transition"
          >
            <ChevronLeft class="w-4 h-4" />
          </button>

          <button
            v-for="page in pagesToShow"
            :key="page"
            @click="emit('changePage', page - 1)"
            class="px-3 py-1 rounded transition"
            :class="
              page === currentPage
                ? 'bg-blue-600 text-white'
                : 'hover:bg-gray-100'
            "
          >
            {{ page }}
          </button>

          <button
            @click="emit('changePage', currentPage)"
            :disabled="currentPage === pageInfo.totalPages"
            class="p-2 rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed transition"
          >
            <ChevronRight class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
