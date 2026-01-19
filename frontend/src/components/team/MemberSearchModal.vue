<script setup lang="ts">
import { ref, watch, toRef } from 'vue'
import { useSwal } from '@/composables/useSwal'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
import { teamApi } from '@/api/team'
import type { MemberDto } from '@/types'
import { Search, X, ChevronLeft, ChevronRight, Loader2 } from 'lucide-vue-next'

const props = defineProps<{
  isOpen: boolean
  teamId: number
  saving: boolean
}>()

const emit = defineEmits<{
  close: []
  'member-added': []
  'update:saving': [boolean]
}>()

const { showError, toastSuccess, confirm } = useSwal()
const isOpenRef = toRef(props, 'isOpen')

useBodyScrollLock(isOpenRef)
useEscapeKey(isOpenRef, () => emit('close'))

const searchKeyword = ref('')
const searchLoading = ref(false)
const searchResult = ref<MemberDto[]>([])
const currentPage = ref(0)
const totalPages = ref(1)
const totalElements = ref(0)
const pageSize = 5

function close() {
  emit('close')
}

function resetSearchState() {
  searchKeyword.value = ''
  searchResult.value = []
  currentPage.value = 0
  totalPages.value = 1
  totalElements.value = 0
}

watch(() => props.isOpen, (open) => {
  if (!open) return
  resetSearchState()
  searchMembers()
})

async function searchMembers() {
  searchLoading.value = true
  try {
    const response = await teamApi.searchMembersToInvite(
      searchKeyword.value,
      currentPage.value,
      pageSize
    )
    searchResult.value = response.data.content
    totalElements.value = response.data.totalElements
    totalPages.value = response.data.totalPages || 1
  } catch (error) {
    console.error('Failed to search members:', error)
  } finally {
    searchLoading.value = false
  }
}

function prevPage() {
  if (currentPage.value > 0) {
    currentPage.value--
    searchMembers()
  }
}

function nextPage() {
  if (currentPage.value < totalPages.value - 1) {
    currentPage.value++
    searchMembers()
  }
}

function goToPage(page: number) {
  currentPage.value = page
  searchMembers()
}

async function addMember(member: MemberDto) {
  if (!member.id) return
  if (!await confirm(`${member.name} 님을 팀에 추가하시겠습니까?`)) return

  emit('update:saving', true)
  try {
    await teamApi.addMember(props.teamId, member.id)
    toastSuccess(`${member.name} 님이 팀에 추가되었습니다.`)
    emit('member-added')
    close()
  } catch (error) {
    console.error('Failed to add member:', error)
    showError('멤버 추가에 실패했습니다.')
  } finally {
    emit('update:saving', false)
  }
}
</script>

