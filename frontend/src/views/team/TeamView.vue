<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import {
  ChevronLeft,
  ChevronRight,
  Settings,
  CalendarPlus,
  Pencil,
  Trash2,
  User,
  Building2,
  X,
  Loader2,
} from 'lucide-vue-next'
import { useAuthStore } from '@/stores/auth'
import { teamApi } from '@/api/team'
import { dutyApi } from '@/api/duty'
import { useSwal } from '@/composables/useSwal'
import { isLightColor } from '@/utils/color'
import YearMonthPicker from '@/components/common/YearMonthPicker.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import type {
  TeamDto,
  TeamScheduleDto,
  DutyByShift,
  SimpleMemberDto,
  DutyCalendarDay,
  HolidayDto,
} from '@/types'

const router = useRouter()
const authStore = useAuthStore()
const { showError, confirmDelete, toastSuccess } = useSwal()

// Loading state
const loading = ref(false)
const shiftLoading = ref(false)
const saving = ref(false)

// State from API
const hasTeam = ref(false)
const isTeamManager = ref(false)
const loginMemberId = computed(() => authStore.user?.id ?? 0)
const team = ref<TeamDto | null>(null)

// Current view date
const now = new Date()
const currentYear = ref(now.getFullYear())
const currentMonth = ref(now.getMonth() + 1)

// Year-Month Picker
const isYearMonthPickerOpen = ref(false)

function handleYearMonthSelect(year: number, month: number) {
  currentYear.value = year
  currentMonth.value = month
  isYearMonthPickerOpen.value = false
  fetchTeamSummary()
}

// Today's date
const today = {
  year: now.getFullYear(),
  month: now.getMonth() + 1,
  day: now.getDate(),
}

// Selected day
const selectedDay = ref({
  year: today.year,
  month: today.month,
  day: today.day,
  index: -1,
})

const weekDays = ['일', '월', '화', '수', '목', '금', '토']

// Team schedules from API - indexed by calendar position
const teamSchedules = ref<TeamScheduleDto[][]>([])

// Shift data from API
const shift = ref<(DutyByShift & { isMyGroup: boolean })[]>([])

// My duty data - fetched from duty API (same as DutyView)
const myDuties = ref<DutyCalendarDay[]>([])

// Holidays by day index
const holidaysByDays = ref<HolidayDto[][]>([])

// Raw calendar days from backend API
const rawCalendarDays = ref<Array<{ year: number; month: number; day: number }>>([])

// Schedule Modal
const showScheduleModal = ref(false)
const scheduleForm = ref({
  id: null as string | null,
  content: '',
  description: '',
  startDate: '',
  endDate: '',
})

// Load calendar structure from backend API (cached)
async function loadCalendar() {
  try {
    rawCalendarDays.value = await dutyApi.getCalendar(currentYear.value, currentMonth.value)
  } catch (error) {
    console.error('Failed to load calendar:', error)
    rawCalendarDays.value = []
  }
}

// Generate calendar days from backend data
const teamDays = computed(() => {
  return rawCalendarDays.value.map((raw) => ({
    year: raw.year,
    month: raw.month,
    day: raw.day,
    isCurrentMonth: raw.year === currentYear.value && raw.month === currentMonth.value,
  }))
})

// Fetch team summary for the month
async function fetchTeamSummary() {
  loading.value = true
  try {
    // Load calendar first to ensure index alignment with holidays
    await loadCalendar()

    const response = await teamApi.getMyTeamSummary(currentYear.value, currentMonth.value)
    const data = response.data

    if (data.team) {
      hasTeam.value = true
      team.value = data.team
      isTeamManager.value = data.isTeamManager

      // Fetch my duties, team schedules, and holidays in parallel
      await Promise.all([
        fetchMyDuties(),
        fetchTeamSchedules(),
        loadHolidays(),
      ])
    } else {
      hasTeam.value = false
      team.value = null
      isTeamManager.value = false
      teamSchedules.value = []
    }
  } catch (error) {
    console.error('Failed to fetch team summary:', error)
    hasTeam.value = false
  } finally {
    loading.value = false
  }
}

