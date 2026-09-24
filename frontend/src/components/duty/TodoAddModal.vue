<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch, type CSSProperties } from 'vue'
import { X, Calendar, Check, ChevronDown, ListTodo, Clock, CheckCircle2 } from '@lucide/vue'
import { useI18n } from 'vue-i18n'
import BaseModal from '@/components/common/BaseModal.vue'
import FileUploader from '@/components/common/FileUploader.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import DatePickerField from '@/components/common/DatePickerField.vue'
import FriendTagSelector from '@/components/common/FriendTagSelector.vue'
import { useEscapeKey } from '@/composables/useEscapeKey'
import type { NormalizedAttachment, TaggableFriend, TodoStatus } from '@/types'
import { useSwal } from '@/composables/useSwal'
import { hasUnsavedTodoChanges, type TodoDismissalDraft } from '@/utils/formDismissal'

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
const isDesktop = ref(
  typeof window !== 'undefined' && window.matchMedia('(min-width: 640px)').matches,
)
let desktopMediaQuery: MediaQueryList | null = null

const { showWarning, showError, confirm } = useSwal()

const { t } = useI18n()

const isTitleMissing = computed(() => !title.value.trim())

function emptyDraft(initialStatus: TodoStatus): TodoDismissalDraft {
  return {
    title: '',
    content: '',
    status: initialStatus,
    dueDate: '',
    tagFriendIds: [],
  }
}

const initialDraft = ref<TodoDismissalDraft>(emptyDraft(props.initialStatus))
let isHandlingClose = false

function hasUnsavedChanges() {
  return hasUnsavedTodoChanges(
    initialDraft.value,
    {
      title: title.value,
      content: content.value,
      status: status.value,
      dueDate: dueDate.value,
      tagFriendIds: tagFriendIds.value,
    },
    [],
    attachments.value.map((attachment) => attachment.id),
    sessionId.value !== null,
  )
}

async function confirmDiscardChanges() {
  return confirm(
    t('common.unsavedChanges.message'),
    t('common.unsavedChanges.title'),
    t('common.unsavedChanges.discard'),
    t('common.actions.cancel'),
    { animation: false },
  )
}

const statusOptions = computed<Array<{ value: TodoStatus; label: string; icon: typeof ListTodo; colorClass: string }>>(() => [
  { value: 'TODO', label: t('duty.todo.status.todo'), icon: ListTodo, colorClass: 'status-card-todo' },
  { value: 'IN_PROGRESS', label: t('duty.todo.status.inProgress'), icon: Clock, colorClass: 'status-card-in-progress' },
  { value: 'DONE', label: t('duty.todo.status.done'), icon: CheckCircle2, colorClass: 'status-card-done' },
])

const selectedStatusOption = computed(() => {
  return statusOptions.value.find((option) => option.value === status.value) ?? statusOptions.value[0]
})

const isStatusMenuOpen = ref(false)
const statusPickerRef = ref<HTMLDivElement | null>(null)
const statusTriggerRef = ref<HTMLButtonElement | null>(null)
const statusMenuRef = ref<HTMLDivElement | null>(null)
const statusMenuStyle = ref<CSSProperties | undefined>()
const statusMenuOpenUpward = ref(false)

function statusModifier(statusValue: TodoStatus) {
  return statusValue.toLowerCase().replace('_', '-')
}

function positionStatusMenu() {
  const trigger = statusTriggerRef.value
  if (!trigger || typeof window === 'undefined') return

  const rect = trigger.getBoundingClientRect()
  const viewportPadding = 8
  const menuGap = 8
  const estimatedMenuHeight = statusOptions.value.length * 48 + 16
  const menuWidth = Math.min(
    Math.max(rect.width, 180),
    Math.max(window.innerWidth - viewportPadding * 2, rect.width),
  )
  const left = Math.min(
    Math.max(rect.right - menuWidth, viewportPadding),
    Math.max(viewportPadding, window.innerWidth - menuWidth - viewportPadding),
  )
  const spaceBelow = window.innerHeight - rect.bottom - menuGap
  const spaceAbove = rect.top - menuGap
  statusMenuOpenUpward.value = spaceBelow < estimatedMenuHeight && spaceAbove > spaceBelow

  statusMenuStyle.value = {
    position: 'fixed',
    left: `${left}px`,
    width: `${menuWidth}px`,
    ...(statusMenuOpenUpward.value
      ? { bottom: `${Math.max(window.innerHeight - rect.top + menuGap, viewportPadding)}px` }
      : { top: `${Math.min(rect.bottom + menuGap, Math.max(viewportPadding, window.innerHeight - estimatedMenuHeight - viewportPadding))}px` }),
  }
}

