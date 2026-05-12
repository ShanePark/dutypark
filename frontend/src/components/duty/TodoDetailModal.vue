<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import {
  X,
  Pencil,
  Trash2,
  Check,
  RotateCcw,
  List,
  Calendar,
  ListTodo,
  Clock,
  CheckCircle2,
} from 'lucide-vue-next'
import { useI18n } from 'vue-i18n'
import BaseModal from '@/components/common/BaseModal.vue'
import FileUploader from '@/components/common/FileUploader.vue'
import AttachmentGrid from '@/components/common/AttachmentGrid.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import FriendTagSelector from '@/components/common/FriendTagSelector.vue'
import MemberTagChips from '@/components/common/MemberTagChips.vue'
import { attachmentApi } from '@/api/attachment'
import { useSwal } from '@/composables/useSwal'
import { formatDateKorean } from '@/utils/date'
import { toDisplayTagMember } from '@/utils/tagMembers'
import type { NormalizedAttachment, TaggableFriend, Todo as TodoDto, TodoStatus } from '@/types'

type TodoDetailItem = Omit<TodoDto, 'attachments'>

const { showWarning, showError } = useSwal()
const { t } = useI18n()

// Helper functions for status compatibility
function isActiveTodo(status: string): boolean {
  return status === 'TODO' || status === 'IN_PROGRESS'
}

function isDoneTodo(status: string): boolean {
  return status === 'DONE'
}

function getStatusLabel(status: string): string {
  switch (status) {
    case 'TODO':
      return t('duty.todo.status.todo')
    case 'IN_PROGRESS':
      return t('duty.todo.status.inProgress')
    case 'DONE':
      return t('duty.todo.status.done')
    default:
      return status
  }
}

interface Props {
  isOpen: boolean
  todo: TodoDetailItem | null
  friends?: TaggableFriend[]
  startInEditMode?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  startInEditMode: false,
  friends: () => [],
})

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'update', data: {
    id: string
    title: string
    content: string
    status: TodoStatus
    dueDate?: string | null
    tagFriendIds?: number[]
    attachmentSessionId?: string
    orderedAttachmentIds?: string[]
  }): void
  (e: 'complete', id: string): void
  (e: 'reopen', id: string): void
  (e: 'change-status', data: { id: string; status: TodoStatus }): void
  (e: 'delete', id: string): void
  (e: 'untagSelf', id: string): void
  (e: 'backToList'): void
}>()

const isEditMode = ref(false)
const editTitle = ref('')
const editContent = ref('')
const editStatus = ref<TodoStatus>('TODO')
const editDueDate = ref('')
const editTagFriendIds = ref<number[]>([])
const editAttachments = ref<NormalizedAttachment[]>([])
const sessionId = ref<string | null>(null)
const isUploading = ref(false)
const fileUploaderRef = ref<InstanceType<typeof FileUploader> | null>(null)
const viewAttachments = ref<NormalizedAttachment[]>([])
const isLoadingAttachments = ref(false)

const statusOptions = computed<Array<{ value: TodoStatus; label: string; icon: typeof ListTodo; colorClass: string }>>(() => [
  { value: 'TODO', label: t('duty.todo.status.todo'), icon: ListTodo, colorClass: 'status-card-todo' },
  { value: 'IN_PROGRESS', label: t('duty.todo.status.inProgress'), icon: Clock, colorClass: 'status-card-in-progress' },
  { value: 'DONE', label: t('duty.todo.status.done'), icon: CheckCircle2, colorClass: 'status-card-done' },
])

const selectedTagSummaries = computed(() => {
  return editTagFriendIds.value.flatMap((id) => {
    const friend = props.friends.find((candidate) => candidate.id === id)
    return friend ? [{ id: friend.id, name: friend.name }] : []
  })
})

const isEditTitleMissing = computed(() => !editTitle.value.trim())
const isEditSaveDisabled = computed(() => isEditTitleMissing.value || isUploading.value)

