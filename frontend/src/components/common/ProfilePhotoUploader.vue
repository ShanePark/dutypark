<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { Camera, Loader2, Upload } from '@lucide/vue'
import { memberApi } from '@/api/member'
import { fetchAuthenticatedImage } from '@/api/attachment'
import { useSwal } from '@/composables/useSwal'
import ImageCropModal from '@/components/common/ImageCropModal.vue'

interface Props {
  memberId: number
  profilePhotoVersion?: number
  size?: 'sm' | 'lg' | 'responsive'
}

const props = withDefaults(defineProps<Props>(), {
  profilePhotoVersion: 0,
  size: 'lg',
})

const sizeClasses: Record<string, string> = {
  sm: 'photo-size-sm',
  lg: 'photo-size-lg',
  responsive: 'photo-size-responsive',
}

const emit = defineEmits<{
  (e: 'upload-complete'): void
}>()

const { t } = useI18n()
const { showError, toastSuccess, confirm } = useSwal()

const displayPhotoUrl = ref<string | null>(null)
const isUploading = ref(false)
const isDeleting = ref(false)

const showCropModal = ref(false)
let photoRequestId = 0
let isUnmounted = false

const hasPhoto = computed(() => !!displayPhotoUrl.value)

const photoUrl = computed(() => {
  return `/api/members/${props.memberId}/profile-photo?v=${props.profilePhotoVersion}`
})

function replaceDisplayPhoto(url: string | null) {
  if (displayPhotoUrl.value?.startsWith('blob:')) {
    URL.revokeObjectURL(displayPhotoUrl.value)
  }
  if (isUnmounted) {
    if (url?.startsWith('blob:')) URL.revokeObjectURL(url)
    displayPhotoUrl.value = null
    return
  }
  displayPhotoUrl.value = url
}

async function loadCurrentPhoto() {
  const requestId = ++photoRequestId
  const blobUrl = await fetchAuthenticatedImage(photoUrl.value)
  if (requestId !== photoRequestId || isUnmounted) {
    if (blobUrl) URL.revokeObjectURL(blobUrl)
    return
  }
  replaceDisplayPhoto(blobUrl)
}

watch(
  () => [props.memberId, props.profilePhotoVersion],
  async () => {
    await loadCurrentPhoto()
  }
)

function openCropModal() {
  if (isUploading.value) return
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

    photoRequestId++
    replaceDisplayPhoto(URL.createObjectURL(file))

    emit('upload-complete')
    toastSuccess(t('profilePhoto.updated'))
  } catch (error) {
    console.error('Failed to upload profile photo:', error)
    showError(t('profilePhoto.updateFailed'))
  } finally {
    isUploading.value = false
  }
}

function onCropCancel() {
  showCropModal.value = false
}

async function deletePhoto() {
  if (!hasPhoto.value || isDeleting.value) return

  isDeleting.value = true
  try {
    await memberApi.deleteProfilePhoto()
    photoRequestId++
    replaceDisplayPhoto(null)
    emit('upload-complete')
    toastSuccess(t('profilePhoto.deleted'))
  } catch (error) {
    console.error('Failed to delete profile photo:', error)
    showError(t('profilePhoto.deleteFailed'))
  } finally {
    isDeleting.value = false
    showCropModal.value = false
  }
}

async function onCropDelete() {
  const confirmed = await confirm(
    t('profilePhoto.deleteConfirm'),
    t('profilePhoto.deleteTitle'),
  )
  if (confirmed) {
    await deletePhoto()
  }
}

onMounted(() => {
  loadCurrentPhoto()
})

onUnmounted(() => {
  isUnmounted = true
  photoRequestId++
  replaceDisplayPhoto(null)
})
</script>

<template>
  <div class="profile-photo-uploader">
    <div class="photo-container" :class="sizeClasses[props.size]" @click="openCropModal">
      <div v-if="hasPhoto" class="photo-preview">
        <img :src="displayPhotoUrl!" :alt="t('profilePhoto.alt')" class="photo-image" />
        <div class="photo-overlay">
          <Camera :class="props.size === 'sm' ? 'w-4 h-4' : props.size === 'responsive' ? 'w-4 h-4 sm:w-6 sm:h-6' : 'w-6 h-6'" class="text-dp-text-on-dark" />
        </div>
      </div>
      <div v-else class="photo-placeholder">
        <Upload :class="props.size === 'sm' ? 'w-5 h-5' : props.size === 'responsive' ? 'w-5 h-5 sm:w-8 sm:h-8' : 'w-8 h-8'" />
        <span v-if="props.size !== 'sm'" class="text-sm mt-1" :class="{ 'hidden sm:inline': props.size === 'responsive' }">{{ t('profilePhoto.uploadPrompt') }}</span>
      </div>
      <div v-if="isUploading || isDeleting" class="upload-loading">
        <Loader2 class="w-8 h-8 animate-spin text-dp-text-on-dark" />
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
  box-shadow: var(--dp-shadow-md);
}

.photo-size-sm,
.photo-size-responsive {
  width: 80px;
  height: 80px;
}

.photo-size-lg {
  width: 120px;
  height: 120px;
}

@media (min-width: 40rem) {
  .photo-size-responsive {
    width: 120px;
    height: 120px;
  }
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
  background-color: var(--dp-overlay-scrim-medium);
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
  background-color: var(--dp-overlay-scrim-strong);
}
</style>
