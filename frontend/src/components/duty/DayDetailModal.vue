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
  EyeOff,
  Users,
  User,
  Upload,
  Download,
  Tag,
  FileText,
} from 'lucide-vue-next'

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

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'changeDutyType', dutyTypeId: number | null): void
  (e: 'createSchedule'): void
  (e: 'editSchedule', schedule: Schedule): void
  (e: 'deleteSchedule', scheduleId: string): void
  (e: 'swapSchedule', schedule1Id: string, schedule2Id: string): void
  (e: 'addTag', scheduleId: string, friendId: number): void
  (e: 'removeTag', scheduleId: string, friendId: number): void
  (e: 'showDescription', schedule: Schedule): void
}>()

const isCreateMode = ref(false)
const newSchedule = ref({
  content: '',
  description: '',
  startDate: '',
  startTime: '00:00',
  endDateTime: '',
  visibility: 'FAMILY' as const,
})

const showTagDropdown = ref<string | null>(null)

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
      const { year, month, day } = props.date
      newSchedule.value.startDate = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
      newSchedule.value.endDateTime = `${newSchedule.value.startDate}T00:00`
    }
  }
)

function startCreateMode() {
  isCreateMode.value = true
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

function cancelCreate() {
  isCreateMode.value = false
}

function saveSchedule() {
  if (!newSchedule.value.content.trim()) {
    return
  }
  emit('createSchedule')
  isCreateMode.value = false
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
          <!-- Duty Type Selection (내 달력에서만 표시) -->
          <div v-if="isMyCalendar && dutyTypes.length > 0" class="mb-4">
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

          <!-- Schedules List -->
          <div class="space-y-3">
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

                  <!-- View description -->
                  <button
                    v-if="schedule.description || schedule.attachments?.length"
                    @click="emit('showDescription', schedule)"
                    class="p-1 hover:bg-gray-200 rounded transition"
                    title="상세보기"
                  >
                    <FileText class="w-4 h-4" />
                  </button>

                  <!-- Edit -->
                  <button
                    v-if="schedule.isMine || isMyCalendar"
                    @click="emit('editSchedule', schedule)"
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

          <!-- Create Schedule Form -->
          <div v-if="isCreateMode" class="mt-4 border-t border-gray-200 pt-4">
            <h3 class="text-sm font-medium text-gray-700 mb-3">일정 추가</h3>
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
                <label
                  class="flex items-center justify-center gap-2 w-full h-20 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-blue-500 hover:bg-blue-50 transition"
                >
                  <Upload class="w-5 h-5 text-gray-400" />
                  <span class="text-sm text-gray-500">파일을 드래그하거나 클릭하여 업로드</span>
                  <input type="file" multiple class="hidden" />
                </label>
              </div>

              <div class="flex gap-2 justify-end">
                <button
                  @click="cancelCreate"
                  class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition"
                >
                  취소
                </button>
                <button
                  @click="saveSchedule"
                  class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
                >
                  저장
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="p-4 border-t border-gray-200 flex justify-end">
          <button
            v-if="!isCreateMode && isMyCalendar"
            @click="startCreateMode"
            class="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition"
          >
            <Plus class="w-4 h-4" />
            일정 추가
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