function closeStatusMenu({ restoreFocus = false } = {}) {
  if (!isStatusMenuOpen.value) return
  isStatusMenuOpen.value = false
  statusMenuStyle.value = undefined
  if (restoreFocus) {
    void nextTick(() => statusTriggerRef.value?.focus())
  }
}

function toggleStatusMenu() {
  if (isStatusMenuOpen.value) {
    closeStatusMenu({ restoreFocus: true })
    return
  }

  isStatusMenuOpen.value = true
  void nextTick(() => {
    positionStatusMenu()
    statusMenuRef.value
      ?.querySelector<HTMLButtonElement>('[role="option"][aria-selected="true"]')
      ?.focus({ preventScroll: true })
  })
}

function selectStatus(nextStatus: TodoStatus) {
  status.value = nextStatus
  closeStatusMenu({ restoreFocus: true })
}

function handleStatusMenuKeydown(event: KeyboardEvent) {
  if (!['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) return
  event.preventDefault()

  const options = Array.from(
    statusMenuRef.value?.querySelectorAll<HTMLButtonElement>('[role="option"]') ?? [],
  )
  if (!options.length) return

  const currentIndex = options.indexOf(event.currentTarget as HTMLButtonElement)
  let nextIndex: number
  if (currentIndex < 0) {
    nextIndex = event.key === 'ArrowUp' || event.key === 'End' ? options.length - 1 : 0
  } else if (event.key === 'Home') {
    nextIndex = 0
  } else if (event.key === 'End') {
    nextIndex = options.length - 1
  } else if (event.key === 'ArrowDown') {
    nextIndex = (currentIndex + 1) % options.length
  } else {
    nextIndex = (currentIndex - 1 + options.length) % options.length
  }
  options[nextIndex]?.focus()
}

function handleStatusDocumentClick(event: MouseEvent) {
  if (!isStatusMenuOpen.value) return
  const target = event.target as Node
  if (statusPickerRef.value?.contains(target) || statusMenuRef.value?.contains(target)) return
  closeStatusMenu()
}

function handleStatusDocumentScroll(event: Event) {
  if (!isStatusMenuOpen.value) return
  const target = event.target as Node
  if (statusPickerRef.value?.contains(target) || statusMenuRef.value?.contains(target)) return
  closeStatusMenu()
}

const selectedTagSummaries = computed(() => {
  return tagFriendIds.value.flatMap((id) => {
    const friend = props.friends.find((candidate) => candidate.id === id)
    return friend ? [{ id: friend.id, name: friend.name }] : []
  })
})

function handleDesktopMediaChange(event: MediaQueryListEvent) {
  isDesktop.value = event.matches
  if (event.matches) {
    closeStatusMenu()
  }
}

useEscapeKey(isStatusMenuOpen, () => closeStatusMenu({ restoreFocus: true }))

onMounted(() => {
  desktopMediaQuery = window.matchMedia('(min-width: 640px)')
  isDesktop.value = desktopMediaQuery.matches
  desktopMediaQuery.addEventListener('change', handleDesktopMediaChange)
  document.addEventListener('click', handleStatusDocumentClick)
  document.addEventListener('scroll', handleStatusDocumentScroll, { capture: true, passive: true })
  window.addEventListener('resize', positionStatusMenu)
})

onUnmounted(() => {
  desktopMediaQuery?.removeEventListener('change', handleDesktopMediaChange)
  document.removeEventListener('click', handleStatusDocumentClick)
  document.removeEventListener('scroll', handleStatusDocumentScroll, { capture: true })
  window.removeEventListener('resize', positionStatusMenu)
})

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      // Reset form when opening
      initialDraft.value = emptyDraft(props.initialStatus)
      title.value = ''
      content.value = ''
      status.value = props.initialStatus
      dueDate.value = ''
      tagFriendIds.value = []
      attachments.value = []
      sessionId.value = null
      isUploading.value = false
    } else {
      closeStatusMenu()
    }
  }
)

