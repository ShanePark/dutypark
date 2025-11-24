<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import {
  ChevronLeft,
  ChevronRight,
  Calendar,
  Settings,
  CalendarPlus,
  Pencil,
  Trash2,
  User,
  Building2,
  X,
} from 'lucide-vue-next'

const router = useRouter()

// State
const hasTeam = ref(true) // Toggle this to false to see no-team state
const isTeamManager = ref(true)
const loginMemberId = ref(1)

// Current view date
const currentYear = ref(2025)
const currentMonth = ref(11)

// Today's date
const today = {
  year: 2025,
  month: 11,
  day: 24,
}

// Selected day
const selectedDay = ref({
  year: 2025,
  month: 11,
  day: 24,
  index: -1,
})

const weekDays = ['일', '월', '화', '수', '목', '금', '토']

// Dummy team data
const team = ref({
  id: 1,
  name: '개발팀',
})

// Dummy my duty colors (indexed by calendar day)
const myDuty = ref<Array<{ dutyColor: string } | null>>([])

// Dummy team schedules grouped by day index
const teamSchedules = ref<Array<Array<{
  id: string
  content: string
  description?: string
  startDateTime: string
  endDateTime: string
  createMember: string
  daysFromStart: number
  totalDays: number
}>>>([])

// Dummy shift data
const shift = ref([
  {
    dutyType: { id: 1, name: '주간', color: '#bae1ff' },
    members: [
      { id: 1, name: '김철수' },
      { id: 2, name: '이영희' },
      { id: 3, name: '박지민' },
      { id: 4, name: '정수현' },
    ],
    isMyGroup: true,
  },
  {
    dutyType: { id: 2, name: '야간', color: '#baffc9' },
    members: [
      { id: 5, name: '최민수' },
      { id: 6, name: '강태희' },
    ],
    isMyGroup: false,
  },
  {
    dutyType: { id: 0, name: 'OFF', color: '#ffffba' },
    members: [
      { id: 7, name: '윤서연' },
      { id: 8, name: '한지우' },
      { id: 9, name: '송민아' },
    ],
    isMyGroup: false,
  },
])

// Schedule Modal
const showScheduleModal = ref(false)
const scheduleForm = ref({
  id: null as string | null,
  content: '',
  description: '',
  startDate: '',
  endDate: '',
})

// Generate calendar days
const teamDays = computed(() => {
  const days: Array<{
    year: number
    month: number
    day: number
    isCurrentMonth: boolean
  }> = []

  const firstDay = new Date(currentYear.value, currentMonth.value - 1, 1)
  const lastDay = new Date(currentYear.value, currentMonth.value, 0)
  const startDayOfWeek = firstDay.getDay()

  // Previous month days
  const prevMonthLastDay = new Date(currentYear.value, currentMonth.value - 1, 0).getDate()
  const prevMonth = currentMonth.value === 1 ? 12 : currentMonth.value - 1
  const prevYear = currentMonth.value === 1 ? currentYear.value - 1 : currentYear.value

  for (let i = startDayOfWeek - 1; i >= 0; i--) {
    days.push({
      year: prevYear,
      month: prevMonth,
      day: prevMonthLastDay - i,
      isCurrentMonth: false,
    })
  }

  // Current month days
  for (let i = 1; i <= lastDay.getDate(); i++) {
    days.push({
      year: currentYear.value,
      month: currentMonth.value,
      day: i,
      isCurrentMonth: true,
    })
  }

  // Next month days
  const nextMonth = currentMonth.value === 12 ? 1 : currentMonth.value + 1
  const nextYear = currentMonth.value === 12 ? currentYear.value + 1 : currentYear.value
  const remainingDays = 42 - days.length

  for (let i = 1; i <= remainingDays; i++) {
    days.push({
      year: nextYear,
      month: nextMonth,
      day: i,
      isCurrentMonth: false,
    })
  }

  return days
})

