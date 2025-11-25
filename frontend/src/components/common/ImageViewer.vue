<script setup lang="ts">
import { ref, watch, onMounted, onUnmounted } from 'vue'
import { X, ChevronLeft, ChevronRight, Download } from 'lucide-vue-next'
import { fetchAuthenticatedImage } from '@/api/attachment'

interface ImageItem {
  id: string
  originalFilename: string
}

interface Props {
  isOpen: boolean
  images: ImageItem[]
  initialIndex?: number
}

const props = withDefaults(defineProps<Props>(), {
  initialIndex: 0,
})

const emit = defineEmits<{
  (e: 'close'): void
}>()

const currentIndex = ref(0)
const fullImageUrls = ref<Record<string, string>>({})
const isLoading = ref(false)

// Touch/swipe handling
const touchStartX = ref(0)
const touchStartY = ref(0)
const touchEndX = ref(0)
const touchEndY = ref(0)
const isSwiping = ref(false)
const SWIPE_THRESHOLD = 50

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      currentIndex.value = props.initialIndex
      loadFullImage(props.images[props.initialIndex]?.id)
    }
  }
)

async function loadFullImage(attachmentId: string | undefined) {
  if (!attachmentId || fullImageUrls.value[attachmentId]) return
  isLoading.value = true
  try {
    const blobUrl = await fetchAuthenticatedImage(`/api/attachments/${attachmentId}/download?inline=true`)
    if (blobUrl) {
      fullImageUrls.value[attachmentId] = blobUrl
    }
  } finally {
    isLoading.value = false
  }
}

function prevImage() {
  if (currentIndex.value > 0) {
    currentIndex.value--
    loadFullImage(props.images[currentIndex.value]?.id)
  }
}

function nextImage() {
  if (currentIndex.value < props.images.length - 1) {
    currentIndex.value++
    loadFullImage(props.images[currentIndex.value]?.id)
  }
}

function getCurrentImageUrl(): string | null {
  const image = props.images[currentIndex.value]
  if (!image) return null
  return fullImageUrls.value[image.id] || null
}

async function downloadImage() {
  const image = props.images[currentIndex.value]
  if (!image) return

  const blobUrl = await fetchAuthenticatedImage(`/api/attachments/${image.id}/download`)
  if (blobUrl) {
    const a = document.createElement('a')
    a.href = blobUrl
    a.download = image.originalFilename
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(blobUrl)
  }
}

function handleKeydown(e: KeyboardEvent) {
  if (!props.isOpen) return
  if (e.key === 'Escape') emit('close')
  if (e.key === 'ArrowLeft') prevImage()
  if (e.key === 'ArrowRight') nextImage()
}

// Touch handlers for swipe navigation
function handleTouchStart(e: TouchEvent) {
  const touch = e.touches[0]
  if (!touch) return
  touchStartX.value = touch.clientX
  touchStartY.value = touch.clientY
  isSwiping.value = true
}

function handleTouchMove(e: TouchEvent) {
  if (!isSwiping.value) return
  const touch = e.touches[0]
  if (!touch) return
  touchEndX.value = touch.clientX
  touchEndY.value = touch.clientY
}

function handleTouchEnd() {
  if (!isSwiping.value) return
  isSwiping.value = false

  const deltaX = touchEndX.value - touchStartX.value
  const deltaY = Math.abs(touchEndY.value - touchStartY.value)

  // Only handle horizontal swipes (ignore vertical scrolling)
  if (Math.abs(deltaX) > SWIPE_THRESHOLD && Math.abs(deltaX) > deltaY) {
    if (deltaX > 0) {
      prevImage()
    } else {
      nextImage()
    }
  }

  // Reset touch values
  touchStartX.value = 0
  touchStartY.value = 0
  touchEndX.value = 0
  touchEndY.value = 0
}

// Keyboard navigation
onMounted(() => {
  window.addEventListener('keydown', handleKeydown)
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeydown)
})
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen && images.length > 0"
      class="fixed inset-0 z-[60] flex items-center justify-center bg-black/90"
      @click.self="emit('close')"
      @touchstart="handleTouchStart"
      @touchmove="handleTouchMove"
      @touchend="handleTouchEnd"
    >
      <!-- Close button -->
      <button
        @click="emit('close')"
        class="absolute top-4 right-4 p-2 text-white hover:bg-white/20 rounded-full transition z-10"
      >
        <X class="w-6 h-6" />
      </button>

      <!-- Previous button - centered vertically, larger touch area on mobile -->
      <button
        v-if="currentIndex > 0"
        @click="prevImage"
        class="absolute left-2 sm:left-4 top-1/2 -translate-y-1/2 p-3 sm:p-2 text-white hover:bg-white/20 active:bg-white/30 rounded-full transition z-10"
      >
        <ChevronLeft class="w-8 h-8" />
      </button>

      <!-- Image -->
      <div class="max-w-[90vw] max-h-[90vh] flex flex-col items-center">
        <img
          v-if="getCurrentImageUrl()"
          :src="getCurrentImageUrl()!"
          :alt="images[currentIndex]?.originalFilename"
          class="max-w-full max-h-[70vh] sm:max-h-[80vh] object-contain"
        />
        <div v-else class="text-white">{{ isLoading ? '로딩 중...' : '이미지를 불러올 수 없습니다' }}</div>

        <!-- Image info -->
        <div class="mt-4 text-white text-center">
          <div class="text-sm">{{ images[currentIndex]?.originalFilename }}</div>
          <div class="text-xs mt-1" style="color: rgba(255, 255, 255, 0.7)">
            {{ currentIndex + 1 }} / {{ images.length }}
          </div>
        </div>

        <!-- Download button - larger touch area on mobile -->
        <button
          @click="downloadImage"
          class="mt-4 flex items-center gap-2 px-5 py-3 sm:px-4 sm:py-2 bg-white/20 hover:bg-white/30 active:bg-white/40 rounded-lg text-white transition"
        >
          <Download class="w-5 h-5 sm:w-4 sm:h-4" />
          다운로드
        </button>
      </div>

      <!-- Next button - centered vertically, larger touch area on mobile -->
      <button
        v-if="currentIndex < images.length - 1"
        @click="nextImage"
        class="absolute right-2 sm:right-4 top-1/2 -translate-y-1/2 p-3 sm:p-2 text-white hover:bg-white/20 active:bg-white/30 rounded-full transition z-10"
      >
        <ChevronRight class="w-8 h-8" />
      </button>
    </div>
  </Teleport>
</template>
