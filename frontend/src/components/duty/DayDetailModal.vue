<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue'
import { X, Plus } from 'lucide-vue-next'
import { useI18n } from 'vue-i18n'
import BaseModal from '@/components/common/BaseModal.vue'
import ScheduleList from '@/components/duty/ScheduleList.vue'
import ScheduleForm from '@/components/duty/ScheduleForm.vue'
import UntagConfirmModal from '@/components/duty/UntagConfirmModal.vue'
import type { NormalizedAttachment, TaggableFriend } from '@/types'
import { normalizeAttachment } from '@/api/attachment'
import { useSwal } from '@/composables/useSwal'
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
  friends: TaggableFriend[]
  memberId: number
  isMyCalendar: boolean
}

const props = withDefaults(defineProps<Props>(), {
  schedules: () => [],
  dutyTypes: () => [],
  friends: () => [],
})

const { t, locale } = useI18n()

interface ScheduleSaveData {
  id?: string
  content: string
  description: string
  startDateTime: string
  endDateTime: string
  visibility: 'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE'
  tagFriendIds: number[]
  attachmentSessionId?: string | null
  orderedAttachmentIds?: string[]
}

interface SelectedTagSummary {
  id: number
  name: string
}

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'changeDutyType', dutyTypeId: number | null): void
  (e: 'createSchedule', data: ScheduleSaveData): void
  (e: 'editSchedule', data: ScheduleSaveData): void
  (e: 'deleteSchedule', scheduleId: string): void
  (e: 'reorderSchedules', scheduleIds: string[]): void
  (e: 'untagSelf', scheduleId: string): void
}>()

const isCreateMode = ref(false)
const isEditMode = ref(false)
const editingScheduleId = ref<string | null>(null)
const scheduleFormRef = ref<InstanceType<typeof ScheduleForm> | null>(null)
const isUploading = ref(false)
const contentRef = ref<HTMLElement | null>(null)

// Local duty state for immediate UI feedback
const selectedDutyType = ref<string | null>(null)

// Sync selectedDutyType with both the selected date and duty prop.
// The modal instance is reused across days, so date changes must also reset this state.
watch(
  () => [props.date.year, props.date.month, props.date.day, props.duty?.dutyType] as const,
  ([, , , dutyType]) => {
    selectedDutyType.value = dutyType ?? null
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
  tagFriendIds: [] as number[],
})
const editAttachments = ref<NormalizedAttachment[]>([])
const selectedTagSummaries = ref<SelectedTagSummary[]>([])

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
  const formatted = new Intl.DateTimeFormat(locale.value, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  }).format(date)
  const dayOfWeek = new Intl.DateTimeFormat(locale.value, {
    weekday: 'short',
  }).format(date)
  return `${formatted} (${dayOfWeek})`
})

const visibilityOptions = computed(() => [
  {
    value: 'PUBLIC' as CalendarVisibility,
    label: t('visibility.labels.public'),
    description: t('visibility.descriptions.public'),
    icon: VISIBILITY_ICONS.PUBLIC,
    color: VISIBILITY_COLORS.PUBLIC,
  },
  {
    value: 'FRIENDS' as CalendarVisibility,
    label: t('visibility.labels.friends'),
    description: t('visibility.descriptions.friends'),
    icon: VISIBILITY_ICONS.FRIENDS,
    color: VISIBILITY_COLORS.FRIENDS,
  },
  {
    value: 'FAMILY' as CalendarVisibility,
    label: t('visibility.labels.family'),
    description: t('visibility.descriptions.family'),
    icon: VISIBILITY_ICONS.FAMILY,
    color: VISIBILITY_COLORS.FAMILY,
  },
  {
    value: 'PRIVATE' as CalendarVisibility,
    label: t('visibility.labels.private'),
    description: t('visibility.descriptions.private'),
    icon: VISIBILITY_ICONS.PRIVATE,
    color: VISIBILITY_COLORS.PRIVATE,
  },
])

const isScheduleTitleMissing = computed(() => !newSchedule.value.content.trim())
const isScheduleTimeRangeInvalid = computed(() => {
  const { startDateTime, endDateTime } = newSchedule.value
  if (!startDateTime || !endDateTime) return false
  return endDateTime < startDateTime
})
const isScheduleSaveDisabled = computed(() =>
  isScheduleTitleMissing.value || isScheduleTimeRangeInvalid.value || isUploading.value
)

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
      newSchedule.value.tagFriendIds = []
      selectedTagSummaries.value = []
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
    tagFriendIds: [],
  }
  selectedTagSummaries.value = []
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
    tagFriendIds: schedule.tags?.map((tag) => tag.id) || [],
  }
  selectedTagSummaries.value = (schedule.tags || []).map((tag) => ({
    id: tag.id,
    name: tag.name,
  }))

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
  selectedTagSummaries.value = []
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
    tagFriendIds: [...newSchedule.value.tagFriendIds],
    attachmentSessionId: sessionId,
    orderedAttachmentIds: orderedIds.length > 0 ? orderedIds : undefined,
  }
}

