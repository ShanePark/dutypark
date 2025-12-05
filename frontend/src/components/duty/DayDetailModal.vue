<script setup lang="ts">
import { ref, computed, watch, nextTick, onUnmounted, toRef } from 'vue'
import Sortable from 'sortablejs'
import {
  X,
  Plus,
  Trash2,
  Pencil,
  GripVertical,
  Paperclip,
  Lock,
  User,
  UserPlus,
  Check,
} from 'lucide-vue-next'
import FileUploader from '@/components/common/FileUploader.vue'
import AttachmentGrid from '@/components/common/AttachmentGrid.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import type { NormalizedAttachment } from '@/types'
import { normalizeAttachment } from '@/api/attachment'
import { useSwal } from '@/composables/useSwal'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
import { getVisibilityIcon, getVisibilityLabel } from '@/utils/visibility'
import { extractDatePart } from '@/utils/date'

const { showWarning, showError } = useSwal()

interface Schedule {
  id: string
  content: string
  description?: string
  startDateTime: string
  endDateTime: string
  visibility: 'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE'
  isMine: boolean
  isTagged: boolean
  taggedBy?: string
  attachments?: Array<{
    id: string
    originalFilename: string
    contentType: string
    size: number
    thumbnailUrl?: string
    hasThumbnail: boolean
  }>
  tags?: Array<{ id: number; name: string }>
  daysFromStart?: number
  totalDays?: number
}

interface DutyType {
  id: number | null
  name: string
  color: string | null
}

interface Props {
  isOpen: boolean
  date: { year: number; month: number; day: number }
  duty?: { dutyType: string; dutyColor: string }
  schedules: Schedule[]
  dutyTypes: DutyType[]
  canEdit: boolean
  batchEditMode: boolean
  friends: Array<{ id: number; name: string }>
  memberId: number
}

const props = withDefaults(defineProps<Props>(), {
  schedules: () => [],
  dutyTypes: () => [],
  friends: () => [],
})

useBodyScrollLock(toRef(props, 'isOpen'))

interface ScheduleSaveData {
  id?: string
  content: string
  description: string
  startDateTime: string
  endDateTime: string
  visibility: 'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE'
  attachmentSessionId?: string | null
  orderedAttachmentIds?: string[]
}

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'changeDutyType', dutyTypeId: number | null): void
  (e: 'createSchedule', data: ScheduleSaveData): void
  (e: 'editSchedule', data: ScheduleSaveData): void
  (e: 'deleteSchedule', scheduleId: string): void
  (e: 'reorderSchedules', scheduleIds: string[]): void
  (e: 'addTag', scheduleId: string, friendId: number): void
  (e: 'removeTag', scheduleId: string, friendId: number): void
  (e: 'untagSelf', scheduleId: string): void
}>()

useEscapeKey(toRef(props, 'isOpen'), () => emit('close'))

const isCreateMode = ref(false)
const isEditMode = ref(false)
const editingScheduleId = ref<string | null>(null)
const fileUploaderRef = ref<InstanceType<typeof FileUploader> | null>(null)
const isUploading = ref(false)
const scheduleListRef = ref<HTMLElement | null>(null)
const contentRef = ref<HTMLElement | null>(null)
const isDragging = ref(false)
let sortableInstance: Sortable | null = null

// Local duty state for immediate UI feedback
const selectedDutyType = ref<string | null>(null)

// Sync selectedDutyType with props.duty
watch(
  () => props.duty?.dutyType,
  (newVal) => {
    selectedDutyType.value = newVal ?? null
  },
  { immediate: true }
)

// Handle duty type change with immediate UI feedback
function handleDutyTypeChange(dutyTypeId: number | null, dutyTypeName: string) {
  selectedDutyType.value = dutyTypeName
  emit('changeDutyType', dutyTypeId)
}

