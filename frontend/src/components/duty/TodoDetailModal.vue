<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import {
  X,
  MoreHorizontal,
  Pencil,
  Siren,
  Trash2,
  List,
  Calendar,
  Clock,
  CheckCircle2,
} from 'lucide-vue-next'
import { useI18n } from 'vue-i18n'
import BaseModal from '@/components/common/BaseModal.vue'
import OverflowMenu from '@/components/common/OverflowMenu.vue'
import FileUploader from '@/components/common/FileUploader.vue'
import AttachmentGrid from '@/components/common/AttachmentGrid.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import DatePickerField from '@/components/common/DatePickerField.vue'
import FriendTagSelector from '@/components/common/FriendTagSelector.vue'
import MemberTagChips from '@/components/common/MemberTagChips.vue'
import CopyTextButton from '@/components/common/CopyTextButton.vue'
import TodoStatusPicker from '@/components/todo/TodoStatusPicker.vue'
import { attachmentApi } from '@/api/attachment'
import { useSwal } from '@/composables/useSwal'
import { formatDateKorean } from '@/utils/date'
import { toDisplayTagMember } from '@/utils/tagMembers'
import type { NormalizedAttachment, TaggableFriend, Todo as TodoDto, TodoStatus } from '@/types'

type TodoDetailItem = Omit<TodoDto, 'attachments'>

const { showWarning, showError } = useSwal()
const { t } = useI18n()

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
  showBackToList?: boolean
  canReport?: boolean
  canChangeStatus?: boolean
  statusChangePending?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  startInEditMode: false,
  showBackToList: true,
  canReport: false,
  canChangeStatus: false,
  statusChangePending: false,
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
  (e: 'delete', todo: Pick<TodoDetailItem, 'id' | 'title'>): void
  (e: 'untagSelf', todo: Pick<TodoDetailItem, 'id' | 'title'>): void
  (e: 'status-change', status: TodoStatus): void
  (e: 'report', todo: Pick<TodoDetailItem, 'id' | 'title'>): void
  (e: 'backToList'): void
}>()

const isEditMode = ref(false)
const editTitle = ref('')
const editContent = ref('')
const editDueDate = ref('')
const editTagFriendIds = ref<number[]>([])
const editAttachments = ref<NormalizedAttachment[]>([])
const sessionId = ref<string | null>(null)
const isUploading = ref(false)
const fileUploaderRef = ref<InstanceType<typeof FileUploader> | null>(null)
const viewAttachments = ref<NormalizedAttachment[]>([])
const isLoadingAttachments = ref(false)

const selectedTagSummaries = computed(() => {
  return editTagFriendIds.value.flatMap((id) => {
    const friend = props.friends.find((candidate) => candidate.id === id)
    return friend ? [{ id: friend.id, name: friend.name }] : []
  })
})

const isEditTitleMissing = computed(() => !editTitle.value.trim())
const isEditSaveDisabled = computed(() => {
  return isEditTitleMissing.value || isUploading.value || props.statusChangePending
})

