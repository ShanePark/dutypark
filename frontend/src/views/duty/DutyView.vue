<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import Swal from 'sweetalert2'
import { useSwal } from '@/composables/useSwal'
import { isLightColor } from '@/utils/color'
import {
  Plus,
  ClipboardList,
  ChevronLeft,
  ChevronRight,
  Search,
  Users,
  FileText,
  Star,
  Loader2,
  Lock,
  CalendarCheck,
  FileSpreadsheet,
  MessageSquareText,
} from 'lucide-vue-next'

// Modal Components
import DayDetailModal from '@/components/duty/DayDetailModal.vue'
import TodoAddModal from '@/components/duty/TodoAddModal.vue'
import TodoDetailModal from '@/components/duty/TodoDetailModal.vue'
import TodoOverviewModal from '@/components/duty/TodoOverviewModal.vue'
import DDayModal from '@/components/duty/DDayModal.vue'
import DDayDetailModal from '@/components/duty/DDayDetailModal.vue'
import SearchResultModal from '@/components/duty/SearchResultModal.vue'
import OtherDutiesModal from '@/components/duty/OtherDutiesModal.vue'
import ScheduleViewModal from '@/components/duty/ScheduleViewModal.vue'
import YearMonthPicker from '@/components/common/YearMonthPicker.vue'
import CalendarGrid from '@/components/common/CalendarGrid.vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'

// API
import { todoApi } from '@/api/todo'
import { dutyApi } from '@/api/duty'
import { ddayApi, memberApi, friendApi } from '@/api/member'
import { scheduleApi, type ScheduleDto, type ScheduleSearchResult } from '@/api/schedule'
import type { DutyCalendarDay, TeamDto, DDayDto, DDaySaveDto, CalendarVisibility, OtherDutyResponse, HolidayDto } from '@/types'

// Local interfaces for this view
interface LocalTodo {
  id: string
  title: string
  content: string
  status: 'ACTIVE' | 'COMPLETED'
  createdDate: string
  completedDate?: string
  hasAttachments: boolean
  attachments: Array<{
    id: string
    name: string
    originalFilename: string
    size: number
    contentType: string
    isImage: boolean
    hasThumbnail: boolean
    thumbnailUrl?: string
    downloadUrl: string
  }>
}

interface DutyType {
  id: number | null
  name: string
  color: string | null
  cnt?: number
}

// Schedule interface for UI display (converted from ScheduleDto)
interface Schedule {
  id: string
  content: string
  contentWithoutTime?: string
  description?: string
  startDateTime: string
  endDateTime: string
  visibility: CalendarVisibility
  isMine: boolean
  isTagged: boolean
  owner?: string
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
  daysFromStart: number
  totalDays: number
}

interface LocalDDay {
  id: number
  title: string
  date: string
  isPrivate: boolean
  calc: number
  dDayText: string
}

interface Friend {
  id: number
  name: string
}

interface CalendarDay {
  year: number
  month: number
  day: number
  isCurrentMonth?: boolean
  isPrev?: boolean
  isNext?: boolean
  isToday?: boolean
}

interface OtherDuty {
  memberId: number
  memberName: string
  duties: Array<{
    dutyType: string
    dutyColor: string
  }>
}

import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const authStore = useAuthStore()
const { showError, confirmDelete, toastSuccess } = useSwal()

// State
const today = new Date()
const currentYear = ref(today.getFullYear())
const currentMonth = ref(today.getMonth() + 1)
const memberName = ref('')
const memberHasProfilePhoto = ref(false)
const memberProfilePhotoVersion = ref(0)
const memberId = computed(() => {
  const paramId = route.params.id as string | undefined
  if (!paramId || paramId === 'me') {
    return authStore.user?.id ?? 0
  }
  return parseInt(paramId)
})
const teamId = ref<number | null>(null)

// isMyCalendar: true if viewing own calendar (no id param, or id matches logged-in user)
const isMyCalendar = computed(() => {
  const paramId = route.params.id as string | undefined
  if (!paramId || paramId === 'me') return true
  // Compare with logged-in user's ID
  const loggedInUserId = authStore.user?.id
  return loggedInUserId !== undefined && loggedInUserId === memberId.value
})
const amIManager = ref(false)

// canEdit: true if own calendar or manager of target member
const canEdit = computed(() => isMyCalendar.value || amIManager.value)

// canSearch: true if can search schedules (same as canEdit)
const canSearch = computed(() => isMyCalendar.value || amIManager.value)

// Loading states
const isLoading = ref(false)
const isLoadingDuties = ref(false)
const loadError = ref<string | null>(null)

// Edit mode states
const batchEditMode = ref(false)
const searchQuery = ref('')

// Modal states
const isDayDetailModalOpen = ref(false)
const isTodoAddModalOpen = ref(false)
const isTodoAddFromOverview = ref(false)
const isTodoDetailModalOpen = ref(false)
const startTodoEditMode = ref(false)
const isTodoOverviewModalOpen = ref(false)
const isDDayModalOpen = ref(false)
const isDDayDetailModalOpen = ref(false)
const isDDayEditFromDetail = ref(false)
const isSearchResultModalOpen = ref(false)
const isOtherDutiesModalOpen = ref(false)
const isScheduleDetailModalOpen = ref(false)

// Search highlight - tracks the date to highlight after search navigation
const searchDay = ref<{ year: number; month: number; day: number } | null>(null)
const isYearMonthPickerOpen = ref(false)

function handleYearMonthSelect(year: number, month: number) {
  searchDay.value = null // Clear search highlight when navigating
  currentYear.value = year
  currentMonth.value = month
  isYearMonthPickerOpen.value = false
}

// Selected items
const selectedDay = ref<CalendarDay | null>(null)
const selectedDayDuty = ref<{ dutyType: string; dutyColor: string } | undefined>(undefined)
const selectedTodo = ref<LocalTodo | null>(null)
const selectedDDay = ref<LocalDDay | null>(null)
const selectedSchedule = ref<Schedule | null>(null)
const pinnedDDay = ref<LocalDDay | null>(null)

// Data
const todos = ref<LocalTodo[]>([])
const completedTodos = ref<LocalTodo[]>([])
const isLoadingTodos = ref(false)

function handleTodoBubbleClick(todo: LocalTodo) {
  openTodoDetail(todo)
}

// Convert API Todo to LocalTodo
function mapToLocalTodo(apiTodo: { id: string; title: string; content: string; position: number | null; status: 'ACTIVE' | 'COMPLETED'; createdDate: string; completedDate: string | null }): LocalTodo {
  return {
    id: apiTodo.id,
    title: apiTodo.title,
    content: apiTodo.content,
    status: apiTodo.status,
    createdDate: apiTodo.createdDate,
    completedDate: apiTodo.completedDate ?? undefined,
    hasAttachments: false,
    attachments: [],
  }
}

// Convert API DDayDto to LocalDDay
function mapToLocalDDay(apiDDay: DDayDto): LocalDDay {
  const dDayText = apiDDay.calc === 0 ? 'D-Day' : apiDDay.calc < 0 ? `D+${Math.abs(apiDDay.calc)}` : `D-${apiDDay.calc}`
  return {
    id: apiDDay.id,
    title: apiDDay.title,
    date: apiDDay.date,
    isPrivate: apiDDay.isPrivate,
    calc: apiDDay.calc,
    dDayText,
  }
}

// Load todos from API
async function loadTodos() {
  if (!isMyCalendar.value) return

  isLoadingTodos.value = true
  try {
    const [activeTodos, completed] = await Promise.all([
      todoApi.getActiveTodos(),
      todoApi.getCompletedTodos(),
    ])
    todos.value = activeTodos.map(mapToLocalTodo)
    completedTodos.value = completed.map(mapToLocalTodo)
  } catch (error) {
    console.error('Failed to load todos:', error)
  } finally {
    isLoadingTodos.value = false
  }
}

// Sort D-Days by date ascending (same as backend: OrderByDate)
function sortDDays() {
  dDays.value.sort((a, b) => {
    return new Date(a.date).getTime() - new Date(b.date).getTime()
  })
}

