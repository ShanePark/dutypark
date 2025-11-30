<script setup lang="ts">
import { ref, shallowRef, onMounted, onUnmounted, watch, computed } from 'vue'
import Uppy from '@uppy/core'
import XHRUpload from '@uppy/xhr-upload'
import { Upload, X, FileIcon, Image, Loader2 } from 'lucide-vue-next'
import type {
  AttachmentContextType,
  NormalizedAttachment,
  CreateSessionResponse,
} from '@/types'
import {
  attachmentApi,
  attachmentValidation,
  normalizeAttachment,
  getDownloadUrl,
  formatBytes,
  getAttachmentIcon,
  validateFile,
  fetchAuthenticatedImage,
} from '@/api/attachment'

// Props
interface Props {
  contextType: AttachmentContextType
  targetContextId?: string | null
  existingAttachments?: NormalizedAttachment[]
  disabled?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  targetContextId: null,
  existingAttachments: () => [],
  disabled: false,
})

// Emits
const emit = defineEmits<{
  (e: 'update:attachments', attachments: NormalizedAttachment[]): void
  (e: 'session-created', sessionId: string): void
  (e: 'upload-start'): void
  (e: 'upload-complete'): void
  (e: 'error', message: string): void
}>()

// Refs
const uploadedAttachments = ref<NormalizedAttachment[]>([...props.existingAttachments])
const uploadProgress = ref<Record<string, number>>({})
const uploadMeta = ref<Record<string, { bytesUploaded: number; bytesTotal: number; startedAt: number }>>({})
const sessionId = ref<string | null>(null)
const sessionCreationPromise = ref<Promise<string> | null>(null)
const uppy = shallowRef<Uppy | null>(null)
const fileInputRef = ref<HTMLInputElement | null>(null)
const dropZoneRef = ref<HTMLElement | null>(null)
const isDragging = ref(false)
const ticker = ref(0)
const imageBlobUrls = ref<Record<string, string>>({})
let tickerInterval: number | null = null

// Computed
const isUploading = computed(() => Object.keys(uploadMeta.value).length > 0)
const hasAttachments = computed(() => uploadedAttachments.value.length > 0)

// Watchers
watch(
  () => props.existingAttachments,
  (newVal) => {
    uploadedAttachments.value = [...newVal]
    loadExistingImages()
  }
)

watch(uploadedAttachments, (newVal) => {
  emit('update:attachments', newVal)
}, { deep: true })

// Session management
async function ensureSession(): Promise<string> {
  if (sessionId.value) {
    return sessionId.value
  }

  if (!sessionCreationPromise.value) {
    sessionCreationPromise.value = attachmentApi
      .createSession({
        contextType: props.contextType,
        targetContextId: props.targetContextId,
      })
      .then((response: CreateSessionResponse) => {
        sessionId.value = response.sessionId
        emit('session-created', response.sessionId)
        return response.sessionId
      })
      .finally(() => {
        sessionCreationPromise.value = null
      })
  }

  return sessionCreationPromise.value
}

// Ticker for upload progress display
function startTicker() {
  if (tickerInterval) return
  tickerInterval = window.setInterval(() => {
    ticker.value = Date.now()
  }, 500)
  ticker.value = Date.now()
}

function stopTicker() {
  if (tickerInterval) {
    clearInterval(tickerInterval)
    tickerInterval = null
  }
  ticker.value = 0
}