function saveSchedule() {
  if (!newSchedule.value.content.trim()) {
    return
  }
  if (isScheduleTimeRangeInvalid.value) {
    return
  }

  // Check if upload is in progress
  if (scheduleFormRef.value?.isUploading()) {
    showWarning(t('duty.schedule.warnings.uploadInProgress'))
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
  <BaseModal
    :is-open="isOpen"
    size="2xl"
    height="viewport"
    z-index="detail"
    @close="emit('close')"
  >
    <div class="day-detail-modal-header modal-header">
      <div class="w-full">
        <div class="flex items-center justify-between gap-3">
          <div class="flex items-center gap-2 min-w-0">
            <span v-if="isCreateMode" class="px-2 py-0.5 bg-dp-success-soft text-dp-success text-xs font-medium rounded">{{ t('duty.schedule.dayDetail.createBadge') }}</span>
            <span v-else-if="isEditMode" class="px-2 py-0.5 bg-dp-accent-soft text-dp-accent-hover text-xs font-medium rounded">{{ t('duty.schedule.dayDetail.editBadge') }}</span>
            <h2>{{ formattedDate }}</h2>
          </div>
          <button @click="emit('close')" class="p-2 rounded-full flex-shrink-0 hover-close-btn cursor-pointer">
            <X class="w-6 h-6 text-dp-text-primary" />
          </button>
        </div>
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
              :style="{ backgroundColor: dutyType.color || 'var(--dp-duty-fallback)', borderColor: 'var(--dp-border-secondary)' }"
            ></span>
            {{ dutyType.name }}
          </button>
        </div>
        <div v-else-if="duty && !canEdit" class="mt-2">
          <span
            class="px-2.5 py-1 rounded-md text-xs font-medium text-dp-text-on-dark"
            :style="{ backgroundColor: duty.dutyColor || 'var(--dp-duty-fallback)' }"
          >
            {{ duty.dutyType || t('duty.common.off') }}
          </span>
        </div>
      </div>
    </div>

        <!-- Content -->
        <div ref="contentRef" class="day-detail-modal-content px-3 py-2.5 sm:p-4 overflow-y-auto overflow-x-hidden flex-1 min-h-0">

          <ScheduleList
            v-if="!isCreateMode && !isEditMode"
            :schedules="schedules"
            :can-edit="canEdit"
            :is-my-calendar="isMyCalendar"
            :member-id="memberId"
            @edit="startEditMode"
            @delete="(scheduleId) => emit('deleteSchedule', scheduleId)"
            @reorder="(scheduleIds) => emit('reorderSchedules', scheduleIds)"
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
            :friends="friends"
            :can-tag-friends="isMyCalendar"
            :selected-tag-summaries="selectedTagSummaries"
            @upload-start="handleUploadStart"
            @upload-complete="handleUploadComplete"
            @error="handleUploadError"
          />
        </div>

        <!-- Footer (sticky at bottom) -->
        <div
          v-if="canEdit || isCreateMode || isEditMode"
          class="day-detail-modal-footer modal-footer-safe px-3 py-2.5 sm:p-4 flex-shrink-0 border-t border-dp-border-primary"
        >
          <!-- List mode: Add schedule button -->
          <div v-if="!isCreateMode && !isEditMode && canEdit" class="flex justify-end">
            <button
              @click="startCreateMode"
              class="flex items-center justify-center gap-2 w-full sm:w-auto px-4 py-2 bg-dp-success text-dp-text-on-dark rounded-lg hover:bg-dp-success-hover transition cursor-pointer"
            >
              <Plus class="w-4 h-4" />
              {{ t('duty.schedule.dayDetail.add') }}
            </button>
          </div>
          <div v-else-if="!isCreateMode && !isEditMode" class="flex justify-end">
            <button
              @click="emit('close')"
              class="w-full sm:w-auto px-4 py-2 rounded-lg transition btn-outline cursor-pointer"
            >
              {{ t('common.actions.close') }}
            </button>
          </div>
          <!-- Create/Edit mode: Save/Cancel buttons -->
          <div v-else-if="isCreateMode || isEditMode" class="flex justify-end gap-2">
            <button
              @click="cancelEdit"
              class="flex-1 sm:flex-none px-4 py-2 rounded-lg transition btn-outline cursor-pointer"
            >
              {{ t('common.actions.cancel') }}
            </button>
            <button
              @click="saveSchedule"
              :disabled="isScheduleSaveDisabled"
              :aria-label="t('duty.schedule.actions.save')"
              class="flex-1 sm:flex-none px-4 py-2 bg-dp-accent text-dp-text-on-dark rounded-lg hover:bg-dp-accent-hover transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
            >
              {{ isUploading ? t('duty.common.uploading') : t('duty.schedule.actions.save') }}
            </button>
          </div>
        </div>
  </BaseModal>

  <!-- Untag Confirm Modal -->
  <UntagConfirmModal
    :is-open="!!untagConfirmScheduleId"
    @close="closeUntagConfirmModal"
    @confirm="confirmUntag"
  />
</template>

<style scoped>
@media (max-width: 639px) {
  .day-detail-modal-header {
    padding: 0.75rem 0.875rem;
  }

  .day-detail-modal-content {
    padding: 0.625rem 0.875rem;
  }

  .day-detail-modal-footer {
    padding-top: 0.625rem;
    padding-left: 0.875rem;
    padding-right: 0.875rem;
  }
}

</style>
