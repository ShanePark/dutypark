<script setup lang="ts">
import { ref, toRef, watch, computed } from 'vue'
import { X, ZoomIn, ZoomOut, Upload, ImagePlus, Trash2 } from 'lucide-vue-next'
import { Cropper, CircleStencil } from 'vue-advanced-cropper'
import 'vue-advanced-cropper/dist/style.css'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
import { attachmentValidation, validateFile } from '@/api/attachment'
import { useSwal } from '@/composables/useSwal'

interface Props {
  isOpen: boolean
  initialImageSource?: string | null
  hasExistingPhoto?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  initialImageSource: null,
  hasExistingPhoto: false,
})

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'confirm', croppedFile: File): void
  (e: 'delete'): void
}>()

useBodyScrollLock(toRef(props, 'isOpen'))
useEscapeKey(toRef(props, 'isOpen'), () => handleClose())

const { showError } = useSwal()

const cropperRef = ref<InstanceType<typeof Cropper> | null>(null)
const fileInputRef = ref<HTMLInputElement | null>(null)
const imageSource = ref<string | null>(null)
const fileName = ref<string>('profile.png')
const zoom = ref(1)
const isProcessing = ref(false)
const isDragging = ref(false)

const minZoom = 1
const maxZoom = 3
const zoomStep = 0.1

const hasImage = computed(() => !!imageSource.value)
const isEditingExistingPhoto = ref(false)

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      zoom.value = 1
      isProcessing.value = false
      imageSource.value = props.initialImageSource || null
      isEditingExistingPhoto.value = !!props.initialImageSource
    } else {
      imageSource.value = null
      fileName.value = 'profile.png'
      isEditingExistingPhoto.value = false
    }
  }
)

function triggerFileInput() {
  fileInputRef.value?.click()
}

function onFileSelect(event: Event) {
  const input = event.target as HTMLInputElement
  const files = Array.from(input.files || [])
  if (files.length > 0 && files[0]) {
    processFile(files[0])
  }
  input.value = ''
}

function processFile(file: File) {
  const validation = validateFile(file)
  if (!validation.valid) {
    showError(validation.message || 'File validation failed')
    return
  }

  if (!file.type.startsWith('image/')) {
    showError('이미지 파일만 업로드할 수 있습니다')
    return
  }

  fileName.value = file.name
  isEditingExistingPhoto.value = false
  const reader = new FileReader()
  reader.onload = (e) => {
    imageSource.value = e.target?.result as string
    zoom.value = 1
  }
  reader.onerror = () => {
    showError('이미지 파일을 읽지 못했습니다')
  }
  reader.readAsDataURL(file)
}

function onDragOver(event: DragEvent) {
  event.preventDefault()
  isDragging.value = true
}

function onDragLeave() {
  isDragging.value = false
}

function onDrop(event: DragEvent) {
  event.preventDefault()
  isDragging.value = false

  const files = event.dataTransfer?.files
  if (files && files.length > 0 && files[0]) {
    processFile(files[0])
  }
}

function handleZoomIn() {
  if (zoom.value < maxZoom) {
    zoom.value = Math.min(maxZoom, zoom.value + zoomStep)
    cropperRef.value?.zoom(1 + zoomStep)
  }
}

function handleZoomOut() {
  if (zoom.value > minZoom) {
    zoom.value = Math.max(minZoom, zoom.value - zoomStep)
    cropperRef.value?.zoom(1 - zoomStep)
  }
}

function handleZoomChange(event: Event) {
  const target = event.target as HTMLInputElement
  const newZoom = parseFloat(target.value)
  const currentZoom = zoom.value
  const ratio = newZoom / currentZoom
  zoom.value = newZoom
  cropperRef.value?.zoom(ratio)
}

function handleConfirm() {
  if (isProcessing.value || !hasImage.value) return

  const result = cropperRef.value?.getResult()
  if (!result?.canvas) {
    emit('close')
    return
  }

  isProcessing.value = true

  result.canvas.toBlob(
    (blob) => {
      if (!blob) {
        isProcessing.value = false
        emit('close')
        return
      }

      const file = new File([blob], fileName.value, {
        type: 'image/png',
      })
      emit('confirm', file)
      isProcessing.value = false
    },
    'image/png',
    0.9
  )
}

function handleClose() {
  if (!isProcessing.value) {
    emit('close')
  }
}

function handleDelete() {
  if (!isProcessing.value) {
    emit('delete')
  }
}

function changeImage() {
  triggerFileInput()
}

const zoomPercent = computed(() => Math.round(zoom.value * 100))

