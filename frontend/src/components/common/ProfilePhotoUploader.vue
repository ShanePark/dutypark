<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { Camera, Loader2, Upload } from 'lucide-vue-next'
import { memberApi } from '@/api/member'
import { fetchAuthenticatedImage } from '@/api/attachment'
import { useSwal } from '@/composables/useSwal'
import ImageCropModal from '@/components/common/ImageCropModal.vue'

interface Props {
  memberId: number
  disabled?: boolean
  profilePhotoVersion?: number
  size?: 'sm' | 'md' | 'lg'
}

const props = withDefaults(defineProps<Props>(), {
  disabled: false,
  profilePhotoVersion: 0,
  size: 'lg',
})

const sizeClasses: Record<string, string> = {
  sm: 'photo-size-sm',
  md: 'photo-size-md',
  lg: 'photo-size-lg',
}

const emit = defineEmits<{
  (e: 'upload-complete'): void
}>()

const { showError, toastSuccess, confirm } = useSwal()

const displayPhotoUrl = ref<string | null>(null)
const isUploading = ref(false)
const isDeleting = ref(false)

const showCropModal = ref(false)

const hasPhoto = computed(() => !!displayPhotoUrl.value)

const photoUrl = computed(() => {
  return `/api/members/${props.memberId}/profile-photo?v=${props.profilePhotoVersion}`
})

async function loadCurrentPhoto() {
  if (displayPhotoUrl.value?.startsWith('blob:')) {
    URL.revokeObjectURL(displayPhotoUrl.value)
  }
  const blobUrl = await fetchAuthenticatedImage(photoUrl.value)
  displayPhotoUrl.value = blobUrl
}

watch(
  () => [props.memberId, props.profilePhotoVersion],
  async () => {
    await loadCurrentPhoto()
  }
)

function openCropModal() {
  if (props.disabled || isUploading.value) return
  showCropModal.value = true
}

async function onCropConfirm(croppedFile: File) {
  showCropModal.value = false
  await uploadFile(croppedFile)
}

async function uploadFile(file: File) {
  isUploading.value = true

  try {
    await memberApi.updateProfilePhoto(file)

    if (displayPhotoUrl.value?.startsWith('blob:')) {
      URL.revokeObjectURL(displayPhotoUrl.value)
    }
    displayPhotoUrl.value = URL.createObjectURL(file)

    emit('upload-complete')
    toastSuccess('프로필 사진이 업데이트되었습니다')
  } catch (error) {
    console.error('Failed to upload profile photo:', error)
    showError('프로필 사진 업로드에 실패했습니다')
  } finally {
    isUploading.value = false
  }
}

function onCropCancel() {
  showCropModal.value = false
}

async function deletePhoto() {
  if (!hasPhoto.value || isDeleting.value || props.disabled) return

  isDeleting.value = true
  try {
    await memberApi.deleteProfilePhoto()
    if (displayPhotoUrl.value?.startsWith('blob:')) {
      URL.revokeObjectURL(displayPhotoUrl.value)
    }
    displayPhotoUrl.value = null
    emit('upload-complete')
    toastSuccess('프로필 사진이 삭제되었습니다')
  } catch (error) {
    console.error('Failed to delete profile photo:', error)
    showError('프로필 사진 삭제에 실패했습니다')
  } finally {
    isDeleting.value = false
    showCropModal.value = false
  }
}

async function onCropDelete() {
  const confirmed = await confirm('프로필 사진을 삭제하시겠습니까?', '사진 삭제')
  if (confirmed) {
    await deletePhoto()
  }
}

onMounted(() => {
  loadCurrentPhoto()
})
</script>

<template>
  <div class="profile-photo-uploader">
    <div class="photo-container" :class="sizeClasses[props.size]" @click="openCropModal">
      <div v-if="hasPhoto" class="photo-preview">
        <img :src="displayPhotoUrl!" alt="Profile" class="photo-image" />
        <div class="photo-overlay">
          <Camera :class="props.size === 'sm' ? 'w-4 h-4' : 'w-6 h-6'" class="text-white" />
        </div>
      </div>
      <div v-else class="photo-placeholder">
        <Upload :class="props.size === 'sm' ? 'w-5 h-5' : 'w-8 h-8'" />
        <span v-if="props.size !== 'sm'" class="text-sm mt-1">Upload Photo</span>
      </div>
      <div v-if="isUploading || isDeleting" class="upload-loading">
        <Loader2 class="w-8 h-8 animate-spin text-white" />
      </div>
    </div>

    <ImageCropModal
      :is-open="showCropModal"
      :initial-image-source="displayPhotoUrl"
      :has-existing-photo="hasPhoto"
      @close="onCropCancel"
      @confirm="onCropConfirm"
      @delete="onCropDelete"
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
  border-radius: 50%;
  cursor: pointer;
  overflow: hidden;
  transition: all 0.2s ease;
  border: 3px solid var(--dp-border-secondary);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.photo-size-sm {
  width: 80px;
  height: 80px;
}

.photo-size-md {
  width: 100px;
  height: 100px;
}

.photo-size-lg {
  width: 120px;
  height: 120px;
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
  color: var(--dp-accent);
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
</style>