async function handleClose() {
  if (isHandlingClose || isUploading.value) return
  isHandlingClose = true
  try {
    if (hasUnsavedChanges() && !(await confirmDiscardChanges())) return

    closeStatusMenu()
    await fileUploaderRef.value?.discardSession()
    title.value = ''
    content.value = ''
    status.value = 'TODO'
    dueDate.value = ''
    tagFriendIds.value = []
    attachments.value = []
    sessionId.value = null
    isUploading.value = false
    emit('close')
  } finally {
    isHandlingClose = false
  }
}

function handleSave() {
  if (!title.value.trim()) {
    return
  }
  if (isUploading.value) {
    showWarning(t('duty.todo.warnings.uploadInProgress'))
    return
  }

  const orderedAttachmentIds = attachments.value.map((a) => a.id)

  closeStatusMenu()
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
    size="3xl"
    height="fit"
    aria-labelledby="todo-add-modal-title"
    @close="handleClose"
  >
    <!-- Header -->
    <div class="modal-header">
      <h2 id="todo-add-modal-title">{{ t('duty.todo.actions.add') }}</h2>
      <button
        type="button"
        @click="handleClose"
        class="p-2 rounded-full hover-close-btn cursor-pointer disabled:cursor-not-allowed disabled:opacity-50"
        :disabled="isUploading"
        :aria-label="t('common.actions.close')"
        :title="t('common.actions.close')"
      >
        <X class="w-6 h-6 text-dp-text-primary" />
      </button>
    </div>

    <!-- Content -->
    <div class="todo-add-modal-body">
      <div class="todo-add-modal-columns">
        <section class="todo-add-modal-main-column" aria-labelledby="todo-add-main-fields-title">
          <h3 id="todo-add-main-fields-title" class="sr-only">{{ t('duty.todo.fields.title') }}</h3>
          <div class="todo-add-modal-title-row">
            <div class="todo-add-modal-title-field">
              <label class="form-label" for="todo-add-title">
                {{ t('duty.todo.fields.title') }} <span class="text-dp-danger">*</span>
                <CharacterCounter :current="title.length" :max="50" />
              </label>
              <input
                id="todo-add-title"
                v-model="title"
                type="text"
                maxlength="50"
                class="form-control"
                :placeholder="t('duty.todo.placeholders.title')"
                :aria-invalid="isTitleMissing"
              />
            </div>

            <div class="todo-add-modal-mobile-status">
              <label class="form-label" for="todo-add-mobile-status-trigger">{{ t('duty.todo.fields.status') }}</label>
              <div ref="statusPickerRef" class="todo-add-modal-status-picker">
                <button
                  id="todo-add-mobile-status-trigger"
                  ref="statusTriggerRef"
                  type="button"
                  class="todo-add-modal-status-trigger"
                  :class="`todo-add-modal-status-trigger--${statusModifier(status)}`"
                  :aria-label="`${t('duty.todo.fields.status')}: ${selectedStatusOption?.label ?? ''}`"
                  aria-haspopup="listbox"
                  aria-controls="todo-add-mobile-status-menu"
                  :aria-expanded="isStatusMenuOpen"
                  @click.stop="toggleStatusMenu"
                >
                  <component
                    :is="selectedStatusOption?.icon"
                    class="todo-add-modal-status-trigger-icon"
                    aria-hidden="true"
                  />
                  <span class="todo-add-modal-status-trigger-label">
                    {{ selectedStatusOption?.label }}
                  </span>
                  <ChevronDown
                    class="todo-add-modal-status-trigger-chevron"
                    :class="{ 'todo-add-modal-status-trigger-chevron--open': isStatusMenuOpen }"
                    aria-hidden="true"
                  />
                </button>

                <Teleport to="body">
                  <div
                    v-if="isStatusMenuOpen"
                    ref="statusMenuRef"
                    id="todo-add-mobile-status-menu"
                    class="todo-add-modal-status-menu"
                    role="listbox"
                    :aria-label="t('duty.todo.fields.status')"
                    :style="statusMenuStyle"
                    @click.stop
                    @keydown.esc.stop.prevent="closeStatusMenu({ restoreFocus: true })"
                  >
                    <button
                      v-for="option in statusOptions"
                      :key="option.value"
                      type="button"
                      role="option"
                      class="todo-add-modal-status-option"
                      :class="[
                        `todo-add-modal-status-option--${statusModifier(option.value)}`,
                        { 'todo-add-modal-status-option--selected': option.value === status },
                      ]"
                      :aria-selected="option.value === status"
                      @click.stop="selectStatus(option.value)"
                      @keydown="handleStatusMenuKeydown"
                    >
                      <component :is="option.icon" class="todo-add-modal-status-option-icon" aria-hidden="true" />
                      <span>{{ option.label }}</span>
                      <Check
                        v-if="option.value === status"
                        class="todo-add-modal-status-option-check"
                        aria-hidden="true"
                      />
                    </button>
                  </div>
                </Teleport>
              </div>
            </div>
          </div>

          <div class="todo-add-modal-status-section">
            <label class="form-label">{{ t('duty.todo.fields.status') }}</label>
            <div class="todo-add-modal-status-grid">
              <button
                v-for="option in statusOptions"
                :key="option.value"
                type="button"
                @click="status = option.value"
                class="status-card cursor-pointer"
                :class="[option.colorClass, { 'status-card-selected': status === option.value }]"
                :aria-pressed="status === option.value"
              >
                <component :is="option.icon" class="w-4 h-4" />
                <span class="text-xs font-medium">{{ option.label }}</span>
              </button>
            </div>
          </div>

          <div class="todo-add-modal-content-field">
            <label class="form-label" for="todo-add-content">{{ t('duty.todo.fields.content') }}</label>
            <textarea
              id="todo-add-content"
              v-model="content"
              rows="8"
              class="form-control todo-add-modal-content-input"
              :placeholder="t('duty.todo.placeholders.content')"
            ></textarea>
          </div>
        </section>

        <section class="todo-add-modal-side-column" aria-labelledby="todo-add-options-title">
          <h3 id="todo-add-options-title" class="sr-only">{{ t('duty.todo.fields.dueDate') }}</h3>

          <div class="todo-add-modal-side-section">
            <label class="form-label" for="todo-add-due-date">
              <Calendar class="w-4 h-4 inline-block mr-1 -mt-0.5" />
              {{ t('duty.todo.fields.dueDate') }}
            </label>
            <DatePickerField
              id="todo-add-due-date"
              v-model="dueDate"
              :aria-label="t('duty.todo.fields.dueDate')"
            />
          </div>

          <div v-if="props.friends.length > 0" class="todo-add-modal-side-section">
            <label class="form-label">{{ t('duty.todo.fields.friendTag') }}</label>
            <FriendTagSelector
              v-model="tagFriendIds"
              :friends="props.friends"
              :selected-summaries="selectedTagSummaries"
              :always-expanded="isDesktop"
              appearance="flat"
            />
          </div>

          <div class="todo-add-modal-side-section">
            <label class="form-label">{{ t('duty.todo.fields.attachments') }}</label>
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
        </section>
      </div>
    </div>

    <!-- Footer (sticky at bottom) -->
    <div class="todo-add-modal-footer modal-actions-compact modal-actions-end modal-footer-safe">
      <button
        @click="handleClose"
        class="flex-1 sm:flex-none px-4 py-2 rounded-lg transition btn-outline cursor-pointer disabled:cursor-not-allowed disabled:opacity-50"
        :disabled="isUploading"
      >
        {{ t('common.actions.close') }}
      </button>
      <button
        @click="handleSave"
        :disabled="isTitleMissing || isUploading"
        class="flex-1 sm:flex-none px-4 py-2 bg-dp-accent text-dp-text-on-dark rounded-lg hover:bg-dp-accent-hover transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
      >
        {{ isUploading ? t('duty.common.uploading') : t('duty.todo.actions.save') }}
      </button>
    </div>
  </BaseModal>