const newSchedule = ref({
  content: '',
  description: '',
  startDate: '',
  startTime: '00:00',
  endDateTime: '',
  visibility: 'FAMILY' as 'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE',
})
const editAttachments = ref<NormalizedAttachment[]>([])

const taggingScheduleId = ref<string | null>(null)
const untagConfirmScheduleId = ref<string | null>(null)

function openUntagConfirmModal(scheduleId: string) {
  untagConfirmScheduleId.value = scheduleId
}

function closeUntagConfirmModal() {
  untagConfirmScheduleId.value = null
}

function confirmUntag() {
  if (untagConfirmScheduleId.value) {
    emit('untagSelf', untagConfirmScheduleId.value)
    untagConfirmScheduleId.value = null
  }
}

const formattedDate = computed(() => {
  const { year, month, day } = props.date
  const date = new Date(year, month - 1, day)
  const weekDays = ['일', '월', '화', '수', '목', '금', '토']
  const dayOfWeek = weekDays[date.getDay()]
  return `${year}년 ${month}월 ${day}일 (${dayOfWeek})`
})

const hasDraggableSchedules = computed(() => {
  return props.canEdit && props.schedules.filter(s => !s.isTagged).length > 1
})

function initSortable() {
  if (!scheduleListRef.value || !props.canEdit) return
  destroySortable()
  if (!hasDraggableSchedules.value) return

  sortableInstance = new Sortable(scheduleListRef.value, {
    animation: 150,
    handle: '.schedule-drag-handle',
    draggable: '.schedule-item:not(.schedule-tagged)',
    ghostClass: 'schedule-ghost',
    chosenClass: 'schedule-chosen',
    dragClass: 'schedule-dragging',
    onStart: () => {
      isDragging.value = true
    },
    onEnd: () => {
      isDragging.value = false
      const items = scheduleListRef.value?.querySelectorAll('.schedule-item:not(.schedule-tagged)')
      if (!items) return
      const ids = Array.from(items).map(el => el.getAttribute('data-schedule-id')).filter(Boolean) as string[]
      if (ids.length > 0) {
        emit('reorderSchedules', ids)
      }
    },
  })
}

function destroySortable() {
  if (sortableInstance) {
    sortableInstance.destroy()
    sortableInstance = null
  }
}

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      isCreateMode.value = false
      isEditMode.value = false
      editingScheduleId.value = null
      editAttachments.value = []
      const { year, month, day } = props.date
      newSchedule.value.startDate = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
      newSchedule.value.endDateTime = `${newSchedule.value.startDate}T00:00`
      nextTick(() => initSortable())
    } else {
      // Cleanup when modal closes
      fileUploaderRef.value?.cleanup()
      destroySortable()
    }
  }
)

watch(
  () => props.schedules,
  () => {
    if (props.isOpen && !isCreateMode.value && !isEditMode.value) {
      nextTick(() => initSortable())
    }
  }
)

onUnmounted(() => {
  destroySortable()
})

// Auto-adjust endDateTime when startTime changes
watch(
  () => [newSchedule.value.startDate, newSchedule.value.startTime],
  ([startDate, startTime]) => {
    if (!startDate || !startTime) return
    const startDateTime = `${startDate}T${startTime}`
    const endDateTime = newSchedule.value.endDateTime
    if (endDateTime && endDateTime < startDateTime) {
      newSchedule.value.endDateTime = startDateTime
    }
  }
)

function startCreateMode() {
  isCreateMode.value = true
  isEditMode.value = false
  editingScheduleId.value = null
  editAttachments.value = []
  const { year, month, day } = props.date
  newSchedule.value = {
    content: '',
    description: '',
    startDate: `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`,
    startTime: '00:00',
    endDateTime: `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}T00:00`,
    visibility: 'FAMILY',
  }
  // Scroll to top when entering create mode
  nextTick(() => {
    if (contentRef.value) {
      contentRef.value.scrollTop = 0
    }
  })
}