watch(
  () => props.isOpen,
  async (open) => {
    if (open && props.todo) {
      editTitle.value = props.todo.title
      editContent.value = props.todo.content
      editStatus.value = props.todo.status
      editDueDate.value = props.todo.dueDate || ''
      editTagFriendIds.value = props.todo.tags.flatMap((tag) => tag.id == null ? [] : [tag.id])
      sessionId.value = null
      isUploading.value = false

      // Load attachments from API
      await loadAttachments()

      // Start in edit mode if requested
      if (props.startInEditMode && !props.todo.isTagged) {
        isEditMode.value = true
      } else {
        isEditMode.value = false
      }
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
      editStatus.value = newTodo.status
      editDueDate.value = newTodo.dueDate || ''
      editTagFriendIds.value = newTodo.tags.flatMap((tag) => tag.id == null ? [] : [tag.id])
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

const isActive = computed(() => props.todo ? isActiveTodo(props.todo.status) : false)
const isTaggedTodo = computed(() => props.todo?.isTagged ?? false)

const taggedOwnerMembers = computed(() => {
  if (!props.todo?.isTagged) return []

  if (props.todo.taggedByMember?.name) {
    return [
      toDisplayTagMember(
        props.todo.taggedByMember,
        `todo-owner-${props.todo.taggedByMember.id ?? props.todo.id}`
      ),
    ]
  }

  if (!props.todo.owner) {
    return []
  }

  return [{
    key: `todo-owner-${props.todo.id}`,
    id: null,
    name: props.todo.owner,
    hasProfilePhoto: false,
    profilePhotoVersion: 0,
  }]
})

const todoTagMembers = computed(() => {
  if (!props.todo) return []
  const todoId = props.todo.id

  return props.todo.tags
    .filter((tag) => tag.name)
    .map((tag, index) => toDisplayTagMember(tag, `todo-tag-${tag.id ?? `${todoId}-${index}`}`))
})

const statusActionOptions = computed(() => {
  if (!props.todo) return []
  const { status } = props.todo
  return statusOptions.value.filter((option) => option.value !== status)
})


function enterEditMode() {
  if (!props.todo || props.todo.isTagged) return
  isEditMode.value = true
  editTitle.value = props.todo.title
  editContent.value = props.todo.content
  editStatus.value = props.todo.status
  editDueDate.value = props.todo.dueDate || ''
  editTagFriendIds.value = props.todo.tags.flatMap((tag) => tag.id == null ? [] : [tag.id])
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
    editStatus.value = props.todo.status
    editDueDate.value = props.todo.dueDate || ''
    editTagFriendIds.value = props.todo.tags.flatMap((tag) => tag.id == null ? [] : [tag.id])
    editAttachments.value = [...viewAttachments.value]
  }
  sessionId.value = null
  isUploading.value = false
}

function saveEdit() {
  if (!props.todo) return
  if (!editTitle.value.trim()) {
    return
  }
  if (isUploading.value) {
    showWarning(t('duty.todo.warnings.uploadInProgress'))
    return
  }

  const orderedAttachmentIds = editAttachments.value.map((a) => a.id)

  emit('update', {
    id: props.todo.id,
    title: editTitle.value.trim(),
    content: editContent.value.trim(),
    status: editStatus.value,
    dueDate: editDueDate.value || null,
    tagFriendIds: [...editTagFriendIds.value],
    attachmentSessionId: sessionId.value || undefined,
    orderedAttachmentIds: orderedAttachmentIds,
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
  <BaseModal
    :is-open="isOpen && !!todo"
    size="xl"
    height="default"
    @close="handleClose"
  >
    <template v-if="todo">
      <div class="modal-header">
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2">
            <h2 class="truncate">{{ todo.title }}</h2>
            <span
              :class="[
                'px-2 py-0.5 text-xs rounded-full flex-shrink-0',
                todo.status === 'TODO' ? 'bg-dp-bg-tertiary text-dp-text-primary' : '',
                todo.status === 'IN_PROGRESS' ? 'bg-dp-warning-soft text-dp-warning' : '',
                todo.status === 'DONE' ? 'bg-dp-success-soft text-dp-success line-through' : '',
              ]"
            >
              {{ getStatusLabel(todo.status) }}
            </span>
          </div>
          <p class="text-xs text-dp-text-muted">
            {{ formatDateKorean(todo.createdDate) }}
            <span v-if="todo.completedDate"> · {{ t('duty.todo.labels.completed') }} {{ formatDateKorean(todo.completedDate) }}</span>
          </p>
        </div>
        <button @click="handleClose" class="p-2 hover-close-btn rounded-full transition flex-shrink-0 cursor-pointer">
          <X class="w-6 h-6 text-dp-text-primary" />
        </button>
      </div>

      <div class="modal-body-form-compact">
        <template v-if="!isEditMode">
          <div v-if="todo.dueDate" class="flex items-center gap-2">
            <Calendar class="w-4 h-4" :class="todo.isOverdue ? 'text-dp-danger' : ''" :style="!todo.isOverdue ? { color: 'var(--dp-text-secondary)' } : undefined" />
            <span
              class="text-sm"
              :class="todo.isOverdue ? 'text-dp-danger font-medium' : ''"
              :style="!todo.isOverdue ? { color: 'var(--dp-text-secondary)' } : undefined"
            >
              {{ t('duty.todo.fields.dueDate') }}: {{ formatDateKorean(todo.dueDate) }}
              <span v-if="todo.isOverdue" class="text-dp-danger">({{ t('duty.todo.labels.overdue') }})</span>
            </span>
          </div>

          <div v-if="taggedOwnerMembers.length > 0" class="space-y-2">
            <div class="text-xs font-semibold text-dp-text-muted">{{ t('duty.todo.labels.owner') }}</div>
            <div class="flex flex-wrap items-center gap-2">
              <MemberTagChips :members="taggedOwnerMembers" density="compact" />
              <span class="text-xs text-dp-text-muted">{{ t('duty.todo.labels.taggedTodo') }}</span>
            </div>
          </div>

          <div v-else-if="todoTagMembers.length > 0" class="space-y-2">
            <div class="text-xs font-semibold text-dp-text-muted">{{ t('duty.todo.labels.taggedFriends') }}</div>
            <MemberTagChips :members="todoTagMembers" density="compact" />
          </div>

          <div v-if="todo.content">
            <p class="whitespace-pre-wrap break-all text-dp-text-primary">{{ todo.content }}</p>
          </div>

          <div v-if="isLoadingAttachments" class="text-sm text-dp-text-secondary">
            {{ t('duty.todo.labels.loadingAttachments') }}
          </div>
          <AttachmentGrid
            v-else
            :attachments="viewAttachments"
            :columns="2"
          />
        </template>

        <template v-else>
          <div>
            <label class="block text-sm font-medium mb-2 text-dp-text-secondary">{{ t('duty.todo.fields.status') }}</label>
            <div class="grid grid-cols-3 gap-2">
              <button
                v-for="option in statusOptions"
                :key="option.value"
                type="button"
                @click="editStatus = option.value"
                class="status-card cursor-pointer"
                :class="[option.colorClass, { 'status-card-selected': editStatus === option.value }]"
              >
                <component :is="option.icon" class="w-4 h-4" />
                <span class="text-xs font-medium">{{ option.label }}</span>
              </button>
            </div>
          </div>

          <div>
            <label class="form-label">
              {{ t('duty.todo.fields.title') }} <span class="text-dp-danger">*</span>
              <CharacterCounter :current="editTitle.length" :max="50" />
            </label>
            <input
              v-model="editTitle"
              type="text"
              maxlength="50"
              class="form-control"
              :aria-invalid="isEditTitleMissing"
            />
          </div>

          <div>
            <label class="form-label">{{ t('duty.todo.fields.content') }}</label>
            <textarea
              v-model="editContent"
              rows="6"
              class="form-control"
            ></textarea>
          </div>

          <div>
            <label class="form-label">
              <Calendar class="w-4 h-4 inline-block mr-1 -mt-0.5" />
              {{ t('duty.todo.fields.dueDate') }}
            </label>
            <input
              v-model="editDueDate"
              type="date"
              class="form-control"
            />
          </div>

          <div v-if="props.friends.length > 0">
            <label class="block text-sm font-medium mb-2 text-dp-text-secondary">{{ t('duty.todo.fields.friendTag') }}</label>
            <FriendTagSelector
              v-model="editTagFriendIds"
              :friends="props.friends"
              :selected-summaries="selectedTagSummaries"
            />
          </div>

          <div>
            <label class="form-label">{{ t('duty.todo.fields.attachments') }}</label>
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
        </template>
      </div>

      <div class="modal-footer-safe p-3 sm:p-4 flex-shrink-0 border-t border-dp-border-primary">
        <template v-if="!isEditMode">
          <div class="flex items-center justify-between gap-2">
            <button
              @click="emit('backToList')"
              class="flex items-center gap-1 px-3 py-2 rounded-lg transition btn-outline cursor-pointer"
              :title="t('duty.todo.actions.backToList')"
            >
              <List class="w-4 h-4" />
              <span class="hidden sm:inline">{{ t('duty.todo.actions.list') }}</span>
            </button>

            <div class="flex gap-2">
              <template v-if="isTaggedTodo">
                <button
                  v-for="option in statusActionOptions"
                  :key="option.value"
                  @click="emit('change-status', { id: todo.id, status: option.value })"
                  class="flex items-center justify-center gap-1 px-3 py-2 border border-dp-accent-border text-dp-accent rounded-lg hover:bg-dp-accent-soft transition cursor-pointer"
                >
                  <component :is="option.icon" class="w-4 h-4" />
                  <span class="hidden sm:inline">{{ option.label }}</span>
                </button>
                <button
                  @click="emit('untagSelf', todo.id)"
                  class="flex items-center justify-center gap-1 px-3 py-2 border border-dp-warning-border text-dp-warning rounded-lg hover:bg-dp-warning-soft transition cursor-pointer"
                >
                  <X class="w-4 h-4" />
                  <span class="hidden sm:inline">{{ t('duty.todo.actions.removeTag') }}</span>
                </button>
              </template>
              <template v-else>
                <button
                  @click="enterEditMode"
                  class="flex items-center justify-center gap-1 px-3 py-2 border border-dp-accent-border text-dp-accent rounded-lg hover:bg-dp-accent-soft transition cursor-pointer"
                >
                  <Pencil class="w-4 h-4" />
                  <span class="hidden sm:inline">{{ t('duty.todo.actions.edit') }}</span>
                </button>
                <button
                  @click="emit('delete', todo.id)"
                  class="flex items-center justify-center gap-1 px-3 py-2 border border-dp-danger-border text-dp-danger rounded-lg hover:bg-dp-danger-soft transition cursor-pointer"
                >
                  <Trash2 class="w-4 h-4" />
                  <span class="hidden sm:inline">{{ t('common.actions.delete') }}</span>
                </button>
                <button
                  v-if="isActive"
                  @click="emit('complete', todo.id)"
                  class="flex items-center justify-center gap-1 px-3 py-2 bg-dp-success text-dp-text-on-dark rounded-lg hover:bg-dp-success-hover transition cursor-pointer"
                >
                  <Check class="w-4 h-4" />
                  <span class="hidden sm:inline">{{ t('duty.todo.actions.complete') }}</span>
                </button>
                <button
                  v-else
                  @click="emit('reopen', todo.id)"
                  class="flex items-center justify-center gap-1 px-3 py-2 bg-dp-accent text-dp-text-on-dark rounded-lg hover:bg-dp-accent-hover transition cursor-pointer"
                >
                  <RotateCcw class="w-4 h-4" />
                  <span class="hidden sm:inline">{{ t('duty.todo.actions.reopen') }}</span>
                </button>
              </template>
            </div>
          </div>
        </template>
        <template v-else>
          <div class="flex justify-end">
            <div class="flex flex-row gap-2 justify-end">
            <button
              @click="cancelEdit"
              class="flex-1 sm:flex-none px-4 py-2 rounded-lg transition btn-outline cursor-pointer"
            >
              {{ t('common.actions.cancel') }}
            </button>
            <button
              @click="saveEdit"
              :disabled="isEditSaveDisabled"
              class="flex-1 sm:flex-none px-4 py-2 bg-dp-accent text-dp-text-on-dark rounded-lg hover:bg-dp-accent-hover transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
            >
              {{ isUploading ? t('duty.common.uploading') : t('duty.todo.actions.save') }}
            </button>
            </div>
          </div>
        </template>
      </div>
    </template>
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
</style>
