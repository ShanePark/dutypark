<script setup lang="ts">
import { ref, computed, watch, nextTick, toRef } from 'vue'
import { X, Plus } from 'lucide-vue-next'
import ScheduleList from '@/components/duty/ScheduleList.vue'
import ScheduleForm from '@/components/duty/ScheduleForm.vue'
import UntagConfirmModal from '@/components/duty/UntagConfirmModal.vue'
import type { NormalizedAttachment } from '@/types'
import { normalizeAttachment } from '@/api/attachment'
import { useSwal } from '@/composables/useSwal'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
import { VISIBILITY_ICONS, VISIBILITY_COLORS, type CalendarVisibility } from '@/utils/visibility'

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
  isMyCalendar: boolean
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
const scheduleFormRef = ref<InstanceType<typeof ScheduleForm> | null>(null)
const isUploading = ref(false)
const contentRef = ref<HTMLElement | null>(null)

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
  startDateTime: '',
  endDateTime: '',
  visibility: 'FAMILY' as 'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE',
})
const editAttachments = ref<NormalizedAttachment[]>([])

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

const visibilityOptions = computed(() => [
  {
    value: 'PUBLIC' as CalendarVisibility,
    label: '전체공개',
    description: '모든 사람에게 공개',
    icon: VISIBILITY_ICONS.PUBLIC,
    color: VISIBILITY_COLORS.PUBLIC,
  },
  {
    value: 'FRIENDS' as CalendarVisibility,
    label: '친구공개',
    description: '친구에게만 공개',
    icon: VISIBILITY_ICONS.FRIENDS,
    color: VISIBILITY_COLORS.FRIENDS,
  },
  {
    value: 'FAMILY' as CalendarVisibility,
    label: '가족공개',
    description: '가족에게만 공개',
    icon: VISIBILITY_ICONS.FAMILY,
    color: VISIBILITY_COLORS.FAMILY,
  },
  {
    value: 'PRIVATE' as CalendarVisibility,
    label: '비공개',
    description: '나만 볼 수 있음',
    icon: VISIBILITY_ICONS.PRIVATE,
    color: VISIBILITY_COLORS.PRIVATE,
  },
])

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      isCreateMode.value = false
      isEditMode.value = false
      editingScheduleId.value = null
      editAttachments.value = []
      const { year, month, day } = props.date
      const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
      newSchedule.value.startDateTime = `${dateStr}T00:00`
      newSchedule.value.endDateTime = `${dateStr}T00:00`
    } else {
      // Cleanup when modal closes
      scheduleFormRef.value?.cleanup()
    }
  }
)

// Auto-adjust endDateTime when startDateTime changes
watch(
  () => newSchedule.value.startDateTime,
  (startDateTime) => {
    if (!startDateTime) return
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
  const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
  newSchedule.value = {
    content: '',
    description: '',
    startDateTime: `${dateStr}T00:00`,
    endDateTime: `${dateStr}T00:00`,
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

  const formatDateTime = (d: Date) =>
    `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}T${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`

  newSchedule.value = {
    content: schedule.content,
    description: schedule.description || '',
    startDateTime: formatDateTime(start),
    endDateTime: formatDateTime(end),
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
  scheduleFormRef.value?.cleanup()
}

function buildScheduleData(): ScheduleSaveData {
  const { year, month, day } = props.date
  const defaultDateTime = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}T00:00:00`

  const startDateTime = newSchedule.value.startDateTime
    ? `${newSchedule.value.startDateTime}:00`
    : defaultDateTime
  const endDateTime = newSchedule.value.endDateTime
    ? `${newSchedule.value.endDateTime}:00`
    : defaultDateTime

  const sessionId = scheduleFormRef.value?.getSessionId() || null
  const attachments = scheduleFormRef.value?.getAttachments() || []
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
  if (scheduleFormRef.value?.isUploading()) {
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
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 pb-16 sm:pb-0"
      @click.self="emit('close')"
    >
      <div class="modal-container max-w-[95vw] sm:max-w-2xl max-h-[calc(100dvh-5rem)] sm:max-h-[90vh]">
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
                'duty-type-btn-selected': selectedDutyType === dutyType.name,
              }"
              :style="{
                color: 'var(--dp-text-primary)',
                backgroundColor: selectedDutyType === dutyType.name && dutyType.color ? dutyType.color + '30' : undefined
              }"
            >
              <span
                class="inline-block w-3 h-3 rounded border"
                :style="{ backgroundColor: dutyType.color || '#6c757d', borderColor: 'var(--dp-border-secondary)' }"
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

          <ScheduleList
            v-if="!isCreateMode && !isEditMode"
            :schedules="schedules"
            :can-edit="canEdit"
            :friends="friends"
            :is-my-calendar="isMyCalendar"
            :member-id="memberId"
            @edit="startEditMode"
            @delete="(scheduleId) => emit('deleteSchedule', scheduleId)"
            @reorder="(scheduleIds) => emit('reorderSchedules', scheduleIds)"
            @add-tag="(scheduleId, friendId) => emit('addTag', scheduleId, friendId)"
            @remove-tag="(scheduleId, friendId) => emit('removeTag', scheduleId, friendId)"
            @request-untag="openUntagConfirmModal"
          />

          <!-- Create/Edit Schedule Form -->
          <ScheduleForm
            v-if="isCreateMode || isEditMode"
            ref="scheduleFormRef"
            :form="newSchedule"
            :edit-attachments="editAttachments"
            :visibility-options="visibilityOptions"
            :is-edit-mode="isEditMode"
            @upload-start="handleUploadStart"
            @upload-complete="handleUploadComplete"
            @error="handleUploadError"
          />
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
  <UntagConfirmModal
    :is-open="!!untagConfirmScheduleId"
    @close="closeUntagConfirmModal"
    @confirm="confirmUntag"
  />
</template>
