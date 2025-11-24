<script setup lang="ts">
import { ref, watch, reactive } from 'vue'
import { Download, Paperclip } from 'lucide-vue-next'
import { fetchAuthenticatedImage, formatBytes } from '@/api/attachment'
import ImageViewer from './ImageViewer.vue'
import type { NormalizedAttachment } from '@/types'

interface Props {
  attachments: NormalizedAttachment[]
  showLabel?: boolean
  columns?: 2 | 3 | 4
}

const props = withDefaults(defineProps<Props>(), {
  showLabel: true,
  columns: 2,
})

const thumbnailBlobUrls = reactive<Record<string, string>>({})

// Image viewer state
const imageViewerOpen = ref(false)
const imageViewerIndex = ref(0)
const imageAttachments = ref<Array<{ id: string; originalFilename: string }>>([])

function getFileIcon(contentType: string): string {
  if (contentType.startsWith('image/')) return 'IMG'
  if (contentType.startsWith('video/')) return 'VID'
  if (contentType.startsWith('audio/')) return 'AUD'
  if (contentType.includes('pdf')) return 'PDF'
  if (contentType.includes('word') || contentType.includes('document')) return 'DOC'
  if (contentType.includes('excel') || contentType.includes('spreadsheet')) return 'XLS'
  if (contentType.includes('zip') || contentType.includes('rar')) return 'ZIP'
  return 'FILE'
}

async function loadThumbnails() {
  for (const attachment of props.attachments) {
    if (attachment.hasThumbnail && attachment.thumbnailUrl && !thumbnailBlobUrls[attachment.id]) {
      const blobUrl = await fetchAuthenticatedImage(attachment.thumbnailUrl)
      if (blobUrl) {
        thumbnailBlobUrls[attachment.id] = blobUrl
      }
    }
  }
}

function getThumbnailUrl(attachmentId: string): string | null {
  return thumbnailBlobUrls[attachmentId] || null
}

function handleAttachmentClick(index: number) {
  const attachment = props.attachments[index]
  if (!attachment) return

  if (attachment.contentType?.startsWith('image/')) {
    openImageViewer(index)
  } else {
    downloadAttachment(attachment.id, attachment.originalFilename)
  }
}

function openImageViewer(clickedIndex: number) {
  // Filter only image attachments
  const images = props.attachments.filter((a) => a.contentType?.startsWith('image/'))
  if (images.length === 0) return

  const clickedAttachment = props.attachments[clickedIndex]
  const imageIndex = images.findIndex((a) => a.id === clickedAttachment?.id)

  imageAttachments.value = images.map((a) => ({
    id: a.id,
    originalFilename: a.originalFilename,
  }))
  imageViewerIndex.value = imageIndex >= 0 ? imageIndex : 0
  imageViewerOpen.value = true
}

async function downloadAttachment(attachmentId: string, filename: string) {
  const blobUrl = await fetchAuthenticatedImage(`/api/attachments/${attachmentId}/download`)
  if (blobUrl) {
    const a = document.createElement('a')
    a.href = blobUrl
    a.download = filename
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(blobUrl)
  }
}

// Watch for attachment changes to load thumbnails
watch(
  () => props.attachments,
  () => {
    loadThumbnails()
  },
  { immediate: true, deep: true }
)

const gridColsClass = {
  2: 'grid-cols-1 sm:grid-cols-2',
  3: 'grid-cols-2 sm:grid-cols-3',
  4: 'grid-cols-2 sm:grid-cols-4',
}
</script>

<template>
  <div v-if="attachments.length > 0">
    <div v-if="showLabel" class="flex items-center gap-1 text-sm text-gray-500 mb-2">
      <Paperclip class="w-3 h-3" />
      첨부파일 ({{ attachments.length }})
    </div>
    <div class="grid gap-2" :class="gridColsClass[columns]">
      <div
        v-for="(attachment, idx) in attachments"
        :key="attachment.id"
        class="relative border border-gray-200 rounded-lg overflow-hidden group cursor-pointer"
        @click="handleAttachmentClick(idx)"
      >
        <!-- Thumbnail or Icon -->
        <div class="aspect-square bg-gray-100 flex items-center justify-center">
          <img
            v-if="getThumbnailUrl(attachment.id)"
            :src="getThumbnailUrl(attachment.id)!"
            :alt="attachment.originalFilename"
            class="w-full h-full object-cover"
          />
          <span v-else class="text-2xl text-gray-400">
            {{ getFileIcon(attachment.contentType || '') }}
          </span>
        </div>

        <!-- Download button overlay -->
        <button
          class="absolute top-1 right-1 p-1 bg-black/50 rounded text-white opacity-0 group-hover:opacity-100 transition hover:bg-black/70"
          @click.stop="downloadAttachment(attachment.id, attachment.originalFilename)"
          title="다운로드"
        >
          <Download class="w-4 h-4" />
        </button>

        <!-- File info -->
        <div class="p-2">
          <p class="text-sm truncate" :title="attachment.originalFilename">
            {{ attachment.originalFilename }}
          </p>
          <p class="text-xs text-gray-500">{{ formatBytes(attachment.size) }}</p>
        </div>
      </div>
    </div>

    <!-- Image Viewer -->
    <ImageViewer
      :is-open="imageViewerOpen"
      :images="imageAttachments"
      :initial-index="imageViewerIndex"
      @close="imageViewerOpen = false"
    />
  </div>
</template>
