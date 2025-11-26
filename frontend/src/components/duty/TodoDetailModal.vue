<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import {
  X,
  Pencil,
  Trash2,
  Check,
  RotateCcw,
  List,
} from 'lucide-vue-next'
import FileUploader from '@/components/common/FileUploader.vue'
import AttachmentGrid from '@/components/common/AttachmentGrid.vue'
import { attachmentApi } from '@/api/attachment'
import { useSwal } from '@/composables/useSwal'
import type { NormalizedAttachment } from '@/types'

const { showWarning, showError } = useSwal()

interface Todo {
  id: string
  title: string
  content: string
  status: 'ACTIVE' | 'COMPLETED'
  createdDate: string
  completedDate?: string
}

interface Props {
  isOpen: boolean
  todo: Todo | null
}

const props = defineProps<Props>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'update', data: {
    id: string
    title: string
    content: string
    attachmentSessionId?: string
    orderedAttachmentIds?: string[]
  }): void
  (e: 'complete', id: string): void
  (e: 'reopen', id: string): void
  (e: 'delete', id: string): void
  (e: 'backToList'): void
}>()

const isEditMode = ref(false)
const editTitle = ref('')
const editContent = ref('')
const editAttachments = ref<NormalizedAttachment[]>([])
const sessionId = ref<string | null>(null)
const isUploading = ref(false)
const fileUploaderRef = ref<InstanceType<typeof FileUploader> | null>(null)
const viewAttachments = ref<NormalizedAttachment[]>([])
const isLoadingAttachments = ref(false)

watch(
  () => props.isOpen,
  async (open) => {
    if (open && props.todo) {
      isEditMode.value = false
      editTitle.value = props.todo.title
      editContent.value = props.todo.content
      sessionId.value = null
      isUploading.value = false

      // Load attachments from API
      await loadAttachments()
    }
  }
)

// Watch for todo content changes (e.g., after update) to reload attachments
watch(
  () => props.todo,
  async (newTodo, oldTodo) => {
    if (props.isOpen && newTodo && oldTodo && newTodo.id === oldTodo.id) {
      // Same todo was updated, reload attachments and reset edit mode
      editTitle.value = newTodo.title
      editContent.value = newTodo.content
      await loadAttachments()
    }
  },
  { deep: true }
)

async function loadAttachments() {
  if (!props.todo) return
  isLoadingAttachments.value = true
  viewAttachments.value = []
  try {
    viewAttachments.value = await attachmentApi.listAttachments('TODO', props.todo.id)
    editAttachments.value = [...viewAttachments.value]
  } catch (error) {
    console.error('Failed to load attachments:', error)
    viewAttachments.value = []
    editAttachments.value = []
  } finally {
    isLoadingAttachments.value = false
  }
}

const isActive = computed(() => props.todo?.status === 'ACTIVE')

function formatDate(dateStr: string): string {
  const date = new Date(dateStr)
  const year = date.getFullYear()
  const month = date.getMonth() + 1
  const day = date.getDate()
  const hours = date.getHours()
  const minutes = date.getMinutes()

  if (hours === 0 && minutes === 0) {
    return `${year}년 ${month}월 ${day}일`
  }
  return `${year}년 ${month}월 ${day}일 ${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`
}

function enterEditMode() {
  if (!props.todo) return
  isEditMode.value = true
  editTitle.value = props.todo.title
  editContent.value = props.todo.content
  editAttachments.value = [...viewAttachments.value]
  sessionId.value = null
  isUploading.value = false
}

function cancelEdit() {
  // Discard session if created during edit
  if (fileUploaderRef.value) {
    fileUploaderRef.value.discardSession()
  }
  isEditMode.value = false
  if (props.todo) {
    editTitle.value = props.todo.title
    editContent.value = props.todo.content
    editAttachments.value = [...viewAttachments.value]
  }
  sessionId.value = null
  isUploading.value = false
}

function saveEdit() {
  if (!props.todo || !editTitle.value.trim()) return
  if (isUploading.value) {
    showWarning('파일 업로드가 진행 중입니다. 완료 후 다시 시도해주세요.')
    return
  }

  const orderedAttachmentIds = editAttachments.value.map((a) => a.id)

  emit('update', {
    id: props.todo.id,
    title: editTitle.value.trim(),
    content: editContent.value.trim(),
    attachmentSessionId: sessionId.value || undefined,
    orderedAttachmentIds: orderedAttachmentIds.length > 0 ? orderedAttachmentIds : undefined,
  })

  // Cleanup after save
  if (fileUploaderRef.value) {
    fileUploaderRef.value.cleanup()
  }
  isEditMode.value = false
  sessionId.value = null
  isUploading.value = false
}

function handleClose() {
  if (isEditMode.value && fileUploaderRef.value) {
    fileUploaderRef.value.discardSession()
  }
  isEditMode.value = false
  sessionId.value = null
  isUploading.value = false
  emit('close')
}

function onSessionCreated(sid: string) {
  sessionId.value = sid
}

function onAttachmentsUpdate(newAttachments: NormalizedAttachment[]) {
  editAttachments.value = newAttachments
}

function onUploadStart() {
  isUploading.value = true
}

function onUploadComplete() {
  isUploading.value = false
}

