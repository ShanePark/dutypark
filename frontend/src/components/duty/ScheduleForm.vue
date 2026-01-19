<script setup lang="ts">
import { ref } from 'vue'
import { Check } from 'lucide-vue-next'
import FileUploader from '@/components/common/FileUploader.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import type { NormalizedAttachment } from '@/types'
import type { CalendarVisibility } from '@/utils/visibility'

interface ScheduleFormData {
  content: string
  description: string
  startDate: string
  startTime: string
  endDateTime: string
  visibility: CalendarVisibility
}

interface VisibilityOption {
  value: CalendarVisibility
  label: string
  description: string
  icon: any
  color: string
}

defineProps<{
  form: ScheduleFormData
  editAttachments: NormalizedAttachment[]
  visibilityOptions: VisibilityOption[]
}>()

const emit = defineEmits<{
  (e: 'upload-start'): void
  (e: 'upload-complete'): void
  (e: 'error', message: string): void
}>()

const fileUploaderRef = ref<InstanceType<typeof FileUploader> | null>(null)

function getSessionId() {
  return fileUploaderRef.value?.getSessionId() || null
}

function getAttachments() {
  return fileUploaderRef.value?.getAttachments() || []
}

function cleanup() {
  fileUploaderRef.value?.cleanup()
}

function isUploading() {
  return fileUploaderRef.value?.isUploading() ?? false
}

defineExpose({
  getSessionId,
  getAttachments,
  cleanup,
  isUploading,
})
</script>

<template>
  <div class="space-y-2 sm:space-y-3">
    <div class="flex items-center gap-2">
      <label class="text-sm flex-shrink-0 w-16" :style="{ color: 'var(--dp-text-secondary)' }">
        제목 <span class="text-red-500">*</span>
      </label>
      <div class="flex-1 min-w-0 relative">
        <input
          v-model="form.content"
          type="text"
          maxlength="50"
          class="w-full px-3 py-1.5 sm:py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
          placeholder="일정 제목을 입력하세요"
        />
        <div class="absolute right-2 top-1/2 -translate-y-1/2">
          <CharacterCounter :current="form.content.length" :max="50" />
        </div>
      </div>
    </div>

    <div class="space-y-2">
      <div class="flex items-center gap-2">
        <label class="text-sm flex-shrink-0 w-16" :style="{ color: 'var(--dp-text-secondary)' }">시작 시간</label>
        <input
          v-model="form.startTime"
          type="time"
          class="flex-1 min-w-0 px-2 sm:px-3 py-1.5 sm:py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
        />
      </div>
      <div class="flex items-center gap-2">
        <label class="text-sm flex-shrink-0 w-16" :style="{ color: 'var(--dp-text-secondary)' }">종료 일시</label>
        <input
          v-model="form.endDateTime"
          type="datetime-local"
          class="flex-1 min-w-0 px-2 sm:px-3 py-1.5 sm:py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
        />
      </div>
    </div>

    <div class="flex items-start gap-2">
      <label class="text-sm flex-shrink-0 w-16 pt-2" :style="{ color: 'var(--dp-text-secondary)' }">설명</label>
      <textarea
        v-model="form.description"
        rows="2"
        class="flex-1 min-w-0 px-3 py-1.5 sm:py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent form-control"
        placeholder="설명 (선택사항)"
      ></textarea>
    </div>

    <div class="flex items-start gap-2">
      <label class="text-sm flex-shrink-0 w-16 pt-2" :style="{ color: 'var(--dp-text-secondary)' }">공개 범위</label>
      <div class="flex-1 min-w-0 grid grid-cols-2 gap-1.5 sm:gap-2">
        <button
          v-for="option in visibilityOptions"
          :key="option.value"
          type="button"
          @click="form.visibility = option.value"
          class="visibility-card relative flex items-center gap-2 sm:gap-3 p-2 sm:p-3 rounded-lg border-2 transition-all duration-150 cursor-pointer text-left"
          :class="{
            'visibility-card-selected': form.visibility === option.value,
            'visibility-card-unselected': form.visibility !== option.value
          }"
        >
          <!-- Check badge -->
          <div
            v-if="form.visibility === option.value"
            class="absolute -top-1.5 -right-1.5 w-5 h-5 bg-blue-500 rounded-full flex items-center justify-center shadow-sm"
          >
            <Check class="w-3 h-3 text-white" />
          </div>
          <div class="flex-shrink-0 w-7 h-7 sm:w-9 sm:h-9 rounded-full flex items-center justify-center" :class="option.color">
            <component
              :is="option.icon"
              class="w-3.5 h-3.5 sm:w-4 sm:h-4 text-white"
            />
          </div>
          <div class="min-w-0 flex-1">
            <div
              class="font-medium text-xs sm:text-sm truncate"
              :class="{
                'text-blue-700 dark:text-blue-400': form.visibility === option.value
              }"
              :style="form.visibility !== option.value ? { color: 'var(--dp-text-primary)' } : undefined"
            >
              {{ option.label }}
            </div>
            <div
              class="text-[10px] sm:text-xs truncate hidden sm:block"
              :style="{ color: 'var(--dp-text-muted)' }"
            >
              {{ option.description }}
            </div>
          </div>
        </button>
      </div>
    </div>

    <!-- Attachment Upload Area -->
    <div class="flex items-start gap-2">
      <label class="text-sm flex-shrink-0 w-16 pt-2" :style="{ color: 'var(--dp-text-secondary)' }">첨부파일</label>
      <FileUploader
        class="flex-1 min-w-0"
        ref="fileUploaderRef"
        context-type="SCHEDULE"
        :existing-attachments="editAttachments"
        @upload-start="emit('upload-start')"
        @upload-complete="emit('upload-complete')"
        @error="emit('error', $event)"
      />
    </div>
  </div>
</template>

<style scoped>
/* Visibility card styles */
.visibility-card-selected {
  border-color: var(--dp-accent);
  background-color: var(--dp-accent-bg);
  box-shadow: 0 0 0 1px var(--dp-accent), 0 2px 8px var(--dp-accent-ring);
}

.visibility-card-unselected {
  border-color: var(--dp-border-primary);
  background-color: var(--dp-bg-card);
  opacity: 0.5;
}

.visibility-card-unselected:hover {
  border-color: var(--dp-accent-border);
  background-color: var(--dp-bg-secondary);
  opacity: 0.85;
}
</style>