</template>

<style scoped>
.todo-add-modal-body {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  padding: 0.75rem;
  overflow-x: hidden;
  overflow-y: auto;
}

.todo-add-modal-columns {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 1rem;
  align-items: stretch;
}

.todo-add-modal-title-row {
  display: block;
}

.todo-add-modal-title-field,
.todo-add-modal-mobile-status {
  min-width: 0;
}

.todo-add-modal-mobile-status {
  display: none;
}

.todo-add-modal-main-column,
.todo-add-modal-side-column {
  display: flex;
  height: 100%;
  min-width: 0;
  flex-direction: column;
  gap: 1rem;
}

.todo-add-modal-content-field {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  gap: 0.5rem;
}

.todo-add-modal-status-section {
  display: grid;
  min-width: 0;
  gap: 0.5rem;
}

.todo-add-modal-content-input {
  flex: 1;
  min-height: 12rem;
  resize: vertical;
}

.todo-add-modal-side-section {
  display: grid;
  min-width: 0;
  gap: 0.5rem;
}

.todo-add-modal-status-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.5rem;
}

.todo-add-modal-status-picker {
  position: relative;
  width: 100%;
  min-width: 0;
}

.todo-add-modal-status-trigger {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  width: 100%;
  min-height: 2.625rem;
  min-width: 0;
  padding: 0.5rem 0.625rem;
  border: 1px solid var(--dp-border-primary);
  border-radius: 0.5rem;
  color: var(--dp-text-primary);
  background: var(--dp-bg-secondary);
  font-size: 0.875rem;
  font-weight: 600;
  text-align: left;
  cursor: pointer;
  transition: background-color 0.15s ease, border-color 0.15s ease, box-shadow 0.15s ease;
}

