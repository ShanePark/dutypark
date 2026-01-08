<script setup lang="ts">
import { computed, ref, toRef, watch } from 'vue'
import { X, ChevronLeft, ChevronRight, Calendar, Paperclip, Search, Loader2 } from 'lucide-vue-next'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
import { formatDateTime, formatDateRange } from '@/utils/date'

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
  isSearching?: boolean
}

const props = defineProps<Props>()

useBodyScrollLock(toRef(props, 'isOpen'))

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'goToDate', result: SearchResult): void
  (e: 'changePage', page: number): void
  (e: 'search', query: string): void
}>()

useEscapeKey(toRef(props, 'isOpen'), () => emit('close'))

const localQuery = ref(props.query)

watch(() => props.query, (newQuery) => {
  localQuery.value = newQuery
})

watch(() => props.isOpen, (isOpen) => {
  if (isOpen) {
    localQuery.value = props.query
  }
})

function handleSearch() {
  const trimmed = localQuery.value.trim()
  if (trimmed) {
    emit('search', trimmed)
  }
}

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
      <div class="modal-container max-w-[95vw] sm:max-w-2xl max-h-[85dvh] sm:max-h-[70vh]">
        <!-- Header -->
        <div class="p-3 sm:p-4 flex-shrink-0" :style="{ backgroundColor: 'var(--dp-bg-tertiary)', borderBottom: '1px solid var(--dp-border-primary)' }">
          <div class="flex items-center justify-between mb-3">
            <h2 class="text-base sm:text-lg font-bold" :style="{ color: 'var(--dp-text-primary)' }">검색 결과</h2>
            <button @click="emit('close')" class="p-2 rounded-full flex-shrink-0 hover-close-btn cursor-pointer">
              <X class="w-6 h-6" :style="{ color: 'var(--dp-text-primary)' }" />
            </button>
          </div>
          <!-- Search input -->
          <form @submit.prevent="handleSearch" class="flex gap-2">
            <div class="relative flex-1">
              <input
                v-model="localQuery"
                type="text"
                placeholder="검색어 입력..."
                class="w-full pl-10 pr-4 py-2 rounded-lg border text-sm transition focus:outline-none focus:ring-2 focus:ring-blue-500"
                :style="{
                  backgroundColor: 'var(--dp-bg-primary)',
                  borderColor: 'var(--dp-border-primary)',
                  color: 'var(--dp-text-primary)'
                }"
                :disabled="isSearching"
              />
              <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4" :style="{ color: 'var(--dp-text-muted)' }" />
            </div>
            <button
              type="submit"
              :disabled="!localQuery.trim() || isSearching"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium transition hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer flex items-center gap-2"
            >
              <Loader2 v-if="isSearching" class="w-4 h-4 animate-spin" />
              <span>검색</span>
            </button>
          </form>
          <p v-if="query" class="text-sm mt-2" :style="{ color: 'var(--dp-text-muted)' }">
            "{{ query }}" 검색 결과 {{ pageInfo.totalElements }}건
          </p>
        </div>

        <!-- Content -->
        <div class="p-3 sm:p-4 overflow-y-auto flex-1 min-h-0">
          <!-- No query entered yet -->
          <div v-if="!query" class="text-center py-8" :style="{ color: 'var(--dp-text-muted)' }">
            검색어를 입력해주세요.
          </div>
          <!-- Query entered but no results -->
          <div v-else-if="results.length === 0" class="text-center py-8" :style="{ color: 'var(--dp-text-muted)' }">
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
          class="px-3 sm:px-4 pt-4 pb-8 flex items-center justify-center gap-0.5 sm:gap-1 overflow-x-auto flex-shrink-0"
          :style="{ borderTop: '1px solid var(--dp-border-primary)' }"
        >
          <button
            @click="emit('changePage', currentPage - 2)"
            :disabled="currentPage === 1"
            class="p-2 rounded disabled:opacity-50 disabled:cursor-not-allowed transition hover-bg cursor-pointer"
            :style="{ color: 'var(--dp-text-primary)' }"
          >
            <ChevronLeft class="w-5 h-5 sm:w-4 sm:h-4" />
          </button>

          <button
            v-for="page in pagesToShow"
            :key="page"
            @click="emit('changePage', page - 1)"
            class="px-2 sm:px-3 py-1 text-sm rounded transition cursor-pointer"
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
            class="p-2 rounded disabled:opacity-50 disabled:cursor-not-allowed transition hover-bg cursor-pointer"
            :style="{ color: 'var(--dp-text-primary)' }"
          >
            <ChevronRight class="w-5 h-5 sm:w-4 sm:h-4" />
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
