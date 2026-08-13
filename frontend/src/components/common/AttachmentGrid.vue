<script setup lang="ts">
import { ref, watch, reactive, type Component } from 'vue'
import { useI18n } from 'vue-i18n'
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
  columns?: 2 | 4
}

const props = withDefaults(defineProps<Props>(), {
  columns: 2,
})

const { t } = useI18n()
const thumbnailBlobUrls = reactive<Record<string, string>>({})

const imageViewerOpen = ref(false)
const imageViewerIndex = ref(0)
const imageAttachments = ref<Array<{ id: string; originalFilename: string }>>([])

const EXTENSION_ICON_MAP: Record<string, Component> = {
  pdf: FileText,
  doc: FileText,
  docx: FileText,
  txt: FileText,
  rtf: FileText,
  md: FileText,
  xls: FileSpreadsheet,
  xlsx: FileSpreadsheet,
  csv: FileSpreadsheet,
  ppt: Presentation,
  pptx: Presentation,
  key: Presentation,
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
  zip: FileArchive,
  rar: FileArchive,
  '7z': FileArchive,
  gz: FileArchive,
  tar: FileArchive,
  mp3: FileAudio,
  wav: FileAudio,
  flac: FileAudio,
  ogg: FileAudio,
  mp4: FileVideo,
  mov: FileVideo,
  avi: FileVideo,
  mkv: FileVideo,
  webm: FileVideo,
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
  const ext = getFileExtension(attachment.originalFilename)
  if (ext && EXTENSION_ICON_MAP[ext]) {
    return EXTENSION_ICON_MAP[ext]
  }

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
    if (thumbnailBlobUrls[attachment.id]) continue

    // For images, always try to load thumbnail (backend falls back to original if thumbnail not ready)
    if (attachment.isImage) {
      const thumbnailUrl = attachment.thumbnailUrl || `/api/attachments/${attachment.id}/thumbnail`
      const blobUrl = await fetchAuthenticatedImage(thumbnailUrl)
      if (blobUrl) {
        thumbnailBlobUrls[attachment.id] = blobUrl
      }
    } else if (attachment.hasThumbnail && attachment.thumbnailUrl) {
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

  // Only open image viewer for images; non-image files require explicit download button click
  if (attachment.contentType?.startsWith('image/')) {
    openImageViewer(index)
  }
}

function openImageViewer(clickedIndex: number) {
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

watch(
  () => props.attachments,
  () => {
    loadThumbnails()
  },
  { immediate: true, deep: true }
)

const gridColsClass = {
  2: 'grid-cols-2',
  4: 'grid-cols-2 sm:grid-cols-4',
}
</script>

<template>
  <div v-if="attachments.length > 0">
    <div class="flex items-center gap-1 text-sm mb-2 text-dp-text-muted">
      <Paperclip class="w-3 h-3" />
      {{ t('attachmentGrid.label', { count: attachments.length }) }}
    </div>
    <div class="grid gap-2" :class="gridColsClass[columns]">
      <div
        v-for="(attachment, idx) in attachments"
        :key="attachment.id"
        class="relative rounded-lg overflow-hidden group"
        :class="{ 'cursor-pointer': attachment.contentType?.startsWith('image/') }"
        :style="{ border: `1px solid var(--dp-border-primary)` }"
        @click="handleAttachmentClick(idx)"
      >
        <div
          class="aspect-square flex items-center justify-center relative bg-dp-bg-secondary"
        >
          <img
            v-if="getThumbnailUrl(attachment.id)"
            :src="getThumbnailUrl(attachment.id)!"
            :alt="attachment.originalFilename"
            class="w-full h-full object-cover"
          />
          <component
            v-else
            :is="getFileIconComponent(attachment)"
            class="w-12 h-12 text-dp-text-muted"
          />

          <div
            v-if="attachment.contentType?.startsWith('image/')"
            class="absolute inset-0 bg-dp-overlay-dark/40 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
            @click.stop="openImageViewer(idx)"
          >
            <ZoomIn class="w-10 h-10 text-dp-text-on-dark" />
          </div>
        </div>

        <button
          class="absolute top-1 right-1 p-2.5 sm:p-1.5 bg-dp-overlay-dark/50 rounded text-dp-text-on-dark hover:bg-dp-overlay-dark/70 active:bg-dp-overlay-dark/80 transition-colors cursor-pointer"
          @click.stop="downloadAttachment(attachment.id, attachment.originalFilename)"
          :title="t('common.actions.download')"
        >
          <Download class="w-5 h-5 sm:w-4 sm:h-4" />
        </button>

        <div class="p-2 bg-dp-bg-card">
          <p class="text-sm truncate text-dp-text-primary" :title="attachment.originalFilename">
            {{ attachment.originalFilename }}
          </p>
          <p class="text-xs text-dp-text-muted">{{ formatBytes(attachment.size) }}</p>
        </div>
      </div>
    </div>

    <ImageViewer
      :is-open="imageViewerOpen"
      :images="imageAttachments"
      :initial-index="imageViewerIndex"
      @close="imageViewerOpen = false"
    />
  </div>
</template>
