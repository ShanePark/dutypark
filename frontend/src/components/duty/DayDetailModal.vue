<script setup lang="ts">
import { ref, computed, watch, reactive } from 'vue'
import {
  X,
  Plus,
  Trash2,
  Pencil,
  ChevronUp,
  ChevronDown,
  Paperclip,
  Eye,
  EyeOff,
  Users,
  User,
  Tag,
  Download,
  ChevronLeft,
  ChevronRight,
} from 'lucide-vue-next'
import FileUploader from '@/components/common/FileUploader.vue'
import type { NormalizedAttachment } from '@/types'
import { normalizeAttachment, fetchAuthenticatedImage } from '@/api/attachment'
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
  isMyCalendar: boolean
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

const newSchedule = ref({
  content: '',
  description: '',
  startDate: '',
  startTime: '00:00',
  endDateTime: '',
  visibility: 'FAMILY' as 'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE',
})
const editAttachments = ref<NormalizedAttachment[]>([])

const showTagDropdown = ref<string | null>(null)
const thumbnailBlobUrls = reactive<Record<string, string>>({})
const fullImageBlobUrls = reactive<Record<string, string>>({})

// Image viewer state
const imageViewerOpen = ref(false)
const currentImageIndex = ref(0)
const currentImageAttachments = ref<Array<{ id: string; originalFilename: string; contentType: string }>>([])

function openImageViewer(attachments: Array<{ id: string; originalFilename: string; contentType: string }>, index: number) {
  const imageAttachments = attachments.filter((a) => a.contentType.startsWith('image/'))
  if (imageAttachments.length === 0) return

  currentImageAttachments.value = imageAttachments
  const clickedAttachment = attachments[index]
  const imageIndex = imageAttachments.findIndex((a) => a.id === clickedAttachment?.id)
  currentImageIndex.value = imageIndex >= 0 ? imageIndex : 0
  imageViewerOpen.value = true

  // Load full image
  loadFullImage(currentImageAttachments.value[currentImageIndex.value]?.id)
}

function closeImageViewer() {
  imageViewerOpen.value = false
}

function prevImage() {
  if (currentImageIndex.value > 0) {
    currentImageIndex.value--
    loadFullImage(currentImageAttachments.value[currentImageIndex.value]?.id)
  }
}

function nextImage() {
  if (currentImageIndex.value < currentImageAttachments.value.length - 1) {
    currentImageIndex.value++
    loadFullImage(currentImageAttachments.value[currentImageIndex.value]?.id)
  }
}

async function loadFullImage(attachmentId: string | undefined) {
  if (!attachmentId || fullImageBlobUrls[attachmentId]) return
  const blobUrl = await fetchAuthenticatedImage(`/api/attachments/${attachmentId}/download?inline=true`)
  if (blobUrl) {
    fullImageBlobUrls[attachmentId] = blobUrl
  }
}

function getCurrentImageUrl(): string | null {
  const attachment = currentImageAttachments.value[currentImageIndex.value]
  if (!attachment) return null
  return fullImageBlobUrls[attachment.id] || thumbnailBlobUrls[attachment.id] || null
}

async function downloadAttachment(attachmentId: string, filename: string) {
  const blobUrl = await fetchAuthenticatedImage(`/api/attachments/${attachmentId}/download`)
  if (blobUrl) {
    const a = document.createElement('a')
    a.href = blobUrl
    a.download = filename
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(blobUrl)
  }
}

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
      return EyeOff
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

function toggleTagDropdown(scheduleId: string) {
  showTagDropdown.value = showTagDropdown.value === scheduleId ? null : scheduleId
}

function getFileIcon(contentType: string): string {
  if (contentType.startsWith('image/')) return 'IMG'
  if (contentType.startsWith('video/')) return 'VID'
  if (contentType.startsWith('audio/')) return 'AUD'
  if (contentType.includes('pdf')) return 'PDF'
  if (contentType.includes('word') || contentType.includes('document')) return 'DOC'
  if (contentType.includes('excel') || contentType.includes('spreadsheet')) return 'XLS'
  if (contentType.includes('zip') || contentType.includes('rar')) return 'ZIP'
  return 'FILE'
}

// Load thumbnail images with authentication
async function loadThumbnails() {
  for (const schedule of props.schedules) {
    if (!schedule.attachments) continue
    for (const attachment of schedule.attachments) {
      if (attachment.hasThumbnail && attachment.thumbnailUrl && !thumbnailBlobUrls[attachment.id]) {
        const blobUrl = await fetchAuthenticatedImage(attachment.thumbnailUrl)
        if (blobUrl) {
          thumbnailBlobUrls[attachment.id] = blobUrl
        }
      }
    }
  }
}

function getThumbnailUrl(attachmentId: string): string | null {
  return thumbnailBlobUrls[attachmentId] || null
}