// Generate dummy data based on calendar
function generateDummyData() {
  // Generate duty colors
  const duties: Array<{ dutyColor: string } | null> = []
  for (let i = 0; i < 42; i++) {
    const dayItem = teamDays.value[i]
    if (dayItem?.isCurrentMonth) {
      const dayNum = dayItem.day
      if (dayNum % 7 === 0 || dayNum % 7 === 6) {
        duties.push({ dutyColor: '#ffffba' }) // Weekend - OFF
      } else if (dayNum % 3 === 0) {
        duties.push({ dutyColor: '#baffc9' }) // Night shift
      } else {
        duties.push({ dutyColor: '#bae1ff' }) // Day shift
      }
    } else {
      duties.push(null)
    }
  }
  myDuty.value = duties

  // Generate schedules
  const schedules: typeof teamSchedules.value = []
  for (let i = 0; i < 42; i++) {
    if (teamDays.value[i]?.day === 24 && teamDays.value[i]?.month === 11) {
      schedules.push([
        {
          id: '1',
          content: '팀 회의',
          description: '월간 정기 회의',
          startDateTime: '2025-11-24T10:00:00',
          endDateTime: '2025-11-24T12:00:00',
          createMember: '김철수',
          daysFromStart: 1,
          totalDays: 1,
        },
        {
          id: '2',
          content: '연말 회식',
          description: '송년회 겸 회식',
          startDateTime: '2025-11-24T18:00:00',
          endDateTime: '2025-11-25T22:00:00',
          createMember: '박지민',
          daysFromStart: 1,
          totalDays: 2,
        },
      ])
    } else if (teamDays.value[i]?.day === 25 && teamDays.value[i]?.month === 11) {
      schedules.push([
        {
          id: '2',
          content: '연말 회식',
          description: '송년회 겸 회식',
          startDateTime: '2025-11-24T18:00:00',
          endDateTime: '2025-11-25T22:00:00',
          createMember: '박지민',
          daysFromStart: 2,
          totalDays: 2,
        },
      ])
    } else if (teamDays.value[i]?.day === 28 && teamDays.value[i]?.month === 11) {
      schedules.push([
        {
          id: '3',
          content: '프로젝트 마감',
          description: '',
          startDateTime: '2025-11-28T00:00:00',
          endDateTime: '2025-11-28T23:59:59',
          createMember: '이영희',
          daysFromStart: 1,
          totalDays: 1,
        },
      ])
    } else {
      schedules.push([])
    }
  }
  teamSchedules.value = schedules
}

// Initial data generation
generateDummyData()

// Find selected day index
function findSelectedDayIndex() {
  const index = teamDays.value.findIndex(day =>
    day.year === selectedDay.value.year &&
    day.month === selectedDay.value.month &&
    day.day === selectedDay.value.day
  )
  selectedDay.value.index = index
}

// Call on mount
findSelectedDayIndex()

function isToday(day: { year: number; month: number; day: number }) {
  return day.year === today.year && day.month === today.month && day.day === today.day
}

function isSelectedDay(day: { year: number; month: number; day: number }) {
  return day.year === selectedDay.value.year &&
         day.month === selectedDay.value.month &&
         day.day === selectedDay.value.day
}

function selectDay(day: { year: number; month: number; day: number }, index: number) {
  selectedDay.value = { ...day, index }
}

function prevMonth() {
  if (currentMonth.value === 1) {
    currentMonth.value = 12
    currentYear.value--
  } else {
    currentMonth.value--
  }
  generateDummyData()
}

function nextMonth() {
  if (currentMonth.value === 12) {
    currentMonth.value = 1
    currentYear.value++
  } else {
    currentMonth.value++
  }
  generateDummyData()
}

function goToToday() {
  currentYear.value = today.year
  currentMonth.value = today.month
  selectedDay.value = { ...today, index: -1 }
  generateDummyData()
  findSelectedDayIndex()
}

function goToTeamManage() {
  router.push(`/team/manage/${team.value.id}`)
}

function goToMemberDuty(memberId: number) {
  router.push(`/duty/${memberId}`)
}

// Schedule Modal functions
function openNewScheduleModal() {
  const dateStr = `${selectedDay.value.year}-${String(selectedDay.value.month).padStart(2, '0')}-${String(selectedDay.value.day).padStart(2, '0')}`
  scheduleForm.value = {
    id: null,
    content: '',
    description: '',
    startDate: dateStr,
    endDate: dateStr,
  }
  showScheduleModal.value = true
}

function openEditScheduleModal(schedule: {
  id: string
  content: string
  description?: string
  startDateTime: string
  endDateTime: string
}) {
  scheduleForm.value = {
    id: schedule.id,
    content: schedule.content,
    description: schedule.description || '',
    startDate: schedule.startDateTime.slice(0, 10),
    endDate: schedule.endDateTime.slice(0, 10),
  }
  showScheduleModal.value = true
}

function closeScheduleModal() {
  showScheduleModal.value = false
}

function saveSchedule() {
  // Dummy save - just close modal
  console.log('Saving schedule:', scheduleForm.value)
  showScheduleModal.value = false
}

function deleteSchedule(scheduleId: string) {
  if (confirm('정말 삭제하시겠습니까?\n삭제된 일정은 복구할 수 없습니다.')) {
    console.log('Deleting schedule:', scheduleId)
  }
}
</script>

