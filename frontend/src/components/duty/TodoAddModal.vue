<script setup lang="ts">
import { ref, watch, toRef } from 'vue'
import { X, Calendar, ListTodo, Clock, CheckCircle2 } from 'lucide-vue-next'
import FileUploader from '@/components/common/FileUploader.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import type { NormalizedAttachment, TodoStatus } from '@/types'
import { useSwal } from '@/composables/useSwal'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'

interface Props {
  isOpen: boolean
  initialStatus?: TodoStatus
}

const props = withDefaults(defineProps<Props>(), {
  initialStatus: 'TODO',
})

useBodyScrollLock(toRef(props, 'isOpen'))

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save', data: {
    title: string
    content: string
    status: TodoStatus
    dueDate?: string
    attachmentSessionId?: string
    orderedAttachmentIds?: string[]
  }): void
}>()

useEscapeKey(toRef(props, 'isOpen'), () => emit('close'))

const title = ref('')
const content = ref('')
const status = ref<TodoStatus>('TODO')
const dueDate = ref('')
const attachments = ref<NormalizedAttachment[]>([])
const sessionId = ref<string | null>(null)
const isUploading = ref(false)
const fileUploaderRef = ref<InstanceType<typeof FileUploader> | null>(null)

const { showWarning, showError } = useSwal()

const statusOptions: Array<{ value: TodoStatus; label: string; icon: typeof ListTodo; colorClass: string }> = [
  { value: 'TODO', label: '할일', icon: ListTodo, colorClass: 'status-card-todo' },
  { value: 'IN_PROGRESS', label: '진행중', icon: Clock, colorClass: 'status-card-in-progress' },
  { value: 'DONE', label: '완료', icon: CheckCircle2, colorClass: 'status-card-done' },
]

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      // Reset form when opening
      title.value = ''
      content.value = ''
      status.value = props.initialStatus
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
  status.value = 'TODO'
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
    status: status.value,
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
  status.value = 'TODO'
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
            <!-- Status Selection -->
            <div>
              <label class="block text-sm font-medium mb-2" :style="{ color: 'var(--dp-text-secondary)' }">상태</label>
              <div class="grid grid-cols-3 gap-2">
                <button
                  v-for="option in statusOptions"
                  :key="option.value"
                  type="button"
                  @click="status = option.value"
                  class="status-card cursor-pointer"
                  :class="[option.colorClass, { 'status-card-selected': status === option.value }]"
                >
                  <component :is="option.icon" class="w-4 h-4" />
                  <span class="text-xs font-medium">{{ option.label }}</span>
                </button>
              </div>
            </div>

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
                <span class="ml-1 text-xs font-normal due-date-optional">(선택)</span>
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

<style scoped>
.status-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.375rem;
  padding: 0.75rem 0.5rem;
  border-radius: 0.5rem;
  border: 2px solid transparent;
  transition: all 0.15s ease;
}

.status-card:hover {
  transform: translateY(-1px);
}

.status-card-todo {
  background-color: var(--dp-bg-tertiary);
  color: var(--dp-text-primary);
}

.status-card-todo:hover {
  background-color: var(--dp-bg-hover);
}

.status-card-todo.status-card-selected {
  border-color: var(--dp-text-primary);
  background-color: var(--dp-bg-hover);
}

.status-card-in-progress {
  background-color: color-mix(in srgb, var(--dp-warning) 15%, var(--dp-bg-tertiary));
  color: var(--dp-warning);
}

.status-card-in-progress:hover {
  background-color: color-mix(in srgb, var(--dp-warning) 25%, var(--dp-bg-tertiary));
}

.status-card-in-progress.status-card-selected {
  border-color: var(--dp-warning);
  background-color: color-mix(in srgb, var(--dp-warning) 25%, var(--dp-bg-tertiary));
}

.status-card-done {
  background-color: color-mix(in srgb, var(--dp-success) 15%, var(--dp-bg-tertiary));
  color: var(--dp-success);
}

.status-card-done:hover {
  background-color: color-mix(in srgb, var(--dp-success) 25%, var(--dp-bg-tertiary));
}

.status-card-done.status-card-selected {
  border-color: var(--dp-success);
  background-color: color-mix(in srgb, var(--dp-success) 25%, var(--dp-bg-tertiary));
}

.due-date-optional {
  color: var(--dp-text-muted);
}
</style>
