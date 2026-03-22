<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { X, Calendar, ListTodo, Clock, CheckCircle2 } from 'lucide-vue-next'
import BaseModal from '@/components/common/BaseModal.vue'
import FileUploader from '@/components/common/FileUploader.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import FriendTagSelector from '@/components/common/FriendTagSelector.vue'
import type { NormalizedAttachment, TaggableFriend, TodoStatus } from '@/types'
import { useSwal } from '@/composables/useSwal'

interface Props {
  isOpen: boolean
  initialStatus?: TodoStatus
  friends?: TaggableFriend[]
}

const props = withDefaults(defineProps<Props>(), {
  initialStatus: 'TODO',
  friends: () => [],
})

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save', data: {
    title: string
    content: string
    status: TodoStatus
    dueDate?: string
    tagFriendIds?: number[]
    attachmentSessionId?: string
    orderedAttachmentIds?: string[]
  }): void
}>()

const title = ref('')
const content = ref('')
const status = ref<TodoStatus>('TODO')
const dueDate = ref('')
const tagFriendIds = ref<number[]>([])
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

const selectedTagSummaries = computed(() => {
  return tagFriendIds.value.flatMap((id) => {
    const friend = props.friends.find((candidate) => candidate.id === id)
    return friend ? [{ id: friend.id, name: friend.name }] : []
  })
})

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      // Reset form when opening
      title.value = ''
      content.value = ''
      status.value = props.initialStatus
      dueDate.value = ''
      tagFriendIds.value = []
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
  tagFriendIds.value = []
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
    tagFriendIds: tagFriendIds.value.length ? [...tagFriendIds.value] : undefined,
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
  tagFriendIds.value = []
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
  <BaseModal
    :is-open="isOpen"
    size="xl"
    height="default"
    @close="handleClose"
  >
    <!-- Header -->
    <div class="modal-header">
      <h2>할 일 추가</h2>
      <button @click="handleClose" class="p-2 rounded-full hover-close-btn cursor-pointer">
        <X class="w-6 h-6 text-dp-text-primary" />
      </button>
    </div>

    <!-- Content -->
    <div class="modal-body-form-compact">
      <!-- Status Selection -->
      <div>
        <label class="block text-sm font-medium mb-2 text-dp-text-secondary">상태</label>
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
        <label class="form-label">
          제목 <span class="text-dp-danger">*</span>
          <CharacterCounter :current="title.length" :max="50" />
        </label>
        <input
          v-model="title"
          type="text"
          maxlength="50"
          class="form-control"
          placeholder="할 일 제목을 입력하세요"
        />
      </div>

      <div>
        <label class="form-label">내용</label>
        <textarea
          v-model="content"
          rows="6"
          class="form-control"
          placeholder="상세 내용을 입력하세요"
        ></textarea>
      </div>

      <div>
        <label class="form-label">
          <Calendar class="w-4 h-4 inline-block mr-1 -mt-0.5" />
          마감일
        </label>
        <input
          v-model="dueDate"
          type="date"
          class="form-control"
        />
      </div>

      <div v-if="props.friends.length > 0">
        <label class="block text-sm font-medium mb-2 text-dp-text-secondary">친구 태그</label>
        <FriendTagSelector
          v-model="tagFriendIds"
          :friends="props.friends"
          :selected-summaries="selectedTagSummaries"
        />
      </div>

      <!-- Attachment Upload -->
      <div>
        <label class="form-label">첨부파일</label>
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

    <!-- Footer (sticky at bottom) -->
    <div class="modal-actions-compact modal-actions-end modal-footer-safe">
      <button
        @click="handleClose"
        class="flex-1 sm:flex-none px-4 py-2 rounded-lg transition btn-outline cursor-pointer"
      >
        취소
      </button>
      <button
        @click="handleSave"
        :disabled="!title.trim() || isUploading"
        class="flex-1 sm:flex-none px-4 py-2 bg-dp-accent text-dp-text-on-dark rounded-lg hover:bg-dp-accent-hover transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
      >
        {{ isUploading ? '업로드 중...' : '저장' }}
      </button>
    </div>
  </BaseModal>
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

/* TODO status - Blue */
.status-card-todo {
  background-color: color-mix(in srgb, var(--dp-accent) 8%, var(--dp-bg-tertiary));
  color: var(--dp-accent);
}

.status-card-todo:hover {
  background-color: color-mix(in srgb, var(--dp-accent) 15%, var(--dp-bg-tertiary));
}

.status-card-todo.status-card-selected {
  border-color: var(--dp-accent);
  background-color: color-mix(in srgb, var(--dp-accent) 25%, var(--dp-bg-tertiary));
  box-shadow: 0 0 0 3px var(--dp-accent-ring);
}

/* IN_PROGRESS status - Orange/Warning */
.status-card-in-progress {
  background-color: color-mix(in srgb, var(--dp-warning) 8%, var(--dp-bg-tertiary));
  color: var(--dp-warning);
}

.status-card-in-progress:hover {
  background-color: color-mix(in srgb, var(--dp-warning) 15%, var(--dp-bg-tertiary));
}

.status-card-in-progress.status-card-selected {
  border-color: var(--dp-warning);
  background-color: color-mix(in srgb, var(--dp-warning) 25%, var(--dp-bg-tertiary));
  box-shadow: 0 0 0 3px var(--dp-warning-ring);
}

/* DONE status - Green/Success */
.status-card-done {
  background-color: color-mix(in srgb, var(--dp-success) 8%, var(--dp-bg-tertiary));
  color: var(--dp-success);
}

.status-card-done:hover {
  background-color: color-mix(in srgb, var(--dp-success) 15%, var(--dp-bg-tertiary));
}

.status-card-done.status-card-selected {
  border-color: var(--dp-success);
  background-color: color-mix(in srgb, var(--dp-success) 25%, var(--dp-bg-tertiary));
  box-shadow: 0 0 0 3px var(--dp-success-ring);
}

</style>