// Load D-Days from API
async function loadDDays() {
  isLoadingDDays.value = true
  try {
    let apiDDays: DDayDto[]
    if (isMyCalendar.value) {
      apiDDays = (await ddayApi.getMyDDays()).data
    } else {
      apiDDays = (await ddayApi.getDDaysByMemberId(memberId.value)).data
    }
    dDays.value = apiDDays.map(mapToLocalDDay)
    // Sort D-Days after loading
    sortDDays()
  } catch (error) {
    console.error('Failed to load D-Days:', error)
  } finally {
    isLoadingDDays.value = false
  }
}

// Convert ScheduleDto to Schedule for UI
function mapToSchedule(dto: ScheduleDto): Schedule {
  return {
    id: dto.id,
    content: dto.content,
    contentWithoutTime: dto.content, // API doesn't provide this separately
    description: dto.description,
    startDateTime: dto.startDateTime,
    endDateTime: dto.endDateTime,
    visibility: dto.visibility || 'FRIENDS',
    isMine: !dto.isTagged,
    isTagged: dto.isTagged,
    owner: dto.owner,
    taggedBy: dto.isTagged ? dto.owner : undefined,
    attachments: dto.attachments.map((a) => ({
      id: a.id,
      originalFilename: a.originalFilename,
      contentType: a.contentType,
      size: a.size,
      thumbnailUrl: a.thumbnailUrl ?? undefined,
      hasThumbnail: a.hasThumbnail,
    })),
    tags: dto.tags.map((t) => ({ id: t.id ?? 0, name: t.name })),
    daysFromStart: dto.daysFromStart,
    totalDays: dto.totalDays,
  }
}

// Load schedules from API
const isLoadingSchedules = ref(false)