.todo-add-modal-status-trigger:hover,
.todo-add-modal-status-trigger:focus-visible {
  outline: none;
  border-color: var(--dp-border-hover);
  box-shadow: 0 0 0 2px var(--dp-accent-ring);
}

.todo-add-modal-status-trigger--todo {
  color: var(--dp-accent);
  background: color-mix(in srgb, var(--dp-accent) 10%, var(--dp-bg-secondary));
  border-color: var(--dp-accent-border);
}

.todo-add-modal-status-trigger--in-progress {
  color: var(--dp-warning);
  background: color-mix(in srgb, var(--dp-warning) 10%, var(--dp-bg-secondary));
  border-color: var(--dp-warning-border);
}

.todo-add-modal-status-trigger--done {
  color: var(--dp-success);
  background: color-mix(in srgb, var(--dp-success) 10%, var(--dp-bg-secondary));
  border-color: var(--dp-success-border);
}

.todo-add-modal-status-trigger-icon,
.todo-add-modal-status-trigger-chevron {
  width: 1rem;
  height: 1rem;
  flex-shrink: 0;
}

.todo-add-modal-status-trigger-label {
  min-width: 0;
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.todo-add-modal-status-trigger-chevron {
  color: var(--dp-text-muted);
  transition: transform 0.15s ease;
}

.todo-add-modal-status-trigger-chevron--open {
  transform: rotate(180deg);
}

.todo-add-modal-status-menu {
  z-index: 10000;
  max-height: min(18rem, calc(100vh - 1rem));
  overflow: hidden;
  padding: 0.375rem;
  border: 1px solid var(--dp-border-primary);
  border-radius: 0.75rem;
  background: var(--dp-bg-card);
  box-shadow: var(--dp-shadow-lg);
}

.todo-add-modal-status-option {
  display: flex;
  align-items: center;
  gap: 0.625rem;
  width: 100%;
  min-height: 2.75rem;
  padding: 0.5rem 0.625rem;
  border: 0;
  border-radius: 0.5rem;
  color: var(--dp-text-primary);
  background: transparent;
  font-size: 0.875rem;
  font-weight: 500;
  text-align: left;
  cursor: pointer;
  transition: background-color 0.15s ease, color 0.15s ease;
}

.todo-add-modal-status-option:hover,
.todo-add-modal-status-option:focus-visible {
  outline: none;
  background: var(--dp-bg-hover);
}

.todo-add-modal-status-option--selected {
  font-weight: 700;
}

.todo-add-modal-status-option--todo {
  color: var(--dp-accent);
}

.todo-add-modal-status-option--in-progress {
  color: var(--dp-warning);
}

.todo-add-modal-status-option--done {
  color: var(--dp-success);
}

.todo-add-modal-status-option--todo.todo-add-modal-status-option--selected {
  background: var(--dp-accent-bg);
}

.todo-add-modal-status-option--in-progress.todo-add-modal-status-option--selected {
  background: var(--dp-warning-bg);
}

.todo-add-modal-status-option--done.todo-add-modal-status-option--selected {
  background: var(--dp-success-bg);
}

.todo-add-modal-status-option-icon,
.todo-add-modal-status-option-check {
  width: 1rem;
  height: 1rem;
  flex-shrink: 0;
}

.todo-add-modal-status-option-check {
  margin-left: auto;
}

@media (min-width: 640px) {
  .todo-add-modal-body {
    height: min(32.875rem, calc(var(--dp-viewport-height, 100dvh) - 10rem));
    flex: 1 1 auto;
    padding: 1rem;
    overflow: hidden;
  }

  .todo-add-modal-columns {
    flex: 1;
    min-height: 0;
    grid-template-columns: minmax(0, 1.3fr) minmax(19rem, 0.9fr);
    gap: 0;
  }

  .todo-add-modal-main-column {
    padding-right: 1.25rem;
  }

  .todo-add-modal-side-column {
    min-height: 0;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--dp-border-secondary) transparent;
    border-left: 1px solid var(--dp-border-primary);
    padding-left: 1.25rem;
    gap: 0.5rem;
  }

  .todo-add-modal-side-column::-webkit-scrollbar {
    width: 0.375rem;
  }

  .todo-add-modal-side-column::-webkit-scrollbar-thumb {
    background: var(--dp-border-secondary);
    border-radius: 9999px;
  }

  .todo-add-modal-side-column::-webkit-scrollbar-track {
    background: transparent;
  }

  .todo-add-modal-side-column > .todo-add-modal-side-section:last-child {
    margin-top: auto;
  }

  .todo-add-modal-side-section > .friend-tag-selector {
    width: 100%;
    min-width: 0;
    max-width: 100%;
  }

  /* The options rail is deliberately denser than the full ScheduleForm. It keeps the inline
     selector readable while leaving enough room for the date and attachment controls beside the
     large content field. */
  .todo-add-modal-side-section {
    gap: 0.25rem;
  }

  .todo-add-modal-side-section > .form-label {
    margin-bottom: 0;
  }

  .todo-add-modal-side-column :deep(.file-uploader) {
    gap: 0.5rem;
  }

  .todo-add-modal-side-column :deep(.drop-zone) {
    display: grid;
    grid-template-columns: auto minmax(0, 1fr);
    gap: 0.25rem 0.5rem;
    padding: 0.375rem 0.5rem;
  }

  .todo-add-modal-side-column :deep(.drop-text-desktop) {
    font-size: 0.75rem;
    line-height: 1rem;
  }

  .todo-add-modal-side-column :deep(.drop-hint-desktop) {
    grid-column: 2;
    margin: 0;
    font-size: 0.75rem;
    line-height: 1rem;
  }

  .todo-add-modal-content-input {
    min-height: 16rem;
  }
}

