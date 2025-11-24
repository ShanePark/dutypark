<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import {
  X,
  Plus,
  Trash2,
  Pencil,
  ChevronUp,
  ChevronDown,
  Paperclip,
  Eye,
  Lock,
  Users,
  User,
  UserPlus,
  Check,
} from 'lucide-vue-next'
import FileUploader from '@/components/common/FileUploader.vue'
import AttachmentGrid from '@/components/common/AttachmentGrid.vue'
import type { NormalizedAttachment } from '@/types'
import { normalizeAttachment } from '@/api/attachment'
import { useSwal } from '@/composables/useSwal'

const { showWarning, showError } = useSwal()

interface Schedule {
  id: string
  content: string
  description?: string
  startDateTime: string
  endDateTime: string
  visibility: 'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE'
  isMine: boolean
  isTagged: boolean
  taggedBy?: string
  attachments?: Array<{
    id: string
    originalFilename: string
    contentType: string
    size: number
    thumbnailUrl?: string
    hasThumbnail: boolean
  }>
  tags?: Array<{ id: number; name: string }>
}

interface DutyType {
  id: number | null
  name: string
  color: string | null
}

interface Props {
  isOpen: boolean
  date: { year: number; month: number; day: number }
  duty?: { dutyType: string; dutyColor: string }
  schedules: Schedule[]
  dutyTypes: DutyType[]
  canEdit: boolean
  batchEditMode: boolean
  friends: Array<{ id: number; name: string }>
}

const props = withDefaults(defineProps<Props>(), {
  schedules: () => [],
  dutyTypes: () => [],
  friends: () => [],
})

interface ScheduleSaveData {
  id?: string
  content: string
  description: string
  startDateTime: string
  endDateTime: string
  visibility: 'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE'
  attachmentSessionId?: string | null
  orderedAttachmentIds?: string[]
}

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'changeDutyType', dutyTypeId: number | null): void
  (e: 'createSchedule', data: ScheduleSaveData): void
  (e: 'editSchedule', data: ScheduleSaveData): void
  (e: 'deleteSchedule', scheduleId: string): void
  (e: 'swapSchedule', schedule1Id: string, schedule2Id: string): void
  (e: 'addTag', scheduleId: string, friendId: number): void
  (e: 'removeTag', scheduleId: string, friendId: number): void
}>()

const isCreateMode = ref(false)
const isEditMode = ref(false)
const editingScheduleId = ref<string | null>(null)
const fileUploaderRef = ref<InstanceType<typeof FileUploader> | null>(null)
const isUploading = ref(false)

// Local duty state for immediate UI feedback
const selectedDutyType = ref<string | null>(null)

// Sync selectedDutyType with props.duty
watch(
  () => props.duty?.dutyType,
  (newVal) => {
    selectedDutyType.value = newVal ?? null
  },
  { immediate: true }
)

// Handle duty type change with immediate UI feedback
function handleDutyTypeChange(dutyTypeId: number | null, dutyTypeName: string) {
  selectedDutyType.value = dutyTypeName
  emit('changeDutyType', dutyTypeId)
}

const newSchedule = ref({
  content: '',
  description: '',
  startDate: '',
  startTime: '00:00',
  endDateTime: '',
  visibility: 'FAMILY' as 'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE',
})
const editAttachments = ref<NormalizedAttachment[]>([])

const taggingScheduleId = ref<string | null>(null)

const formattedDate = computed(() => {
  const { year, month, day } = props.date
  const date = new Date(year, month - 1, day)
  const weekDays = ['일', '월', '화', '수', '목', '금', '토']
  const dayOfWeek = weekDays[date.getDay()]
  return `${year}년 ${month}월 ${day}일 (${dayOfWeek})`
})

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      isCreateMode.value = false
      isEditMode.value = false
      editingScheduleId.value = null
      editAttachments.value = []
      const { year, month, day } = props.date
      newSchedule.value.startDate = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
      newSchedule.value.endDateTime = `${newSchedule.value.startDate}T00:00`
    } else {
      // Cleanup when modal closes
      fileUploaderRef.value?.cleanup()
    }
  }
)

function startCreateMode() {
  isCreateMode.value = true
  isEditMode.value = false
  editingScheduleId.value = null
  editAttachments.value = []
  const { year, month, day } = props.date
  newSchedule.value = {
    content: '',
    description: '',
    startDate: `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`,
    startTime: '00:00',
    endDateTime: `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}T00:00`,
    visibility: 'FAMILY',
  }
}

