<script setup lang="ts">
import { ref, watch, reactive, computed, type Component } from 'vue'
import {
  Download,
  Paperclip,
  ZoomIn,
  FileText,
  FileImage,
  FileVideo,
  FileAudio,
  FileArchive,
  FileSpreadsheet,
  FileCode,
  File,
  Presentation,
} from 'lucide-vue-next'
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

// File extension to icon mapping
const EXTENSION_ICON_MAP: Record<string, Component> = {
  // Documents
  pdf: FileText,
  doc: FileText,
  docx: FileText,
  txt: FileText,
  rtf: FileText,
  md: FileText,
  // Spreadsheets
  xls: FileSpreadsheet,
  xlsx: FileSpreadsheet,
  csv: FileSpreadsheet,
  // Presentations
  ppt: Presentation,
  pptx: Presentation,
  key: Presentation,
  // Code
  js: FileCode,
  ts: FileCode,
  jsx: FileCode,
  tsx: FileCode,
  html: FileCode,
  css: FileCode,
  json: FileCode,
  xml: FileCode,
  java: FileCode,
  kt: FileCode,
  py: FileCode,
  // Archives
  zip: FileArchive,
  rar: FileArchive,
  '7z': FileArchive,
  gz: FileArchive,
  tar: FileArchive,
  // Media
  mp3: FileAudio,
  wav: FileAudio,
  flac: FileAudio,
  ogg: FileAudio,
  mp4: FileVideo,
  mov: FileVideo,
  avi: FileVideo,
  mkv: FileVideo,
  webm: FileVideo,
  // Images
  jpg: FileImage,
  jpeg: FileImage,
  png: FileImage,
  gif: FileImage,
  webp: FileImage,
  svg: FileImage,
  bmp: FileImage,
}

function getFileExtension(filename: string): string {
  if (!filename || !filename.includes('.')) return ''
  return filename.split('.').pop()?.toLowerCase() || ''
}

function getFileIconComponent(attachment: NormalizedAttachment): Component {
  // First try by extension
  const ext = getFileExtension(attachment.originalFilename)
  if (ext && EXTENSION_ICON_MAP[ext]) {
    return EXTENSION_ICON_MAP[ext]
  }

  // Fallback by content type
  const contentType = attachment.contentType || ''
  if (contentType.startsWith('image/')) return FileImage
  if (contentType.startsWith('video/')) return FileVideo
  if (contentType.startsWith('audio/')) return FileAudio
  if (contentType.includes('pdf')) return FileText
  if (contentType.includes('word') || contentType.includes('document')) return FileText
  if (contentType.includes('excel') || contentType.includes('spreadsheet')) return FileSpreadsheet
  if (contentType.includes('powerpoint') || contentType.includes('presentation')) return Presentation
  if (contentType.includes('zip') || contentType.includes('rar') || contentType.includes('archive')) return FileArchive

  return File
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
        <div class="aspect-square bg-gray-100 flex items-center justify-center relative">
          <img
            v-if="getThumbnailUrl(attachment.id)"
            :src="getThumbnailUrl(attachment.id)!"
            :alt="attachment.originalFilename"
            class="w-full h-full object-cover"
          />
          <component
            v-else
            :is="getFileIconComponent(attachment)"
            class="w-12 h-12 text-gray-400"
          />

          <!-- Zoom overlay for images - shown on hover -->
          <div
            v-if="attachment.contentType?.startsWith('image/')"
            class="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
            @click.stop="openImageViewer(idx)"
          >
            <ZoomIn class="w-10 h-10 text-white" />
          </div>
        </div>

        <!-- Download button - always visible -->
        <button
          class="absolute top-1 right-1 p-1.5 bg-black/50 rounded text-white hover:bg-black/70 transition-colors"
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