function onUploadError(message: string) {
  showError(message)
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen && todo"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @click.self="handleClose"
    >
      <div class="rounded-lg shadow-xl w-full max-w-[95vw] sm:max-w-xl max-h-[90dvh] sm:max-h-[90vh] overflow-hidden mx-2 sm:mx-4" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
        <!-- Header -->
        <div class="flex items-center justify-between p-3 sm:p-4" :style="{ borderBottom: '1px solid var(--dp-border-primary)' }">
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <h2 class="text-base sm:text-lg font-bold truncate" :style="{ color: 'var(--dp-text-primary)' }">{{ todo.title }}</h2>
              <span
                :class="[
                  'px-2 py-0.5 text-xs rounded-full flex-shrink-0',
                  isActive
                    ? 'bg-blue-100 text-blue-700'
                    : 'bg-gray-100 text-gray-600 line-through',
                ]"
              >
                {{ isActive ? '진행중' : '완료' }}
              </span>
            </div>
            <p class="text-xs" :style="{ color: 'var(--dp-text-muted)' }">
              {{ formatDate(todo.createdDate) }}
              <span v-if="todo.completedDate"> · 완료 {{ formatDate(todo.completedDate) }}</span>
            </p>
          </div>
          <button @click="handleClose" class="p-2 rounded-full transition flex-shrink-0">
            <X class="w-6 h-6" :style="{ color: 'var(--dp-text-primary)' }" />
          </button>
        </div>

        <!-- Content -->
        <div class="p-3 sm:p-4 overflow-y-auto max-h-[calc(90dvh-200px)] sm:max-h-[calc(90vh-200px)]">
          <!-- View Mode -->
          <template v-if="!isEditMode">
            <div class="space-y-4">
              <div v-if="todo.content">
                <p class="whitespace-pre-wrap" :style="{ color: 'var(--dp-text-primary)' }">{{ todo.content }}</p>
              </div>

              <!-- Attachments (View Mode) -->
              <div v-if="isLoadingAttachments" class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">
                첨부파일 로딩 중...
              </div>
              <AttachmentGrid
                v-else
                :attachments="viewAttachments"
                :columns="2"
              />
            </div>
          </template>

          <!-- Edit Mode -->
          <template v-else>
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
                  제목 <span class="text-red-500">*</span>
                </label>
                <input
                  v-model="editTitle"
                  type="text"
                  class="w-full px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
                />
              </div>

              <div>
                <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">내용</label>
                <textarea
                  v-model="editContent"
                  rows="6"
                  class="w-full px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
                ></textarea>
              </div>

              <!-- Attachments (Edit Mode) -->
              <div>
                <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">첨부파일</label>
                <FileUploader
                  v-if="isEditMode"
                  ref="fileUploaderRef"
                  context-type="TODO"
                  :target-context-id="todo?.id"
                  :existing-attachments="editAttachments"
                  @session-created="onSessionCreated"
                  @update:attachments="onAttachmentsUpdate"
                  @upload-start="onUploadStart"
                  @upload-complete="onUploadComplete"
                  @error="onUploadError"
                />
              </div>
            </div>
          </template>
        </div>

        <!-- Footer -->
        <div class="p-3 sm:p-4" :style="{ borderTop: '1px solid var(--dp-border-primary)' }">
          <template v-if="!isEditMode">
            <div class="flex items-center justify-between gap-2">
              <!-- Left: Back to list -->
              <button
                @click="emit('backToList')"
                class="flex items-center gap-1 px-3 py-2 rounded-lg transition btn-outline"
                title="목록으로 돌아가기"
              >
                <List class="w-4 h-4" />
                <span class="hidden sm:inline">목록</span>
              </button>

              <!-- Right: Action buttons -->
              <div class="flex gap-2">
                <button
                  @click="enterEditMode"
                  class="flex items-center justify-center gap-1 px-3 py-2 rounded-lg transition btn-outline"
                >
                  <Pencil class="w-4 h-4" />
                  <span class="hidden sm:inline">수정</span>
                </button>
                <button
                  @click="emit('delete', todo.id)"
                  class="flex items-center justify-center gap-1 px-3 py-2 border border-red-300 text-red-600 rounded-lg hover:bg-red-50 transition"
                >
                  <Trash2 class="w-4 h-4" />
                  <span class="hidden sm:inline">삭제</span>
                </button>
                <button
                  v-if="isActive"
                  @click="emit('complete', todo.id)"
                  class="flex items-center justify-center gap-1 px-3 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition"
                >
                  <Check class="w-4 h-4" />
                  <span class="hidden sm:inline">완료</span>
                </button>
                <button
                  v-else
                  @click="emit('reopen', todo.id)"
                  class="flex items-center justify-center gap-1 px-3 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
                >
                  <RotateCcw class="w-4 h-4" />
                  <span class="hidden sm:inline">재오픈</span>
                </button>
              </div>
            </div>
          </template>
          <template v-else>
            <div class="flex flex-col-reverse sm:flex-row gap-2 sm:justify-end">
              <button
                @click="cancelEdit"
                class="w-full sm:w-auto px-4 py-2 rounded-lg transition btn-outline"
              >
                취소
              </button>
              <button
                @click="saveEdit"
                :disabled="!editTitle.trim() || isUploading"
                class="w-full sm:w-auto px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition disabled:opacity-50"
              >
                {{ isUploading ? '업로드 중...' : '저장' }}
              </button>
            </div>
          </template>
        </div>
      </div>
    </div>
  </Teleport>
</template>
