<script setup lang="ts">
import { ref, computed, watch, nextTick, onMounted, onUnmounted } from 'vue'
import Sortable from 'sortablejs'
import { useI18n } from 'vue-i18n'
import {
  GripVertical,
  Paperclip,
  Pencil,
  Trash2,
  X,
} from 'lucide-vue-next'
import AttachmentGrid from '@/components/common/AttachmentGrid.vue'
import MemberTagChips from '@/components/common/MemberTagChips.vue'
import VisibilityHintIcon from '@/components/common/VisibilityHintIcon.vue'
import CopyTextButton from '@/components/common/CopyTextButton.vue'
import { useDragClickGuard } from '@/composables/useDragClickGuard'
import type { NormalizedAttachment } from '@/types'
import { normalizeAttachment } from '@/api/attachment'
import { buildDisplayTagMembers } from '@/utils/tagMembers'
import { canEditCalendarSchedule } from '@/utils/schedulePermissions'

interface Schedule {
  id: string
  content: string
  description?: string
  startDateTime: string
  endDateTime: string
  visibility: 'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE'
  isMine: boolean
  isTagged: boolean
  owner?: string
  taggedBy?: string
  taggedByMember?: {
    id: number
    name: string
    hasProfilePhoto?: boolean
    profilePhotoVersion?: number
  }
  attachments?: Array<{
    id: string
    originalFilename: string
    contentType: string
    size: number
    thumbnailUrl?: string
    hasThumbnail: boolean
  }>
  tags?: Array<{
    id: number
    name: string
    hasProfilePhoto?: boolean
    profilePhotoVersion?: number
  }>
  daysFromStart?: number
  totalDays?: number
}

const props = defineProps<{
  schedules: Schedule[]
  canEdit: boolean
  isMyCalendar: boolean
  memberId: number
}>()

const emit = defineEmits<{
  (e: 'edit', schedule: Schedule): void
  (e: 'delete', scheduleId: string): void
  (e: 'reorder', scheduleIds: string[]): void
  (e: 'request-untag', scheduleId: string): void
}>()

const { t } = useI18n()
const { isDragging, startDrag, endDrag, cancelDrag, handlePointerDown, handleClick } = useDragClickGuard()

const scheduleListRef = ref<HTMLElement | null>(null)
let sortableInstance: Sortable | null = null

const hasDraggableSchedules = computed(() => {
  return props.canEdit && props.schedules.filter(s => !s.isTagged).length > 1
})

function initSortable() {
  if (!scheduleListRef.value || !props.canEdit) {
    destroySortable()
    return
  }
  if (!hasDraggableSchedules.value) {
    destroySortable()
    return
  }

  destroySortable()
  sortableInstance = new Sortable(scheduleListRef.value, {
    animation: 150,
    handle: '.schedule-drag-handle',
    draggable: '.schedule-item:not(.schedule-tagged)',
    ghostClass: 'schedule-ghost',
    chosenClass: 'schedule-chosen',
    dragClass: 'schedule-dragging',
    onStart: startDrag,
    onEnd: () => {
      endDrag()
      const items = scheduleListRef.value?.querySelectorAll('.schedule-item:not(.schedule-tagged)')
      if (!items) return
      const ids = Array.from(items).map(el => el.getAttribute('data-schedule-id')).filter(Boolean) as string[]
      if (ids.length > 0) {
        emit('reorder', ids)
      }
    },
  })
}

function destroySortable() {
  if (sortableInstance) {
    sortableInstance.destroy()
    sortableInstance = null
  }
  if (isDragging.value) {
    cancelDrag()
  }
}

watch(
  () => props.schedules,
  () => {
    nextTick(() => initSortable())
  }
)

watch(
  () => props.canEdit,
  () => {
    nextTick(() => initSortable())
  }
)

watch(
  () => hasDraggableSchedules.value,
  () => {
    nextTick(() => initSortable())
  }
)

onMounted(() => {
  nextTick(() => initSortable())
})