function maxSizeDefault({ imageSize }: { imageSize: { width: number; height: number } }) {
  const size = Math.min(imageSize.width, imageSize.height)
  return {
    width: size,
    height: size,
  }
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @mousedown.self="handleClose"
    >
      <div class="modal-container crop-modal max-w-[95vw] sm:max-w-xl max-h-[90dvh] sm:max-h-[90vh]">
        <!-- Header -->
        <div class="modal-header">
          <h2>프로필 사진 편집</h2>
          <button
            @click="handleClose"
            class="p-2 rounded-full transition hover-bg-light cursor-pointer"
            :disabled="isProcessing"
          >
            <X class="w-6 h-6" :style="{ color: 'var(--dp-text-primary)' }" />
          </button>
        </div>

        <!-- Content -->
        <div class="flex-1 overflow-hidden p-4 flex flex-col gap-4">
          <!-- File Upload Area (when no image) -->
          <div
            v-if="!hasImage"
            class="upload-area"
            :class="{ 'upload-area-dragging': isDragging }"
            @click="triggerFileInput"
            @dragover="onDragOver"
            @dragleave="onDragLeave"
            @drop="onDrop"
          >
            <div class="upload-content">
              <ImagePlus class="w-12 h-12 mb-3" />
              <p class="upload-title">이미지를 선택하세요</p>
              <p class="upload-hint">클릭하거나 파일을 드래그하세요</p>
              <p class="upload-size">최대 {{ attachmentValidation.maxFileSizeLabel }}</p>
            </div>
          </div>

          <!-- Cropper (when image exists) -->
          <template v-else>
            <div
              class="cropper-wrapper"
              :class="{ 'cropper-wrapper-dragging': isDragging }"
              @dragover="onDragOver"
              @dragleave="onDragLeave"
              @drop="onDrop"
            >
              <Cropper
                ref="cropperRef"
                :src="imageSource!"
                :stencil-component="CircleStencil"
                :stencil-props="{
                  aspectRatio: 1,
                }"
                :resize-image="{
                  adjustStencil: false,
                }"
                :default-size="isEditingExistingPhoto ? maxSizeDefault : undefined"
                class="cropper"
              />
              <!-- Drag overlay -->
              <Transition name="fade">
                <div v-if="isDragging" class="drag-overlay">
                  <ImagePlus class="w-12 h-12" />
                  <span>이미지 변경</span>
                </div>
              </Transition>
            </div>

            <!-- Zoom Controls -->
            <div class="zoom-controls">
              <button
                type="button"
                @click="handleZoomOut"
                class="zoom-btn"
                :disabled="zoom <= minZoom || isProcessing"
              >
                <ZoomOut class="w-5 h-5" />
              </button>
              <div class="zoom-slider-wrapper">
                <input
                  type="range"
                  :min="minZoom"
                  :max="maxZoom"
                  :step="zoomStep"
                  :value="zoom"
                  @input="handleZoomChange"
                  class="zoom-slider"
                  :disabled="isProcessing"
                />
                <span class="zoom-label">{{ zoomPercent }}%</span>
              </div>
              <button
                type="button"
                @click="handleZoomIn"
                class="zoom-btn"
                :disabled="zoom >= maxZoom || isProcessing"
              >
                <ZoomIn class="w-5 h-5" />
              </button>
            </div>

            <!-- Change Image Button -->
            <button
              type="button"
              @click="changeImage"
              class="change-image-btn"
              :disabled="isProcessing"
            >
              <Upload class="w-4 h-4" />
              <span>다른 이미지 선택</span>
            </button>
          </template>
        </div>

        <!-- Footer -->
        <div class="modal-footer flex-shrink-0">
          <button
            type="button"
            @click="handleClose"
            class="btn-cancel"
            :disabled="isProcessing"
          >
            취소
          </button>
          <button
            v-if="hasExistingPhoto"
            type="button"
            @click="handleDelete"
            class="btn-delete"
            :disabled="isProcessing"
          >
            <Trash2 class="w-4 h-4" />
            삭제
          </button>
          <button
            type="button"
            @click="handleConfirm"
            class="btn-confirm"
            :disabled="isProcessing || !hasImage"
          >
            {{ isProcessing ? '저장 중...' : '저장' }}
          </button>
        </div>

        <!-- Hidden file input -->
        <input
          ref="fileInputRef"
          type="file"
          accept="image/*"
          class="hidden"
          @change="onFileSelect"
        />
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.crop-modal {
  background-color: var(--dp-bg-modal);
}

.upload-area {
  width: 100%;
  height: 400px;
  border: 2px dashed var(--dp-border-primary);
  border-radius: 0.75rem;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s ease;
  background-color: var(--dp-bg-tertiary);
}