// Fetch team schedules
async function fetchTeamSchedules() {
  if (!team.value) return

  try {
    const response = await teamApi.getTeamSchedules(
      team.value.id,
      currentYear.value,
      currentMonth.value
    )
    teamSchedules.value = response.data
  } catch (error) {
    console.error('Failed to fetch team schedules:', error)
    teamSchedules.value = []
  }
}

// Fetch shift data for selected day
async function fetchShift() {
  if (!hasTeam.value) return

  shiftLoading.value = true
  try {
    const response = await teamApi.getShift(
      selectedDay.value.year,
      selectedDay.value.month,
      selectedDay.value.day
    )

    // Add isMyGroup flag based on loginMemberId
    shift.value = response.data.map(group => ({
      ...group,
      isMyGroup: group.members.some((m: SimpleMemberDto) => m.id === loginMemberId.value),
    }))
  } catch (error) {
    console.error('Failed to fetch shift:', error)
    shift.value = []
  } finally {
    shiftLoading.value = false
  }
}

// Fetch my duty data
async function fetchMyDuties() {
  if (!loginMemberId.value) return

  try {
    myDuties.value = await dutyApi.getDuties(
      loginMemberId.value,
      currentYear.value,
      currentMonth.value
    )
  } catch (error) {
    console.error('Failed to fetch my duties:', error)
    myDuties.value = []
  }
}

// Get duty color for a day
function getDutyColor(day: { year: number; month: number; day: number }): string | null {
  // Find duty from fetched data
  const duty = myDuties.value.find(
    d => d.year === day.year && d.month === day.month && d.day === day.day
  )
  return duty?.dutyColor ?? null
}

// Check if a color is light (for text contrast)

// Get adaptive border color based on background brightness
function getAdaptiveBorderColor(backgroundColor: string | null | undefined): string {
  if (!backgroundColor) return 'var(--dp-border-secondary)'
  const isLight = isLightColor(backgroundColor)
  return isLight ? 'rgba(0, 0, 0, 0.2)' : 'rgba(255, 255, 255, 0.2)'
}

// Load holidays from API
async function loadHolidays() {
  try {
    holidaysByDays.value = await dutyApi.getHolidays(
      currentYear.value,
      currentMonth.value
    )
  } catch (error) {
    console.error('Failed to load holidays:', error)
    holidaysByDays.value = []
  }
}

// Find selected day index
function findSelectedDayIndex() {
  const index = teamDays.value.findIndex(day =>
    day.year === selectedDay.value.year &&
    day.month === selectedDay.value.month &&
    day.day === selectedDay.value.day
  )
  selectedDay.value.index = index
}

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
  fetchShift()
}

function prevMonth() {
  if (currentMonth.value === 1) {
    currentMonth.value = 12
    currentYear.value--
  } else {
    currentMonth.value--
  }
  fetchTeamSummary()
}

function nextMonth() {
  if (currentMonth.value === 12) {
    currentMonth.value = 1
    currentYear.value++
  } else {
    currentMonth.value++
  }
  fetchTeamSummary()
}

function goToToday() {
  currentYear.value = today.year
  currentMonth.value = today.month
  selectedDay.value = { ...today, index: -1 }
  fetchTeamSummary().then(() => {
    findSelectedDayIndex()
    fetchShift()
  })
}