function startEditMode(schedule: Schedule) {
  isCreateMode.value = false
  isEditMode.value = true
  editingScheduleId.value = schedule.id

  const start = new Date(schedule.startDateTime)
  const end = new Date(schedule.endDateTime)

  newSchedule.value = {
    content: schedule.content,
    description: schedule.description || '',
    startDate: extractDatePart(schedule.startDateTime),
    startTime: `${String(start.getHours()).padStart(2, '0')}:${String(start.getMinutes()).padStart(2, '0')}`,
    endDateTime: `${end.getFullYear()}-${String(end.getMonth() + 1).padStart(2, '0')}-${String(end.getDate()).padStart(2, '0')}T${String(end.getHours()).padStart(2, '0')}:${String(end.getMinutes()).padStart(2, '0')}`,
    visibility: schedule.visibility,
  }

  // Load existing attachments
  editAttachments.value = (schedule.attachments || []).map((a) =>
    normalizeAttachment({
      id: a.id,
      contextType: 'SCHEDULE',
      contextId: schedule.id,
      originalFilename: a.originalFilename,
      contentType: a.contentType,
      size: a.size,
      hasThumbnail: a.hasThumbnail,
      thumbnailUrl: a.thumbnailUrl || null,
      orderIndex: 0,
      createdAt: '',
      createdBy: 0,
    })
  )

  // Scroll to top when entering edit mode
  nextTick(() => {
    if (contentRef.value) {
      contentRef.value.scrollTop = 0
    }
  })
}

function cancelEdit() {
  isCreateMode.value = false
  isEditMode.value = false
  editingScheduleId.value = null
  editAttachments.value = []
  fileUploaderRef.value?.cleanup()
}

function buildScheduleData(): ScheduleSaveData {
  const { year, month, day } = props.date
  const startDateTime = `${newSchedule.value.startDate}T${newSchedule.value.startTime}:00`
  const endDateTime = newSchedule.value.endDateTime
    ? `${newSchedule.value.endDateTime}:00`
    : `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}T00:00:00`

  const sessionId = fileUploaderRef.value?.getSessionId() || null
  const attachments = fileUploaderRef.value?.getAttachments() || []
  const orderedIds = attachments.map((a) => a.id)

  return {
    id: isEditMode.value ? editingScheduleId.value || undefined : undefined,
    content: newSchedule.value.content.trim(),
    description: newSchedule.value.description.trim(),
    startDateTime,
    endDateTime,
    visibility: newSchedule.value.visibility,
    attachmentSessionId: sessionId,
    orderedAttachmentIds: orderedIds.length > 0 ? orderedIds : undefined,
  }
}

function saveSchedule() {
  if (!newSchedule.value.content.trim()) {
    return
  }

  // Check if upload is in progress
  if (fileUploaderRef.value?.isUploading()) {
    showWarning('파일 업로드가 진행 중입니다. 잠시 후 다시 시도해주세요.')
    return
  }

  const data = buildScheduleData()

  if (isEditMode.value) {
    emit('editSchedule', data)
  } else {
    emit('createSchedule', data)
  }

  isCreateMode.value = false
  isEditMode.value = false
  editingScheduleId.value = null
  editAttachments.value = []
}

function handleUploadStart() {
  isUploading.value = true
}

function handleUploadComplete() {
  isUploading.value = false
}

function handleUploadError(message: string) {
  showError(message)
}

function formatScheduleTime(schedule: Schedule) {
  const start = new Date(schedule.startDateTime)
  const end = new Date(schedule.endDateTime)
  const startTime = `${String(start.getHours()).padStart(2, '0')}:${String(start.getMinutes()).padStart(2, '0')}`
  const endTime = `${String(end.getHours()).padStart(2, '0')}:${String(end.getMinutes()).padStart(2, '0')}`

  if (startTime === '00:00' && endTime === '00:00') {
    return ''
  }
  if (startTime !== '00:00' && endTime === '00:00') {
    return `(${startTime})`
  }
  return `(${startTime}~${endTime})`
}

