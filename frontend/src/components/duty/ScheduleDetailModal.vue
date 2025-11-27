<script setup lang="ts">
import { computed, toRef } from 'vue'
import { X, Download, Lock, Paperclip } from 'lucide-vue-next'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { formatBytes } from '@/api/attachment'

interface Attachment {
  id: string
  originalFilename: string
  contentType: string
  size: number
  thumbnailUrl?: string
  hasThumbnail: boolean
}

interface Schedule {
  id: string
  content: string
  description?: string
  startDateTime: string
  endDateTime: string
  visibility: 'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE'
  attachments?: Attachment[]
}

interface Props {
  isOpen: boolean
  schedule: Schedule | null
}

const props = defineProps<Props>()

useBodyScrollLock(toRef(props, 'isOpen'))

const emit = defineEmits<{
  (e: 'close'): void
}>()

const formattedDescription = computed(() => {
  if (!props.schedule?.description) return ''
  return props.schedule.description.replace(/\n/g, '<br>')
})

function getAttachmentIcon(attachment: Attachment): string {
  const type = attachment.contentType || ''
  if (type.startsWith('image/')) return 'IMG'
  if (type.startsWith('video/')) return 'VID'
  if (type.startsWith('audio/')) return 'AUD'
  if (type.includes('pdf')) return 'PDF'
  if (type.includes('word') || type.includes('document')) return 'DOC'
  if (type.includes('excel') || type.includes('spreadsheet')) return 'XLS'
  if (type.includes('zip') || type.includes('rar') || type.includes('7z')) return 'ZIP'
  return 'FILE'
}

function downloadUrl(attachmentId: string): string {
  return `/api/attachments/${attachmentId}/download`
}
</script>

<style scoped>
.hover-bg:hover {
  background-color: var(--dp-bg-secondary);
}

.hover-border:hover {
  background-color: var(--dp-bg-secondary);
}
</style>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen && schedule"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @click.self="emit('close')"
    >
      <div class="rounded-lg shadow-xl w-full max-w-[95vw] sm:max-w-2xl max-h-[90dvh] sm:max-h-[90vh] overflow-hidden mx-2 sm:mx-4" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
        <!-- Header -->
        <div class="flex items-center justify-between p-3 sm:p-4" :style="{ backgroundColor: 'var(--dp-bg-tertiary)', borderBottom: '1px solid var(--dp-border-primary)' }">
          <div class="flex items-center gap-2 min-w-0 flex-1 mr-2">
            <Lock v-if="schedule.visibility === 'PRIVATE'" class="w-4 h-4 flex-shrink-0" :style="{ color: 'var(--dp-text-muted)' }" />
            <h2 class="text-base sm:text-lg font-bold truncate" :style="{ color: 'var(--dp-text-primary)' }">{{ schedule.content }}</h2>
          </div>
          <button @click="emit('close')" class="p-2 rounded-full transition flex-shrink-0 hover-bg-light">
            <X class="w-6 h-6" :style="{ color: 'var(--dp-text-primary)' }" />
          </button>
        </div>

        <!-- Content -->
        <div class="p-3 sm:p-4 overflow-y-auto max-h-[calc(90dvh-130px)] sm:max-h-[calc(90vh-130px)]">
          <!-- Description -->
          <div v-if="schedule.description" class="mb-6">
            <h3 class="text-sm font-medium mb-2" :style="{ color: 'var(--dp-text-secondary)' }">상세 내용</h3>
            <div
              class="p-4 rounded-lg"
              :style="{ backgroundColor: 'var(--dp-bg-secondary)', color: 'var(--dp-text-secondary)' }"
              v-html="formattedDescription"
            ></div>
          </div>

          <!-- Attachments -->
          <div v-if="schedule.attachments?.length" class="space-y-3">
            <h3 class="text-sm font-medium flex items-center gap-2" :style="{ color: 'var(--dp-text-secondary)' }">
              <Paperclip class="w-4 h-4" />
              첨부파일 ({{ schedule.attachments.length }})
            </h3>
            <div class="grid grid-cols-2 sm:grid-cols-3 gap-2 sm:gap-3">
              <div
                v-for="attachment in schedule.attachments"
                :key="attachment.id"
                class="relative border rounded-lg overflow-hidden group"
                :style="{ borderColor: 'var(--dp-border-primary)' }"
              >
                <!-- Thumbnail or Icon -->
                <div class="aspect-square flex items-center justify-center" :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }">
                  <img
                    v-if="attachment.hasThumbnail && attachment.thumbnailUrl"
                    :src="attachment.thumbnailUrl"
                    :alt="attachment.originalFilename"
                    class="w-full h-full object-cover"
                  />
                  <span
                    v-else
                    class="text-sm font-bold"
                    :style="{ color: 'var(--dp-text-muted)' }"
                  >{{ getAttachmentIcon(attachment) }}</span>
                </div>

                <!-- Download button overlay -->
                <a
                  :href="downloadUrl(attachment.id)"
                  download
                  class="absolute top-2 right-2 p-1.5 bg-black/50 rounded-full text-white opacity-0 group-hover:opacity-100 transition hover:bg-black/70"
                  title="다운로드"
                >
                  <Download class="w-4 h-4" />
                </a>

                <!-- File info -->
                <div class="p-2">
                  <p class="text-sm truncate" :title="attachment.originalFilename" :style="{ color: 'var(--dp-text-primary)' }">
                    {{ attachment.originalFilename }}
                  </p>
                  <p class="text-xs" :style="{ color: 'var(--dp-text-muted)' }">{{ formatBytes(attachment.size) }}</p>
                </div>
              </div>
            </div>
          </div>

          <!-- Empty state -->
          <div
            v-if="!schedule.description && !schedule.attachments?.length"
            class="text-center py-8"
            :style="{ color: 'var(--dp-text-muted)' }"
          >
            상세 내용이 없습니다.
          </div>
        </div>

        <!-- Footer -->
        <div class="p-3 sm:p-4 border-t flex justify-end" :style="{ borderColor: 'var(--dp-border-primary)' }">
          <button
            @click="emit('close')"
            class="w-full sm:w-auto px-4 py-2 border rounded-lg transition hover-border"
            :style="{ borderColor: 'var(--dp-border-secondary)', color: 'var(--dp-text-primary)' }"
          >
            닫기
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