// Setup Uppy
function setupUppy() {
  if (uppy.value) {
    try {
      uppy.value.cancelAll()
    } catch (e) {
      console.warn('Failed to cancel uppy:', e)
    }
  }

  const uppyInstance = new Uppy({
    restrictions: {
      maxFileSize: attachmentValidation.maxFileSizeBytes,
    },
    autoProceed: true,
  }).use(XHRUpload, {
    endpoint: '/api/attachments',
    fieldName: 'file',
    formData: true,
    bundle: false,
    withCredentials: true,
  })

  // File added event
  uppyInstance.on('file-added', (file) => {
    const fileData = file.data as File
    const validation = validateFile(fileData)
    if (!validation.valid) {
      uppyInstance.removeFile(file.id)
      emit('error', validation.message || '파일 검증 실패')
      return
    }

    const fileType = fileData?.type || ''
    const tempAttachment: NormalizedAttachment = {
      id: file.id,
      name: file.name,
      originalFilename: file.name,
      contentType: fileType,
      size: fileData?.size || 0,
      isImage: fileType.startsWith('image/'),
      hasThumbnail: false,
      thumbnailUrl: null,
      downloadUrl: null,
      orderIndex: uploadedAttachments.value.length,
      createdAt: null,
      createdBy: null,
      previewUrl: fileType.startsWith('image/') ? URL.createObjectURL(fileData) : null,
    }

    const wasIdle = Object.keys(uploadMeta.value).length === 0
    uploadedAttachments.value.push(tempAttachment)
    uploadProgress.value[file.id] = 0
    uploadMeta.value[file.id] = {
      bytesUploaded: 0,
      bytesTotal: fileData?.size || 0,
      startedAt: Date.now(),
    }

    if (wasIdle) {
      emit('upload-start')
      startTicker()
    }
  })

  // Pre-processor to ensure session exists
  uppyInstance.addPreProcessor(async (fileIDs: string[]) => {
    if (!fileIDs || fileIDs.length === 0) return

    try {
      const sid = await ensureSession()
      fileIDs.forEach((fileId) => {
        const file = uppyInstance.getFile(fileId)
        if (file) {
          uppyInstance.setFileMeta(fileId, {
            ...file.meta,
            sessionId: String(sid),
          })
        }
      })
    } catch (error) {
      emit('error', '파일 업로드 세션 생성에 실패했습니다.')
      fileIDs.forEach((fileId) => {
        removeFileFromState(fileId)
        const file = uppyInstance.getFile(fileId)
        if (file) uppyInstance.removeFile(fileId)
      })
      throw error
    }
  })

  // Upload progress
  uppyInstance.on('upload-progress', (file, progress) => {
    if (!file) return
    const bytesTotal = progress.bytesTotal ?? 1
    const bytesUploaded = progress.bytesUploaded ?? 0
    uploadProgress.value[file.id] = bytesUploaded / bytesTotal
    const meta = uploadMeta.value[file.id]
    if (meta) {
      meta.bytesUploaded = bytesUploaded
      meta.bytesTotal = bytesTotal
    }
  })

  // Upload success
  uppyInstance.on('upload-success', (file, response) => {
    if (!file) return
    const dto = response.body as unknown
    if (!dto) return
    const normalized = normalizeAttachment(dto as import('@/types').AttachmentDto)

    const index = uploadedAttachments.value.findIndex((a) => a.id === file.id)
    if (index !== -1) {
      const existing = uploadedAttachments.value[index]
      const oldPreviewUrl = existing?.previewUrl

      // Keep the local blob URL for display
      if (normalized.isImage && oldPreviewUrl?.startsWith('blob:')) {
        imageBlobUrls.value[normalized.id] = oldPreviewUrl
      }

      uploadedAttachments.value[index] = normalized
    }

    delete uploadProgress.value[file.id]
    delete uploadMeta.value[file.id]

    if (Object.keys(uploadMeta.value).length === 0) {
      emit('upload-complete')
      stopTicker()
    }
  })

  // Upload error
  uppyInstance.on('upload-error', (file, error, response) => {
    if (!file) return
    console.error('Upload error:', error, response)

    removeFileFromState(file.id)

    let message = '파일 업로드에 실패했습니다.'
    if (response?.status === 413) {
      message = attachmentValidation.tooLargeMessage(file.name)
    } else if (response?.status === 400 && response?.body?.code === 'ATTACHMENT_EXTENSION_BLOCKED') {
      message = attachmentValidation.blockedExtensionMessage(file.name)
    } else if (response?.body?.message) {
      message = response.body.message
    }

    emit('error', message)
  })

  // Restriction failed
  uppyInstance.on('restriction-failed', (file, error) => {
    if (error && /maximum allowed size/i.test(error.message || '')) {
      emit('error', attachmentValidation.tooLargeMessage(file?.name))
    } else {
      emit('error', '파일 추가에 실패했습니다.')
    }
  })

  uppy.value = uppyInstance
}

function removeFileFromState(fileId: string) {
  const index = uploadedAttachments.value.findIndex((a) => a.id === fileId)
  if (index !== -1) {
    const attachment = uploadedAttachments.value[index]
    if (attachment && attachment.previewUrl?.startsWith('blob:')) {
      URL.revokeObjectURL(attachment.previewUrl)
    }
    uploadedAttachments.value.splice(index, 1)
  }
  delete uploadProgress.value[fileId]
  delete uploadMeta.value[fileId]

  if (Object.keys(uploadMeta.value).length === 0) {
    stopTicker()
  }
}