onUnmounted(() => {
  destroySortable()
})

function formatScheduleTime(schedule: Schedule) {
  const start = new Date(schedule.startDateTime)
  const end = new Date(schedule.endDateTime)
  const startTime = `${String(start.getHours()).padStart(2, '0')}:${String(start.getMinutes()).padStart(2, '0')}`
  const endTime = `${String(end.getHours()).padStart(2, '0')}:${String(end.getMinutes()).padStart(2, '0')}`

  if (startTime === '00:00' && endTime === '00:00') {
    return ''
  }
  if (startTime === endTime) {
    return `(${startTime})`
  }
  if (startTime !== '00:00' && endTime === '00:00') {
    return `(${startTime})`
  }
  return `(${startTime}~${endTime})`
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

function getDisplayTagMembers(schedule: Schedule) {
  return buildDisplayTagMembers({
    itemKey: schedule.id,
    isTagged: schedule.isTagged,
    owner: schedule.owner,
    taggedBy: schedule.taggedBy,
    taggedByMember: schedule.taggedByMember,
    tags: schedule.tags,
    excludeMemberId: props.memberId,
  })
}

function canEditSchedule(schedule: Schedule) {
  return canEditCalendarSchedule(props.canEdit, schedule.isTagged)
}

function canUntagSchedule(schedule: Schedule) {
  return schedule.isTagged && props.isMyCalendar
}

function shouldShowVisibility(schedule: Schedule) {
  return props.isMyCalendar && schedule.isMine
}

function handleTagClick(schedule: Schedule) {
  if (!canEditSchedule(schedule)) return
  emit('edit', schedule)
}
</script>

<template>
  <div class="space-y-3">
    <div v-if="schedules.length === 0" class="text-center py-6 text-dp-text-muted">
      {{ t('duty.schedule.list.empty') }}
    </div>

    <div
      ref="scheduleListRef"
      :class="['space-y-2', { 'is-dragging': isDragging }]"
      @pointerdown.capture="handlePointerDown"
      @click.capture="handleClick"
    >
      <div
        v-for="schedule in schedules"
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
        <div class="flex items-start">
          <div
            v-if="hasDraggableSchedules && canEdit && !schedule.isTagged"
            class="schedule-drag-handle flex items-center pr-2 cursor-grab text-dp-text-muted"
            :title="t('duty.schedule.list.dragToReorder')"
          >
            <GripVertical class="w-5 h-5" />
          </div>
          <div class="min-w-0 flex-1">
            <div class="schedule-primary-row flex items-start gap-1.5 sm:gap-2">
              <div class="schedule-primary-info min-w-0 flex-1">
                <div class="schedule-primary-content min-w-0">
                  <span class="schedule-primary-title font-medium text-dp-text-primary">{{ schedule.content }}<template v-if="schedule.totalDays && schedule.totalDays > 1"> ({{ schedule.daysFromStart }}/{{ schedule.totalDays }})</template></span>
                  <div
                    v-if="formatScheduleTime(schedule) || schedule.attachments?.length"
                    class="schedule-primary-extra text-sm text-dp-text-secondary"
                  >
                    <span v-if="formatScheduleTime(schedule)" class="schedule-primary-time">
                      {{ formatScheduleTime(schedule) }}
                    </span>
                    <span
                      v-if="schedule.attachments?.length"
                      class="schedule-primary-attachments flex items-center gap-1 text-dp-text-muted"
                    >
                      <Paperclip class="w-3 h-3" />
                      {{ schedule.attachments.length }}
                    </span>
                  </div>
                </div>
              </div>

              <div
                v-if="shouldShowVisibility(schedule) || canUntagSchedule(schedule) || canEditSchedule(schedule)"
                class="schedule-action-row flex shrink-0 items-center gap-1"
              >
                <VisibilityHintIcon
                  v-if="shouldShowVisibility(schedule)"
                  :visibility="schedule.visibility"
                  size="sm"
                  align="end"
                  class="schedule-primary-visibility"
                />
                <button
                  v-if="canUntagSchedule(schedule)"
                  @click="emit('request-untag', schedule.id)"
                  class="inline-flex min-h-[44px] shrink-0 items-center gap-1 whitespace-nowrap rounded border border-dp-warning-border px-2 py-1 text-xs font-medium text-dp-warning transition hover:bg-dp-warning-soft cursor-pointer"
                  :title="t('duty.schedule.list.untag')"
                >
                  <X class="w-3.5 h-3.5" />
                  {{ t('duty.schedule.list.untag') }}
                </button>

                <template v-if="canEditSchedule(schedule)">
                  <button
                    @click="emit('edit', schedule)"
                    class="p-1.5 rounded-lg hover-icon-btn cursor-pointer text-dp-accent"
                    :title="t('duty.schedule.list.edit')"
                  >
                    <Pencil class="w-4 h-4" />
                  </button>
                  <button
                    @click="emit('delete', schedule.id)"
                    class="p-1.5 rounded-lg hover-danger cursor-pointer text-dp-danger"
                    :title="t('duty.schedule.list.delete')"
                  >
                    <Trash2 class="w-4 h-4" />
                  </button>
                </template>
              </div>
            </div>

            <div
              v-if="getDisplayTagMembers(schedule).length"
              class="mt-1.5 w-full sm:mt-2"
            >
              <MemberTagChips
                :members="getDisplayTagMembers(schedule)"
                :interactive="canEditSchedule(schedule)"
                :button-title="t('duty.schedule.list.editTag')"
                :density="canEditSchedule(schedule) ? 'regular' : 'compact'"
                @chip-click="handleTagClick(schedule)"
              />
            </div>

            <!-- Description -->
            <div v-if="schedule.description" class="mt-2 pt-2 border-t border-dp-border-primary flex items-start gap-2">
              <div class="flex-1 min-w-0 text-sm whitespace-pre-wrap text-dp-text-secondary">{{ schedule.description }}</div>
              <CopyTextButton :text="schedule.description" class="shrink-0" />
            </div>

            <!-- Attachments -->
            <div v-if="schedule.attachments?.length" class="mt-2 pt-2 border-t border-dp-border-primary">
              <AttachmentGrid
                :attachments="toNormalizedAttachments(schedule.attachments)"
                :columns="4"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.schedule-ghost {
  opacity: 0.4;
  background-color: var(--dp-accent-bg);
}

.schedule-chosen {
  box-shadow: 0 4px 12px var(--dp-accent-ring);
}

/* Show only title when dragging - applies to all items in drag mode */
.is-dragging .schedule-item .flex-1 > *:not(:first-child),
.is-dragging .schedule-item .schedule-action-row {
  display: none !important;
}

.is-dragging .schedule-item {
  padding: 0.5rem 0.75rem;
  transition: padding 0.15s ease;
}

.schedule-dragging {
  opacity: 0.95;
  background: var(--dp-bg-card);
  border-radius: 0.5rem;
  padding: 0.5rem 0.75rem;
  box-shadow: var(--dp-shadow-lg);
}

.schedule-drag-handle:active {
  cursor: grabbing;
}

.schedule-primary-visibility {
  margin-top: 0.05rem;
  align-self: flex-start;
}

.schedule-primary-content {
  flex: 1 1 auto;
  min-width: 0;
}

.schedule-primary-title {
  display: block;
  min-width: 0;
  line-height: 1.4;
  word-break: keep-all;
  overflow-wrap: anywhere;
}

.schedule-primary-extra {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.375rem 0.625rem;
  margin-top: 0.25rem;
}

.schedule-primary-time {
  white-space: nowrap;
}

.schedule-primary-attachments {
  flex-shrink: 0;
  white-space: nowrap;
}

@media (min-width: 640px) {
  .schedule-primary-title {
    line-height: 1.45;
  }
}

</style>
