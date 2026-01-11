<script setup lang="ts">
import { ref, watch, toRef } from 'vue'
import { X, Calendar } from 'lucide-vue-next'
import FileUploader from '@/components/common/FileUploader.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import type { NormalizedAttachment } from '@/types'
import { useSwal } from '@/composables/useSwal'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'

interface Props {
  isOpen: boolean
}

const props = defineProps<Props>()

useBodyScrollLock(toRef(props, 'isOpen'))

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save', data: {
    title: string
    content: string
    dueDate?: string
    attachmentSessionId?: string
    orderedAttachmentIds?: string[]
  }): void
}>()

useEscapeKey(toRef(props, 'isOpen'), () => emit('close'))

const title = ref('')
const content = ref('')
const dueDate = ref('')
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
      dueDate.value = ''
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
  dueDate.value = ''
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
    dueDate: dueDate.value || undefined,
    attachmentSessionId: sessionId.value || undefined,
    orderedAttachmentIds: orderedAttachmentIds.length > 0 ? orderedAttachmentIds : undefined,
  })

  // Cleanup after save (don't discard session - it will be used by the todo)
  if (fileUploaderRef.value) {
    fileUploaderRef.value.cleanup()
  }
  title.value = ''
  content.value = ''
  dueDate.value = ''
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
      <div class="modal-container max-w-[95vw] sm:max-w-xl max-h-[90dvh] sm:max-h-[90vh]">
        <!-- Header -->
        <div class="modal-header">
          <h2>할 일 추가</h2>
          <button @click="handleClose" class="p-2 hover-bg-light rounded-full transition cursor-pointer">
            <X class="w-6 h-6" :style="{ color: 'var(--dp-text-primary)' }" />
          </button>
        </div>

        <!-- Content -->
        <div class="p-3 sm:p-4 overflow-y-auto overflow-x-hidden flex-1 min-h-0">
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
                제목 <span class="text-red-500">*</span>
                <CharacterCounter :current="title.length" :max="50" />
              </label>
              <input
                v-model="title"
                type="text"
                maxlength="50"
                class="w-full px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
                placeholder="할 일 제목을 입력하세요"
              />
            </div>

            <div>
              <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">내용</label>
              <textarea
                v-model="content"
                rows="6"
                class="w-full px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
                placeholder="상세 내용을 입력하세요 (선택사항)"
              ></textarea>
            </div>

            <div>
              <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
                <Calendar class="w-4 h-4 inline-block mr-1 -mt-0.5" />
                마감일
              </label>
              <input
                v-model="dueDate"
                type="date"
                class="w-full px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
              />
            </div>

            <!-- Attachment Upload -->
            <div>
              <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">첨부파일</label>
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

        <!-- Footer (sticky at bottom) -->
        <div class="p-3 sm:p-4 flex-shrink-0 flex flex-row gap-2 justify-end" :style="{ borderTop: '1px solid var(--dp-border-primary)' }">
          <button
            @click="handleClose"
            class="flex-1 sm:flex-none px-4 py-2 rounded-lg transition btn-outline cursor-pointer"
          >
            취소
          </button>
          <button
            @click="handleSave"
            :disabled="!title.trim() || isUploading"
            class="flex-1 sm:flex-none px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
          >
            {{ isUploading ? '업로드 중...' : '저장' }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