// Remove attachment
function removeAttachment(attachmentId: string) {
  removeFileFromState(attachmentId)

  if (uppy.value) {
    const file = uppy.value.getFile(attachmentId)
    if (file) {
      try {
        uppy.value.removeFile(attachmentId)
      } catch (e) {
        console.warn('Failed to remove file from uppy:', e)
      }
    }
  }
}

// File input handler
function onFileSelect(event: Event) {
  const input = event.target as HTMLInputElement
  const files = Array.from(input.files || [])
  files.forEach((file) => {
    try {
      uppy.value?.addFile({
        name: file.name,
        type: file.type,
        data: file,
      })
    } catch (e) {
      console.error('Failed to add file:', e)
    }
  })
  input.value = ''
}

// Drag and drop handlers
function onDragOver(event: DragEvent) {
  event.preventDefault()
  event.stopPropagation()
  isDragging.value = true
}

function onDragLeave(event: DragEvent) {
  event.preventDefault()
  event.stopPropagation()
  isDragging.value = false
}

function onDrop(event: DragEvent) {
  event.preventDefault()
  event.stopPropagation()
  isDragging.value = false

  const files = Array.from(event.dataTransfer?.files || [])
  files.forEach((file) => {
    try {
      uppy.value?.addFile({
        name: file.name,
        type: file.type,
        data: file,
      })
    } catch (e) {
      console.error('Failed to add dropped file:', e)
    }
  })
}

// Cleanup
function cleanup() {
  if (uppy.value) {
    const uppyInstance = uppy.value
    uppy.value = null
    try {
      uppyInstance.cancelAll()
    } catch (e) {
      console.warn('Failed to cleanup uppy:', e)
    }
  }

  uploadedAttachments.value.forEach((attachment) => {
    if (attachment.previewUrl?.startsWith('blob:')) {
      URL.revokeObjectURL(attachment.previewUrl)
    }
  })

  // Cleanup cached blob URLs
  Object.values(imageBlobUrls.value).forEach((url) => {
    URL.revokeObjectURL(url)
  })
  imageBlobUrls.value = {}

  uploadedAttachments.value = []
  uploadProgress.value = {}
  uploadMeta.value = {}
  sessionId.value = null
  sessionCreationPromise.value = null
  stopTicker()
}

// Discard session
async function discardSession() {
  if (sessionId.value) {
    try {
      await attachmentApi.discardSession(sessionId.value)
    } catch (e) {
      console.warn('Failed to discard session:', e)
    }
  }
  cleanup()
}

// Expose methods
defineExpose({
  getSessionId: () => sessionId.value,
  getAttachments: () => uploadedAttachments.value,
  getOrderedIds: () => uploadedAttachments.value.map((a) => a.id),
  isUploading: () => isUploading.value,
  cleanup,
  discardSession,
})

// Lifecycle
onMounted(() => {
  setupUppy()
  loadExistingImages()
})

onUnmounted(() => {
  cleanup()
})

// Helper to get icon component
function getIconComponent(attachment: NormalizedAttachment) {
  const iconName = getAttachmentIcon(attachment)
  if (iconName === 'image') return Image
  return FileIcon
}

// Get display image URL for attachment
function getDisplayImageUrl(attachment: NormalizedAttachment): string | null {
  // First check blob URL cache
  const blobUrl = imageBlobUrls.value[attachment.id]
  if (blobUrl) {
    return blobUrl
  }
  // Then check previewUrl (local blob URL from upload)
  if (attachment.previewUrl?.startsWith('blob:')) {
    return attachment.previewUrl
  }
  return null
}

// Load authenticated image as blob URL
async function loadAuthenticatedImage(attachment: NormalizedAttachment) {
  if (!attachment.isImage) return
  if (imageBlobUrls.value[attachment.id]) return
  if (attachment.previewUrl?.startsWith('blob:')) return

  const imageUrl = attachment.thumbnailUrl || getDownloadUrl(attachment, true)
  if (!imageUrl) return

  const blobUrl = await fetchAuthenticatedImage(imageUrl)
  if (blobUrl) {
    imageBlobUrls.value[attachment.id] = blobUrl
  }
}

// Load images for existing attachments
async function loadExistingImages() {
  for (const attachment of uploadedAttachments.value) {
    await loadAuthenticatedImage(attachment)
  }
}
</script>

