<script setup lang="ts">
import { computed, ref, watch, onMounted, onUnmounted } from 'vue'
import { fetchAuthenticatedImage } from '@/api/attachment'

interface Props {
  memberId?: number | null
  size?: 'xs' | 'sm' | 'md' | 'xl'
  /** `portrait` fills the parent box with an ID-photo style rounded rectangle. */
  shape?: 'circle' | 'portrait'
  name?: string
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
}

const props = withDefaults(defineProps<Props>(), {
  memberId: null,
  size: 'md',
  shape: 'circle',
  name: '',
  hasProfilePhoto: false,
  profilePhotoVersion: 0,
})

const photoUrl = computed(() => {
  if (!props.memberId) return null
  return `/api/members/${props.memberId}/profile-photo?thumbnail=true&v=${props.profilePhotoVersion}`
})

const sizeClasses = computed(() => {
  if (props.shape === 'portrait') {
    return 'w-full h-full'
  }

  switch (props.size) {
    case 'xs':
      return 'w-3.5 h-3.5 sm:w-4 sm:h-4'
    case 'sm':
      return 'w-6 h-6 sm:w-8 sm:h-8'
    case 'md':
      return 'w-9 h-9'
    case 'xl':
      return 'w-16 h-16'
    default:
      return 'w-9 h-9'
  }
})

const imageError = ref(false)
const imageBlobUrl = ref<string | null>(null)

async function loadImage() {
  if (!photoUrl.value || !props.hasProfilePhoto) {
    imageBlobUrl.value = null
    return
  }

  imageError.value = false
  const blobUrl = await fetchAuthenticatedImage(photoUrl.value)
  if (blobUrl) {
    imageBlobUrl.value = blobUrl
  } else {
    imageError.value = true
  }
}

function handleImageError() {
  imageError.value = true
}

watch(
  () => [props.memberId, props.hasProfilePhoto, props.profilePhotoVersion],
  () => {
    if (imageBlobUrl.value) {
      URL.revokeObjectURL(imageBlobUrl.value)
      imageBlobUrl.value = null
    }
    loadImage()
  }
)

onMounted(() => {
  loadImage()
})

onUnmounted(() => {
  if (imageBlobUrl.value) {
    URL.revokeObjectURL(imageBlobUrl.value)
  }
})
</script>

<template>
  <div
    class="profile-avatar flex items-center justify-center overflow-hidden flex-shrink-0"
    :class="[sizeClasses, shape === 'portrait' ? 'rounded-xl' : 'rounded-full']"
  >
    <img
      v-if="imageBlobUrl && !imageError"
      :src="imageBlobUrl"
      :alt="name || 'Profile'"
      draggable="false"
      class="w-full h-full object-cover"
      @error="handleImageError"
    />
    <img
      v-else
      src="/img/default-profile.png"
      :alt="name || 'Profile'"
      draggable="false"
      class="w-full h-full object-cover"
    />
  </div>
</template>

<style scoped>
.profile-avatar {
  background-color: var(--dp-bg-tertiary);
  border: 2px solid var(--dp-border-primary);
}

</style>