function goToTeamManage() {
  if (team.value) {
    router.push(`/team/manage/${team.value.id}`)
  }
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

function openEditScheduleModal(schedule: TeamScheduleDto) {
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

async function saveSchedule() {
  if (!team.value || !scheduleForm.value.content.trim()) return

  saving.value = true
  const isNew = !scheduleForm.value.id
  try {
    await teamApi.saveTeamSchedule({
      id: scheduleForm.value.id ?? undefined,
      teamId: team.value.id,
      content: scheduleForm.value.content,
      description: scheduleForm.value.description,
      startDateTime: `${scheduleForm.value.startDate}T00:00:00`,
      endDateTime: `${scheduleForm.value.endDate}T23:59:59`,
    })
    showScheduleModal.value = false
    await fetchTeamSchedules()
    toastSuccess(isNew ? '일정이 등록되었습니다.' : '일정이 수정되었습니다.')
  } catch (error) {
    console.error('Failed to save schedule:', error)
    showError('일정 저장에 실패했습니다.')
  } finally {
    saving.value = false
  }
}

async function deleteSchedule(scheduleId: string) {
  if (!await confirmDelete('정말 삭제하시겠습니까?\n삭제된 일정은 복구할 수 없습니다.')) return

  try {
    await teamApi.deleteTeamSchedule(scheduleId)
    await fetchTeamSchedules()
    toastSuccess('일정이 삭제되었습니다.')
  } catch (error) {
    console.error('Failed to delete schedule:', error)
    showError('일정 삭제에 실패했습니다.')
  }
}

// Initial load
onMounted(() => {
  fetchTeamSummary().then(() => {
    findSelectedDayIndex()
    fetchShift()
  })
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-2 sm:px-4 py-4">
    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center py-20">
      <Loader2 class="w-8 h-8 animate-spin text-blue-500" />
    </div>

    <!-- No Team State -->
    <template v-else-if="!hasTeam">
      <div class="rounded-lg shadow overflow-hidden" :style="{ backgroundColor: 'var(--dp-bg-card)' }">
        <div class="bg-gray-600 text-white font-bold text-xl text-center py-3">
          내 팀
        </div>
        <div class="flex flex-col items-center justify-center p-12" :style="{ color: 'var(--dp-text-secondary)' }">
          <Building2 class="w-16 h-16 mb-4" :style="{ color: 'var(--dp-text-muted)' }" />
          <p class="text-xl font-bold mb-2">어느 팀에도 속해있지 않습니다.</p>
          <p class="text-lg">팀 관리자에게 가입을 요청해주세요.</p>
        </div>
      </div>
    </template>

    <!-- Team View -->
    <template v-else-if="team">
      <!-- Team Header & Month Controls -->
      <div class="flex items-center justify-between gap-1 mb-1">
        <!-- Left: Team name -->
        <div class="w-20 sm:w-24 flex-shrink-0 flex items-center justify-start">
          <div class="flex items-center gap-1.5 px-2 py-1 rounded-full border" :style="{ backgroundColor: 'var(--dp-bg-tertiary)', borderColor: 'var(--dp-border-secondary)' }">
            <Building2 class="w-3.5 h-3.5 flex-shrink-0" :style="{ color: 'var(--dp-text-secondary)' }" />
            <span class="text-xs sm:text-sm font-semibold truncate max-w-[60px] sm:max-w-[72px]" :style="{ color: 'var(--dp-text-primary)' }">{{ team.name }}</span>
          </div>
        </div>

        <!-- Center: Year-Month Navigation -->
        <div class="flex items-center justify-center">
          <button @click="prevMonth" class="calendar-nav-btn p-1 sm:p-2 rounded-full flex items-center justify-center flex-shrink-0 cursor-pointer">
            <ChevronLeft class="w-5 h-5 sm:w-6 sm:h-6" />
          </button>
          <button
            @click="isYearMonthPickerOpen = true"
            class="calendar-nav-btn px-2 sm:px-3 py-1 text-lg sm:text-2xl font-semibold rounded whitespace-nowrap cursor-pointer"
          >
            {{ currentYear }}-{{ String(currentMonth).padStart(2, '0') }}
          </button>
          <button @click="nextMonth" class="calendar-nav-btn p-1 sm:p-2 rounded-full flex items-center justify-center flex-shrink-0 cursor-pointer">
            <ChevronRight class="w-5 h-5 sm:w-6 sm:h-6" />
          </button>
        </div>

        <!-- Right: Team manage button -->
        <div class="flex-shrink-0">
          <button
            v-if="isTeamManager"
            @click="goToTeamManage"
            class="px-3 py-2 border rounded-lg flex items-center gap-1 hover-interactive cursor-pointer"
            :style="{ borderColor: 'var(--dp-border-secondary)' }"
          >
            <Settings class="w-4 h-4" />
            <span class="hidden sm:inline">팀 관리</span>
          </button>
          <div v-else class="w-16 sm:w-20"></div>
        </div>
      </div>

      <!-- Calendar Grid -->
      <div class="rounded-lg border overflow-hidden mb-2 shadow-sm" :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-secondary)' }">
        <!-- Week Days Header -->
        <div class="grid grid-cols-7" :style="{ backgroundColor: 'var(--dp-calendar-header-bg)' }">
          <div
            v-for="(day, idx) in weekDays"
            :key="day"
            class="py-2 text-center font-bold border-b-2 text-sm"
            :style="{ borderColor: 'var(--dp-border-secondary)', color: idx === 0 ? '#dc2626' : idx === 6 ? '#2563eb' : 'var(--dp-text-primary)' }"
            :class="{
              'border-r': idx < 6,
            }"
          >
            {{ day }}
          </div>
        </div>

        <!-- Calendar Days -->
        <div class="grid grid-cols-7">
          <div
            v-for="(day, idx) in teamDays"
            :key="idx"
            @click="selectDay(day, idx)"
            class="min-h-[70px] sm:min-h-[80px] md:min-h-[100px] border-b border-r p-0.5 sm:p-1 transition-all duration-150 relative cursor-pointer hover:brightness-95 hover:shadow-inner"
            :style="{
              borderColor: getAdaptiveBorderColor(getDutyColor(day)),
              backgroundColor: getDutyColor(day) || (!day.isCurrentMonth ? 'var(--dp-calendar-cell-prev-next)' : 'var(--dp-calendar-cell-bg)'),
              opacity: !day.isCurrentMonth ? 0.5 : 1
            }"
            :class="{
              'ring-2 ring-red-500 ring-inset': isToday(day),
              'ring-2 ring-blue-500 ring-inset': isSelectedDay(day) && !isToday(day),
            }"
          >
            <!-- Day Number -->
            <div class="flex items-center justify-between">
              <span
                class="text-xs sm:text-sm font-medium"
                :class="{
                  'font-bold': isToday(day),
                }"
                :style="{
                  color: idx % 7 === 0 ? '#dc2626' : idx % 7 === 6 ? '#2563eb' : (getDutyColor(day) ? (isLightColor(getDutyColor(day)) ? '#1f2937' : '#ffffff') : 'var(--dp-text-primary)')
                }"
              >
                {{ day.day }}
              </span>
            </div>

            <!-- Holidays -->
            <div
              v-for="holiday in holidaysByDays[idx] ?? []"
              :key="holiday.localDate + holiday.dateName"
              class="text-[10px] sm:text-sm leading-snug px-0.5"
              :class="holiday.isHoliday ? 'text-red-600' : ''"
              :style="!holiday.isHoliday ? { color: getDutyColor(day) ? (isLightColor(getDutyColor(day)) ? '#6b7280' : 'rgba(255,255,255,0.7)') : 'var(--dp-text-muted)' } : {}"
            >
              {{ holiday.dateName }}
            </div>

            <!-- Team Schedules -->
            <div v-if="teamSchedules[idx]?.length" class="mt-0.5">
              <div
                v-for="schedule in teamSchedules[idx].slice(0, 2)"
                :key="schedule.id"
                class="text-[10px] sm:text-sm leading-snug px-0.5 border-t-2 border-dashed break-words"
                :style="{
                  color: getDutyColor(day) ? (isLightColor(getDutyColor(day)) ? '#1f2937' : '#ffffff') : 'var(--dp-text-primary)',
                  borderColor: getDutyColor(day) ? (isLightColor(getDutyColor(day)) ? 'rgba(0,0,0,0.15)' : 'rgba(255,255,255,0.3)') : 'var(--dp-border-primary)'
                }"
              >
                {{ schedule.content }}
                <span
                  v-if="schedule.totalDays && schedule.totalDays > 1"
                  class="text-[9px] sm:text-xs"
                  :style="{ color: getDutyColor(day) ? (isLightColor(getDutyColor(day)) ? '#6b7280' : 'rgba(255,255,255,0.7)') : 'var(--dp-text-muted)' }"
                >
                  ({{ schedule.daysFromStart }}/{{ schedule.totalDays }})
                </span>
              </div>
              <div
                v-if="teamSchedules[idx].length > 2"
                class="text-[10px] font-medium"
                :style="{ color: getDutyColor(day) ? (isLightColor(getDutyColor(day)) ? '#6b7280' : 'rgba(255,255,255,0.8)') : 'var(--dp-text-muted)' }"
              >
                +{{ teamSchedules[idx].length - 2 }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Selected Day Schedule -->
      <div class="rounded-lg border shadow-sm p-3" :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-secondary)' }">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-3">
          <h3 class="text-lg font-bold" :style="{ color: 'var(--dp-text-primary)' }">
            {{ selectedDay.year }}년 {{ selectedDay.month }}월 {{ selectedDay.day }}일
          </h3>
          <button
            v-if="isTeamManager"
            @click="openNewScheduleModal"
            class="px-3 py-1.5 bg-green-500 text-white rounded-lg font-medium hover:bg-green-600 transition flex items-center gap-1 w-full sm:w-auto justify-center"
          >
            <CalendarPlus class="w-4 h-4" />
            팀 일정 추가
          </button>
        </div>

        <!-- Schedule List -->
        <div
          v-if="selectedDay.index >= 0 && teamSchedules[selectedDay.index]?.length"
          class="space-y-2"
        >
          <div
            v-for="schedule in teamSchedules[selectedDay.index]"
            :key="schedule.id"
            class="rounded-lg p-3 border transition-all duration-150 hover:shadow-md"
            :style="{ backgroundColor: 'var(--dp-bg-secondary)', borderColor: 'var(--dp-border-primary)' }"
          >
            <div class="flex items-start justify-between">
              <div class="flex-1 min-w-0">
                <div class="font-bold mb-1" :style="{ color: 'var(--dp-text-primary)' }">
                  {{ schedule.content }}
                  <span class="text-sm font-normal" :style="{ color: 'var(--dp-text-secondary)' }">
                    (by: <strong>{{ schedule.createMember }}</strong>)
                  </span>
                </div>
                <div v-if="schedule.description" class="text-sm whitespace-pre-wrap break-words" :style="{ color: 'var(--dp-text-secondary)' }">
                  {{ schedule.description }}
                </div>
              </div>
              <div v-if="isTeamManager" class="flex gap-1 ml-2 flex-shrink-0">
                <button
                  @click="openEditScheduleModal(schedule)"
                  class="p-1.5 text-blue-500 rounded-lg hover:bg-blue-100 transition"
                  title="수정"
                >
                  <Pencil class="w-4 h-4" />
                </button>
                <button
                  @click="deleteSchedule(schedule.id)"
                  class="p-1.5 text-red-500 rounded-lg hover:bg-red-100 transition"
                  title="삭제"
                >
                  <Trash2 class="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>
        <div v-else class="text-center py-6" :style="{ color: 'var(--dp-text-muted)' }">
          이 날의 팀 일정이 없습니다.
        </div>
      </div>

      <!-- Shift Groups -->
      <div v-if="shiftLoading" class="mt-3 flex items-center justify-center py-8">
        <Loader2 class="w-6 h-6 animate-spin text-blue-500" />
      </div>
      <div v-else-if="shift.length > 0" class="mt-3 space-y-3">
        <template v-for="group in shift" :key="group.dutyType.id">
          <div
            v-if="group.members.length > 0"
            class="rounded-lg border overflow-hidden shadow-sm"
            :class="{ 'ring-2': group.isMyGroup }"
            :style="{
              backgroundColor: 'var(--dp-bg-card)',
              borderColor: 'var(--dp-border-secondary)',
              '--tw-ring-color': 'var(--dp-text-primary)'
            }"
          >
            <!-- Duty Type Header -->
            <div
              class="p-3 flex items-center justify-between"
              :style="{ backgroundColor: group.dutyType.color ?? '#e8e8e8' }"
            >
              <span class="font-bold" :style="{ color: isLightColor(group.dutyType.color) ? '#1f2937' : '#ffffff' }">{{ group.dutyType.name }}</span>
              <span class="px-2 py-0.5 rounded-full text-sm font-medium" :style="{ backgroundColor: 'rgba(255,255,255,0.9)', color: '#1f2937' }">
                {{ group.members.length }}명
              </span>
            </div>

            <!-- Members Grid -->
            <div class="p-3 grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2">
              <div
                v-for="member in group.members"
                :key="member.id"
                @click="goToMemberDuty(member.id)"
                class="flex flex-col items-center p-2 border rounded-lg cursor-pointer hover-card-select"
                :class="{ 'ring-2': member.id === loginMemberId }"
                :style="{
                  borderColor: 'var(--dp-border-secondary)',
                  backgroundColor: 'var(--dp-bg-secondary)',
                  '--tw-ring-color': 'var(--dp-text-primary)'
                }"
              >
                <User class="w-5 h-5 mb-1" :style="{ color: 'var(--dp-text-secondary)' }" />
                <span class="text-sm font-medium truncate w-full text-center" :style="{ color: 'var(--dp-text-primary)' }">
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
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
      @click.self="closeScheduleModal"
    >
      <div class="rounded-lg shadow-xl w-full max-w-lg" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
        <div class="flex items-center justify-between p-4 border-b" :style="{ borderColor: 'var(--dp-border-primary)' }">
          <h3 class="text-lg font-bold">팀 일정 저장</h3>
          <button
            @click="closeScheduleModal"
            class="p-1.5 rounded-full hover-close-btn cursor-pointer"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="p-4 space-y-4">
          <div>
            <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-primary)' }">
              제목(필수)
              <CharacterCounter :current="scheduleForm.content.length" :max="50" />
            </label>
            <input
              v-model="scheduleForm.content"
              type="text"
              maxlength="50"
              class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              :style="{
                backgroundColor: 'var(--dp-bg-input)',
                borderColor: 'var(--dp-border-input)',
                color: 'var(--dp-text-primary)'
              }"
              placeholder="일정 제목을 입력하세요"
            />
          </div>

          <div>
            <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-primary)' }">
              상세(옵션)
            </label>
            <textarea
              v-model="scheduleForm.description"
              rows="4"
              class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
              :style="{
                backgroundColor: 'var(--dp-bg-input)',
                borderColor: 'var(--dp-border-input)',
                color: 'var(--dp-text-primary)'
              }"
              placeholder="상세 내용을 입력하세요"
            ></textarea>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-primary)' }">
                시작일
              </label>
              <input
                v-model="scheduleForm.startDate"
                type="date"
                readonly
                class="w-full px-3 py-2 border rounded-lg"
                :style="{
                  backgroundColor: 'var(--dp-bg-tertiary)',
                  borderColor: 'var(--dp-border-input)',
                  color: 'var(--dp-text-primary)'
                }"
              />
            </div>
            <div>
              <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-primary)' }">
                종료일
              </label>
              <input
                v-model="scheduleForm.endDate"
                type="date"
                class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                :style="{
                  backgroundColor: 'var(--dp-bg-input)',
                  borderColor: 'var(--dp-border-input)',
                  color: 'var(--dp-text-primary)'
                }"
              />
            </div>
          </div>
        </div>

        <div class="flex justify-end gap-2 p-4 border-t" :style="{ borderColor: 'var(--dp-border-primary)' }">
          <button
            @click="saveSchedule"
            :disabled="saving || !scheduleForm.content.trim()"
            class="px-4 py-2 bg-blue-500 text-white rounded-lg font-medium hover:bg-blue-600 transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          >
            <Loader2 v-if="saving" class="w-4 h-4 animate-spin" />
            저장
          </button>
          <button
            @click="closeScheduleModal"
            class="px-4 py-2 rounded-lg font-medium hover-interactive cursor-pointer"
            :style="{
              backgroundColor: 'var(--dp-bg-tertiary)',
              color: 'var(--dp-text-primary)'
            }"
          >
            취소
          </button>
        </div>
      </div>
    </div>

    <YearMonthPicker
      :is-open="isYearMonthPickerOpen"
      :current-year="currentYear"
      :current-month="currentMonth"
      @close="isYearMonthPickerOpen = false"
      @select="handleYearMonthSelect"
      @go-to-this-month="goToToday(); isYearMonthPickerOpen = false"
    />
  </div>
</template>
