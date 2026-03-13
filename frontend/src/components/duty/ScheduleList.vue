<script setup lang="ts">
import { ref, computed, watch, nextTick, onMounted, onUnmounted } from 'vue'
import Sortable from 'sortablejs'
import {
  GripVertical,
  Paperclip,
  Lock,
  Pencil,
  Trash2,
  X,
} from 'lucide-vue-next'
import AttachmentGrid from '@/components/common/AttachmentGrid.vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import type { NormalizedAttachment } from '@/types'
import { normalizeAttachment } from '@/api/attachment'
import { getVisibilityIcon, getVisibilityLabel } from '@/utils/visibility'

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

type DisplayTagMember = {
  key: string
  id?: number
  name: string
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
}

const scheduleListRef = ref<HTMLElement | null>(null)
const isDragging = ref(false)
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
    onStart: () => {
      isDragging.value = true
    },
    onEnd: () => {
      isDragging.value = false
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

function getVisibleTags(schedule: Schedule) {
  return (schedule.tags ?? []).filter((tag) => tag.id !== props.memberId)
}

function getDisplayTagMembers(schedule: Schedule) {
  const visibleTags: DisplayTagMember[] = getVisibleTags(schedule).map((tag) => ({
    key: `tag-${tag.id}`,
    id: tag.id,
    name: tag.name,
    hasProfilePhoto: tag.hasProfilePhoto,
    profilePhotoVersion: tag.profilePhotoVersion,
  }))

  const taggedByMember = schedule.taggedByMember
  if (schedule.isTagged && taggedByMember && !visibleTags.some((tag) => tag.id === taggedByMember.id)) {
    visibleTags.unshift({
      key: `tagged-by-${taggedByMember.id}`,
      id: taggedByMember.id,
      name: taggedByMember.name,
      hasProfilePhoto: taggedByMember.hasProfilePhoto,
      profilePhotoVersion: taggedByMember.profilePhotoVersion,
    })
  } else if (schedule.isTagged && !taggedByMember && (schedule.taggedBy || schedule.owner)) {
    visibleTags.unshift({
      key: `tagged-by-${schedule.id}`,
      name: schedule.taggedBy || schedule.owner || '',
    })
  }

  return visibleTags.filter((tag) => tag.name)
}
</script>

<template>
  <div class="space-y-3">
    <div v-if="schedules.length === 0" class="text-center py-6 text-dp-text-muted">
      등록된 일정이 없습니다.
    </div>

    <div ref="scheduleListRef" :class="['space-y-2', { 'is-dragging': isDragging }]">
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
        <div class="flex items-start justify-between">
          <div
            v-if="hasDraggableSchedules && canEdit && !schedule.isTagged"
            class="schedule-drag-handle flex items-center pr-2 cursor-grab text-dp-text-muted"
            title="드래그하여 순서 변경"
          >
            <GripVertical class="w-5 h-5" />
          </div>
          <div class="flex-1">
            <div class="flex items-center gap-2 flex-wrap">
              <Lock
                v-if="schedule.visibility === 'PRIVATE'"
                class="w-4 h-4 text-dp-text-muted"
                :title="getVisibilityLabel(schedule.visibility)"
              />
              <span class="font-medium text-dp-text-primary">{{ schedule.content }}<template v-if="schedule.totalDays && schedule.totalDays > 1"> ({{ schedule.daysFromStart }}/{{ schedule.totalDays }})</template></span>
              <span v-if="formatScheduleTime(schedule)" class="text-sm text-dp-text-secondary">
                {{ formatScheduleTime(schedule) }}
              </span>
              <component
                v-if="schedule.visibility !== 'PRIVATE'"
                :is="getVisibilityIcon(schedule.visibility)"
                class="w-4 h-4 text-dp-text-muted"
                :title="getVisibilityLabel(schedule.visibility)"
              />
              <span
                v-if="schedule.attachments?.length"
                class="flex items-center gap-1 text-sm text-dp-text-muted"
              >
                <Paperclip class="w-3 h-3" />
                {{ schedule.attachments.length }}
              </span>
            </div>

          <div
            v-if="getDisplayTagMembers(schedule).length"
            class="mt-2 flex flex-wrap items-center gap-1.5"
          >
            <span
              v-for="tag in getDisplayTagMembers(schedule)"
              :key="tag.key"
              class="inline-flex min-h-[34px] items-center gap-1.5 rounded-full border border-dp-accent-border bg-dp-accent-soft px-1 py-1 pr-2 text-xs text-dp-text-primary"
            >
              <ProfileAvatar
                :member-id="tag.id ?? null"
                :name="tag.name"
                :has-profile-photo="tag.hasProfilePhoto"
                :profile-photo-version="tag.profilePhotoVersion"
                size="sm"
              />
              <span class="max-w-[120px] truncate font-medium">{{ tag.name }}</span>
            </span>
          </div>

          <!-- Description -->
          <div v-if="schedule.description" class="mt-2 pt-2 border-t border-dp-border-primary">
            <div class="text-sm whitespace-pre-wrap text-dp-text-secondary">{{ schedule.description }}</div>
          </div>

          <!-- Attachments -->
          <div v-if="schedule.attachments?.length" class="mt-2 pt-2 border-t border-dp-border-primary">
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
              @click="emit('edit', schedule)"
              class="p-1.5 rounded-lg hover-icon-btn cursor-pointer text-dp-accent"
              title="수정"
            >
              <Pencil class="w-4 h-4" />
            </button>
            <button
              @click="emit('delete', schedule.id)"
              class="p-1.5 rounded-lg hover-danger cursor-pointer text-dp-danger"
              title="삭제"
            >
              <Trash2 class="w-4 h-4" />
            </button>
          </template>

          <!-- Untag for tagged schedules (only on own calendar) -->
          <button
            v-if="schedule.isTagged && isMyCalendar"
            @click="emit('request-untag', schedule.id)"
            class="px-2 py-1 border border-dp-warning-border hover:bg-dp-warning-soft rounded transition text-dp-warning text-xs font-medium flex items-center gap-1 cursor-pointer"
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
.is-dragging .schedule-item .flex.items-center.gap-1.ml-2 {
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
</style>
