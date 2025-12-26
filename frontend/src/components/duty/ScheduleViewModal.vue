<script setup lang="ts">
import { computed, toRef } from 'vue'
import {
  X,
  Lock,
  Calendar,
  FileText,
  Paperclip,
  User,
  Users,
} from 'lucide-vue-next'
import AttachmentGrid from '@/components/common/AttachmentGrid.vue'
import type { NormalizedAttachment } from '@/types'
import { normalizeAttachment } from '@/api/attachment'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
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

interface Props {
  isOpen: boolean
  schedule: Schedule | null
  memberId: number
}

const props = defineProps<Props>()

useBodyScrollLock(toRef(props, 'isOpen'))

const emit = defineEmits<{
  (e: 'close'): void
}>()

useEscapeKey(toRef(props, 'isOpen'), () => emit('close'))

const formattedDateTime = computed(() => {
  if (!props.schedule) return ''

  const start = new Date(props.schedule.startDateTime)
  const end = new Date(props.schedule.endDateTime)

  const formatDate = (d: Date) => {
    const year = d.getFullYear()
    const month = d.getMonth() + 1
    const day = d.getDate()
    const weekDays = ['일', '월', '화', '수', '목', '금', '토']
    const dayOfWeek = weekDays[d.getDay()]
    return `${year}년 ${month}월 ${day}일 (${dayOfWeek})`
  }

  const formatTime = (d: Date) => {
    const hours = String(d.getHours()).padStart(2, '0')
    const minutes = String(d.getMinutes()).padStart(2, '0')
    return `${hours}:${minutes}`
  }

  const startDate = formatDate(start)
  const endDate = formatDate(end)
  const startTime = formatTime(start)
  const endTime = formatTime(end)

  const isSameDay = start.toDateString() === end.toDateString()
  const isAllDay = startTime === '00:00' && endTime === '00:00'

  if (isSameDay) {
    if (isAllDay) {
      return startDate
    }
    if (startTime === endTime) {
      return `${startDate} ${startTime}`
    }
    return `${startDate} ${startTime} ~ ${endTime}`
  }

  if (isAllDay) {
    return `${startDate} ~ ${endDate}`
  }

  return `${startDate} ${startTime} ~ ${endDate} ${endTime}`
})