watch(
  () => props.isOpen,
  async (open) => {
    if (open && props.todo) {
      editTitle.value = props.todo.title
      editContent.value = props.todo.content
      editDueDate.value = props.todo.dueDate || ''
      editTagFriendIds.value = props.todo.tags.flatMap((tag) => tag.id == null ? [] : [tag.id])
      sessionId.value = null
      isUploading.value = false

      // Load attachments from API
      await loadAttachments()

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

function enterEditMode() {
  if (!props.todo || props.todo.isTagged || props.statusChangePending) return
  isEditMode.value = true
  editTitle.value = props.todo.title
  editContent.value = props.todo.content
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
    editDueDate.value = props.todo.dueDate || ''
    editTagFriendIds.value = props.todo.tags.flatMap((tag) => tag.id == null ? [] : [tag.id])
    editAttachments.value = [...viewAttachments.value]
  }
  sessionId.value = null
  isUploading.value = false
}

function saveEdit() {
  if (!props.todo) return
  if (props.statusChangePending) return
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
    status: props.todo.status,
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
    aria-labelledby="todo-detail-modal-title"
    @close="handleClose"
  >
    <template v-if="todo">
      <div class="modal-header">
        <div class="min-w-0 flex-1">
          <div class="flex flex-wrap items-center gap-2">
            <h2 id="todo-detail-modal-title" class="truncate">{{ todo.title }}</h2>
          </div>
          <div class="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1">
            <span class="inline-flex items-center gap-1 text-xs text-dp-text-muted">
              <Clock class="w-3.5 h-3.5 flex-shrink-0" />
              {{ formatDateKorean(todo.createdDate) }}
            </span>
          </div>
        </div>
        <button
          type="button"
          @click="handleClose"
          class="p-2 hover-close-btn rounded-full transition flex-shrink-0 cursor-pointer"
          :aria-label="t('common.actions.close')"
          :title="t('common.actions.close')"
        >
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

          <div v-if="todo.content" class="flex items-start gap-2">
            <p class="flex-1 min-w-0 whitespace-pre-wrap break-all text-dp-text-primary">{{ todo.content }}</p>
            <CopyTextButton :text="todo.content" class="shrink-0" />
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
            <DatePickerField
              v-model="editDueDate"
              :aria-label="t('duty.todo.fields.dueDate')"
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

      <div
        :class="[
          'modal-footer-safe',
          isEditMode
            ? 'modal-actions-compact modal-actions-end'
            : 'p-3 sm:p-4 flex-shrink-0 border-t border-dp-border-primary',
        ]"
      >
        <template v-if="!isEditMode">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <button
              v-if="showBackToList"
              @click="emit('backToList')"
              class="flex min-h-11 w-full items-center justify-center gap-1 px-3 py-2 text-sm rounded-lg transition btn-outline cursor-pointer sm:w-auto sm:flex-none"
              :title="t('duty.todo.actions.backToList')"
            >
              <List class="w-4 h-4" />
              <span class="whitespace-nowrap">{{ t('duty.todo.actions.list') }}</span>
            </button>

            <div class="todo-detail-footer-actions flex min-w-0 w-full items-stretch justify-end gap-2 sm:w-auto sm:flex-none">
              <div
                class="todo-detail-primary-actions grid min-w-0 flex-1 gap-2"
                :class="isTaggedTodo ? 'grid-cols-2' : 'grid-cols-3'"
              >
                <TodoStatusPicker
                  v-if="canChangeStatus && !isEditMode"
                  :status="todo.status"
                  :disabled="statusChangePending"
                  :footer="true"
                  class="todo-detail-primary-action min-w-0"
                  @change="emit('status-change', $event)"
                />
                <span
                  v-else-if="!canChangeStatus && !isEditMode"
                  :class="[
                    'todo-detail-primary-action flex min-h-11 min-w-0 items-center justify-center gap-1 rounded-lg px-3 py-2 text-center text-sm',
                    todo.status === 'TODO' ? 'bg-dp-bg-tertiary text-dp-text-primary' : '',
                    todo.status === 'IN_PROGRESS' ? 'bg-dp-warning-soft text-dp-warning' : '',
                    todo.status === 'DONE' ? 'bg-dp-success-soft text-dp-success' : '',
                  ]"
                  :aria-label="getStatusLabel(todo.status)"
                >
                  <CheckCircle2 v-if="todo.status === 'DONE'" class="h-4 w-4 flex-shrink-0" />
                  {{ getStatusLabel(todo.status) }}
                  <template v-if="todo.status === 'DONE' && todo.completedDate">
                    ({{ formatDateKorean(todo.completedDate) }})
                  </template>
                </span>

                <button
                  v-if="isTaggedTodo"
                  type="button"
                  class="todo-detail-primary-action flex min-h-11 min-w-0 w-full cursor-pointer items-center justify-center gap-1 rounded-lg border border-dp-border-primary px-3 py-2 text-center text-sm text-dp-text-primary transition hover:bg-dp-bg-hover disabled:cursor-not-allowed disabled:opacity-50"
                  @click="emit('untagSelf', { id: todo.id, title: todo.title })"
                  :disabled="statusChangePending"
                >
                  <X class="h-4 w-4 flex-shrink-0" />
                  <span class="min-w-0 whitespace-normal break-words text-center leading-tight">{{ t('duty.todo.actions.removeTag') }}</span>
                </button>

                <template v-if="!isTaggedTodo">
                  <button
                    @click="enterEditMode"
                    :disabled="statusChangePending"
                    class="todo-detail-primary-action flex min-h-11 min-w-0 w-full cursor-pointer items-center justify-center gap-1 rounded-lg border border-dp-accent-border px-3 py-2 text-center text-sm text-dp-accent transition hover:bg-dp-accent-soft disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    <Pencil class="w-4 h-4 flex-shrink-0" />
                    <span class="whitespace-nowrap">{{ t('duty.todo.actions.edit') }}</span>
                  </button>
                  <button
                    @click="emit('delete', { id: todo.id, title: todo.title })"
                    :disabled="statusChangePending"
                    class="todo-detail-primary-action flex min-h-11 min-w-0 w-full cursor-pointer items-center justify-center gap-1 rounded-lg border border-dp-danger-border px-3 py-2 text-center text-sm text-dp-danger transition hover:bg-dp-danger-soft disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    <Trash2 class="w-4 h-4 flex-shrink-0" />
                    <span class="whitespace-nowrap">{{ t('common.actions.delete') }}</span>
                  </button>
                </template>
              </div>

              <OverflowMenu
                v-if="canReport"
                class="shrink-0"
                :menu-label="t('report.actions.menu')"
                align="right"
                placement="above"
                trigger-class="todo-detail-report-trigger flex min-h-11 min-w-11 shrink-0 items-center justify-center rounded-lg px-2 py-2 text-sm transition btn-outline cursor-pointer"
              >
                <template #trigger>
                  <MoreHorizontal class="w-4 h-4" />
                </template>

                <button
                  v-if="canReport"
                  type="button"
                  role="menuitem"
                  class="flex w-full min-h-11 cursor-pointer items-center gap-2.5 px-4 py-2.5 text-left text-sm text-dp-danger transition hover:bg-dp-danger-soft"
                  @click="emit('report', { id: todo.id, title: todo.title })"
                >
                  <Siren class="h-4 w-4 flex-shrink-0" />
                  {{ t('report.actions.report') }}
                </button>
              </OverflowMenu>
            </div>
          </div>
        </template>
        <template v-else>
          <button
            @click="cancelEdit"
            class="flex-1 sm:flex-none px-4 py-2 rounded-lg transition btn-outline cursor-pointer"
          >
            {{ t('common.actions.close') }}
          </button>
          <button
            @click="saveEdit"
            :disabled="isEditSaveDisabled"
            class="flex-1 sm:flex-none px-4 py-2 bg-dp-accent text-dp-text-on-dark rounded-lg hover:bg-dp-accent-hover transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
          >
            {{ isUploading ? t('duty.common.uploading') : t('duty.todo.actions.save') }}
          </button>
        </template>
      </div>
    </template>
  </BaseModal>
</template>
