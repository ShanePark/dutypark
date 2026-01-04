<script setup lang="ts">
import { computed, ref, watch, onMounted } from 'vue'
import { User } from 'lucide-vue-next'
import { fetchAuthenticatedImage } from '@/api/attachment'

interface Props {
  photoUrl?: string | null
  size?: 'sm' | 'md' | 'lg' | 'xl'
  name?: string
}

const props = withDefaults(defineProps<Props>(), {
  photoUrl: null,
  size: 'md',
  name: '',
})

const sizeClasses = computed(() => {
  switch (props.size) {
    case 'sm':
      return 'w-6 h-6 sm:w-8 sm:h-8'
    case 'md':
      return 'w-9 h-9'
    case 'lg':
      return 'w-12 h-12'
    case 'xl':
      return 'w-16 h-16'
    default:
      return 'w-9 h-9'
  }
})

const iconSizeClasses = computed(() => {
  switch (props.size) {
    case 'sm':
      return 'w-3 h-3 sm:w-4 sm:h-4'
    case 'md':
      return 'w-5 h-5'
    case 'lg':
      return 'w-6 h-6'
    case 'xl':
      return 'w-8 h-8'
    default:
      return 'w-5 h-5'
  }
})

const imageError = ref(false)
const imageBlobUrl = ref<string | null>(null)

async function loadImage() {
  if (!props.photoUrl) {
    imageBlobUrl.value = null
    return
  }

  imageError.value = false
  const blobUrl = await fetchAuthenticatedImage(props.photoUrl)
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
  () => props.photoUrl,
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
</script>

<template>
  <div
    class="profile-avatar rounded-full flex items-center justify-center overflow-hidden flex-shrink-0"
    :class="sizeClasses"
  >
    <img
      v-if="imageBlobUrl && !imageError"
      :src="imageBlobUrl"
      :alt="name || 'Profile'"
      class="w-full h-full object-cover"
      @error="handleImageError"
    />
    <div
      v-else
      class="w-full h-full flex items-center justify-center profile-avatar-fallback"
    >
      <User :class="iconSizeClasses" />
    </div>
  </div>
</template>

<style scoped>
.profile-avatar {
  background-color: var(--dp-bg-tertiary);
  border: 1px solid var(--dp-border-primary);
}

.profile-avatar-fallback {
  color: var(--dp-text-muted);
}
</style>