// Filter tags to exclude self
const displayTags = computed(() => {
  if (!props.schedule?.tags) return []
  return props.schedule.tags.filter(t => t.id !== props.memberId)
})

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
      v-if="isOpen && schedule"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 pb-16 sm:pb-0"
      @click.self="emit('close')"
    >
      <div
        class="rounded-lg shadow-xl w-full max-w-[95vw] sm:max-w-lg max-h-[calc(100dvh-5rem)] sm:max-h-[85vh] mx-2 sm:mx-4 flex flex-col"
        :style="{ backgroundColor: 'var(--dp-bg-modal)' }"
      >
        <!-- Header -->
        <div
          class="p-3 sm:p-4 flex-shrink-0"
          :style="{ backgroundColor: 'var(--dp-bg-tertiary)', borderBottom: '1px solid var(--dp-border-primary)' }"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 flex-wrap">
                <Lock
                  v-if="schedule.visibility === 'PRIVATE'"
                  class="w-4 h-4 flex-shrink-0"
                  :style="{ color: 'var(--dp-text-muted)' }"
                />
                <h2
                  class="text-base sm:text-lg font-bold break-words"
                  :style="{ color: 'var(--dp-text-primary)' }"
                >
                  {{ schedule.content }}
                </h2>
                <component
                  v-if="schedule.visibility !== 'PRIVATE'"
                  :is="getVisibilityIcon(schedule.visibility)"
                  class="w-4 h-4 flex-shrink-0"
                  :style="{ color: 'var(--dp-text-muted)' }"
                  :title="getVisibilityLabel(schedule.visibility)"
                />
              </div>
              <!-- Multi-day indicator -->
              <div
                v-if="schedule.totalDays && schedule.totalDays > 1"
                class="text-xs mt-1"
                :style="{ color: 'var(--dp-text-muted)' }"
              >
                {{ schedule.daysFromStart }}/{{ schedule.totalDays }}일차
              </div>
            </div>
            <button
              @click="emit('close')"
              class="p-2 rounded-full flex-shrink-0 hover-close-btn cursor-pointer"
            >
              <X class="w-5 h-5" :style="{ color: 'var(--dp-text-primary)' }" />
            </button>
          </div>
        </div>

        <!-- Content -->
        <div class="p-3 sm:p-4 overflow-y-auto flex-1 min-h-0 space-y-4">
          <!-- Date/Time -->
          <div class="flex items-start gap-3">
            <div
              class="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0"
              :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }"
            >
              <Calendar class="w-4 h-4" :style="{ color: 'var(--dp-text-muted)' }" />
            </div>
            <div class="flex-1 pt-1">
              <div class="text-sm" :style="{ color: 'var(--dp-text-primary)' }">
                {{ formattedDateTime }}
              </div>
            </div>
          </div>

          <!-- Owner (for tagged schedules) -->
          <div v-if="schedule.isTagged" class="flex items-start gap-3">
            <div
              class="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0"
              :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }"
            >
              <User class="w-4 h-4" :style="{ color: 'var(--dp-text-muted)' }" />
            </div>
            <div class="flex-1 pt-1">
              <div class="text-xs mb-1" :style="{ color: 'var(--dp-text-muted)' }">태그한 사람</div>
              <div class="text-sm" :style="{ color: 'var(--dp-text-primary)' }">
                {{ schedule.taggedBy || schedule.owner }}
              </div>
            </div>
          </div>

          <!-- Tags -->
          <div v-if="displayTags.length > 0" class="flex items-start gap-3">
            <div
              class="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0"
              :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }"
            >
              <Users class="w-4 h-4" :style="{ color: 'var(--dp-text-muted)' }" />
            </div>
            <div class="flex-1 pt-1">
              <div class="text-xs mb-1.5" :style="{ color: 'var(--dp-text-muted)' }">함께하는 사람</div>
              <div class="flex flex-wrap gap-1.5">
                <span
                  v-for="tag in displayTags"
                  :key="tag.id"
                  class="inline-flex items-center px-2 py-0.5 bg-blue-100 text-blue-700 text-xs rounded-full"
                >
                  {{ tag.name }}
                </span>
              </div>
            </div>
          </div>

          <!-- Description -->
          <div v-if="schedule.description" class="flex items-start gap-3">
            <div
              class="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0"
              :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }"
            >
              <FileText class="w-4 h-4" :style="{ color: 'var(--dp-text-muted)' }" />
            </div>
            <div class="flex-1 pt-1">
              <div class="text-xs mb-1" :style="{ color: 'var(--dp-text-muted)' }">설명</div>
              <div
                class="text-sm whitespace-pre-wrap"
                :style="{ color: 'var(--dp-text-primary)' }"
              >
                {{ schedule.description }}
              </div>
            </div>
          </div>

          <!-- Attachments -->
          <div v-if="schedule.attachments?.length" class="flex items-start gap-3">
            <div
              class="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0"
              :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }"
            >
              <Paperclip class="w-4 h-4" :style="{ color: 'var(--dp-text-muted)' }" />
            </div>
            <div class="flex-1 pt-1">
              <div class="text-xs mb-2" :style="{ color: 'var(--dp-text-muted)' }">
                첨부파일 ({{ schedule.attachments.length }})
              </div>
              <AttachmentGrid
                :attachments="toNormalizedAttachments(schedule.attachments)"
                :columns="4"
              />
            </div>
          </div>

          <!-- Empty state when no extra info -->
          <div
            v-if="!schedule.isTagged && displayTags.length === 0 && !schedule.description && !schedule.attachments?.length"
            class="text-center py-4"
            :style="{ color: 'var(--dp-text-muted)' }"
          >
            추가 정보가 없습니다.
          </div>
        </div>

        <!-- Footer -->
        <div
          class="p-3 sm:p-4 flex-shrink-0"
          :style="{ borderTop: '1px solid var(--dp-border-primary)' }"
        >
          <button
            @click="emit('close')"
            class="w-full px-4 py-2 rounded-lg transition btn-outline cursor-pointer"
          >
            닫기
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