// Watch for schedule changes to load thumbnails
watch(
  () => props.schedules,
  () => {
    loadThumbnails()
  },
  { immediate: true, deep: true }
)
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @click.self="emit('close')"
    >
      <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] overflow-hidden">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-gray-200">
          <h2 class="text-lg font-bold">{{ formattedDate }}</h2>
          <button @click="emit('close')" class="p-1 hover:bg-gray-100 rounded-full transition">
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- Content -->
        <div class="p-4 overflow-y-auto max-h-[calc(90vh-130px)]">
          <!-- Duty Type Selection (내 달력에서만 표시, 추가/수정 모드에서는 숨김) -->
          <div v-if="!isCreateMode && !isEditMode && isMyCalendar && dutyTypes.length > 0" class="mb-4">
            <h3 class="text-sm font-medium text-gray-700 mb-2">근무</h3>
            <div class="flex flex-wrap gap-2">
              <button
                v-for="dutyType in dutyTypes"
                :key="dutyType.id ?? 'off'"
                @click="emit('changeDutyType', dutyType.id)"
                class="px-4 py-2 rounded-lg border-2 text-sm font-medium transition flex items-center gap-2"
                :class="{
                  'border-blue-500 ring-2 ring-blue-200': duty?.dutyType === dutyType.name,
                  'border-gray-200 hover:border-gray-400': duty?.dutyType !== dutyType.name,
                }"
                :style="{
                  backgroundColor: duty?.dutyType === dutyType.name && dutyType.color ? dutyType.color + '30' : undefined,
                }"
              >
                <span
                  class="inline-block w-4 h-4 rounded"
                  :style="{ backgroundColor: dutyType.color || '#6c757d' }"
                ></span>
                {{ dutyType.name }}
              </button>
            </div>
          </div>

          <!-- Current Duty (다른 사람 달력일 때만) -->
          <div v-else-if="duty && !isMyCalendar" class="mb-4">
            <div class="flex items-center gap-2">
              <span class="text-sm text-gray-500">근무:</span>
              <span
                class="px-3 py-1 rounded-full text-sm font-medium text-white"
                :style="{ backgroundColor: duty.dutyColor || '#6c757d' }"
              >
                {{ duty.dutyType || 'OFF' }}
              </span>
            </div>
          </div>

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
                    <span class="font-medium">{{ schedule.content }}</span>
                    <span v-if="formatScheduleTime(schedule)" class="text-sm text-gray-500">
                      {{ formatScheduleTime(schedule) }}
                    </span>
                    <component
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

                  <!-- Tags -->
                  <div
                    v-if="schedule.tags?.length"
                    class="flex items-center gap-1 mt-1 flex-wrap"
                  >
                    <span
                      v-for="tag in schedule.tags"
                      :key="tag.id"
                      class="inline-flex items-center gap-1 px-2 py-0.5 bg-blue-100 text-blue-700 text-xs rounded-full"
                    >
                      {{ tag.name }}
                      <button
                        v-if="isMyCalendar"
                        @click.stop="emit('removeTag', schedule.id, tag.id)"
                        class="hover:text-red-500"
                      >
                        <X class="w-3 h-3" />
                      </button>
                    </span>
                  </div>

                  <!-- Tagged indicator -->
                  <div
                    v-if="schedule.isTagged"
                    class="text-xs text-gray-500 mt-1"
                  >
                    by {{ schedule.taggedBy }}
                  </div>

                  <!-- Description -->
                  <div v-if="schedule.description" class="mt-2 pt-2 border-t border-gray-100">
                    <div class="text-sm text-gray-600 whitespace-pre-wrap">{{ schedule.description }}</div>
                  </div>

                  <!-- Attachments -->
                  <div v-if="schedule.attachments?.length" class="mt-2 pt-2 border-t border-gray-100">
                    <div class="flex items-center gap-1 text-sm text-gray-500 mb-2">
                      <Paperclip class="w-3 h-3" />
                      첨부파일 ({{ schedule.attachments.length }})
                    </div>
                    <div class="grid grid-cols-3 sm:grid-cols-4 gap-2">
                      <div
                        v-for="(attachment, idx) in schedule.attachments"
                        :key="attachment.id"
                        class="relative border border-gray-200 rounded overflow-hidden group cursor-pointer"
                        @click="attachment.contentType.startsWith('image/') ? openImageViewer(schedule.attachments, idx) : downloadAttachment(attachment.id, attachment.originalFilename)"
                      >
                        <div class="aspect-square bg-gray-100 flex items-center justify-center">
                          <img
                            v-if="getThumbnailUrl(attachment.id)"
                            :src="getThumbnailUrl(attachment.id)!"
                            :alt="attachment.originalFilename"
                            class="w-full h-full object-cover"
                          />
                          <span v-else class="text-2xl text-gray-400">
                            {{ getFileIcon(attachment.contentType) }}
                          </span>
                        </div>
                        <!-- Download button in corner -->
                        <button
                          class="absolute top-1 right-1 p-1 bg-black/50 rounded text-white opacity-0 group-hover:opacity-100 transition hover:bg-black/70"
                          @click.stop="downloadAttachment(attachment.id, attachment.originalFilename)"
                          title="다운로드"
                        >
                          <Download class="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Actions -->
                <div class="flex items-center gap-1 ml-2">
                  <!-- Reorder buttons -->
                  <button
                    v-if="idx > 0 && isMyCalendar && schedules[idx - 1]"
                    @click="emit('swapSchedule', schedule.id, schedules[idx - 1]!.id)"
                    class="p-1 hover:bg-gray-200 rounded transition"
                    title="위로"
                  >
                    <ChevronUp class="w-4 h-4" />
                  </button>
                  <button
                    v-if="idx < schedules.length - 1 && isMyCalendar && schedules[idx + 1]"
                    @click="emit('swapSchedule', schedule.id, schedules[idx + 1]!.id)"
                    class="p-1 hover:bg-gray-200 rounded transition"
                    title="아래로"
                  >
                    <ChevronDown class="w-4 h-4" />
                  </button>

                  <!-- Tag button -->
                  <div v-if="isMyCalendar && schedule.isMine" class="relative">
                    <button
                      @click="toggleTagDropdown(schedule.id)"
                      class="p-1 hover:bg-gray-200 rounded transition"
                      title="태그"
                    >
                      <Tag class="w-4 h-4" />
                    </button>
                    <div
                      v-if="showTagDropdown === schedule.id"
                      class="absolute right-0 mt-1 w-40 bg-white border border-gray-200 rounded-lg shadow-lg z-10"
                    >
                      <div
                        v-for="friend in friends"
                        :key="friend.id"
                        @click="emit('addTag', schedule.id, friend.id); showTagDropdown = null"
                        class="px-3 py-2 hover:bg-gray-100 cursor-pointer text-sm"
                      >
                        {{ friend.name }}
                      </div>
                    </div>
                  </div>

                  <!-- Edit -->
                  <button
                    v-if="schedule.isMine || isMyCalendar"
                    @click="startEditMode(schedule)"
                    class="p-1 hover:bg-gray-200 rounded transition text-blue-600"
                    title="수정"
                  >
                    <Pencil class="w-4 h-4" />
                  </button>

                  <!-- Delete -->
                  <button
                    v-if="schedule.isMine || isMyCalendar"
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

              <div class="grid grid-cols-2 gap-3">
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

              <div class="flex gap-2 justify-end">
                <button
                  @click="cancelEdit"
                  class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition"
                >
                  취소
                </button>
                <button
                  @click="saveSchedule"
                  :disabled="isUploading"
                  class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {{ isUploading ? '업로드 중...' : (isEditMode ? '수정' : '저장') }}
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="p-4 border-t border-gray-200 flex justify-end">
          <button
            v-if="!isCreateMode && !isEditMode && isMyCalendar"
            @click="startCreateMode"
            class="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition"
          >
            <Plus class="w-4 h-4" />
            일정 추가
          </button>
        </div>
      </div>
    </div>

    <!-- Image Viewer Modal -->
    <div
      v-if="imageViewerOpen"
      class="fixed inset-0 z-[60] flex items-center justify-center bg-black/90"
      @click.self="closeImageViewer"
    >
      <!-- Close button -->
      <button
        @click="closeImageViewer"
        class="absolute top-4 right-4 p-2 text-white hover:bg-white/20 rounded-full transition"
      >
        <X class="w-6 h-6" />
      </button>

      <!-- Previous button -->
      <button
        v-if="currentImageIndex > 0"
        @click="prevImage"
        class="absolute left-4 p-2 text-white hover:bg-white/20 rounded-full transition"
      >
        <ChevronLeft class="w-8 h-8" />
      </button>

      <!-- Image -->
      <div class="max-w-[90vw] max-h-[90vh] flex flex-col items-center">
        <img
          v-if="getCurrentImageUrl()"
          :src="getCurrentImageUrl()!"
          :alt="currentImageAttachments[currentImageIndex]?.originalFilename"
          class="max-w-full max-h-[80vh] object-contain"
        />
        <div v-else class="text-white">로딩 중...</div>

        <!-- Image info -->
        <div class="mt-4 text-white text-center">
          <div class="text-sm">{{ currentImageAttachments[currentImageIndex]?.originalFilename }}</div>
          <div class="text-xs text-gray-400 mt-1">
            {{ currentImageIndex + 1 }} / {{ currentImageAttachments.length }}
          </div>
        </div>

        <!-- Download button -->
        <button
          @click="downloadAttachment(currentImageAttachments[currentImageIndex]?.id, currentImageAttachments[currentImageIndex]?.originalFilename)"
          class="mt-4 flex items-center gap-2 px-4 py-2 bg-white/20 hover:bg-white/30 rounded-lg text-white transition"
        >
          <Download class="w-4 h-4" />
          다운로드
        </button>
      </div>

      <!-- Next button -->
      <button
        v-if="currentImageIndex < currentImageAttachments.length - 1"
        @click="nextImage"
        class="absolute right-4 p-2 text-white hover:bg-white/20 rounded-full transition"
      >
        <ChevronRight class="w-8 h-8" />
      </button>
    </div>
  </Teleport>
</template>