function startEditMode(schedule: Schedule) {
  isCreateMode.value = false
  isEditMode.value = true
  editingScheduleId.value = schedule.id

  const start = new Date(schedule.startDateTime)
  const end = new Date(schedule.endDateTime)

  newSchedule.value = {
    content: schedule.content,
    description: schedule.description || '',
    startDate: schedule.startDateTime.split('T')[0] || '',
    startTime: `${String(start.getHours()).padStart(2, '0')}:${String(start.getMinutes()).padStart(2, '0')}`,
    endDateTime: `${end.getFullYear()}-${String(end.getMonth() + 1).padStart(2, '0')}-${String(end.getDate()).padStart(2, '0')}T${String(end.getHours()).padStart(2, '0')}:${String(end.getMinutes()).padStart(2, '0')}`,
    visibility: schedule.visibility,
  }

  // Load existing attachments
  editAttachments.value = (schedule.attachments || []).map((a) =>
    normalizeAttachment({
      id: a.id,
      contextType: 'SCHEDULE',
      contextId: schedule.id,
      originalFilename: a.originalFilename,
      contentType: a.contentType,
      size: a.size,
      hasThumbnail: a.hasThumbnail,
      thumbnailUrl: a.thumbnailUrl || null,
      orderIndex: 0,
      createdAt: '',
      createdBy: 0,
    })
  )
}

function cancelEdit() {
  isCreateMode.value = false
  isEditMode.value = false
  editingScheduleId.value = null
  editAttachments.value = []
  fileUploaderRef.value?.cleanup()
}

function buildScheduleData(): ScheduleSaveData {
  const { year, month, day } = props.date
  const startDateTime = `${newSchedule.value.startDate}T${newSchedule.value.startTime}:00`
  const endDateTime = newSchedule.value.endDateTime
    ? `${newSchedule.value.endDateTime}:00`
    : `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}T00:00:00`

  const sessionId = fileUploaderRef.value?.getSessionId() || null
  const attachments = fileUploaderRef.value?.getAttachments() || []
  const orderedIds = attachments.map((a) => a.id)

  return {
    id: isEditMode.value ? editingScheduleId.value || undefined : undefined,
    content: newSchedule.value.content.trim(),
    description: newSchedule.value.description.trim(),
    startDateTime,
    endDateTime,
    visibility: newSchedule.value.visibility,
    attachmentSessionId: sessionId,
    orderedAttachmentIds: orderedIds.length > 0 ? orderedIds : undefined,
  }
}

function saveSchedule() {
  if (!newSchedule.value.content.trim()) {
    return
  }

  // Check if upload is in progress
  if (fileUploaderRef.value?.isUploading()) {
    showWarning('파일 업로드가 진행 중입니다. 잠시 후 다시 시도해주세요.')
    return
  }

  const data = buildScheduleData()

  if (isEditMode.value) {
    emit('editSchedule', data)
  } else {
    emit('createSchedule', data)
  }

  isCreateMode.value = false
  isEditMode.value = false
  editingScheduleId.value = null
  editAttachments.value = []
}

function handleUploadStart() {
  isUploading.value = true
}

function handleUploadComplete() {
  isUploading.value = false
}

function handleUploadError(message: string) {
  showError(message)
}

function getVisibilityIcon(visibility: string) {
  switch (visibility) {
    case 'PUBLIC':
      return Eye
    case 'FRIENDS':
      return Users
    case 'FAMILY':
      return User
    case 'PRIVATE':
      return Lock
    default:
      return Eye
  }
}

function getVisibilityLabel(visibility: string) {
  switch (visibility) {
    case 'PUBLIC':
      return '전체공개'
    case 'FRIENDS':
      return '친구공개'
    case 'FAMILY':
      return '가족공개'
    case 'PRIVATE':
      return '나만보기'
    default:
      return visibility
  }
}

function formatScheduleTime(schedule: Schedule) {
  const start = new Date(schedule.startDateTime)
  const end = new Date(schedule.endDateTime)
  const startTime = `${String(start.getHours()).padStart(2, '0')}:${String(start.getMinutes()).padStart(2, '0')}`
  const endTime = `${String(end.getHours()).padStart(2, '0')}:${String(end.getMinutes()).padStart(2, '0')}`

  if (startTime === '00:00' && endTime === '00:00') {
    return ''
  }
  if (startTime !== '00:00' && endTime === '00:00') {
    return `(${startTime})`
  }
  return `(${startTime}~${endTime})`
}

