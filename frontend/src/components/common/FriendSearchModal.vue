<script setup lang="ts">
import { computed } from 'vue'
import { UserPlus, X, Search, ChevronLeft, ChevronRight, Loader2 } from 'lucide-vue-next'
import type { MemberPreviewDto } from '@/types'
import BaseModal from '@/components/common/BaseModal.vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'

const props = defineProps<{
  isOpen: boolean
  keyword: string
  results: MemberPreviewDto[]
  currentPage: number
  totalPages: number
  totalElements: number
  loading: boolean
}>()

const emit = defineEmits<{
  close: []
  search: []
  requestFriend: [member: MemberPreviewDto]
  changePage: [page: number]
  'update:keyword': [value: string]
}>()

const currentPageDisplay = computed(() => props.currentPage + 1)

function handleKeywordInput(event: Event) {
  emit('update:keyword', (event.target as HTMLInputElement).value)
}
</script>

<template>
  <BaseModal
    :is-open="isOpen"
    size="2xl"
    height="search"
    rounded
    @close="emit('close')"
  >
    <div class="modal-header">
      <div class="flex items-center gap-3 min-w-0">
        <div class="w-10 h-10 bg-gradient-to-br from-dp-accent to-dp-accent-hover rounded-xl flex items-center justify-center flex-shrink-0">
          <UserPlus class="w-5 h-5 text-dp-text-on-dark" />
        </div>
        <h2>친구 추가</h2>
      </div>
      <button
        class="p-2 rounded-full hover-close-btn cursor-pointer text-dp-text-muted"
        @click="emit('close')"
      >
        <X class="w-5 h-5" />
      </button>
    </div>

    <div class="modal-body-form-lg">
      <div class="flex gap-2">
        <div class="flex-grow relative min-w-0">
          <Search class="w-5 h-5 absolute left-3.5 top-1/2 -translate-y-1/2 text-dp-text-muted" />
          <input
            :value="keyword"
            type="text"
            placeholder="이름 또는 팀 검색"
            class="form-control-neutral w-full pl-11 pr-4 py-3 rounded-xl"
            @input="handleKeywordInput"
            @keyup.enter="emit('search')"
          />
        </div>
        <button
          class="flex-shrink-0 px-4 sm:px-5 py-3 bg-gradient-to-r from-dp-surface-strong to-dp-surface-strong-alt text-dp-text-on-dark rounded-xl hover:from-dp-surface-strong-alt hover:to-dp-surface-strong-hover transition-all shadow-lg flex items-center gap-2 font-medium cursor-pointer whitespace-nowrap"
          @click="emit('search')"
        >
          <Search class="w-4 h-4" />
          <span class="hidden sm:inline">검색</span>
        </button>
      </div>

      <div v-if="loading" class="flex justify-center py-10">
        <Loader2 class="w-8 h-8 animate-spin text-dp-accent" />
      </div>

      <div v-else-if="results.length > 0" class="space-y-4">
        <div class="space-y-2">
          <div
            v-for="(member, index) in results"
            :key="member.id ?? index"
            class="flex items-center justify-between p-4 rounded-xl hover-bg-light bg-dp-bg-secondary"
          >
            <div class="flex items-center gap-3 min-w-0">
              <ProfileAvatar
                :member-id="member.id"
                :name="member.name"
                :has-profile-photo="member.hasProfilePhoto"
                :profile-photo-version="member.profilePhotoVersion"
                size="md"
              />
              <div class="min-w-0">
                <p class="font-semibold truncate text-dp-text-primary">{{ member.name }}</p>
                <p class="text-sm truncate text-dp-text-secondary">{{ member.team ?? '팀 없음' }}</p>
              </div>
            </div>
            <button
              class="px-4 py-2 text-sm font-medium bg-dp-success text-dp-text-on-dark rounded-xl hover:bg-dp-success-hover transition shadow-sm cursor-pointer flex-shrink-0"
              @click="emit('requestFriend', member)"
            >
              친구 요청
            </button>
          </div>
        </div>

        <div v-if="totalPages > 1" class="flex justify-center items-center gap-2">
          <button
            class="p-2.5 rounded-xl border disabled:opacity-50 disabled:cursor-not-allowed hover-bg-light cursor-pointer border-dp-border-primary"
            :disabled="currentPage === 0"
            @click="emit('changePage', currentPage - 1)"
          >
            <ChevronLeft class="w-4 h-4" />
          </button>

          <template v-for="page in totalPages" :key="page">
            <button
              class="w-10 h-10 rounded-xl border font-medium hover-bg-light cursor-pointer"
              :class="page - 1 === currentPage ? 'bg-dp-accent text-dp-text-on-dark border-dp-accent' : ''"
              :style="page - 1 !== currentPage ? { borderColor: 'var(--dp-border-primary)' } : {}"
              @click="emit('changePage', page - 1)"
            >
              {{ page }}
            </button>
          </template>

          <button
            class="p-2.5 rounded-xl border disabled:opacity-50 disabled:cursor-not-allowed hover-bg-light cursor-pointer border-dp-border-primary"
            :disabled="currentPage >= totalPages - 1"
            @click="emit('changePage', currentPage + 1)"
          >
            <ChevronRight class="w-4 h-4" />
          </button>
        </div>

        <p class="text-center text-sm text-dp-text-secondary">
          페이지 {{ currentPageDisplay }} / {{ totalPages }} | 전체 결과: {{ totalElements }}
        </p>
      </div>

      <div v-else class="text-center py-12">
        <Search class="w-12 h-12 mx-auto mb-3 text-dp-border-secondary" />
        <p class="text-dp-text-secondary">
          {{ keyword.trim() ? '검색 결과가 없습니다.' : '검색어를 입력하고 검색해주세요.' }}
        </p>
      </div>
    </div>

    <div class="modal-actions modal-actions-end modal-footer-safe">
      <button
        class="px-5 py-2.5 rounded-xl font-medium hover-interactive cursor-pointer bg-dp-bg-tertiary text-dp-text-primary"
        @click="emit('close')"
      >
        닫기
      </button>
    </div>
  </BaseModal>
</template>
