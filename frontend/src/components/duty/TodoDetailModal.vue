<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import {
  X,
  Pencil,
  Trash2,
  Check,
  RotateCcw,
  FileText,
  Download,
} from 'lucide-vue-next'
import FileUploader from '@/components/common/FileUploader.vue'
import { formatBytes } from '@/api/attachment'
import { useSwal } from '@/composables/useSwal'
import type { NormalizedAttachment } from '@/types'

const { showWarning, showError } = useSwal()

interface Attachment {
  id: string
  name: string
  originalFilename: string
  size: number
  contentType: string
  isImage: boolean
  hasThumbnail: boolean
  thumbnailUrl?: string
  downloadUrl: string
}

interface Todo {
  id: string
  title: string
  content: string
  status: 'ACTIVE' | 'COMPLETED'
  createdDate: string
  completedDate?: string
  attachments: Attachment[]
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
}>()

const isEditMode = ref(false)
const editTitle = ref('')
const editContent = ref('')
const editAttachments = ref<NormalizedAttachment[]>([])
const sessionId = ref<string | null>(null)
const isUploading = ref(false)
const fileUploaderRef = ref<InstanceType<typeof FileUploader> | null>(null)

// Convert backend attachment to normalized format
function toNormalizedAttachment(att: Attachment): NormalizedAttachment {
  return {
    id: att.id,
    name: att.name || att.originalFilename,
    originalFilename: att.originalFilename,
    contentType: att.contentType,
    size: att.size,
    thumbnailUrl: att.thumbnailUrl || null,
    downloadUrl: att.downloadUrl || `/api/attachments/${att.id}/download`,
    isImage: att.isImage,
    hasThumbnail: att.hasThumbnail,
    orderIndex: 0,
    createdAt: null,
    createdBy: null,
    previewUrl: null,
  }
}

watch(
  () => props.isOpen,
  (open) => {
    if (open && props.todo) {
      isEditMode.value = false
      editTitle.value = props.todo.title
      editContent.value = props.todo.content
      editAttachments.value = props.todo.attachments.map(toNormalizedAttachment)
      sessionId.value = null
      isUploading.value = false
    }
  }
)

const isActive = computed(() => props.todo?.status === 'ACTIVE')

function enterEditMode() {
  if (!props.todo) return
  isEditMode.value = true
  editTitle.value = props.todo.title
  editContent.value = props.todo.content
  editAttachments.value = props.todo.attachments.map(toNormalizedAttachment)
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
    editAttachments.value = props.todo.attachments.map(toNormalizedAttachment)
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
      <div class="bg-white rounded-lg shadow-xl w-full max-w-[95vw] sm:max-w-lg max-h-[90dvh] sm:max-h-[90vh] overflow-hidden mx-2 sm:mx-4">
        <!-- Header -->
        <div class="flex items-center justify-between p-3 sm:p-4 border-b border-gray-200">
          <div class="flex items-center gap-2">
            <h2 class="text-base sm:text-lg font-bold">할 일 상세</h2>
            <span
              :class="[
                'px-2 py-0.5 text-xs rounded-full',
                isActive
                  ? 'bg-blue-100 text-blue-700'
                  : 'bg-gray-100 text-gray-600 line-through',
              ]"
            >
              {{ isActive ? '진행중' : '완료' }}
            </span>
          </div>
          <button @click="handleClose" class="p-2 hover:bg-gray-100 rounded-full transition">
            <X class="w-6 h-6" />
          </button>
        </div>

        <!-- Content -->
        <div class="p-3 sm:p-4 overflow-y-auto max-h-[calc(90dvh-200px)] sm:max-h-[calc(90vh-200px)]">
          <!-- View Mode -->
          <template v-if="!isEditMode">
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-500 mb-1">제목</label>
                <p class="text-lg font-medium">{{ todo.title }}</p>
              </div>

              <div v-if="todo.content">
                <label class="block text-sm font-medium text-gray-500 mb-1">내용</label>
                <p class="text-gray-700 whitespace-pre-wrap">{{ todo.content }}</p>
              </div>

              <div class="text-sm text-gray-500">
                <p>등록: {{ todo.createdDate }}</p>
                <p v-if="todo.completedDate">완료: {{ todo.completedDate }}</p>
              </div>

              <!-- Attachments (View Mode) -->
              <div v-if="todo.attachments.length > 0">
                <label class="block text-sm font-medium text-gray-500 mb-2">첨부파일</label>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  <div
                    v-for="attachment in todo.attachments"
                    :key="attachment.id"
                    class="border border-gray-200 rounded-lg overflow-hidden"
                  >
                    <div
                      v-if="attachment.hasThumbnail"
                      class="aspect-square bg-gray-100 flex items-center justify-center"
                    >
                      <img
                        :src="attachment.thumbnailUrl"
                        :alt="attachment.originalFilename"
                        class="w-full h-full object-cover"
                      />
                    </div>
                    <div
                      v-else
                      class="aspect-square bg-gray-50 flex items-center justify-center"
                    >
                      <FileText class="w-12 h-12 text-gray-300" />
                    </div>
                    <div class="p-2">
                      <p class="text-sm truncate" :title="attachment.originalFilename">
                        {{ attachment.originalFilename }}
                      </p>
                      <div class="flex items-center justify-between mt-1">
                        <span class="text-xs text-gray-500">{{
                          formatBytes(attachment.size)
                        }}</span>
                        <a
                          :href="attachment.downloadUrl"
                          download
                          class="text-blue-600 hover:text-blue-700"
                        >
                          <Download class="w-4 h-4" />
                        </a>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </template>

          <!-- Edit Mode -->
          <template v-else>
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  제목 <span class="text-red-500">*</span>
                </label>
                <input
                  v-model="editTitle"
                  type="text"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">내용</label>
                <textarea
                  v-model="editContent"
                  rows="4"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                ></textarea>
              </div>

              <!-- Attachments (Edit Mode) -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">첨부파일</label>
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
        <div class="p-3 sm:p-4 border-t border-gray-200">
          <template v-if="!isEditMode">
            <div class="flex flex-col sm:flex-row items-stretch sm:items-center sm:justify-between gap-2">
              <div class="flex gap-2 order-2 sm:order-1">
                <button
                  v-if="isActive"
                  @click="emit('complete', todo.id)"
                  class="flex-1 sm:flex-initial flex items-center justify-center gap-1 px-3 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition"
                >
                  <Check class="w-4 h-4" />
                  완료
                </button>
                <button
                  v-else
                  @click="emit('reopen', todo.id)"
                  class="flex-1 sm:flex-initial flex items-center justify-center gap-1 px-3 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
                >
                  <RotateCcw class="w-4 h-4" />
                  재오픈
                </button>
              </div>
              <div class="flex gap-2 order-1 sm:order-2">
                <button
                  @click="enterEditMode"
                  class="flex-1 sm:flex-initial flex items-center justify-center gap-1 px-3 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition"
                >
                  <Pencil class="w-4 h-4" />
                  수정
                </button>
                <button
                  @click="emit('delete', todo.id)"
                  class="flex-1 sm:flex-initial flex items-center justify-center gap-1 px-3 py-2 border border-red-300 text-red-600 rounded-lg hover:bg-red-50 transition"
                >
                  <Trash2 class="w-4 h-4" />
                  삭제
                </button>
              </div>
            </div>
          </template>
          <template v-else>
            <div class="flex flex-col-reverse sm:flex-row gap-2 sm:justify-end">
              <button
                @click="cancelEdit"
                class="w-full sm:w-auto px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition"
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