.upload-area:hover {
  border-color: var(--color-primary, #3b82f6);
  background-color: var(--dp-bg-hover);
}

.upload-area-dragging {
  border-color: var(--color-primary, #3b82f6);
  background-color: var(--dp-bg-hover);
}

.upload-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  color: var(--dp-text-muted);
}

.upload-title {
  font-size: 1rem;
  font-weight: 500;
  color: var(--dp-text-secondary);
  margin-bottom: 0.25rem;
}

.upload-hint {
  font-size: 0.875rem;
  margin-bottom: 0.5rem;
}

.upload-size {
  font-size: 0.75rem;
}

.cropper-wrapper {
  width: 100%;
  height: 400px;
  border-radius: 0.5rem;
  overflow: hidden;
  background-color: var(--dp-bg-tertiary);
  position: relative;
  transition: outline 0.15s ease;
}

.cropper-wrapper-dragging {
  outline: 3px dashed var(--color-primary, #3b82f6);
  outline-offset: -3px;
}

.drag-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  background-color: rgba(59, 130, 246, 0.85);
  color: white;
  font-size: 1rem;
  font-weight: 500;
  z-index: 10;
  pointer-events: none;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.15s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

@media (min-width: 640px) {
  .cropper-wrapper {
    height: 450px;
  }
}

.cropper {
  width: 100%;
  height: 100%;
}

.zoom-controls {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem 0;
}

.zoom-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 44px;
  min-height: 44px;
  padding: 0.5rem;
  border-radius: 0.5rem;
  border: none;
  background-color: var(--dp-bg-tertiary);
  color: var(--dp-text-secondary);
  cursor: pointer;
  transition: all 0.15s ease;
}

.zoom-btn:hover:not(:disabled) {
  background-color: var(--dp-bg-hover);
  color: var(--dp-text-primary);
}

.zoom-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.zoom-slider-wrapper {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.25rem;
}

.zoom-slider {
  width: 100%;
  height: 6px;
  border-radius: 3px;
  appearance: none;
  background-color: var(--dp-bg-tertiary);
  cursor: pointer;
}

.zoom-slider::-webkit-slider-thumb {
  appearance: none;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background-color: var(--color-primary, #3b82f6);
  cursor: pointer;
  transition: transform 0.15s ease;
}

.zoom-slider::-webkit-slider-thumb:hover {
  transform: scale(1.1);
}

.zoom-slider::-moz-range-thumb {
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background-color: var(--color-primary, #3b82f6);
  border: none;
  cursor: pointer;
}

.zoom-slider:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.zoom-label {
  font-size: 0.75rem;
  color: var(--dp-text-muted);
}

.change-image-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.75rem;
  font-size: 0.875rem;
  font-weight: 500;
  border-radius: 0.5rem;
  border: 1px solid var(--dp-border-primary);
  background-color: transparent;
  color: var(--dp-text-secondary);
  cursor: pointer;
  transition: all 0.15s ease;
}

.change-image-btn:hover:not(:disabled) {
  background-color: var(--dp-bg-hover);
  color: var(--dp-text-primary);
}

.change-image-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 1rem 1.5rem;
  border-top: 1px solid var(--dp-border-primary);
}

.btn-cancel,
.btn-delete,
.btn-confirm {
  min-width: 80px;
  min-height: 44px;
  padding: 0.625rem 1.25rem;
  font-size: 0.875rem;
  font-weight: 500;
  border-radius: 0.5rem;
  border: none;
  cursor: pointer;
  transition: all 0.15s ease;
}

.btn-cancel {
  background-color: var(--dp-bg-tertiary);
  color: var(--dp-text-secondary);
}

.btn-cancel:hover:not(:disabled) {
  background-color: var(--dp-bg-hover);
}

.btn-delete {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.375rem;
  background-color: #fee2e2;
  color: #dc2626;
}

.btn-delete:hover:not(:disabled) {
  background-color: #fecaca;
}

.dark .btn-delete {
  background-color: rgba(220, 38, 38, 0.2);
  color: #f87171;
}

.dark .btn-delete:hover:not(:disabled) {
  background-color: rgba(220, 38, 38, 0.3);
}

.btn-confirm {
  background-color: var(--color-primary, #3b82f6);
  color: white;
}

.btn-confirm:hover:not(:disabled) {
  background-color: var(--color-primary-dark, #2563eb);
}

.btn-cancel:disabled,
.btn-delete:disabled,
.btn-confirm:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.hidden {
  display: none;
}
</style>

<style>
/* vue-advanced-cropper overrides for dark mode */
.vue-advanced-cropper__background {
  background-color: var(--dp-bg-secondary) !important;
}

.vue-advanced-cropper__foreground {
  background-color: rgba(0, 0, 0, 0.5) !important;
}
</style>