<template>
  <div class="max-w-4xl mx-auto px-2 sm:px-4 py-4">
    <!-- No Team State -->
    <template v-if="!hasTeam">
      <div class="bg-white rounded-lg shadow overflow-hidden">
        <div class="bg-gray-600 text-white font-bold text-xl text-center py-3">
          내 팀
        </div>
        <div class="flex flex-col items-center justify-center p-12 text-gray-500">
          <Building2 class="w-16 h-16 mb-4 text-gray-300" />
          <p class="text-xl font-bold mb-2">어느 팀에도 속해있지 않습니다.</p>
          <p class="text-lg">팀 관리자에게 가입을 요청해주세요.</p>
        </div>
      </div>
    </template>

    <!-- Team View -->
    <template v-if="hasTeam">
      <!-- Team Header -->
      <div class="bg-gray-600 text-white font-bold text-xl text-center py-3 rounded-t-lg">
        {{ team.name }}
      </div>

      <!-- Month Controls -->
      <div class="flex flex-wrap items-center justify-between gap-2 bg-white p-2 border-x border-gray-200">
        <button
          @click="goToToday"
          class="px-4 py-2 bg-blue-500 text-white rounded-lg font-medium hover:bg-blue-600 transition flex items-center gap-1"
        >
          오늘
          <Calendar class="w-4 h-4" />
        </button>

        <div class="flex items-center gap-2">
          <button
            @click="prevMonth"
            class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-100 transition"
          >
            <ChevronLeft class="w-5 h-5" />
          </button>

          <h2 class="text-lg font-bold min-w-[140px] text-center">
            {{ currentYear }}년 {{ currentMonth }}월
          </h2>

          <button
            @click="nextMonth"
            class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-100 transition"
          >
            <ChevronRight class="w-5 h-5" />
          </button>
        </div>

        <button
          v-if="isTeamManager"
          @click="goToTeamManage"
          class="px-3 py-2 border border-gray-300 rounded-lg hover:bg-gray-100 transition flex items-center gap-1"
        >
          <Settings class="w-4 h-4" />
          팀 관리
        </button>
        <div v-else class="w-20"></div>
      </div>

      <!-- Calendar -->
      <div class="bg-white border border-gray-200">
        <!-- Week Days Header -->
        <div class="grid grid-cols-7 bg-gray-100 border-b-2 border-gray-800">
          <div
            v-for="(day, idx) in weekDays"
            :key="day"
            class="py-2 text-center font-bold text-sm border-x border-gray-800 first:border-l-0 last:border-r-0"
            :class="{
              'text-red-500': idx === 0,
              'text-blue-500': idx === 6,
            }"
          >
            {{ day }}
          </div>
        </div>

        <!-- Calendar Grid -->
        <div class="grid grid-cols-7">
          <div
            v-for="(day, idx) in teamDays"
            :key="idx"
            @click="selectDay(day, idx)"
            class="min-h-[70px] sm:min-h-[90px] border border-gray-300 p-1 cursor-pointer hover:bg-gray-50 transition relative"
            :class="{
              'opacity-60': !day.isCurrentMonth,
              'ring-2 ring-inset ring-blue-500': isSelectedDay(day),
            }"
            :style="{ backgroundColor: day.isCurrentMonth && myDuty[idx]?.dutyColor ? myDuty[idx]?.dutyColor : '' }"
          >
            <!-- Today indicator -->
            <div
              v-if="isToday(day)"
              class="absolute inset-0 ring-2 ring-red-500 pointer-events-none"
            ></div>

            <div
              class="text-center"
              :class="{
                'text-red-500': idx % 7 === 0,
                'text-blue-500': idx % 7 === 6,
              }"
            >
              <span
                class="text-sm font-bold"
                :class="{ 'underline decoration-red-500 decoration-2': isToday(day) }"
              >
                {{ day.day }}
              </span>
            </div>

            <!-- Team Schedules -->
            <div v-if="teamSchedules[idx]?.length" class="mt-0.5 space-y-0.5">
              <div
                v-for="schedule in teamSchedules[idx].slice(0, 2)"
                :key="schedule.id"
                class="text-xs text-gray-600 truncate px-0.5"
              >
                {{ schedule.content }}
                <span v-if="schedule.totalDays > 1" class="text-gray-400">
                  ({{ schedule.daysFromStart }}/{{ schedule.totalDays }})
                </span>
              </div>
              <div
                v-if="teamSchedules[idx].length > 2"
                class="text-xs text-gray-400 px-0.5"
              >
                +{{ teamSchedules[idx].length - 2 }} more
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Selected Day Schedule -->
      <div class="bg-white border-x border-b border-gray-200 p-3">
        <div class="flex items-center justify-between mb-3">
          <h3 class="text-lg font-bold">
            {{ selectedDay.year }}년 {{ selectedDay.month }}월 {{ selectedDay.day }}일
          </h3>
          <button
            v-if="isTeamManager"
            @click="openNewScheduleModal"
            class="px-3 py-1.5 bg-green-500 text-white rounded-lg font-medium hover:bg-green-600 transition flex items-center gap-1"
          >
            <CalendarPlus class="w-4 h-4" />
            팀 일정 추가
          </button>
        </div>

        <!-- Schedule List -->
        <div
          v-if="selectedDay.index >= 0 && teamSchedules[selectedDay.index]?.length"
          class="space-y-3"
        >
          <div
            v-for="schedule in teamSchedules[selectedDay.index]"
            :key="schedule.id"
            class="bg-gray-50 rounded-lg p-3 border border-gray-200"
          >
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <div class="font-bold text-gray-800 mb-1">
                  {{ schedule.content }}
                  <span class="text-sm font-normal text-gray-500">
                    (by: <strong>{{ schedule.createMember }}</strong>)
                  </span>
                </div>
                <div v-if="schedule.description" class="text-sm text-gray-600">
                  {{ schedule.description }}
                </div>
              </div>
              <div v-if="isTeamManager" class="flex gap-2 ml-3">
                <button
                  @click="openEditScheduleModal(schedule)"
                  class="px-2 py-1 text-sm border border-blue-500 text-blue-500 rounded hover:bg-blue-50 transition flex items-center gap-1"
                >
                  <Pencil class="w-3 h-3" />
                  수정
                </button>
                <button
                  @click="deleteSchedule(schedule.id)"
                  class="px-2 py-1 text-sm border border-red-500 text-red-500 rounded hover:bg-red-50 transition flex items-center gap-1"
                >
                  <Trash2 class="w-3 h-3" />
                  삭제
                </button>
              </div>
            </div>
          </div>
        </div>
        <div v-else class="text-center text-gray-400 py-4">
          이 날의 팀 일정이 없습니다.
        </div>
      </div>

      <!-- Shift Groups -->
      <div v-if="shift.length > 0" class="mt-4 space-y-4">
        <template v-for="group in shift" :key="group.dutyType.id">
          <div
            v-if="group.members.length > 0"
            class="bg-white rounded-lg border overflow-hidden"
            :class="{ 'border-2 border-gray-800': group.isMyGroup, 'border-gray-200': !group.isMyGroup }"
          >
            <!-- Duty Type Header -->
            <div
              class="p-3 flex items-center justify-between"
              :style="{ backgroundColor: group.dutyType.color }"
            >
              <span class="font-bold text-gray-800">{{ group.dutyType.name }}</span>
              <span class="bg-white text-gray-800 px-2 py-0.5 rounded-full text-sm font-medium">
                {{ group.members.length }}
              </span>
            </div>

            <!-- Members Grid -->
            <div class="p-3 grid grid-cols-4 gap-2">
              <div
                v-for="member in group.members"
                :key="member.id"
                @click="goToMemberDuty(member.id)"
                class="flex flex-col items-center p-2 border rounded-lg cursor-pointer hover:bg-gray-50 transition"
                :class="{ 'border-2 border-gray-800': member.id === loginMemberId, 'border-gray-200': member.id !== loginMemberId }"
              >
                <User class="w-5 h-5 text-gray-500 mb-1" />
                <span class="text-sm font-medium text-gray-700 truncate w-full text-center">
                  {{ member.name }}
                </span>
              </div>
            </div>
          </div>
        </template>
      </div>
    </template>

    <!-- Schedule Modal -->
    <div
      v-if="showScheduleModal"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
      @click.self="closeScheduleModal"
    >
      <div class="bg-white rounded-lg shadow-xl w-full max-w-lg">
        <div class="flex items-center justify-between p-4 border-b">
          <h3 class="text-lg font-bold">팀 일정 저장</h3>
          <button
            @click="closeScheduleModal"
            class="p-1 hover:bg-gray-100 rounded transition"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="p-4 space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              제목(필수)
            </label>
            <input
              v-model="scheduleForm.content"
              type="text"
              maxlength="30"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="일정 제목을 입력하세요"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              상세(옵션)
            </label>
            <textarea
              v-model="scheduleForm.description"
              rows="4"
              maxlength="4096"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
              placeholder="상세 내용을 입력하세요"
            ></textarea>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                시작일
              </label>
              <input
                v-model="scheduleForm.startDate"
                type="date"
                readonly
                class="w-full px-3 py-2 border border-gray-300 rounded-lg bg-gray-100"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                종료일
              </label>
              <input
                v-model="scheduleForm.endDate"
                type="date"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
          </div>
        </div>

        <div class="flex justify-end gap-2 p-4 border-t">
          <button
            @click="saveSchedule"
            class="px-4 py-2 bg-blue-500 text-white rounded-lg font-medium hover:bg-blue-600 transition"
          >
            저장
          </button>
          <button
            @click="closeScheduleModal"
            class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg font-medium hover:bg-gray-300 transition"
          >
            닫기
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
