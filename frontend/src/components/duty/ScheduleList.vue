<script setup lang="ts">
import { ref, computed, watch, nextTick, onMounted, onUnmounted } from 'vue'
import Sortable from 'sortablejs'
import {
  GripVertical,
  Paperclip,
  Lock,
  User,
  UserPlus,
  Pencil,
  Trash2,
  X,
} from 'lucide-vue-next'
import AttachmentGrid from '@/components/common/AttachmentGrid.vue'
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

interface Friend {
  id: number
  name: string
}

const props = defineProps<{
  schedules: Schedule[]
  canEdit: boolean
  friends: Friend[]
  isMyCalendar: boolean
  memberId: number
}>()

const emit = defineEmits<{
  (e: 'edit', schedule: Schedule): void
  (e: 'delete', scheduleId: string): void
  (e: 'reorder', scheduleIds: string[]): void
  (e: 'add-tag', scheduleId: string, friendId: number): void
  (e: 'remove-tag', scheduleId: string, friendId: number): void
  (e: 'request-untag', scheduleId: string): void
}>()

const scheduleListRef = ref<HTMLElement | null>(null)
const isDragging = ref(false)
let sortableInstance: Sortable | null = null

const hasDraggableSchedules = computed(() => {
  return props.canEdit && props.schedules.filter(s => !s.isTagged).length > 1
})

const taggingScheduleId = ref<string | null>(null)

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
</script>

<template>
  <div class="space-y-3">
    <div v-if="schedules.length === 0" class="text-center py-6" :style="{ color: 'var(--dp-text-muted)' }">
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

          <!-- Tags Section (only shown on own calendar) -->
          <div
            v-if="isMyCalendar && schedule.isMine && canEdit && (schedule.tags?.length || friends.length > 0)"
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
                  @click.stop="emit('remove-tag', schedule.id, tag.id)"
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
                  @click.stop="emit('add-tag', schedule.id, friend.id)"
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
              @click="emit('edit', schedule)"
              class="p-1.5 rounded-lg hover-icon-btn cursor-pointer text-blue-600"
              title="수정"
            >
              <Pencil class="w-4 h-4" />
            </button>
            <button
              @click="emit('delete', schedule.id)"
              class="p-1.5 rounded-lg hover-danger cursor-pointer text-red-600"
              title="삭제"
            >
              <Trash2 class="w-4 h-4" />
            </button>
          </template>

          <!-- Untag for tagged schedules (only on own calendar) -->
          <button
            v-if="schedule.isTagged && isMyCalendar"
            @click="emit('request-untag', schedule.id)"
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
  background: white;
  border-radius: 0.5rem;
  padding: 0.5rem 0.75rem;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
}

.schedule-drag-handle:active {
  cursor: grabbing;
}
</style>