function openTagPanel(scheduleId: string) {
  taggingScheduleId.value = scheduleId
}

function closeTagPanel() {
  taggingScheduleId.value = null
}

function getUntaggedFriends(schedule: Schedule) {
  const taggedIds = new Set(schedule.tags?.map((t) => t.id) || [])
  return props.friends.filter((f) => !taggedIds.has(f.id))
}

function toNormalizedAttachments(attachments: Schedule['attachments']): NormalizedAttachment[] {
  if (!attachments) return []
  return attachments.map((a) =>
    normalizeAttachment({
      id: a.id,
      contextType: 'SCHEDULE',
      contextId: '',
      originalFilename: a.originalFilename,
      contentType: a.contentType,
      size: a.size,
      hasThumbnail: a.hasThumbnail,
      thumbnailUrl: a.thumbnailUrl || null,
      orderIndex: 0,
      createdAt: '',
      createdBy: 0,
    })
  )
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @click.self="emit('close')"
    >
      <div class="bg-white rounded-lg shadow-xl w-full max-w-[95vw] sm:max-w-2xl max-h-[90dvh] sm:max-h-[90vh] overflow-hidden mx-2 sm:mx-4">
        <!-- Header -->
        <div class="flex items-center justify-between p-3 sm:p-4 border-b border-gray-200">
          <div class="flex items-center gap-3 flex-wrap">
            <h2 class="text-base sm:text-lg font-bold">{{ formattedDate }}</h2>
            <!-- Duty Type Selection (내 달력에서만 표시, 추가/수정 모드에서는 숨김) -->
            <div v-if="!isCreateMode && !isEditMode && canEdit && dutyTypes.length > 0" class="flex flex-wrap gap-1.5">
              <button
                v-for="dutyType in dutyTypes"
                :key="dutyType.id ?? 'off'"
                @click="handleDutyTypeChange(dutyType.id, dutyType.name)"
                class="px-2.5 py-1 rounded-md border text-xs font-medium transition flex items-center gap-1.5"
                :class="{
                  'border-blue-500 ring-1 ring-blue-200': selectedDutyType === dutyType.name,
                  'border-gray-200 hover:border-gray-400': selectedDutyType !== dutyType.name,
                }"
                :style="{
                  backgroundColor: selectedDutyType === dutyType.name && dutyType.color ? dutyType.color + '30' : undefined,
                }"
              >
                <span
                  class="inline-block w-3 h-3 rounded"
                  :style="{ backgroundColor: dutyType.color || '#6c757d' }"
                ></span>
                {{ dutyType.name }}
              </button>
            </div>
            <!-- Current Duty (다른 사람 달력일 때만) -->
            <span
              v-else-if="duty && !canEdit"
              class="px-2.5 py-1 rounded-md text-xs font-medium text-white"
              :style="{ backgroundColor: duty.dutyColor || '#6c757d' }"
            >
              {{ duty.dutyType || 'OFF' }}
            </span>
          </div>
          <button @click="emit('close')" class="p-2 hover:bg-gray-100 rounded-full transition flex-shrink-0">
            <X class="w-6 h-6" />
          </button>
        </div>

        <!-- Content -->
        <div class="p-3 sm:p-4 overflow-y-auto max-h-[calc(90dvh-130px)] sm:max-h-[calc(90vh-130px)]">

          <!-- Schedules List (hidden during create/edit mode) -->
          <div v-if="!isCreateMode && !isEditMode" class="space-y-3">
            <h3 class="text-sm font-medium text-gray-700">일정 목록</h3>

            <div v-if="schedules.length === 0" class="text-center py-6 text-gray-400">
              등록된 일정이 없습니다.
            </div>

            <div
              v-for="(schedule, idx) in schedules"
              :key="schedule.id"
              class="border border-gray-200 rounded-lg p-3 hover:bg-gray-50 transition"
            >
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <div class="flex items-center gap-2 flex-wrap">
                    <Lock
                      v-if="schedule.visibility === 'PRIVATE'"
                      class="w-4 h-4 text-gray-400"
                      :title="getVisibilityLabel(schedule.visibility)"
                    />
                    <span class="font-medium">{{ schedule.content }}</span>
                    <span v-if="formatScheduleTime(schedule)" class="text-sm text-gray-500">
                      {{ formatScheduleTime(schedule) }}
                    </span>
                    <component
                      v-if="schedule.visibility !== 'PRIVATE'"
                      :is="getVisibilityIcon(schedule.visibility)"
                      class="w-4 h-4 text-gray-400"
                      :title="getVisibilityLabel(schedule.visibility)"
                    />
                    <span
                      v-if="schedule.attachments?.length"
                      class="flex items-center gap-1 text-gray-400 text-sm"
                    >
                      <Paperclip class="w-3 h-3" />
                      {{ schedule.attachments.length }}
                    </span>
                  </div>

                  <!-- Tags Section -->
                  <div
                    v-if="schedule.isMine && canEdit && (schedule.tags?.length || friends.length > 0)"
                    class="mt-2"
                  >
                    <div class="flex items-center gap-1.5 flex-wrap">
                      <!-- Existing tags -->
                      <span
                        v-for="tag in schedule.tags"
                        :key="tag.id"
                        class="inline-flex items-center gap-1 pl-2 pr-1 py-0.5 bg-blue-100 text-blue-700 text-xs rounded-full"
                      >
                        {{ tag.name }}
                        <button
                          @click.stop="emit('removeTag', schedule.id, tag.id)"
                          class="p-0.5 hover:bg-blue-200 rounded-full transition"
                          title="태그 삭제"
                        >
                          <X class="w-3 h-3" />
                        </button>
                      </span>

                      <!-- Add tag button -->
                      <button
                        v-if="friends.length > 0"
                        @click.stop="openTagPanel(schedule.id)"
                        class="inline-flex items-center gap-1 px-2 py-0.5 border border-dashed border-gray-300 text-gray-500 text-xs rounded-full hover:border-blue-400 hover:text-blue-500 hover:bg-blue-50 transition"
                        :class="{ 'border-blue-400 text-blue-500 bg-blue-50': taggingScheduleId === schedule.id }"
                        title="친구 태그"
                      >
                        <UserPlus class="w-3 h-3" />
                        <span>태그</span>
                      </button>
                    </div>

                    <!-- Inline tag selection (expanded below the button) -->
                    <div
                      v-if="taggingScheduleId === schedule.id && getUntaggedFriends(schedule).length > 0"
                      class="mt-2 p-2.5 bg-blue-50 border border-blue-200 rounded-lg"
                    >
                      <div class="flex items-center justify-between mb-2">
                        <span class="text-xs font-medium text-blue-700">친구 선택</span>
                        <button
                          @click.stop="closeTagPanel"
                          class="p-0.5 hover:bg-blue-100 rounded transition"
                        >
                          <X class="w-3.5 h-3.5 text-blue-500" />
                        </button>
                      </div>
                      <div class="flex flex-wrap gap-1.5">
                        <button
                          v-for="friend in getUntaggedFriends(schedule)"
                          :key="friend.id"
                          @click.stop="emit('addTag', schedule.id, friend.id)"
                          class="inline-flex items-center gap-1 px-2 py-1 bg-white border border-blue-200 text-gray-700 text-xs rounded-full hover:border-blue-400 hover:bg-blue-100 transition"
                        >
                          <User class="w-3 h-3" />
                          {{ friend.name }}
                        </button>
                      </div>
                    </div>
                  </div>

                  <!-- Tags display for non-owners (show tags list) -->
                  <div
                    v-else-if="!schedule.isTagged && schedule.tags?.length"
                    class="flex items-center gap-1.5 mt-2 flex-wrap"
                  >
                    <span
                      v-for="tag in schedule.tags"
                      :key="tag.id"
                      class="inline-flex items-center gap-1 px-2 py-0.5 bg-blue-100 text-blue-700 text-xs rounded-full"
                    >
                      {{ tag.name }}
                    </span>
                  </div>

                  <!-- Tagged by indicator (when I was tagged by someone) -->
                  <div
                    v-else-if="schedule.isTagged"
                    class="mt-2"
                  >
                    <span class="inline-flex items-center gap-1 px-2 py-0.5 bg-gray-100 text-gray-600 text-xs rounded-full">
                      by {{ schedule.taggedBy }}
                    </span>
                  </div>

                  <!-- Description -->
                  <div v-if="schedule.description" class="mt-2 pt-2 border-t border-gray-100">
                    <div class="text-sm text-gray-600 whitespace-pre-wrap">{{ schedule.description }}</div>
                  </div>

                  <!-- Attachments -->
                  <div v-if="schedule.attachments?.length" class="mt-2 pt-2 border-t border-gray-100">
                    <AttachmentGrid
                      :attachments="toNormalizedAttachments(schedule.attachments)"
                      :columns="4"
                    />
                  </div>
                </div>

                <!-- Actions -->
                <div class="flex items-center gap-1 ml-2">
                  <!-- Reorder buttons -->
                  <button
                    v-if="idx > 0 && canEdit && schedules[idx - 1]"
                    @click="emit('swapSchedule', schedule.id, schedules[idx - 1]!.id)"
                    class="p-1 hover:bg-gray-200 rounded transition"
                    title="위로"
                  >
                    <ChevronUp class="w-4 h-4" />
                  </button>
                  <button
                    v-if="idx < schedules.length - 1 && canEdit && schedules[idx + 1]"
                    @click="emit('swapSchedule', schedule.id, schedules[idx + 1]!.id)"
                    class="p-1 hover:bg-gray-200 rounded transition"
                    title="아래로"
                  >
                    <ChevronDown class="w-4 h-4" />
                  </button>

                  <!-- Edit -->
                  <button
                    v-if="schedule.isMine || canEdit"
                    @click="startEditMode(schedule)"
                    class="p-1 hover:bg-gray-200 rounded transition text-blue-600"
                    title="수정"
                  >
                    <Pencil class="w-4 h-4" />
                  </button>

                  <!-- Delete -->
                  <button
                    v-if="schedule.isMine || canEdit"
                    @click="emit('deleteSchedule', schedule.id)"
                    class="p-1 hover:bg-gray-200 rounded transition text-red-600"
                    title="삭제"
                  >
                    <Trash2 class="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          </div>

          <!-- Create/Edit Schedule Form -->
          <div v-if="isCreateMode || isEditMode" class="mt-4 border-t border-gray-200 pt-4">
            <h3 class="text-sm font-medium text-gray-700 mb-3">{{ isEditMode ? '일정 수정' : '일정 추가' }}</h3>
            <div class="space-y-3">
              <div>
                <label class="block text-sm text-gray-600 mb-1">내용</label>
                <input
                  v-model="newSchedule.content"
                  type="text"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="일정 내용을 입력하세요"
                />
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label class="block text-sm text-gray-600 mb-1">시작 시간</label>
                  <input
                    v-model="newSchedule.startTime"
                    type="time"
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
                <div>
                  <label class="block text-sm text-gray-600 mb-1">종료 일시</label>
                  <input
                    v-model="newSchedule.endDateTime"
                    type="datetime-local"
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  />
                </div>
              </div>

              <div>
                <label class="block text-sm text-gray-600 mb-1">설명</label>
                <textarea
                  v-model="newSchedule.description"
                  rows="3"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="설명 (선택사항)"
                ></textarea>
              </div>

              <div>
                <label class="block text-sm text-gray-600 mb-1">공개 범위</label>
                <select
                  v-model="newSchedule.visibility"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="PUBLIC">전체공개</option>
                  <option value="FRIENDS">친구공개</option>
                  <option value="FAMILY">가족공개</option>
                  <option value="PRIVATE">나만보기</option>
                </select>
              </div>

              <!-- Attachment Upload Area -->
              <div>
                <label class="block text-sm text-gray-600 mb-1">첨부파일</label>
                <FileUploader
                  ref="fileUploaderRef"
                  context-type="SCHEDULE"
                  :existing-attachments="editAttachments"
                  @upload-start="handleUploadStart"
                  @upload-complete="handleUploadComplete"
                  @error="handleUploadError"
                />
              </div>

              <div class="flex flex-col-reverse sm:flex-row gap-2 sm:justify-end">
                <button
                  @click="cancelEdit"
                  class="w-full sm:w-auto px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition"
                >
                  취소
                </button>
                <button
                  @click="saveSchedule"
                  :disabled="isUploading"
                  class="w-full sm:w-auto px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {{ isUploading ? '업로드 중...' : (isEditMode ? '수정' : '저장') }}
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="p-3 sm:p-4 border-t border-gray-200 flex justify-end">
          <button
            v-if="!isCreateMode && !isEditMode && canEdit"
            @click="startCreateMode"
            class="flex items-center justify-center gap-2 w-full sm:w-auto px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition"
          >
            <Plus class="w-4 h-4" />
            일정 추가
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