async function loadSchedules() {
  if (!memberId.value) return

  isLoadingSchedules.value = true
  try {
    const response = await scheduleApi.getSchedules(
      memberId.value,
      currentYear.value,
      currentMonth.value
    )
    // API returns array indexed by day (0 = day 1, etc.)
    // We need to map this to our calendarDays structure
    const schedulesMap = new Map<string, Schedule[]>()

    // Process each day's schedules from API response
    response.forEach((daySchedules) => {
      daySchedules.forEach((dto) => {
        // Create key from the date in the DTO
        const key = `${dto.year}-${dto.month}-${dto.dayOfMonth}`
        if (!schedulesMap.has(key)) {
          schedulesMap.set(key, [])
        }
        schedulesMap.get(key)!.push(mapToSchedule(dto))
      })
    })

    // Map to calendarDays structure
    schedulesByDays.value = calendarDays.value.map((day) => {
      const key = `${day.year}-${day.month}-${day.day}`
      return schedulesMap.get(key) || []
    })
  } catch (error) {
    console.error('Failed to load schedules:', error)
  } finally {
    isLoadingSchedules.value = false
  }
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

// Team and duty types from API
const team = ref<TeamDto | null>(null)
const dutyTypes = ref<DutyType[]>([])

// Raw duty data from API
const rawDuties = ref<DutyCalendarDay[]>([])

const dDays = ref<LocalDDay[]>([])
const isLoadingDDays = ref(false)

const friends = ref<Friend[]>([])
const isLoadingFriends = ref(false)

const selectedFriendIds = ref<number[]>([])
const showMyDuties = ref(false)

const otherDuties = ref<OtherDuty[]>([])

// Schedules by day index
const schedulesByDays = ref<Schedule[][]>([])

// Holidays by day index
const holidaysByDays = ref<HolidayDto[][]>([])

// Raw calendar days from backend API
const rawCalendarDays = ref<Array<{ year: number; month: number; day: number }>>([])

// Search results
const searchResults = ref<any[]>([])
const searchPageInfo = ref({
  pageNumber: 0,
  pageSize: 10,
  totalPages: 0,
  totalElements: 0,
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

// Generate calendar days from backend data with additional UI properties
const calendarDays = computed(() => {
  const today = new Date()

  return rawCalendarDays.value.map((raw) => {
    const isCurrentMonth = raw.year === currentYear.value && raw.month === currentMonth.value
    const isToday =
      raw.day === today.getDate() &&
      raw.month === today.getMonth() + 1 &&
      raw.year === today.getFullYear()

    return {
      year: raw.year,
      month: raw.month,
      day: raw.day,
      isCurrentMonth,
      isPrev: raw.month < currentMonth.value || (raw.month === 12 && currentMonth.value === 1),
      isNext: raw.month > currentMonth.value || (raw.month === 1 && currentMonth.value === 12),
      isToday,
    } as CalendarDay
  })
})

// Duties computed from raw API data
const duties = computed(() => {
  return calendarDays.value.map((day) => {
    // Find matching duty from raw data
    const duty = rawDuties.value.find(
      (d) => d.year === day.year && d.month === day.month && d.day === day.day
    )
    if (!duty) return null

    // Find duty type ID from name
    const dutyType = dutyTypes.value.find((dt) => dt.name === duty.dutyType)
    return {
      dutyType: duty.dutyType || 'OFF',
      dutyColor: duty.dutyColor || '#6c757d',
      dutyTypeId: dutyType?.id ?? null,
    }
  })
})

// Get duty color for CalendarGrid component
function getDutyColorForDay(day: CalendarDay): string | null {
  const idx = calendarDays.value.findIndex(
    (d) => d.year === day.year && d.month === day.month && d.day === day.day
  )
  return duties.value[idx]?.dutyColor ?? null
}

// Load team info and duty types
async function loadTeam() {
  if (!teamId.value) return

  try {
    team.value = await dutyApi.getTeam(teamId.value)
    // Map duty types from team
    dutyTypes.value = team.value.dutyTypes.map((dt) => ({
      id: dt.id,
      name: dt.name,
      color: dt.color,
      cnt: 0,
    }))
  } catch (error) {
    console.error('Failed to load team:', error)
  }
}

// Load duties from API
async function loadDuties() {
  if (!memberId.value) return

  isLoadingDuties.value = true
  try {
    rawDuties.value = await dutyApi.getDuties(
      memberId.value,
      currentYear.value,
      currentMonth.value
    )
    // Update duty counts
    updateDutyCounts()
  } catch (error) {
    console.error('Failed to load duties:', error)
    loadError.value = '근무 정보를 불러오는데 실패했습니다.'
  } finally {
    isLoadingDuties.value = false
  }
}

// Update duty type counts for the current month
function updateDutyCounts() {
  const daysInMonth = new Date(currentYear.value, currentMonth.value, 0).getDate()
  let offCount = daysInMonth

  // Reset all counts
  dutyTypes.value.forEach((dt) => {
    dt.cnt = 0
  })

  // Count duties for current month only
  rawDuties.value
    .filter((d) => d.month === currentMonth.value)
    .forEach((duty) => {
      const dutyType = dutyTypes.value.find((dt) => dt.id !== null && dt.name === duty.dutyType)
      if (dutyType) {
        dutyType.cnt = (dutyType.cnt || 0) + 1
        offCount--
      }
    })

  // Set OFF count (id === null)
  const offType = dutyTypes.value.find((dt) => dt.id === null)
  if (offType) {
    offType.cnt = offCount
  }
}

// Check if user can manage this member's duties
async function checkCanManage() {
  if (!authStore.user?.id || !memberId.value) return

  try {
    amIManager.value = await dutyApi.canManage(memberId.value)
  } catch (error) {
    console.error('Failed to check management permission:', error)
  }
}

// Load member info (for both own and friend's calendar)
async function loadMemberInfo() {
  try {
    if (isMyCalendar.value) {
      const response = await memberApi.getMyInfo()
      memberName.value = response.data.name
      teamId.value = response.data.teamId
      memberHasProfilePhoto.value = response.data.hasProfilePhoto ?? false
      memberProfilePhotoVersion.value = response.data.profilePhotoVersion ?? 0
    } else {
      const response = await memberApi.getMemberById(memberId.value)
      memberName.value = response.data.name
      teamId.value = response.data.teamId
      memberHasProfilePhoto.value = response.data.hasProfilePhoto ?? false
      memberProfilePhotoVersion.value = response.data.profilePhotoVersion ?? 0
    }
  } catch (error) {
    console.error('Failed to load member info:', error)
    // Fallback to auth store for own calendar
    if (isMyCalendar.value && authStore.user) {
      memberName.value = authStore.user.name
      teamId.value = authStore.user.teamId
      memberHasProfilePhoto.value = false
      memberProfilePhotoVersion.value = 0
    }
  }
}

// Initialize on mount
onMounted(async () => {
  isLoading.value = true
  loadError.value = null

  // Listen for "go to today" event from footer navigation
  window.addEventListener('duty-go-to-today', goToToday)

  try {
    // Load calendar structure first (needed for index alignment with holidays)
    await loadCalendar()

    // Load member info to get teamId
    await loadMemberInfo()

    // Load data in parallel
    await Promise.all([
      loadTodos(),
      loadDuties(),
      loadDDays(),
      loadSchedules(),
      loadFriends(),
      checkCanManage(),
      loadHolidays(),
    ])

    // Load team info for duty types
    if (teamId.value) {
      await loadTeam()
    }

    // Set pinned DDay from localStorage (after D-Days are loaded)
    const storedDDay = localStorage.getItem(`selectedDday_${memberId.value}`)
    if (storedDDay) {
      const id = parseInt(storedDDay)
      pinnedDDay.value = dDays.value.find((d) => d.id === id) || null
    }
  } catch (error) {
    console.error('Failed to initialize duty view:', error)
    loadError.value = '데이터를 불러오는데 실패했습니다.'
  } finally {
    isLoading.value = false
  }
})

// Cleanup on unmount
onUnmounted(() => {
  window.removeEventListener('duty-go-to-today', goToToday)
})

// Watch for month changes to reload data
watch(
  () => [currentYear.value, currentMonth.value],
  async () => {
    // Load calendar first to ensure index alignment
    await loadCalendar()
    await Promise.all([loadDuties(), loadSchedules(), loadOtherDuties(), loadHolidays()])
  }
)

// Watch for route params changes (when navigating between calendars)
watch(
  () => route.params.id,
  async () => {
    isLoading.value = true
    loadError.value = null

    // Reset state
    todos.value = []
    completedTodos.value = []
    dDays.value = []
    rawDuties.value = []
    schedulesByDays.value = []
    holidaysByDays.value = []
    rawCalendarDays.value = []
    dutyTypes.value = []
    team.value = null
    pinnedDDay.value = null
    friends.value = []
    selectedFriendIds.value = []
    showMyDuties.value = false
    otherDuties.value = []
    memberName.value = ''
    memberHasProfilePhoto.value = false
    memberProfilePhotoVersion.value = 0

    try {
      // Load calendar first to ensure index alignment
      await loadCalendar()
      await loadMemberInfo()
      await Promise.all([
        loadTodos(),
        loadDuties(),
        loadDDays(),
        loadSchedules(),
        loadFriends(),
        checkCanManage(),
        loadHolidays(),
      ])
      if (teamId.value) {
        await loadTeam()
      }
      // Restore pinned D-Day from localStorage
      const storedDDay = localStorage.getItem(`selectedDday_${memberId.value}`)
      if (storedDDay) {
        const id = parseInt(storedDDay)
        pinnedDDay.value = dDays.value.find((d) => d.id === id) || null
      }
    } catch (error) {
      console.error('Failed to reload duty view:', error)
      loadError.value = '데이터를 불러오는데 실패했습니다.'
    } finally {
      isLoading.value = false
    }
  }
)

// Navigation
function prevMonth() {
  searchDay.value = null // Clear search highlight when navigating
  if (currentMonth.value === 1) {
    currentMonth.value = 12
    currentYear.value--
  } else {
    currentMonth.value--
  }
}

function nextMonth() {
  searchDay.value = null // Clear search highlight when navigating
  if (currentMonth.value === 12) {
    currentMonth.value = 1
    currentYear.value++
  } else {
    currentMonth.value++
  }
}

function goToToday() {
  searchDay.value = null // Clear search highlight when navigating
  const today = new Date()
  currentYear.value = today.getFullYear()
  currentMonth.value = today.getMonth() + 1
}

// Day click handler
function handleDayClick(day: CalendarDay, index: number) {
  if (!canEdit.value) return // Disable click if no edit permission
  if (batchEditMode.value) return // In edit mode, clicks are handled by duty type buttons
  selectedDay.value = day
  selectedDayDuty.value = duties.value[index] || undefined
  isDayDetailModalOpen.value = true
}

// Schedule click handler (for read-only view on other's calendar)
function handleScheduleClick(schedule: Schedule, event: Event) {
  event.stopPropagation() // Prevent day click
  selectedSchedule.value = schedule
  isScheduleDetailModalOpen.value = true
}

// Batch edit mode: change duty type directly on cell
async function handleBatchDutyChange(day: CalendarDay, dutyTypeId: number | null) {
  if (!memberId.value) return
  if (!canEdit.value) return

  const { year, month, day: dayNum } = day

  try {
    await dutyApi.updateDuty(memberId.value, year, month, dayNum, dutyTypeId)
    await loadDuties()
  } catch (error) {
    console.error('Failed to change duty type:', error)
    showError('근무 변경에 실패했습니다.')
  }
}

// D-Day handlers
function togglePinnedDDay(dday: LocalDDay) {
  if (pinnedDDay.value?.id === dday.id) {
    pinnedDDay.value = null
    localStorage.removeItem(`selectedDday_${memberId.value}`)
  } else {
    pinnedDDay.value = dday
    localStorage.setItem(`selectedDday_${memberId.value}`, String(dday.id))
  }
}

function openDDayDetail(dday: LocalDDay) {
  selectedDDay.value = dday
  isDDayDetailModalOpen.value = true
}

function openDDayModal(dday?: LocalDDay) {
  selectedDDay.value = dday || null
  isDDayModalOpen.value = true
}

function handleDDayEdit(dday: LocalDDay) {
  isDDayDetailModalOpen.value = false
  isDDayEditFromDetail.value = true
  openDDayModal(dday)
}

async function handleDDayDeleteFromDetail(dday: LocalDDay) {
  isDDayDetailModalOpen.value = false
  await deleteDDay(dday)
}

function handleDDayTogglePin(dday: LocalDDay) {
  togglePinnedDDay(dday)
}

// Get D-Day badge class based on calc value
function getDDayBadgeClass(calc: number): string {
  if (calc === 0) {
    return 'dday-badge-today'
  } else if (calc < 0) {
    return 'dday-badge-past'
  } else if (calc === 1) {
    return 'dday-badge-upcoming-1'
  } else if (calc === 2) {
    return 'dday-badge-upcoming-2'
  } else if (calc === 3) {
    return 'dday-badge-upcoming-3'
  } else {
    return 'dday-badge-future'
  }
}

async function handleDDaySave(dday: { id?: number; title: string; date: string; isPrivate: boolean }) {
  try {
    const saveDto: DDaySaveDto = {
      id: dday.id,
      title: dday.title,
      date: dday.date,
      isPrivate: dday.isPrivate,
    }
    const savedDDay = (await ddayApi.saveDDay(saveDto)).data
    const localDDay = mapToLocalDDay(savedDDay)

    if (dday.id) {
      // Update existing in local list
      const idx = dDays.value.findIndex((d) => d.id === dday.id)
      if (idx >= 0) {
        dDays.value[idx] = localDDay
      }
      // Update pinned D-Day if it's the one being edited
      if (pinnedDDay.value?.id === dday.id) {
        pinnedDDay.value = localDDay
      }
      // Update selectedDDay for detail modal
      selectedDDay.value = localDDay
    } else {
      // Add new to local list
      dDays.value.push(localDDay)
    }
    // Re-sort after add/update
    sortDDays()
  } catch (error) {
    console.error('Failed to save D-Day:', error)
    showError('D-Day 저장에 실패했습니다.')
  }
  isDDayModalOpen.value = false
  // Return to detail modal if editing from there
  if (isDDayEditFromDetail.value) {
    isDDayDetailModalOpen.value = true
    isDDayEditFromDetail.value = false
  }
}

async function deleteDDay(dday: LocalDDay) {
  if (!await confirmDelete(`[${dday.title}]을(를) 정말로 삭제하시겠습니까?`)) return

  try {
    await ddayApi.deleteDDay(dday.id)
    dDays.value = dDays.value.filter((d) => d.id !== dday.id)
    if (pinnedDDay.value?.id === dday.id) {
      pinnedDDay.value = null
      localStorage.removeItem(`selectedDday_${memberId.value}`)
    }
  } catch (error) {
    console.error('Failed to delete D-Day:', error)
    showError('D-Day 삭제에 실패했습니다.')
  }
}

// Calculate D-Day for calendar cell (Korean style: D-Day = 1st day, next day = D+2)
function calcDDayForDay(day: CalendarDay) {
  if (!pinnedDDay.value) return null
  const [y, m, d] = pinnedDDay.value.date.split('-').map(Number) as [number, number, number]
  const targetDate = new Date(y, m - 1, d)
  const cellDate = new Date(day.year, day.month - 1, day.day)
  const diffDays = Math.floor((cellDate.getTime() - targetDate.getTime()) / (1000 * 60 * 60 * 24))
  if (diffDays === 0) return 'D-Day'
  return diffDays < 0 ? `D${diffDays}` : `D+${diffDays + 1}`
}

// Get D-Days that fall on a specific day
function getDDaysForDay(day: CalendarDay): LocalDDay[] {
  return dDays.value.filter((dday) => {
    const ddayDate = new Date(dday.date)
    return (
      ddayDate.getFullYear() === day.year &&
      ddayDate.getMonth() + 1 === day.month &&
      ddayDate.getDate() === day.day
    )
  })
}

// Todo handlers
function openTodoDetail(todo: LocalTodo) {
  selectedTodo.value = todo
  isTodoDetailModalOpen.value = true
}

async function handleTodoUpdate(data: {
  id: string
  title: string
  content: string
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}) {
  try {
    const updatedTodo = await todoApi.updateTodo(data.id, {
      title: data.title,
      content: data.content,
      attachmentSessionId: data.attachmentSessionId,
      orderedAttachmentIds: data.orderedAttachmentIds,
    })
    const localTodo = mapToLocalTodo(updatedTodo)
    const idx = todos.value.findIndex((t) => t.id === data.id)
    if (idx >= 0) {
      todos.value[idx] = localTodo
    }
    // Update selectedTodo for the detail modal
    selectedTodo.value = localTodo
    toastSuccess('할 일이 수정되었습니다.')
  } catch (error) {
    console.error('Failed to update todo:', error)
    showError('할 일 수정에 실패했습니다.')
  }
}

async function handleTodoComplete(id: string) {
  const fromDetailModal = isTodoDetailModalOpen.value
  try {
    const completedTodo = await todoApi.completeTodo(id)
    todos.value = todos.value.filter((t) => t.id !== id)
    completedTodos.value.unshift(mapToLocalTodo(completedTodo))
  } catch (error) {
    console.error('Failed to complete todo:', error)
    showError('할 일 완료 처리에 실패했습니다.')
  }
  // Only close detail modal and return to overview if called from detail modal
  if (fromDetailModal) {
    isTodoDetailModalOpen.value = false
  }
}

async function handleTodoReopen(id: string) {
  const fromDetailModal = isTodoDetailModalOpen.value
  try {
    const reopenedTodo = await todoApi.reopenTodo(id)
    completedTodos.value = completedTodos.value.filter((t) => t.id !== id)
    todos.value.push(mapToLocalTodo(reopenedTodo))
  } catch (error) {
    console.error('Failed to reopen todo:', error)
    showError('할 일 재오픈에 실패했습니다.')
  }
  // Only close detail modal if called from detail modal
  if (fromDetailModal) {
    isTodoDetailModalOpen.value = false
  }
}

async function handleTodoDelete(id: string) {
  if (!await confirmDelete('할 일을 삭제하시겠습니까?')) return
  const fromDetailModal = isTodoDetailModalOpen.value
  try {
    await todoApi.deleteTodo(id)
    todos.value = todos.value.filter((t) => t.id !== id)
    completedTodos.value = completedTodos.value.filter((t) => t.id !== id)
  } catch (error) {
    console.error('Failed to delete todo:', error)
    showError('할 일 삭제에 실패했습니다.')
  }
  // Only close detail modal if called from detail modal
  if (fromDetailModal) {
    isTodoDetailModalOpen.value = false
  }
}

async function handleTodoAdd(data: {
  title: string
  content: string
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}) {
  try {
    const newTodo = await todoApi.createTodo({
      title: data.title,
      content: data.content,
      attachmentSessionId: data.attachmentSessionId,
      orderedAttachmentIds: data.orderedAttachmentIds,
    })
    todos.value.unshift(mapToLocalTodo(newTodo))
    toastSuccess('할 일이 추가되었습니다.')
  } catch (error) {
    console.error('Failed to add todo:', error)
    showError('할 일 추가에 실패했습니다.')
  }
  isTodoAddModalOpen.value = false
  // Only return to overview modal if added from overview
  if (isTodoAddFromOverview.value) {
    isTodoOverviewModalOpen.value = true
    isTodoAddFromOverview.value = false
  }
}

// Todo position update for drag-and-drop
async function handleTodoPositionUpdate(orderedIds: string[]) {
  try {
    await todoApi.updatePositions(orderedIds)
    // Reorder local todos array to match the new order
    const todoMap = new Map(todos.value.map((t) => [t.id, t]))
    todos.value = orderedIds.map((id) => todoMap.get(id)).filter((t): t is LocalTodo => t !== undefined)
  } catch (error) {
    console.error('Failed to update todo positions:', error)
    showError('할 일 순서 변경에 실패했습니다.')
    // Reload todos to restore correct order
    await loadTodos()
  }
}

// Search handler
const isSearching = ref(false)

function openSearchModal() {
  // Open modal without searching - user can enter query in modal
  isSearchResultModalOpen.value = true
}

async function handleSearch(page: number = 0) {
  if (!searchQuery.value.trim() || !memberId.value) return

  isSearching.value = true
  try {
    const response = await scheduleApi.searchSchedules(
      memberId.value,
      searchQuery.value.trim(),
      page,
      searchPageInfo.value.pageSize
    )
    searchResults.value = response.content.map((result) => ({
      id: result.id,
      content: result.content,
      description: result.description,
      startDateTime: result.startDateTime,
      endDateTime: result.endDateTime,
      hasAttachments: result.hasAttachments,
    }))
    searchPageInfo.value = {
      pageNumber: response.number,
      pageSize: response.size,
      totalPages: response.totalPages,
      totalElements: response.totalElements,
    }
    isSearchResultModalOpen.value = true
  } catch (error) {
    console.error('Failed to search schedules:', error)
    showError('검색에 실패했습니다.')
  } finally {
    isSearching.value = false
  }
}

function handleSearchPageChange(page: number) {
  handleSearch(page)
}

function handleSearchFromModal(query: string) {
  searchQuery.value = query
  handleSearch(0)
}

function handleSearchGoToDate(result: any) {
  const date = new Date(result.startDateTime)
  currentYear.value = date.getFullYear()
  currentMonth.value = date.getMonth() + 1
  // Set searchDay to highlight the selected date on the calendar
  searchDay.value = {
    year: date.getFullYear(),
    month: date.getMonth() + 1,
    day: date.getDate(),
  }
  isSearchResultModalOpen.value = false
}

// Other duties (view together)
async function handleFriendToggle(friendId: number) {
  const idx = selectedFriendIds.value.indexOf(friendId)
  if (idx >= 0) {
    selectedFriendIds.value.splice(idx, 1)
  } else {
    selectedFriendIds.value.push(friendId)
  }
  await loadOtherDuties()
}

async function handleMyDutiesToggle() {
  showMyDuties.value = !showMyDuties.value
  await loadOtherDuties()
}

async function handleToggleOtherDuties() {
  if (isMyCalendar.value) {
    // My calendar: open friend selection modal
    isOtherDutiesModalOpen.value = true
  } else {
    // Other's calendar: toggle my duties directly
    await handleMyDutiesToggle()
  }
}

async function loadOtherDuties() {
  // Build list of member IDs to fetch
  const memberIdsToFetch = [...selectedFriendIds.value]
  // Add logged-in user ID when "show my duties" is enabled on other's calendar
  if (showMyDuties.value && authStore.user?.id) {
    memberIdsToFetch.push(authStore.user.id)
  }

  if (memberIdsToFetch.length === 0) {
    otherDuties.value = []
    return
  }

  try {
    const response = await dutyApi.getOtherDuties(
      memberIdsToFetch,
      currentYear.value,
      currentMonth.value
    )
    // Map API response to local OtherDuty format (index-aligned with calendarDays)
    otherDuties.value = response.map((item, index) => ({
      memberId: memberIdsToFetch[index] || 0,
      memberName: item.name,
      duties: item.duties.map((d) => ({
        dutyType: d.dutyType || 'OFF',
        dutyColor: d.dutyColor || '#6c757d',
      })),
    }))
  } catch (error) {
    console.error('Failed to load other duties:', error)
    showError('친구 근무 정보를 불러오는데 실패했습니다.')
  }
}

// Load friends list
async function loadFriends() {
  if (!isMyCalendar.value) return

  isLoadingFriends.value = true
  try {
    const response = await friendApi.getFriends()
    friends.value = response.data.map((f) => ({
      id: f.id ?? 0,
      name: f.name,
    }))
  } catch (error) {
    console.error('Failed to load friends:', error)
  } finally {
    isLoadingFriends.value = false
  }
}

// Schedule handlers
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

async function handleCreateSchedule(data: ScheduleSaveData) {
  if (!memberId.value) return

  try {
    await scheduleApi.saveSchedule({
      memberId: memberId.value,
      content: data.content,
      description: data.description || undefined,
      startDateTime: data.startDateTime,
      endDateTime: data.endDateTime,
      visibility: data.visibility,
      attachmentSessionId: data.attachmentSessionId || undefined,
      orderedAttachmentIds: data.orderedAttachmentIds,
    })
    await loadSchedules()
    toastSuccess('일정이 추가되었습니다.')
  } catch (error) {
    console.error('Failed to create schedule:', error)
    showError('일정 생성에 실패했습니다.')
  }
}

async function handleEditSchedule(data: ScheduleSaveData) {
  if (!memberId.value || !data.id) return

  try {
    await scheduleApi.saveSchedule({
      id: data.id,
      memberId: memberId.value,
      content: data.content,
      description: data.description || undefined,
      startDateTime: data.startDateTime,
      endDateTime: data.endDateTime,
      visibility: data.visibility,
      attachmentSessionId: data.attachmentSessionId || undefined,
      orderedAttachmentIds: data.orderedAttachmentIds,
    })
    await loadSchedules()
    toastSuccess('일정이 수정되었습니다.')
  } catch (error) {
    console.error('Failed to update schedule:', error)
    showError('일정 수정에 실패했습니다.')
  }
}

async function handleDeleteSchedule(scheduleId: string) {
  if (!await confirmDelete('이 일정을 삭제하시겠습니까?')) return

  try {
    await scheduleApi.deleteSchedule(scheduleId)
    await loadSchedules()
    toastSuccess('일정이 삭제되었습니다.')
  } catch (error) {
    console.error('Failed to delete schedule:', error)
    showError('일정 삭제에 실패했습니다.')
  }
}

async function handleReorderSchedules(scheduleIds: string[]) {
  try {
    await scheduleApi.reorderSchedulePositions(scheduleIds)
    await loadSchedules()
    toastSuccess('일정 순서가 변경되었습니다.')
  } catch (error) {
    console.error('Failed to reorder schedules:', error)
    showError('일정 순서 변경에 실패했습니다.')
  }
}

async function handleAddTag(scheduleId: string, friendId: number) {
  try {
    await scheduleApi.tagFriend(scheduleId, friendId)
    await loadSchedules()
  } catch (error) {
    console.error('Failed to add tag:', error)
    showError('태그 추가에 실패했습니다.')
  }
}

async function handleRemoveTag(scheduleId: string, friendId: number) {
  try {
    await scheduleApi.untagFriend(scheduleId, friendId)
    await loadSchedules()
  } catch (error) {
    console.error('Failed to remove tag:', error)
    showError('태그 삭제에 실패했습니다.')
  }
}

async function handleUntagSelf(scheduleId: string) {
  try {
    await scheduleApi.untagSelf(scheduleId)
    await loadSchedules()
    toastSuccess('태그가 해제되었습니다.')
  } catch (error) {
    console.error('Failed to untag self:', error)
    showError('태그 해제에 실패했습니다.')
  }
}

async function handleChangeDutyType(dutyTypeId: number | null) {
  if (!memberId.value || !selectedDay.value) return
  // Allow if viewing own calendar OR if user has manager permission
  if (!isMyCalendar.value && !amIManager.value) return

  const { year, month, day } = selectedDay.value

  try {
    await dutyApi.updateDuty(memberId.value, year, month, day, dutyTypeId)
    await loadDuties()
  } catch (error) {
    console.error('Failed to change duty type:', error)
    showError('근무 변경에 실패했습니다.')
  }
}

// Get schedule time display - show start time on first day, end time on last day
function formatScheduleTime(schedule: Schedule) {
  const start = new Date(schedule.startDateTime)
  const end = new Date(schedule.endDateTime)
  const startHour = start.getHours().toString().padStart(2, '0')
  const startMin = start.getMinutes().toString().padStart(2, '0')
  const endHour = end.getHours().toString().padStart(2, '0')
  const endMin = end.getMinutes().toString().padStart(2, '0')

  const isStartMidnight = startHour === '00' && startMin === '00'
  const isEndMidnight = endHour === '00' && endMin === '00'
  const isSameDateTime = start.getTime() === end.getTime()

  const showStartTime = schedule.daysFromStart === 1 && !isStartMidnight
  const showEndTime = schedule.daysFromStart === schedule.totalDays &&
    !isEndMidnight &&
    !(schedule.totalDays === 1 && isSameDateTime)

  if (showStartTime && showEndTime) {
    return `(${startHour}:${startMin}~${endHour}:${endMin})`
  }
  if (showStartTime) {
    return `(${startHour}:${startMin})`
  }
  if (showEndTime) {
    return `(~${endHour}:${endMin})`
  }
  return ''
}

// Batch update modal - update all days in current month to a single duty type
async function showBatchUpdateModal() {
  if (!memberId.value || dutyTypes.value.length === 0) return

  const buttonsHtml = dutyTypes.value
    .map((dt) => {
      const textColor = isLightColor(dt.color) ? '#000' : '#fff'
      return `<button class="swal2-styled duty-type-btn" style="background-color: ${dt.color || '#6c757d'}; color: ${textColor}; margin: 4px;" data-id="${dt.id}">${dt.name}</button>`
    })
    .join('')

  const result = await Swal.fire({
    title: '한번에 수정',
    html: `
      <p>${currentYear.value}년 ${currentMonth.value}월의 기본 근무를 선택해주세요.</p>
      <p>현재 월의 모든 날짜가 선택한 근무로 설정됩니다.</p>
      <p class="text-sm text-orange-600 font-semibold mt-2">클릭시 바로 변경됩니다.</p>
      <div class="mt-4">${buttonsHtml}</div>
    `,
    showConfirmButton: false,
    showCancelButton: true,
    cancelButtonText: '취소',
    didOpen: () => {
      const buttons = document.querySelectorAll('.duty-type-btn')
      buttons.forEach((button) => {
        button.addEventListener('click', async () => {
          const dutyTypeId = button.getAttribute('data-id')
          Swal.close()
          try {
            await dutyApi.batchUpdateDuty(
              memberId.value,
              currentYear.value,
              currentMonth.value,
              dutyTypeId ? parseInt(dutyTypeId) : null
            )
            await loadDuties()
          } catch (error) {
            console.error('Failed to batch update duties:', error)
            showError('일괄 수정에 실패했습니다.')
          }
        })
      })
    },
  })
}

// Excel upload modal
async function showExcelUploadModal() {
  if (!memberId.value || !team.value?.dutyBatchTemplate) return

  const fileExtensions = team.value.dutyBatchTemplate.fileExtensions || ['.xlsx', '.xls']

  const { value: file } = await Swal.fire({
    title: '시간표 파일 업로드',
    input: 'file',
    html: `시간표 파일을 업로드해주세요.<br/>자동으로 파일에 맞춰 시간표를 업데이트 합니다.<br/><span class="text-orange-600 font-semibold">업로드하는 시간표가 ${currentYear.value}년 ${currentMonth.value}월에 맞는지 꼭 확인해주세요.</span>`,
    inputAttributes: {
      accept: fileExtensions.join(','),
      'aria-label': '시간표 파일을 업로드해주세요.',
    },
    confirmButtonText: '등록',
    showCancelButton: true,
    cancelButtonText: '취소',
  })

  if (!file) return

  try {
    const result = await dutyApi.uploadDutyBatch(
      memberId.value,
      currentYear.value,
      currentMonth.value,
      file
    )

    if (!result.result) {
      showError(result.errorMessage || '파일 업로드에 실패했습니다.', '시간표 파일 업로드 실패')
      return
    }

    await Swal.fire({
      icon: 'success',
      title: '시간표 적용 완료',
      html: `시간표가 업로드 되었습니다.<br/>[${result.startDate}] ~ [${result.endDate}]<br/>총 ${result.workingDays + result.offDays}일 중 근무일은 ${result.workingDays}, 휴무일은 ${result.offDays}일 입니다.`,
      confirmButtonText: '확인',
    })

    await loadDuties()
  } catch (error) {
    console.error('Failed to upload duty batch:', error)
    showError('파일 업로드에 실패했습니다.')
  }
}
</script>

<template>
  <div class="max-w-4xl mx-auto px-2 sm:px-4 py-4">
    <!-- Loading State -->
    <div v-if="isLoading" class="flex items-center justify-center py-20">
      <Loader2 class="w-8 h-8 text-blue-500 animate-spin" />
      <span class="ml-2" :style="{ color: 'var(--dp-text-secondary)' }">데이터를 불러오는 중...</span>
    </div>

    <!-- Error State -->
    <div v-else-if="loadError" class="border rounded-lg p-4 mb-4" :style="{ backgroundColor: '#fef2f2', borderColor: '#fecaca' }">
      <p class="text-red-700">{{ loadError }}</p>
      <button
        @click="loadDuties"
        class="mt-2 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 transition cursor-pointer"
      >
        다시 시도
      </button>
    </div>

    <!-- Main Content -->
    <template v-else>
    <!-- Header: Profile + Year-Month (centered) + Search -->
    <div class="grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center mb-2 px-1 gap-1">
      <!-- Left: Profile Photo + Name -->
      <div class="flex items-center gap-1.5 min-w-0">
        <!-- Profile Photo (smaller on mobile) -->
        <ProfileAvatar :member-id="memberId" :has-profile-photo="memberHasProfilePhoto" :profile-photo-version="memberProfilePhotoVersion" size="lg" class="flex-shrink-0 sm:hidden" :name="memberName" />
        <ProfileAvatar :member-id="memberId" :has-profile-photo="memberHasProfilePhoto" :profile-photo-version="memberProfilePhotoVersion" size="xl" class="flex-shrink-0 hidden sm:block" :name="memberName" />
        <!-- Name -->
        <span
          class="text-xs sm:text-sm font-semibold truncate"
          :style="{ color: 'var(--dp-text-primary)' }"
        >{{ memberName }}</span>
      </div>

      <!-- Center: Year-Month Navigation -->
      <div class="flex items-center justify-center">
        <button @click="prevMonth" class="calendar-nav-btn p-0.5 sm:p-2 rounded-full flex items-center justify-center flex-shrink-0 cursor-pointer">
          <ChevronLeft class="w-5 h-5 sm:w-6 sm:h-6" />
        </button>
        <button
          @click="isYearMonthPickerOpen = true"
          class="calendar-nav-btn px-1 sm:px-3 py-1 text-lg sm:text-2xl font-semibold rounded whitespace-nowrap cursor-pointer"
        >
          {{ currentYear }}-{{ String(currentMonth).padStart(2, '0') }}
        </button>
        <button @click="nextMonth" class="calendar-nav-btn p-0.5 sm:p-2 rounded-full flex items-center justify-center flex-shrink-0 cursor-pointer">
          <ChevronRight class="w-5 h-5 sm:w-6 sm:h-6" />
        </button>
      </div>

      <!-- Right: Search -->
      <div class="flex justify-end">
        <div v-if="canSearch" class="flex items-stretch rounded-lg border overflow-hidden" :style="{ borderColor: 'var(--dp-border-secondary)' }">
          <input
            v-model="searchQuery"
            type="text"
            placeholder="검색"
            @keyup.enter="handleSearch()"
            class="px-2 py-1.5 text-sm focus:ring-2 focus:ring-blue-500 focus:outline-none w-12 sm:w-20 border-none"
            :style="{ backgroundColor: 'var(--dp-bg-input)', color: 'var(--dp-text-primary)' }"
          />
          <button
            @click="searchQuery.trim() ? handleSearch() : openSearchModal()"
            class="px-2 py-1.5 bg-gray-800 text-white hover:bg-gray-700 transition flex items-center justify-center cursor-pointer"
          >
            <Search class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>

    <!-- Todo row (only for my calendar) -->
    <div v-if="isMyCalendar" class="flex items-center gap-1.5 mb-1 px-1">
      <!-- Button Group: List + Add -->
      <div class="flex-shrink-0 inline-flex rounded-lg border overflow-hidden" :style="{ borderColor: 'var(--dp-border-secondary)' }">
        <!-- Todo List Button -->
        <button
          @click="isTodoOverviewModalOpen = true"
          class="todo-btn-list h-7 px-2.5 flex items-center gap-1.5 transition-all duration-150 cursor-pointer"
          :style="{ backgroundColor: 'var(--dp-bg-card)' }"
        >
          <ClipboardList class="w-3.5 h-3.5 transition-colors" :style="{ color: 'var(--dp-text-muted)' }" />
          <span class="text-xs font-medium transition-colors" :style="{ color: 'var(--dp-text-secondary)' }">{{ todos.length }}</span>
        </button>
        <!-- Add Todo Button -->
        <button
          @click="isTodoAddModalOpen = true"
          class="todo-btn-add h-7 px-2 flex items-center justify-center transition-all duration-150 cursor-pointer border-l"
          :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-secondary)', color: 'var(--dp-text-secondary)' }"
        >
          <Plus class="w-4 h-4" />
        </button>
      </div>

      <!-- Todo Items -->
      <div class="flex-1 min-w-0 overflow-x-auto scrollbar-hide py-0.5">
        <div class="flex gap-1.5">
          <button
            v-for="todo in todos"
            :key="todo.id"
            @click="handleTodoBubbleClick(todo)"
            class="todo-item-bubble flex-shrink-0 max-w-[120px] sm:max-w-[160px] flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11px] sm:text-xs cursor-pointer transition-all duration-150 border"
            :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-secondary)', color: 'var(--dp-text-primary)' }"
          >
            <span class="truncate">{{ todo.title }}</span>
            <FileText v-if="todo.content || todo.hasAttachments" class="w-2.5 h-2.5 flex-shrink-0" :style="{ color: 'var(--dp-text-muted)' }" />
          </button>
        </div>
      </div>
    </div>

    <!-- Duty Types & Buttons -->
    <div class="flex flex-wrap items-center justify-between gap-1 mb-1.5">
      <div class="flex flex-wrap items-center gap-2 sm:gap-4">
        <template v-if="dutyTypes.length > 0">
          <div v-for="dutyType in dutyTypes" :key="dutyType.name" class="flex items-center gap-1">
            <span
              class="w-4 h-4 rounded border-2"
              :style="{ backgroundColor: dutyType.color || '#6c757d', borderColor: 'var(--dp-border-primary)' }"
            ></span>
            <span class="text-xs sm:text-sm" :style="{ color: 'var(--dp-text-secondary)' }">{{ dutyType.name }}</span>
            <span class="text-xs sm:text-sm font-bold" :style="{ color: 'var(--dp-text-primary)' }">{{ dutyType.cnt }}</span>
          </div>
        </template>
        <span v-else-if="isLoadingDuties" class="text-sm" :style="{ color: 'var(--dp-text-muted)' }">
          <Loader2 class="w-4 h-4 animate-spin inline mr-1" />
          로딩 중...
        </span>
        <span v-else class="text-sm" :style="{ color: 'var(--dp-text-muted)' }">
          근무 타입 정보 없음
        </span>
      </div>
      <div class="inline-flex rounded-lg border overflow-hidden" :style="{ borderColor: 'var(--dp-border-secondary)' }">
        <button
          v-if="!batchEditMode"
          @click="handleToggleOtherDuties"
          class="px-2 sm:px-3 py-1.5 min-h-[36px] text-xs sm:text-sm transition-colors duration-150 flex items-center gap-1 border-r cursor-pointer"
          :style="{ borderColor: 'var(--dp-border-secondary)' }"
          :class="(selectedFriendIds.length > 0 || showMyDuties) ? 'bg-blue-50/70 text-blue-700 hover:bg-blue-50' : 'hover:bg-gray-500/10 dark:hover:bg-gray-400/10'"
        >
          <Users class="w-4 h-4" />
          <span class="hidden xs:inline">함께보기</span>
          <span v-if="selectedFriendIds.length > 0 || showMyDuties" class="text-xs">
            ({{ selectedFriendIds.length + (showMyDuties ? 1 : 0) }})
          </span>
        </button>
        <button
          v-if="canEdit && isMyCalendar && batchEditMode"
          @click="showBatchUpdateModal"
          class="px-2 sm:px-3 py-1.5 min-h-[36px] text-xs sm:text-sm transition-colors duration-150 border-r cursor-pointer hover:bg-gray-500/10 dark:hover:bg-gray-400/10"
          :style="{ borderColor: 'var(--dp-border-secondary)' }"
        >
          일괄수정
        </button>
        <button
          v-if="canEdit"
          @click="batchEditMode = !batchEditMode"
          class="px-2 sm:px-3 py-1.5 min-h-[36px] text-xs sm:text-sm transition-colors duration-150 border-r last:border-r-0 cursor-pointer"
          :style="{ borderColor: 'var(--dp-border-secondary)' }"
          :class="batchEditMode ? 'bg-orange-50/70 text-orange-700 hover:bg-orange-50' : 'hover:bg-gray-500/10 dark:hover:bg-gray-400/10'"
        >
          편집모드
        </button>
        <button
          v-if="canEdit && isMyCalendar && team?.dutyBatchTemplate && !batchEditMode"
          @click="showExcelUploadModal"
          class="px-2 sm:px-3 py-1.5 min-h-[36px] text-xs sm:text-sm transition-colors duration-150 flex items-center gap-1 cursor-pointer hover:bg-gray-500/10 dark:hover:bg-gray-400/10"
        >
          <FileSpreadsheet class="w-4 h-4" />
          <span class="hidden sm:inline">엑셀</span>
        </button>
      </div>
    </div>

    <!-- Calendar Grid -->
    <CalendarGrid
      :days="calendarDays"
      :current-year="currentYear"
      :current-month="currentMonth"
      :holidays="batchEditMode ? [] : holidaysByDays"
      :get-duty-color="getDutyColorForDay"
      :highlight-day="searchDay"
      @day-click="handleDayClick"
    >
      <!-- D-Day indicator in header -->
      <template #day-header="{ day, index }">
        <span
          v-if="pinnedDDay && !batchEditMode"
          class="text-[9px] sm:text-xs"
          :style="{ color: duties[index]?.dutyColor ? (isLightColor(duties[index]?.dutyColor) ? '#6b7280' : 'rgba(255,255,255,0.7)') : 'var(--dp-text-muted)' }"
        >
          {{ calcDDayForDay(day) }}
        </span>
      </template>

      <!-- Day content slot -->
      <template #day-content="{ day, index }">
        <!-- Batch Edit Mode: Duty Type Buttons -->
        <div v-if="batchEditMode && day.isCurrentMonth" class="mt-1 grid grid-cols-2 gap-0.5">
          <button
            v-for="dutyType in dutyTypes"
            :key="dutyType.id ?? 'off'"
            @click.stop="handleBatchDutyChange(day, dutyType.id)"
            class="text-[10px] sm:text-xs px-1 py-1 rounded border transition-all min-h-[22px] sm:min-h-[26px] cursor-pointer"
            :class="{
              'ring-2 ring-gray-800 font-bold shadow-sm':
                (duties[index]?.dutyType === dutyType.name) ||
                (!duties[index]?.dutyType && dutyType.id === null),
              'hover:opacity-80': true,
            }"
            :style="{
              backgroundColor: dutyType.color || '#6c757d',
              color: isLightColor(dutyType.color) ? '#000' : '#fff',
              borderColor: dutyType.color || '#6c757d',
            }"
          >
            <span class="sm:hidden">{{ dutyType.name.charAt(0) }}</span>
            <span class="hidden sm:inline">{{ dutyType.name.length > 4 ? dutyType.name.substring(0, 4) : dutyType.name }}</span>
          </button>
        </div>

        <div v-if="!batchEditMode" class="mt-0.5">
          <!-- Other duties -->
          <div v-if="otherDuties.length > 0" class="flex flex-wrap justify-center gap-1 mb-1">
            <div
              v-for="otherDuty in otherDuties"
              :key="otherDuty.memberId"
              class="text-[10px] sm:text-sm px-1.5 py-0.5 rounded-full border border-white/50"
              :style="{
                backgroundColor: otherDuty.duties[index]?.dutyColor || '#6c757d',
                color: isLightColor(otherDuty.duties[index]?.dutyColor) ? '#000' : '#fff',
              }"
            >
              {{ otherDuty.memberName }}<template v-if="otherDuty.duties[index]?.dutyType">:{{ otherDuty.duties[index].dutyType.slice(0, 4) }}</template>
            </div>
          </div>

          <!-- D-Days -->
          <div
            v-for="dday in getDDaysForDay(day)"
            :key="dday.id"
            class="text-[10px] sm:text-sm leading-snug px-0.5 break-words"
            :style="{ color: duties[index]?.dutyColor ? (isLightColor(duties[index]?.dutyColor) ? '#1f2937' : '#ffffff') : 'var(--dp-text-primary)' }"
          ><CalendarCheck class="w-2.5 h-2.5 sm:w-3.5 sm:h-3.5 inline align-[-1px] sm:align-[-2px]" />{{ dday.title }}</div>

          <!-- Schedules -->
          <div
            v-for="schedule in schedulesByDays[index]?.slice(0, 3)"
            :key="schedule.id"
            class="text-[10px] sm:text-sm leading-snug px-0.5 border-t-2 border-dashed break-words"
            :class="{ 'cursor-pointer hover:underline': !canEdit && (schedule.description || schedule.attachments?.length) }"
            :style="{ color: duties[index]?.dutyColor ? (isLightColor(duties[index]?.dutyColor) ? '#1f2937' : '#ffffff') : 'var(--dp-text-primary)', borderColor: duties[index]?.dutyColor ? (isLightColor(duties[index]?.dutyColor) ? 'rgba(0,0,0,0.15)' : 'rgba(255,255,255,0.3)') : 'var(--dp-border-primary)' }"
            @click="!canEdit && (schedule.description || schedule.attachments?.length) ? handleScheduleClick(schedule, $event) : null"
          ><Lock v-if="schedule.visibility === 'PRIVATE'" class="w-2.5 h-2.5 sm:w-3.5 sm:h-3.5 inline align-[-1px] sm:align-[-2px]" :style="{ color: duties[index]?.dutyColor ? (isLightColor(duties[index]?.dutyColor) ? '#6b7280' : 'rgba(255,255,255,0.7)') : 'var(--dp-text-muted)' }" />{{ schedule.contentWithoutTime || schedule.content }}{{ formatScheduleTime(schedule) }}<template v-if="schedule.totalDays > 1">({{ schedule.daysFromStart }}/{{ schedule.totalDays }})</template><MessageSquareText
              v-if="schedule.description || schedule.attachments?.length"
              class="w-2.5 h-2.5 sm:w-3 sm:h-3 inline align-[-1px] sm:align-[-2px] ml-0.5"
              :style="{ color: duties[index]?.dutyColor ? (isLightColor(duties[index]?.dutyColor) ? '#000000' : '#ffffff') : 'var(--dp-text-primary)' }"
            />
            <!-- Tags display -->
            <div v-if="schedule.tags?.length || schedule.isTagged" class="flex flex-wrap gap-0.5 justify-end">
              <span
                v-for="tag in schedule.tags?.filter(t => t.id !== memberId)"
                :key="tag.id"
                class="schedule-tag"
              >{{ tag.name }}</span>
              <span
                v-if="schedule.isTagged"
                class="schedule-tag"
              ><span class="text-[6px] sm:text-[10px]">by</span> {{ schedule.owner }}</span>
            </div>
          </div>
          <div
            v-if="(schedulesByDays[index]?.length ?? 0) > 3"
            class="text-[10px] font-medium"
            :style="{ color: duties[index]?.dutyColor ? (isLightColor(duties[index]?.dutyColor) ? '#6b7280' : 'rgba(255,255,255,0.8)') : 'var(--dp-text-muted)' }"
          >
            +{{ (schedulesByDays[index]?.length ?? 0) - 3 }}
          </div>
        </div>
      </template>
    </CalendarGrid>

    <!-- D-Day List -->
    <div class="grid grid-cols-2 lg:grid-cols-3 gap-2 sm:gap-3">
      <div
        v-for="dday in dDays"
        :key="dday.id"
        class="relative overflow-hidden rounded-xl sm:rounded-2xl cursor-pointer transition-all duration-300 hover:scale-[1.02] hover:shadow-lg border"
        :class="[
          pinnedDDay?.id === dday.id
            ? 'ring-2 ring-amber-400 shadow-md'
            : 'shadow-sm',
          dday.calc <= 0
            ? 'dday-card-past'
            : 'dday-card-future'
        ]"
        @click="openDDayDetail(dday)"
      >
        <div class="p-2.5 sm:p-4">
          <!-- D-Day badge and pin star -->
          <div class="flex justify-between items-start mb-2 sm:mb-3">
            <div
              class="inline-flex items-center px-2 py-1 sm:px-3 sm:py-1.5 rounded-full text-xs sm:text-sm font-bold shadow-sm"
              :class="getDDayBadgeClass(dday.calc)"
            >
              {{ dday.dDayText }}
            </div>
            <!-- Pin star -->
            <button
              @click.stop="togglePinnedDDay(dday)"
              class="p-1 sm:p-1.5 rounded-full transition hover:scale-110 cursor-pointer"
              :class="pinnedDDay?.id === dday.id ? 'hover:bg-amber-100' : 'hover:bg-gray-100'"
              :title="pinnedDDay?.id === dday.id ? '고정 해제' : '캘린더에 고정'"
            >
              <Star
                class="w-4 h-4 sm:w-5 sm:h-5 transition-colors"
                :class="pinnedDDay?.id === dday.id ? 'text-amber-500 fill-amber-500' : 'text-gray-300 hover:text-amber-400'"
              />
            </button>
          </div>

          <!-- Title -->
          <p class="text-sm sm:text-base font-medium mb-1 sm:mb-2 flex items-start gap-1 sm:gap-1.5" :style="{ color: 'var(--dp-text-primary)' }">
            <Lock v-if="dday.isPrivate" class="w-3.5 h-3.5 sm:w-4 sm:h-4 flex-shrink-0 mt-0.5" :style="{ color: 'var(--dp-text-muted)' }" />
            <span class="line-clamp-2">{{ dday.title }}</span>
          </p>

          <!-- Date -->
          <p class="text-xs sm:text-sm flex items-center gap-1" :style="{ color: 'var(--dp-text-muted)' }">
            <CalendarCheck class="w-3.5 h-3.5 sm:w-4 sm:h-4" />
            {{ dday.date }}
          </p>
        </div>
      </div>

      <!-- Add D-Day Button (only for my calendar) -->
      <div
        v-if="isMyCalendar"
        @click="openDDayModal()"
        class="rounded-xl sm:rounded-2xl border-2 border-dashed cursor-pointer hover:border-blue-400 hover:bg-blue-50/50 transition-all duration-300 flex flex-col items-center justify-center min-h-[100px] sm:min-h-[120px] group"
        :style="{ borderColor: 'var(--dp-border-secondary)' }"
      >
        <div class="w-10 h-10 sm:w-12 sm:h-12 rounded-full group-hover:bg-blue-100 flex items-center justify-center mb-1.5 sm:mb-2 transition-colors" :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }">
          <Plus class="w-5 h-5 sm:w-6 sm:h-6 group-hover:text-blue-500 transition-colors" :style="{ color: 'var(--dp-text-muted)' }" />
        </div>
        <span class="text-xs sm:text-sm group-hover:text-blue-600 transition-colors font-medium" :style="{ color: 'var(--dp-text-muted)' }">디데이 추가</span>
      </div>
    </div>

    <!-- Modals -->
    <DayDetailModal
      :is-open="isDayDetailModalOpen"
      :date="selectedDay || { year: currentYear, month: currentMonth, day: 1 }"
      :duty="selectedDayDuty"
      :schedules="selectedDay ? (schedulesByDays[calendarDays.findIndex(d => d.year === selectedDay!.year && d.month === selectedDay!.month && d.day === selectedDay!.day)] ?? []) : []"
      :duty-types="dutyTypes"
      :can-edit="canEdit"
      :batch-edit-mode="batchEditMode"
      :friends="friends"
      :member-id="memberId"
      @close="isDayDetailModalOpen = false"
      @create-schedule="handleCreateSchedule"
      @edit-schedule="handleEditSchedule"
      @delete-schedule="handleDeleteSchedule"
      @reorder-schedules="handleReorderSchedules"
      @add-tag="handleAddTag"
      @remove-tag="handleRemoveTag"
      @untag-self="handleUntagSelf"
      @change-duty-type="handleChangeDutyType"
    />

    <TodoAddModal
      :is-open="isTodoAddModalOpen"
      @close="isTodoAddModalOpen = false; if (isTodoAddFromOverview) { isTodoOverviewModalOpen = true; isTodoAddFromOverview = false; }"
      @save="handleTodoAdd"
    />

    <TodoDetailModal
      :is-open="isTodoDetailModalOpen"
      :todo="selectedTodo"
      :start-in-edit-mode="startTodoEditMode"
      @close="isTodoDetailModalOpen = false; startTodoEditMode = false"
      @update="handleTodoUpdate"
      @complete="handleTodoComplete"
      @reopen="handleTodoReopen"
      @delete="handleTodoDelete"
      @back-to-list="isTodoDetailModalOpen = false; startTodoEditMode = false; isTodoOverviewModalOpen = true"
    />

    <TodoOverviewModal
      :is-open="isTodoOverviewModalOpen"
      :todos="todos"
      :completed-todos="completedTodos"
      @close="isTodoOverviewModalOpen = false"
      @show-detail="(todo: LocalTodo) => { selectedTodo = todo; isTodoDetailModalOpen = true; isTodoOverviewModalOpen = false; }"
      @edit="(todo: LocalTodo) => { selectedTodo = todo; startTodoEditMode = true; isTodoDetailModalOpen = true; isTodoOverviewModalOpen = false; }"
      @complete="handleTodoComplete"
      @reopen="handleTodoReopen"
      @delete="handleTodoDelete"
      @reorder="handleTodoPositionUpdate"
      @add="isTodoOverviewModalOpen = false; isTodoAddModalOpen = true; isTodoAddFromOverview = true"
    />

    <DDayModal
      :is-open="isDDayModalOpen"
      :dday="selectedDDay"
      @close="isDDayModalOpen = false; if (isDDayEditFromDetail) { isDDayDetailModalOpen = true; isDDayEditFromDetail = false; }"
      @save="handleDDaySave"
    />

    <DDayDetailModal
      :is-open="isDDayDetailModalOpen"
      :dday="selectedDDay"
      :is-pinned="pinnedDDay?.id === selectedDDay?.id"
      :can-edit="isMyCalendar"
      @close="isDDayDetailModalOpen = false"
      @edit="handleDDayEdit"
      @delete="handleDDayDeleteFromDetail"
      @toggle-pin="handleDDayTogglePin"
    />

    <SearchResultModal
      :is-open="isSearchResultModalOpen"
      :query="searchQuery"
      :results="searchResults"
      :page-info="searchPageInfo"
      :is-searching="isSearching"
      @close="isSearchResultModalOpen = false"
      @go-to-date="handleSearchGoToDate"
      @change-page="handleSearchPageChange"
      @search="handleSearchFromModal"
    />

    <OtherDutiesModal
      :is-open="isOtherDutiesModalOpen"
      :friends="friends"
      :selected-friend-ids="selectedFriendIds"
      @close="isOtherDutiesModalOpen = false"
      @toggle="handleFriendToggle"
    />

    <ScheduleViewModal
      :is-open="isScheduleDetailModalOpen"
      :schedule="selectedSchedule"
      :member-id="memberId"
      @close="isScheduleDetailModalOpen = false"
    />

    </template>

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