function openTagPanel(scheduleId: string) {
  taggingScheduleId.value = scheduleId
}

function closeTagPanel() {
  taggingScheduleId.value = null
}

function getUntaggedFriends(schedule: Schedule) {
  const taggedIds = new Set(schedule.tags?.map((t) => t.id) || [])
  return props.friends.filter((f) => !taggedIds.has(f.id))
}

function toNormalizedAttachments(attachments: Schedule['attachments']): NormalizedAttachment[] {
  if (!attachments) return []
  return attachments.map((a) =>
    normalizeAttachment({
      id: a.id,
      contextType: 'SCHEDULE',
      contextId: '',
      originalFilename: a.originalFilename,
      contentType: a.contentType,
      size: a.size,
      hasThumbnail: a.hasThumbnail,
      thumbnailUrl: a.thumbnailUrl || null,
      orderIndex: 0,
      createdAt: '',
      createdBy: 0,
    })
  )
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-start sm:items-center justify-center bg-black/50 pt-2 sm:pt-0 pb-16 sm:pb-0"
      @click.self="emit('close')"
    >
      <div class="rounded-lg shadow-xl w-full max-w-[95vw] sm:max-w-2xl max-h-[calc(100dvh-5rem)] sm:max-h-[90vh] mx-2 sm:mx-4 flex flex-col" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
        <!-- Header -->
        <div class="p-3 sm:p-4 flex-shrink-0" :style="{ backgroundColor: 'var(--dp-bg-tertiary)', borderBottom: '1px solid var(--dp-border-primary)' }">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <span v-if="isCreateMode" class="px-2 py-0.5 bg-green-100 text-green-700 text-xs font-medium rounded">일정 추가</span>
              <span v-else-if="isEditMode" class="px-2 py-0.5 bg-blue-100 text-blue-700 text-xs font-medium rounded">일정 수정</span>
              <h2 class="text-base sm:text-lg font-bold" :style="{ color: 'var(--dp-text-primary)' }">{{ formattedDate }}</h2>
            </div>
            <button @click="emit('close')" class="p-2 rounded-full flex-shrink-0 hover-close-btn cursor-pointer">
              <X class="w-6 h-6" :style="{ color: 'var(--dp-text-primary)' }" />
            </button>
          </div>
          <!-- Duty Type Selection (my calendar only, hidden in add/edit mode) -->
          <div v-if="!isCreateMode && !isEditMode && canEdit && dutyTypes.length > 0" class="flex flex-wrap gap-1.5 mt-2">
            <button
              v-for="dutyType in dutyTypes"
              :key="dutyType.id ?? 'off'"
              @click="handleDutyTypeChange(dutyType.id, dutyType.name)"
              class="duty-type-btn px-2.5 py-1 rounded-md text-xs font-medium flex items-center gap-1.5 cursor-pointer"
              :class="{
                'border-blue-500 ring-1 ring-blue-200 duty-type-btn-selected': selectedDutyType === dutyType.name,
              }"
              :style="{
                border: selectedDutyType === dutyType.name ? undefined : '1px solid var(--dp-border-primary)',
                color: 'var(--dp-text-primary)',
                backgroundColor: selectedDutyType === dutyType.name && dutyType.color ? dutyType.color + '30' : undefined
              }"
            >
              <span
                class="inline-block w-3 h-3 rounded border border-gray-400"
                :style="{ backgroundColor: dutyType.color || '#6c757d' }"
              ></span>
              {{ dutyType.name }}
            </button>
          </div>
          <!-- Current Duty (other's calendar only) -->
          <div v-else-if="duty && !canEdit" class="mt-2">
            <span
              class="px-2.5 py-1 rounded-md text-xs font-medium text-white"
              :style="{ backgroundColor: duty.dutyColor || '#6c757d' }"
            >
              {{ duty.dutyType || 'OFF' }}
            </span>
          </div>
        </div>

        <!-- Content -->
        <div ref="contentRef" class="p-3 sm:p-4 overflow-y-auto overflow-x-hidden flex-1 min-h-0">

          <!-- Schedules List (hidden during create/edit mode) -->
          <div v-if="!isCreateMode && !isEditMode" class="space-y-3">
            <div v-if="schedules.length === 0" class="text-center py-6" :style="{ color: 'var(--dp-text-muted)' }">
              등록된 일정이 없습니다.
            </div>

            <div ref="scheduleListRef" :class="['space-y-2', { 'is-dragging': isDragging }]">
              <div
                v-for="(schedule, idx) in schedules"
                :key="schedule.id"
                :data-schedule-id="schedule.id"
                :class="[
                  'schedule-item rounded-lg p-3 transition',
                  { 'schedule-tagged': schedule.isTagged }
                ]"
                :style="{
                  border: '1px solid var(--dp-border-primary)',
                  backgroundColor: 'var(--dp-bg-card)'
                }"
              >
                <div class="flex items-start justify-between">
                  <div
                    v-if="hasDraggableSchedules && canEdit && !schedule.isTagged"
                    class="schedule-drag-handle flex items-center pr-2 cursor-grab"
                    :style="{ color: 'var(--dp-text-muted)' }"
                    title="드래그하여 순서 변경"
                  >
                    <GripVertical class="w-5 h-5" />
                  </div>
                  <div class="flex-1">
                    <div class="flex items-center gap-2 flex-wrap">
                    <Lock
                      v-if="schedule.visibility === 'PRIVATE'"
                      class="w-4 h-4"
                      :style="{ color: 'var(--dp-text-muted)' }"
                      :title="getVisibilityLabel(schedule.visibility)"
                    />
                    <span class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">{{ schedule.content }}<template v-if="schedule.totalDays && schedule.totalDays > 1"> ({{ schedule.daysFromStart }}/{{ schedule.totalDays }})</template></span>
                    <span v-if="formatScheduleTime(schedule)" class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">
                      {{ formatScheduleTime(schedule) }}
                    </span>
                    <component
                      v-if="schedule.visibility !== 'PRIVATE'"
                      :is="getVisibilityIcon(schedule.visibility)"
                      class="w-4 h-4"
                      :style="{ color: 'var(--dp-text-muted)' }"
                      :title="getVisibilityLabel(schedule.visibility)"
                    />
                    <span
                      v-if="schedule.attachments?.length"
                      class="flex items-center gap-1 text-sm"
                      :style="{ color: 'var(--dp-text-muted)' }"
                    >
                      <Paperclip class="w-3 h-3" />
                      {{ schedule.attachments.length }}
                    </span>
                  </div>

                  <!-- Tags Section -->
                  <div
                    v-if="schedule.isMine && canEdit && (schedule.tags?.length || friends.length > 0)"
                    class="mt-2"
                  >
                    <div class="flex items-center gap-1.5 flex-wrap">
                      <!-- Existing tags -->
                      <span
                        v-for="tag in schedule.tags"
                        :key="tag.id"
                        class="inline-flex items-center gap-1 pl-2 pr-1 py-0.5 bg-blue-100 text-blue-700 text-xs rounded-full"
                      >
                        {{ tag.name }}
                        <button
                          @click.stop="emit('removeTag', schedule.id, tag.id)"
                          class="p-0.5 hover:bg-blue-200 rounded-full transition cursor-pointer"
                          title="태그 삭제"
                        >
                          <X class="w-3 h-3" />
                        </button>
                      </span>

                      <!-- Add tag button -->
                      <button
                        v-if="friends.length > 0"
                        @click.stop="openTagPanel(schedule.id)"
                        class="inline-flex items-center gap-1 px-2 py-0.5 border border-dashed text-xs rounded-full hover:border-blue-400 hover:text-blue-500 hover:bg-blue-50 transition cursor-pointer"
                        :class="{ 'border-blue-400 text-blue-500 bg-blue-50': taggingScheduleId === schedule.id }"
                        :style="{
                          borderColor: taggingScheduleId === schedule.id ? undefined : 'var(--dp-border-secondary)',
                          color: taggingScheduleId === schedule.id ? undefined : 'var(--dp-text-secondary)'
                        }"
                        title="친구 태그"
                      >
                        <UserPlus class="w-3 h-3" />
                        <span>태그</span>
                      </button>
                    </div>

                    <!-- Inline tag selection (expanded below the button) -->
                    <div
                      v-if="taggingScheduleId === schedule.id && getUntaggedFriends(schedule).length > 0"
                      class="mt-2 p-2.5 bg-blue-50 border border-blue-200 rounded-lg"
                    >
                      <div class="flex items-center justify-between mb-2">
                        <span class="text-xs font-medium text-blue-700">친구 선택</span>
                        <button
                          @click.stop="closeTagPanel"
                          class="p-0.5 hover:bg-blue-100 rounded transition cursor-pointer"
                        >
                          <X class="w-3.5 h-3.5 text-blue-500" />
                        </button>
                      </div>
                      <div class="flex flex-wrap gap-1.5">
                        <button
                          v-for="friend in getUntaggedFriends(schedule)"
                          :key="friend.id"
                          @click.stop="emit('addTag', schedule.id, friend.id)"
                          class="inline-flex items-center gap-1 px-2 py-1 border border-blue-200 text-xs rounded-full hover:border-blue-400 hover:bg-blue-100 transition cursor-pointer"
                          :style="{
                            backgroundColor: 'var(--dp-bg-primary)',
                            color: 'var(--dp-text-primary)'
                          }"
                        >
                          <User class="w-3 h-3" />
                          {{ friend.name }}
                        </button>
                      </div>
                    </div>
                  </div>

                  <!-- Tags display for non-owners (show tags list) -->
                  <div
                    v-else-if="!schedule.isTagged && schedule.tags?.length"
                    class="flex items-center gap-1.5 mt-2 flex-wrap"
                  >
                    <span
                      v-for="tag in schedule.tags"
                      :key="tag.id"
                      class="inline-flex items-center gap-1 px-2 py-0.5 bg-blue-100 text-blue-700 text-xs rounded-full"
                    >
                      {{ tag.name }}
                    </span>
                  </div>

                  <!-- Tagged by indicator (when I was tagged by someone) -->
                  <div
                    v-else-if="schedule.isTagged"
                    class="flex items-center gap-1.5 mt-2 flex-wrap"
                  >
                    <!-- Show other tagged members (exclude calendar owner) -->
                    <span
                      v-for="tag in schedule.tags?.filter(t => t.id !== memberId)"
                      :key="tag.id"
                      class="inline-flex items-center gap-1 px-2 py-0.5 bg-blue-100 text-blue-700 text-xs rounded-full"
                    >
                      {{ tag.name }}
                    </span>
                    <!-- Show who tagged me -->
                    <span class="inline-flex items-center gap-1 px-2 py-0.5 bg-gray-100 text-gray-600 text-xs rounded-full">
                      by {{ schedule.taggedBy }}
                    </span>
                  </div>

                  <!-- Description -->
                  <div v-if="schedule.description" class="mt-2 pt-2" :style="{ borderTop: '1px solid var(--dp-border-primary)' }">
                    <div class="text-sm whitespace-pre-wrap" :style="{ color: 'var(--dp-text-secondary)' }">{{ schedule.description }}</div>
                  </div>

                  <!-- Attachments -->
                  <div v-if="schedule.attachments?.length" class="mt-2 pt-2" :style="{ borderTop: '1px solid var(--dp-border-primary)' }">
                    <AttachmentGrid
                      :attachments="toNormalizedAttachments(schedule.attachments)"
                      :columns="4"
                    />
                  </div>
                </div>

                <!-- Actions -->
                <div class="flex items-center gap-1 ml-2">
                  <!-- Edit/Delete for own schedules or manager -->
                  <template v-if="!schedule.isTagged && (schedule.isMine || canEdit)">
                    <button
                      @click="startEditMode(schedule)"
                      class="p-1.5 rounded-lg hover-icon-btn cursor-pointer text-blue-600"
                      title="수정"
                    >
                      <Pencil class="w-4 h-4" />
                    </button>
                    <button
                      @click="emit('deleteSchedule', schedule.id)"
                      class="p-1.5 rounded-lg hover-danger cursor-pointer text-red-600"
                      title="삭제"
                    >
                      <Trash2 class="w-4 h-4" />
                    </button>
                  </template>

                  <!-- Untag for tagged schedules -->
                  <button
                    v-if="schedule.isTagged"
                    @click="openUntagConfirmModal(schedule.id)"
                    class="px-2 py-1 border border-orange-300 hover:bg-orange-100 rounded transition text-orange-600 text-xs font-medium flex items-center gap-1 cursor-pointer"
                    title="태그 제거"
                  >
                    <X class="w-3.5 h-3.5" />
                    태그 제거
                  </button>
                </div>
              </div>
            </div>
            </div>
          </div>

          <!-- Create/Edit Schedule Form -->
          <div v-if="isCreateMode || isEditMode">
            <div class="space-y-3">
              <div>
                <label class="block text-sm mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
                  내용 <span class="text-red-500">*</span>
                  <CharacterCounter :current="newSchedule.content.length" :max="50" />
                </label>
                <input
                  v-model="newSchedule.content"
                  type="text"
                  maxlength="50"
                  class="w-full px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
                  placeholder="일정 내용을 입력하세요"
                />
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label class="block text-sm mb-1" :style="{ color: 'var(--dp-text-secondary)' }">시작 시간</label>
                  <input
                    v-model="newSchedule.startTime"
                    type="time"
                    class="w-full px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
                  />
                </div>
                <div>
                  <label class="block text-sm mb-1" :style="{ color: 'var(--dp-text-secondary)' }">종료 일시</label>
                  <input
                    v-model="newSchedule.endDateTime"
                    type="datetime-local"
                    class="w-full px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
                  />
                </div>
              </div>

              <div>
                <label class="block text-sm mb-1" :style="{ color: 'var(--dp-text-secondary)' }">설명</label>
                <textarea
                  v-model="newSchedule.description"
                  rows="3"
                  class="w-full px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
                  placeholder="설명 (선택사항)"
                ></textarea>
              </div>

              <div>
                <label class="block text-sm mb-1" :style="{ color: 'var(--dp-text-secondary)' }">공개 범위</label>
                <select
                  v-model="newSchedule.visibility"
                  class="w-full px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
                >
                  <option value="PUBLIC">전체공개</option>
                  <option value="FRIENDS">친구공개</option>
                  <option value="FAMILY">가족공개</option>
                  <option value="PRIVATE">나만보기</option>
                </select>
              </div>

              <!-- Attachment Upload Area -->
              <div>
                <label class="block text-sm mb-1" :style="{ color: 'var(--dp-text-secondary)' }">첨부파일</label>
                <FileUploader
                  ref="fileUploaderRef"
                  context-type="SCHEDULE"
                  :existing-attachments="editAttachments"
                  @upload-start="handleUploadStart"
                  @upload-complete="handleUploadComplete"
                  @error="handleUploadError"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Footer (sticky at bottom) -->
        <div class="p-3 sm:p-4 flex-shrink-0" :style="{ borderTop: '1px solid var(--dp-border-primary)' }">
          <!-- List mode: Add schedule button -->
          <div v-if="!isCreateMode && !isEditMode && canEdit" class="flex justify-end">
            <button
              @click="startCreateMode"
              class="flex items-center justify-center gap-2 w-full sm:w-auto px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition cursor-pointer"
            >
              <Plus class="w-4 h-4" />
              일정 추가
            </button>
          </div>
          <!-- Create/Edit mode: Save/Cancel buttons -->
          <div v-else-if="isCreateMode || isEditMode" class="flex flex-row gap-2 justify-end">
            <button
              @click="cancelEdit"
              class="flex-1 sm:flex-none px-4 py-2 rounded-lg transition btn-outline cursor-pointer"
            >
              취소
            </button>
            <button
              @click="saveSchedule"
              :disabled="isUploading"
              class="flex-1 sm:flex-none px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
            >
              {{ isUploading ? '업로드 중...' : (isEditMode ? '수정' : '저장') }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </Teleport>

  <!-- Untag Confirm Modal -->
  <Teleport to="body">
    <div
      v-if="untagConfirmScheduleId"
      class="fixed inset-0 z-[60] flex items-center justify-center bg-black/50 p-4"
      @click.self="closeUntagConfirmModal"
    >
      <div
        class="rounded-2xl w-full max-w-[340px] min-w-[280px] overflow-hidden border"
        :style="{
          backgroundColor: 'var(--dp-bg-modal)',
          borderColor: 'var(--dp-border-primary)',
          boxShadow: '0 20px 40px -8px rgba(0, 0, 0, 0.25), 0 8px 16px -4px rgba(0, 0, 0, 0.1)'
        }"
      >
        <div
          class="py-2.5 px-4 text-sm font-semibold"
          :style="{
            backgroundColor: 'var(--dp-bg-tertiary)',
            borderBottom: '1px solid var(--dp-border-primary)',
            color: 'var(--dp-text-primary)'
          }"
        >
          태그 제거
        </div>
        <div class="py-4 px-4 space-y-3">
          <p class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">
            이 일정에서 태그를 제거하시겠습니까?
          </p>
          <div
            class="p-3 rounded-lg text-xs space-y-1"
            :style="{ backgroundColor: 'var(--dp-bg-secondary)', color: 'var(--dp-text-muted)' }"
          >
            <p>• 태그를 제거하면 이 일정이 내 달력에서 사라집니다.</p>
            <p>• 태그 복원은 불가능하며, 다시 태그하려면 해당 사용자에게 요청해야 합니다.</p>
          </div>
        </div>
        <div class="pb-4 flex justify-center gap-2">
          <button
            @click="confirmUntag"
            class="px-5 py-2 bg-orange-500 hover:bg-orange-600 text-white rounded-lg text-sm font-medium transition-all duration-200 hover:-translate-y-px cursor-pointer"
            style="box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1), 0 1px 2px rgba(0, 0, 0, 0.06);"
          >
            태그 제거
          </button>
          <button
            @click="closeUntagConfirmModal"
            class="px-5 py-2 rounded-lg text-sm font-medium transition-all duration-200 border hover:-translate-y-px cursor-pointer"
            :style="{
              backgroundColor: 'var(--dp-bg-card)',
              color: 'var(--dp-text-secondary)',
              borderColor: 'var(--dp-border-primary)',
              boxShadow: '0 1px 2px rgba(0, 0, 0, 0.05)'
            }"
          >
            취소
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.schedule-ghost {
  opacity: 0.4;
  background-color: #e0e7ff;
}

.schedule-chosen {
  box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
}

/* Show only title when dragging - applies to all items in drag mode */
.is-dragging .schedule-item .flex-1 > *:not(:first-child),
.is-dragging .schedule-item .flex.items-center.gap-1.ml-2 {
  display: none !important;
}

.is-dragging .schedule-item {
  padding: 0.5rem 0.75rem;
  transition: padding 0.15s ease;
}

.schedule-dragging {
  opacity: 0.95;
  background: white;
  border-radius: 0.5rem;
  padding: 0.5rem 0.75rem;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
}

.schedule-drag-handle:active {
  cursor: grabbing;
}
</style>