<template>
  <div class="file-uploader">
    <!-- Drop zone -->
    <div
      ref="dropZoneRef"
      class="drop-zone cursor-pointer"
      :class="{ 'drag-over': isDragging, disabled: disabled }"
      @dragover="onDragOver"
      @dragleave="onDragLeave"
      @drop="onDrop"
      @click="fileInputRef?.click()"
    >
      <Upload class="upload-icon" :size="24" />
      <span class="drop-text">파일을 드래그하거나 클릭하여 업로드</span>
      <span class="drop-hint">최대 {{ attachmentValidation.maxFileSizeLabel }}</span>
    </div>

    <input
      ref="fileInputRef"
      type="file"
      multiple
      class="hidden"
      :disabled="disabled"
      @change="onFileSelect"
    />

    <!-- Attachment list -->
    <div v-if="hasAttachments" class="attachment-list">
      <div
        v-for="attachment in uploadedAttachments"
        :key="attachment.id"
        class="attachment-item"
      >
        <!-- Thumbnail or icon -->
        <div class="attachment-preview">
          <template v-if="attachment.isImage && getDisplayImageUrl(attachment)">
            <img
              :src="getDisplayImageUrl(attachment) || ''"
              :alt="attachment.name"
              class="thumbnail"
            />
          </template>
          <template v-else>
            <component :is="getIconComponent(attachment)" :size="24" class="file-icon" />
          </template>
        </div>

        <!-- Info -->
        <div class="attachment-info">
          <span class="attachment-name" :title="attachment.name">{{ attachment.name }}</span>
          <span class="attachment-size">{{ formatBytes(attachment.size) }}</span>
        </div>

        <!-- Progress or actions -->
        <div class="attachment-actions">
          <template v-if="uploadProgress[attachment.id] !== undefined">
            <div class="upload-progress">
              <Loader2 class="spinner" :size="16" />
              <span class="progress-text">
                {{ Math.round((uploadProgress[attachment.id] || 0) * 100) }}%
              </span>
            </div>
          </template>
          <template v-else>
            <button
              type="button"
              class="remove-btn"
              :disabled="disabled"
              @click.stop="removeAttachment(attachment.id)"
            >
              <X :size="16" />
            </button>
          </template>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.file-uploader {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.drop-zone {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 1.5rem;
  border: 2px dashed var(--dp-border-primary);
  border-radius: 0.5rem;
  background-color: var(--dp-bg-secondary);
  transition: all 0.2s ease;
}

.drop-zone:hover:not(.disabled) {
  border-color: var(--color-primary, #3b82f6);
  background-color: var(--dp-bg-tertiary);
}

.drop-zone.drag-over {
  border-color: var(--color-primary, #3b82f6);
  background-color: var(--color-primary-light, #eff6ff);
}

.drop-zone.disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.upload-icon {
  color: var(--dp-text-secondary);
}

.drop-text {
  font-size: 0.875rem;
  color: var(--dp-text-secondary);
}

.drop-hint {
  font-size: 0.75rem;
  color: var(--dp-text-muted);
}

.hidden {
  display: none;
}

.attachment-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.attachment-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem;
  border: 1px solid var(--dp-border-primary);
  border-radius: 0.375rem;
  background-color: var(--dp-bg-card);
}

.attachment-preview {
  flex-shrink: 0;
  width: 2.5rem;
  height: 2.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 0.25rem;
  background-color: var(--dp-bg-secondary);
  overflow: hidden;
}

.thumbnail {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.file-icon {
  color: var(--dp-text-secondary);
}

.attachment-info {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.attachment-name {
  font-size: 0.875rem;
  color: var(--dp-text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.attachment-size {
  font-size: 0.75rem;
  color: var(--dp-text-muted);
}

.attachment-actions {
  flex-shrink: 0;
}

.upload-progress {
  display: flex;
  align-items: center;
  gap: 0.375rem;
}

.spinner {
  animation: spin 1s linear infinite;
  color: var(--color-primary, #3b82f6);
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

.progress-text {
  font-size: 0.75rem;
  color: var(--dp-text-secondary);
  min-width: 2.5rem;
}

.remove-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0.25rem;
  border: none;
  border-radius: 0.25rem;
  background: transparent;
  color: var(--dp-text-secondary);
  cursor: pointer;
  transition: all 0.15s ease;
}

.remove-btn:hover:not(:disabled) {
  background-color: var(--color-danger-light, #fef2f2);
  color: var(--color-danger, #ef4444);
}

.remove-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
