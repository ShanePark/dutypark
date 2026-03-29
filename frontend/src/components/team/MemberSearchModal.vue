<script setup lang="ts">
import { ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import BaseModal from '@/components/common/BaseModal.vue'
import { useSwal } from '@/composables/useSwal'
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
const { t } = useI18n()

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
  if (!await confirm(t('team.memberSearch.confirmAdd', { name: member.name }))) return

  emit('update:saving', true)
  try {
    await teamApi.addMember(props.teamId, member.id)
    toastSuccess(t('team.memberSearch.addedSuccess', { name: member.name }))
    emit('member-added')
    close()
  } catch (error) {
    console.error('Failed to add member:', error)
    showError(t('team.memberSearch.addFailed'))
  } finally {
    emit('update:saving', false)
  }
}
</script>

<template>
  <BaseModal
    :is-open="isOpen"
    size="lg"
    height="fit"
    @close="close"
  >
    <div class="modal-header">
      <h2>{{ t('team.memberSearch.title') }}</h2>
      <button
        @click="close"
        class="p-1.5 rounded-full hover-close-btn cursor-pointer"
        :aria-label="t('common.actions.close')"
      >
        <X class="w-5 h-5" />
      </button>
    </div>

    <div class="modal-body-form">
      <div class="flex gap-2">
        <input
          v-model="searchKeyword"
          type="text"
          :placeholder="t('team.memberSearch.searchPlaceholder')"
          class="form-control-neutral flex-1"
          @keyup.enter="searchMembers"
        />
        <button
          @click="searchMembers"
          class="px-4 py-2 text-dp-text-on-dark rounded-lg hover:bg-dp-surface-strong-hover transition bg-dp-surface-strong cursor-pointer flex items-center justify-center"
        >
          <Search class="w-5 h-5" />
        </button>
      </div>

      <div v-if="searchLoading" class="flex items-center justify-center py-8">
        <Loader2 class="w-6 h-6 animate-spin text-dp-accent" />
      </div>
      <div v-else-if="searchResult.length > 0" class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-dp-bg-secondary">
            <tr>
              <th class="px-3 py-2 text-left text-sm text-dp-text-secondary">#</th>
              <th class="px-3 py-2 text-left text-sm text-dp-text-secondary">{{ t('team.memberSearch.columns.name') }}</th>
              <th class="px-3 py-2 text-left text-sm text-dp-text-secondary">{{ t('team.memberSearch.columns.email') }}</th>
              <th class="px-3 py-2 text-center text-sm text-dp-text-secondary">{{ t('team.memberSearch.columns.add') }}</th>
            </tr>
          </thead>
          <tbody class="border-dp-border-primary">
            <tr v-for="(member, index) in searchResult" :key="member.id ?? index" class="hover-bg-light border-b border-dp-border-primary">
              <td class="px-3 py-2 text-sm text-dp-text-muted">
                {{ currentPage * pageSize + index + 1 }}
              </td>
              <td class="px-3 py-2 text-sm font-medium text-dp-text-primary">{{ member.name }}</td>
              <td class="px-3 py-2 text-sm text-dp-text-muted">{{ member.email }}</td>
              <td class="px-3 py-2 text-center">
                <button
                  @click="addMember(member)"
                  :disabled="!!member.teamId || saving"
                  class="px-3 py-1 bg-dp-accent text-dp-text-on-dark text-sm rounded hover:bg-dp-accent-hover transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
                >
                  {{ member.teamId ? t('team.memberSearch.alreadyAssigned') : t('common.actions.add') }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div v-else class="text-center py-4 text-dp-text-muted">
        {{ t('team.memberSearch.empty') }}
      </div>

      <div v-if="searchResult.length > 0" class="space-y-2">
        <div class="text-sm text-dp-text-muted">
          {{ t('team.memberSearch.pagination', { current: currentPage + 1, total: totalPages, count: totalElements }) }}
        </div>
        <div class="flex flex-wrap items-center gap-1">
          <button
            @click="prevPage"
            :disabled="currentPage === 0"
            class="px-2 sm:px-3 py-1 border rounded hover-bg-light transition disabled:opacity-50 border-dp-border-secondary cursor-pointer"
          >
            <ChevronLeft class="w-4 h-4" />
          </button>
          <button
            v-for="i in totalPages"
            :key="i"
            @click="goToPage(i - 1)"
            class="px-2 sm:px-3 py-1 text-sm border rounded transition cursor-pointer"
            :class="i - 1 === currentPage ? 'bg-dp-accent text-dp-text-on-dark border-dp-accent-border' : ''"
            :style="i - 1 !== currentPage ? { borderColor: 'var(--dp-border-secondary)' } : {}"
          >
            {{ i }}
          </button>
          <button
            @click="nextPage"
            :disabled="currentPage >= totalPages - 1"
            class="px-2 sm:px-3 py-1 border rounded hover-bg-light transition disabled:opacity-50 cursor-pointer"
            :style="{ borderColor: 'var(--dp-border-secondary)' }"
          >
            <ChevronRight class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>

    <div class="modal-actions modal-actions-end modal-footer-safe">
      <button
        @click="close"
        class="px-4 py-2 rounded-lg font-medium hover-interactive cursor-pointer bg-dp-bg-tertiary text-dp-text-secondary"
      >
        {{ t('common.actions.close') }}
      </button>
    </div>
  </BaseModal>
</template>
