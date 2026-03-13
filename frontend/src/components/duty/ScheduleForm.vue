<script setup lang="ts">
import { ref, computed } from 'vue'
import { Check } from 'lucide-vue-next'
import FileUploader from '@/components/common/FileUploader.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import FriendTagSelector from '@/components/common/FriendTagSelector.vue'
import type { NormalizedAttachment, TaggableFriend } from '@/types'
import type { CalendarVisibility } from '@/utils/visibility'

interface SelectedTagSummary {
  id: number
  name: string
}

interface ScheduleFormData {
  content: string
  description: string
  startDateTime: string
  endDateTime: string
  visibility: CalendarVisibility
  tagFriendIds: number[]
}

interface VisibilityOption {
  value: CalendarVisibility
  label: string
  description: string
  icon: any
  color: string
}

const props = defineProps<{
  form: ScheduleFormData
  editAttachments: NormalizedAttachment[]
  visibilityOptions: VisibilityOption[]
  isEditMode: boolean
  friends: TaggableFriend[]
  canTagFriends: boolean
  selectedTagSummaries: SelectedTagSummary[]
}>()

// For create mode: extract time portion from startDateTime
const startTime = computed({
  get: () => {
    if (!props.form.startDateTime) return '00:00'
    const timePart = props.form.startDateTime.split('T')[1]
    return timePart || '00:00'
  },
  set: (time: string) => {
    const datePart = props.form.startDateTime.split('T')[0]
    props.form.startDateTime = `${datePart}T${time}`
  },
})

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
      <label class="text-sm flex-shrink-0 w-16 text-dp-text-secondary">
        제목 <span class="text-dp-danger">*</span>
      </label>
      <div class="flex-1 min-w-0 relative">
        <input
          v-model="form.content"
          type="text"
          maxlength="50"
          class="w-full px-3 py-1.5 sm:py-2 rounded-lg focus:ring-2 focus:ring-dp-accent focus:border-transparent form-control"
          placeholder="일정 제목을 입력하세요"
        />
        <div class="absolute right-2 top-1/2 -translate-y-1/2">
          <CharacterCounter :current="form.content.length" :max="50" />
        </div>
      </div>
    </div>

    <div class="space-y-2">
      <!-- Create mode: time only (date is already selected from calendar) -->
      <div v-if="!isEditMode" class="flex items-center gap-2">
        <label class="text-sm flex-shrink-0 w-16 text-dp-text-secondary">시작 시간</label>
        <input
          v-model="startTime"
          type="time"
          class="flex-1 min-w-0 px-2 sm:px-3 py-1.5 sm:py-2 rounded-lg focus:ring-2 focus:ring-dp-accent focus:border-transparent form-control"
        />
      </div>
      <!-- Edit mode: full datetime (allow changing date) -->
      <div v-else class="flex items-center gap-2">
        <label class="text-sm flex-shrink-0 w-16 text-dp-text-secondary">시작 일시</label>
        <input
          v-model="form.startDateTime"
          type="datetime-local"
          class="flex-1 min-w-0 px-2 sm:px-3 py-1.5 sm:py-2 rounded-lg focus:ring-2 focus:ring-dp-accent focus:border-transparent form-control"
        />
      </div>
      <div class="flex items-center gap-2">
        <label class="text-sm flex-shrink-0 w-16 text-dp-text-secondary">종료 일시</label>
        <input
          v-model="form.endDateTime"
          type="datetime-local"
          class="flex-1 min-w-0 px-2 sm:px-3 py-1.5 sm:py-2 rounded-lg focus:ring-2 focus:ring-dp-accent focus:border-transparent form-control"
        />
      </div>
    </div>

    <div class="flex items-start gap-2">
      <label class="text-sm flex-shrink-0 w-16 pt-2 text-dp-text-secondary">설명</label>
      <textarea
        v-model="form.description"
        rows="2"
        class="flex-1 min-w-0 px-3 py-1.5 sm:py-2 rounded-lg focus:ring-2 focus:ring-dp-accent focus:border-transparent form-control"
        placeholder="설명"
      ></textarea>
    </div>

    <div class="flex items-start gap-2">
      <label class="text-sm flex-shrink-0 w-16 pt-2 text-dp-text-secondary">공개 범위</label>
      <div class="flex-1 min-w-0 grid grid-cols-4 gap-1 sm:gap-2">
        <button
          v-for="option in visibilityOptions"
          :key="option.value"
          type="button"
          @click="form.visibility = option.value"
          class="visibility-card relative flex min-h-11 flex-col items-center justify-center gap-1 px-1 py-2 sm:min-h-12 sm:gap-1.5 sm:px-2 sm:py-2.5 rounded-lg border-2 transition-all duration-150 cursor-pointer text-center"
          :class="{
            'visibility-card-selected': form.visibility === option.value,
            'visibility-card-unselected': form.visibility !== option.value
          }"
        >
          <!-- Check badge -->
          <div
            v-if="form.visibility === option.value"
            class="absolute -top-1.5 -right-1.5 w-5 h-5 bg-dp-accent rounded-full flex items-center justify-center shadow-sm"
          >
            <Check class="w-3 h-3 text-dp-text-on-dark" />
          </div>
          <div class="flex-shrink-0 w-6 h-6 sm:w-8 sm:h-8 rounded-full flex items-center justify-center" :class="option.color">
            <component
              :is="option.icon"
              class="w-3 h-3 sm:w-4 sm:h-4 text-dp-text-on-dark"
            />
          </div>
          <div class="min-w-0 w-full">
            <div
              class="font-medium text-[11px] sm:text-xs md:text-sm leading-tight whitespace-nowrap"
              :class="{
                'text-dp-accent-hover dark:text-dp-accent-light': form.visibility === option.value
              }"
              :style="form.visibility !== option.value ? { color: 'var(--dp-text-primary)' } : undefined"
            >
              {{ option.label }}
            </div>
          </div>
        </button>
      </div>
    </div>

    <!-- Attachment Upload Area -->
    <div class="flex items-start gap-2">
      <label class="text-sm flex-shrink-0 w-16 pt-2 text-dp-text-secondary">첨부파일</label>
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

    <div v-if="canTagFriends" class="flex items-start gap-2">
      <label class="text-sm flex-shrink-0 w-16 pt-2 text-dp-text-secondary">친구 태그</label>
      <div class="flex-1 min-w-0">
        <FriendTagSelector
          v-model="form.tagFriendIds"
          :friends="friends"
          :selected-summaries="selectedTagSummaries"
        />
      </div>
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
  opacity: 0.72;
}

.visibility-card-unselected:hover {
  border-color: var(--dp-accent-border);
  background-color: var(--dp-bg-secondary);
  opacity: 0.92;
}
</style>
