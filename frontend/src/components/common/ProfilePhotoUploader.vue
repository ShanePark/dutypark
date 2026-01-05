<script setup lang="ts">
import { ref, shallowRef, computed, onMounted, onUnmounted, watch } from 'vue'
import Uppy from '@uppy/core'
import XHRUpload from '@uppy/xhr-upload'
import { Camera, Trash2, Loader2, Upload } from 'lucide-vue-next'
import { memberApi } from '@/api/member'
import { attachmentApi, attachmentValidation, validateFile, fetchAuthenticatedImage } from '@/api/attachment'
import { useSwal } from '@/composables/useSwal'
import ImageCropModal from '@/components/common/ImageCropModal.vue'
import type { CreateSessionResponse, AttachmentDto } from '@/types'

interface Props {
  currentPhotoUrl?: string | null
  disabled?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  currentPhotoUrl: null,
  disabled: false,
})

const emit = defineEmits<{
  (e: 'update:photoUrl', photoUrl: string | null): void
  (e: 'upload-complete', photoUrl: string | null): void
}>()

const { showError, toastSuccess, confirm } = useSwal()

const displayPhotoUrl = ref<string | null>(null)
const isUploading = ref(false)
const isDeleting = ref(false)
const sessionId = ref<string | null>(null)
const uploadedAttachmentId = ref<string | null>(null)
const uppy = shallowRef<Uppy | null>(null)

const showCropModal = ref(false)

const hasPhoto = computed(() => !!displayPhotoUrl.value)

async function loadCurrentPhoto() {
  if (props.currentPhotoUrl) {
    const blobUrl = await fetchAuthenticatedImage(props.currentPhotoUrl)
    if (blobUrl) {
      displayPhotoUrl.value = blobUrl
    }
  }
}

watch(
  () => props.currentPhotoUrl,
  async (newUrl) => {
    if (displayPhotoUrl.value?.startsWith('blob:')) {
      URL.revokeObjectURL(displayPhotoUrl.value)
    }
    if (newUrl) {
      await loadCurrentPhoto()
    } else {
      displayPhotoUrl.value = null
    }
  }
)

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
      maxNumberOfFiles: 1,
      allowedFileTypes: ['image/*'],
    },
    autoProceed: true,
  }).use(XHRUpload, {
    endpoint: '/api/attachments',
    fieldName: 'file',
    formData: true,
    bundle: false,
    withCredentials: true,
  })

  uppyInstance.on('file-added', async (file) => {
    const fileData = file.data as File
    const validation = validateFile(fileData)
    if (!validation.valid) {
      uppyInstance.removeFile(file.id)
      showError(validation.message || 'File validation failed')
      return
    }

    if (!fileData.type.startsWith('image/')) {
      uppyInstance.removeFile(file.id)
      showError('이미지 파일만 업로드할 수 있습니다')
      return
    }

    isUploading.value = true
  })

  uppyInstance.addPreProcessor(async (fileIDs: string[]) => {
    if (!fileIDs || fileIDs.length === 0) return

    try {
      const response: CreateSessionResponse = await attachmentApi.createSession({
        contextType: 'PROFILE',
        targetContextId: null,
      })
      sessionId.value = response.sessionId

      fileIDs.forEach((fileId) => {
        const file = uppyInstance.getFile(fileId)
        if (file) {
          uppyInstance.setFileMeta(fileId, {
            ...file.meta,
            sessionId: String(sessionId.value),
          })
        }
      })
    } catch (error) {
      showError('업로드 세션 생성에 실패했습니다')
      fileIDs.forEach((fileId) => {
        uppyInstance.removeFile(fileId)
      })
      isUploading.value = false
      throw error
    }
  })

  uppyInstance.on('upload-success', async (file, response) => {
    if (!file) return
    const dto = response.body as unknown as AttachmentDto
    if (!dto || !dto.id) {
      isUploading.value = false
      return
    }

    uploadedAttachmentId.value = dto.id

    if (displayPhotoUrl.value?.startsWith('blob:')) {
      URL.revokeObjectURL(displayPhotoUrl.value)
    }
    const fileData = file.data as File
    displayPhotoUrl.value = URL.createObjectURL(fileData)

    try {
      if (!sessionId.value || !uploadedAttachmentId.value) {
        throw new Error('Session or attachment ID missing')
      }

      const result = await memberApi.updateProfilePhoto({
        sessionId: sessionId.value,
        attachmentId: uploadedAttachmentId.value,
      })

      emit('update:photoUrl', result.data.profilePhotoUrl)
      emit('upload-complete', result.data.profilePhotoUrl)
      toastSuccess('프로필 사진이 업데이트되었습니다')
    } catch (error) {
      console.error('Failed to update profile photo:', error)
      showError('프로필 사진 저장에 실패했습니다')
    } finally {
      isUploading.value = false
      sessionId.value = null
      uploadedAttachmentId.value = null
    }
  })

  uppyInstance.on('upload-error', (file, error) => {
    console.error('Upload error:', error)
    isUploading.value = false
    showError('파일 업로드에 실패했습니다')
  })

  uppyInstance.on('restriction-failed', (file, error) => {
    if (error && /maximum allowed size/i.test(error.message || '')) {
      showError(attachmentValidation.tooLargeMessage(file?.name))
    } else if (error && /allowed file types/i.test(error.message || '')) {
      showError('이미지 파일만 업로드할 수 있습니다')
    } else {
      showError('파일 업로드가 허용되지 않습니다')
    }
  })

  uppy.value = uppyInstance
}

