<script setup lang="ts">
import { ref, watch } from 'vue'
import { X } from 'lucide-vue-next'
import FileUploader from '@/components/common/FileUploader.vue'
import type { NormalizedAttachment } from '@/types'
import { useSwal } from '@/composables/useSwal'

interface Props {
  isOpen: boolean
}

const props = defineProps<Props>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save', data: {
    title: string
    content: string
    attachmentSessionId?: string
    orderedAttachmentIds?: string[]
  }): void
}>()

const title = ref('')
const content = ref('')
const attachments = ref<NormalizedAttachment[]>([])
const sessionId = ref<string | null>(null)
const isUploading = ref(false)
const fileUploaderRef = ref<InstanceType<typeof FileUploader> | null>(null)

const { showWarning, showError } = useSwal()

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      // Reset form when opening
      title.value = ''
      content.value = ''
      attachments.value = []
      sessionId.value = null
      isUploading.value = false
    }
  }
)

function handleClose() {
  // Discard session if exists
  if (fileUploaderRef.value) {
    fileUploaderRef.value.discardSession()
  }
  title.value = ''
  content.value = ''
  attachments.value = []
  sessionId.value = null
  isUploading.value = false
  emit('close')
}

function handleSave() {
  if (!title.value.trim()) {
    return
  }
  if (isUploading.value) {
    showWarning('파일 업로드가 진행 중입니다. 완료 후 다시 시도해주세요.')
    return
  }

  const orderedAttachmentIds = attachments.value.map((a) => a.id)

  emit('save', {
    title: title.value.trim(),
    content: content.value.trim(),
    attachmentSessionId: sessionId.value || undefined,
    orderedAttachmentIds: orderedAttachmentIds.length > 0 ? orderedAttachmentIds : undefined,
  })

  // Cleanup after save (don't discard session - it will be used by the todo)
  if (fileUploaderRef.value) {
    fileUploaderRef.value.cleanup()
  }
  title.value = ''
  content.value = ''
  attachments.value = []
  sessionId.value = null
  isUploading.value = false
  emit('close')
}

function onSessionCreated(sid: string) {
  sessionId.value = sid
}

function onAttachmentsUpdate(newAttachments: NormalizedAttachment[]) {
  attachments.value = newAttachments
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
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @click.self="handleClose"
    >
      <div class="bg-white rounded-lg shadow-xl w-full max-w-[95vw] sm:max-w-md max-h-[90dvh] sm:max-h-[90vh] overflow-hidden mx-2 sm:mx-4">
        <!-- Header -->
        <div class="flex items-center justify-between p-3 sm:p-4 border-b border-gray-200">
          <h2 class="text-base sm:text-lg font-bold">할 일 추가</h2>
          <button @click="handleClose" class="p-2 hover:bg-gray-100 rounded-full transition">
            <X class="w-6 h-6" />
          </button>
        </div>

        <!-- Content -->
        <div class="p-3 sm:p-4 overflow-y-auto max-h-[calc(90dvh-130px)] sm:max-h-[calc(90vh-130px)]">
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                제목 <span class="text-red-500">*</span>
              </label>
              <input
                v-model="title"
                type="text"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="할 일 제목을 입력하세요"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">내용</label>
              <textarea
                v-model="content"
                rows="4"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="상세 내용을 입력하세요 (선택사항)"
              ></textarea>
            </div>

            <!-- Attachment Upload -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">첨부파일</label>
              <FileUploader
                v-if="isOpen"
                ref="fileUploaderRef"
                context-type="TODO"
                @session-created="onSessionCreated"
                @update:attachments="onAttachmentsUpdate"
                @upload-start="onUploadStart"
                @upload-complete="onUploadComplete"
                @error="onUploadError"
              />
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="p-3 sm:p-4 border-t border-gray-200 flex flex-col-reverse sm:flex-row gap-2 sm:justify-end">
          <button
            @click="handleClose"
            class="w-full sm:w-auto px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition"
          >
            취소
          </button>
          <button
            @click="handleSave"
            :disabled="!title.trim() || isUploading"
            class="w-full sm:w-auto px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ isUploading ? '업로드 중...' : '저장' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