<template>
  <div
    v-if="isOpen"
    class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
    @click.self="close"
  >
    <div class="rounded-lg shadow-xl w-full max-w-lg" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
      <div class="flex items-center justify-between p-4 border-b" :style="{ borderColor: 'var(--dp-border-primary)' }">
        <h3 class="text-lg font-bold" :style="{ color: 'var(--dp-text-primary)' }">멤버 추가</h3>
        <button
          @click="close"
          class="p-1.5 rounded-full hover-close-btn cursor-pointer"
        >
          <X class="w-5 h-5" />
        </button>
      </div>

      <div class="p-4">
        <!-- Search Input -->
        <div class="flex gap-2 mb-4">
          <input
            v-model="searchKeyword"
            type="text"
            placeholder="이름 또는 이메일로 검색"
            class="flex-1 px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            :style="{ backgroundColor: 'var(--dp-bg-input)', borderColor: 'var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
            @keyup.enter="searchMembers"
          />
          <button
            @click="searchMembers"
            class="px-4 py-2 text-white rounded-lg hover:bg-gray-700 transition"
            :style="{ backgroundColor: 'var(--dp-modal-header-bg)' }"
          >
            <Search class="w-5 h-5" />
          </button>
        </div>

        <!-- Search Results -->
        <div v-if="searchLoading" class="flex items-center justify-center py-8">
          <Loader2 class="w-6 h-6 animate-spin text-blue-500" />
        </div>
        <div v-else-if="searchResult.length > 0" class="overflow-x-auto">
          <table class="w-full">
            <thead :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <tr>
                <th class="px-3 py-2 text-left text-sm" :style="{ color: 'var(--dp-text-secondary)' }">#</th>
                <th class="px-3 py-2 text-left text-sm" :style="{ color: 'var(--dp-text-secondary)' }">이름</th>
                <th class="px-3 py-2 text-left text-sm" :style="{ color: 'var(--dp-text-secondary)' }">이메일</th>
                <th class="px-3 py-2 text-center text-sm" :style="{ color: 'var(--dp-text-secondary)' }">추가</th>
              </tr>
            </thead>
            <tbody :style="{ borderColor: 'var(--dp-border-primary)' }">
              <tr v-for="(member, index) in searchResult" :key="member.id ?? index" class="hover-bg-light" :style="{ borderBottomWidth: '1px', borderBottomStyle: 'solid', borderBottomColor: 'var(--dp-border-primary)' }">
                <td class="px-3 py-2 text-sm" :style="{ color: 'var(--dp-text-muted)' }">
                  {{ currentPage * pageSize + index + 1 }}
                </td>
                <td class="px-3 py-2 text-sm font-medium" :style="{ color: 'var(--dp-text-primary)' }">{{ member.name }}</td>
                <td class="px-3 py-2 text-sm" :style="{ color: 'var(--dp-text-muted)' }">{{ member.email }}</td>
                <td class="px-3 py-2 text-center">
                  <button
                    @click="addMember(member)"
                    :disabled="!!member.teamId || saving"
                    class="px-3 py-1 bg-blue-500 text-white text-sm rounded hover:bg-blue-600 transition disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {{ member.teamId ? '소속 있음' : '추가' }}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-else class="text-center py-4" :style="{ color: 'var(--dp-text-muted)' }">
          검색 결과가 없습니다.
        </div>

        <!-- Pagination -->
        <div v-if="searchResult.length > 0" class="mt-4">
          <div class="text-sm mb-2" :style="{ color: 'var(--dp-text-muted)' }">
            Page {{ currentPage + 1 }} of {{ totalPages }} | Total: {{ totalElements }}
          </div>
          <div class="flex flex-wrap items-center gap-1">
            <button
              @click="prevPage"
              :disabled="currentPage === 0"
              class="px-2 sm:px-3 py-1 border rounded hover-bg-light transition disabled:opacity-50"
              :style="{ borderColor: 'var(--dp-border-secondary)' }"
            >
              <ChevronLeft class="w-4 h-4" />
            </button>
            <button
              v-for="i in totalPages"
              :key="i"
              @click="goToPage(i - 1)"
              class="px-2 sm:px-3 py-1 text-sm border rounded transition"
              :class="i - 1 === currentPage ? 'bg-blue-500 text-white border-blue-500' : ''"
              :style="i - 1 !== currentPage ? { borderColor: 'var(--dp-border-secondary)' } : {}"
            >
              {{ i }}
            </button>
            <button
              @click="nextPage"
              :disabled="currentPage >= totalPages - 1"
              class="px-2 sm:px-3 py-1 border rounded hover-bg-light transition disabled:opacity-50"
              :style="{ borderColor: 'var(--dp-border-secondary)' }"
            >
              <ChevronRight class="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>

      <div class="flex justify-end p-4 border-t" :style="{ borderColor: 'var(--dp-border-primary)' }">
        <button
          @click="close"
          class="px-4 py-2 rounded-lg font-medium hover-interactive cursor-pointer"
          :style="{ backgroundColor: 'var(--dp-bg-tertiary)', color: 'var(--dp-text-secondary)' }"
        >
          닫기
        </button>
      </div>
    </div>
  </div>
</template>