@media (max-width: 639px) {
  .todo-add-modal-body {
    height: min(35rem, calc(var(--dp-viewport-height, 100dvh) - 9.5rem));
    flex: 1 1 auto;
    padding: 0.625rem;
    padding-block: 0.5rem;
    overflow-y: auto;
  }

  .todo-add-modal-columns {
    gap: 0.625rem;
  }

  .todo-add-modal-main-column,
  .todo-add-modal-side-column {
    height: auto;
    gap: 0.75rem;
  }

  .todo-add-modal-side-section {
    gap: 0.25rem;
  }

  .todo-add-modal-content-input {
    min-height: 7rem;
  }

  .todo-add-modal-title-row {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 8rem;
    gap: 0.5rem;
    align-items: end;
  }

  .todo-add-modal-mobile-status {
    display: grid;
    gap: 0.25rem;
  }

  .todo-add-modal-mobile-status .form-label {
    margin-bottom: 0;
  }

  .todo-add-modal-status-trigger {
    min-height: 2.625rem;
    padding-inline: 0.5rem;
    font-size: 1rem;
  }

  .todo-add-modal-status-section {
    display: none;
  }

  .todo-add-modal-status-grid {
    gap: 0.375rem;
  }

  .todo-add-modal-main-column {
    padding-right: 0;
  }

  .todo-add-modal-side-column {
    border-left: none;
    padding-left: 0;
  }

}

.status-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.375rem;
  min-height: 3.25rem;
  padding: 0.625rem 0.35rem;
  border-radius: 0.5rem;
  border: 2px solid transparent;
  transition: all 0.15s ease;
}

.status-card:hover {
  transform: translateY(-1px);
}

.status-card:focus-visible {
  outline: 2px solid currentColor;
  outline-offset: 2px;
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

/* Keep the compact status cards touch-sized on narrow screens after the shared card defaults. */
@media (max-width: 639px) {
  .todo-add-modal-content-input {
    height: 7rem;
    block-size: 7rem;
    flex: none;
  }

  .status-card {
    min-height: 2.75rem;
    gap: 0.25rem;
    padding: 0.5rem 0.25rem;
  }
}

@media (max-width: 639px) and (max-height: 700px) {
  .todo-add-modal-content-input {
    min-height: 6rem;
    height: 6rem;
    block-size: 6rem;
  }
}

</style>