function openCropModal() {
  if (props.disabled || isUploading.value) return
  showCropModal.value = true
}

function onCropConfirm(croppedFile: File) {
  showCropModal.value = false

  try {
    uppy.value?.addFile({
      name: croppedFile.name,
      type: croppedFile.type,
      data: croppedFile,
    })
  } catch (e) {
    console.error('Failed to add cropped file:', e)
    showError('크롭된 이미지 처리에 실패했습니다')
  }
}

function onCropCancel() {
  showCropModal.value = false
}

async function deletePhoto() {
  if (!hasPhoto.value || isDeleting.value || props.disabled) return

  const confirmed = await confirm('프로필 사진을 삭제하시겠습니까?', '사진 삭제')
  if (!confirmed) return

  isDeleting.value = true
  try {
    await memberApi.deleteProfilePhoto()
    if (displayPhotoUrl.value?.startsWith('blob:')) {
      URL.revokeObjectURL(displayPhotoUrl.value)
    }
    displayPhotoUrl.value = null
    emit('update:photoUrl', null)
    emit('upload-complete', null)
    toastSuccess('프로필 사진이 삭제되었습니다')
  } catch (error) {
    console.error('Failed to delete profile photo:', error)
    showError('프로필 사진 삭제에 실패했습니다')
  } finally {
    isDeleting.value = false
  }
}

function cleanup() {
  if (uppy.value) {
    try {
      uppy.value.cancelAll()
    } catch (e) {
      console.warn('Failed to cleanup uppy:', e)
    }
    uppy.value = null
  }
  if (displayPhotoUrl.value?.startsWith('blob:')) {
    URL.revokeObjectURL(displayPhotoUrl.value)
  }
}

onMounted(() => {
  setupUppy()
  loadCurrentPhoto()
})

onUnmounted(() => {
  cleanup()
})
</script>

<template>
  <div class="profile-photo-uploader">
    <div class="photo-container" @click="openCropModal">
      <div v-if="hasPhoto" class="photo-preview">
        <img :src="displayPhotoUrl!" alt="Profile" class="photo-image" />
        <div class="photo-overlay">
          <Camera class="w-6 h-6 text-white" />
        </div>
      </div>
      <div v-else class="photo-placeholder">
        <Upload class="w-8 h-8" />
        <span class="text-sm mt-1">Upload Photo</span>
      </div>
      <div v-if="isUploading" class="upload-loading">
        <Loader2 class="w-8 h-8 animate-spin text-white" />
      </div>
    </div>

    <div class="actions">
      <button
        v-if="hasPhoto"
        type="button"
        class="delete-btn"
        :disabled="disabled || isDeleting || isUploading"
        @click.stop="deletePhoto"
      >
        <Loader2 v-if="isDeleting" class="w-4 h-4 animate-spin" />
        <Trash2 v-else class="w-4 h-4" />
        <span>Delete</span>
      </button>
    </div>

    <ImageCropModal
      :is-open="showCropModal"
      @close="onCropCancel"
      @confirm="onCropConfirm"
    />
  </div>
</template>

<style scoped>
.profile-photo-uploader {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
}

.photo-container {
  position: relative;
  width: 120px;
  height: 120px;
  border-radius: 50%;
  cursor: pointer;
  overflow: hidden;
  transition: all 0.2s ease;
}

.photo-container:hover {
  transform: scale(1.02);
}

.photo-preview {
  width: 100%;
  height: 100%;
  position: relative;
}

.photo-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.photo-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: rgba(0, 0, 0, 0.4);
  opacity: 0;
  transition: opacity 0.2s ease;
}

.photo-preview:hover .photo-overlay {
  opacity: 1;
}

.photo-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background-color: var(--dp-bg-tertiary);
  border-radius: 50%;
  color: var(--dp-text-muted);
  transition: all 0.2s ease;
}

.photo-placeholder:hover {
  color: var(--color-primary, #3b82f6);
  background-color: var(--dp-bg-hover);
}

.upload-loading {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: rgba(0, 0, 0, 0.6);
}

.actions {
  display: flex;
  gap: 0.5rem;
}

.delete-btn {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.5rem 1rem;
  font-size: 0.875rem;
  font-weight: 500;
  border-radius: 0.5rem;
  border: none;
  background-color: var(--dp-bg-tertiary);
  color: var(--dp-text-secondary);
  cursor: pointer;
  transition: all 0.15s ease;
}

.delete-btn:hover:not(:disabled) {
  background-color: #fee2e2;
  color: #dc2626;
}

.dark .delete-btn:hover:not(:disabled) {
  background-color: rgba(220, 38, 38, 0.2);
  color: #f87171;
}

.delete-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
