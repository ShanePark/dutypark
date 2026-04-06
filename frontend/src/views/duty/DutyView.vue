<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import Swal from 'sweetalert2'
import { useSwal } from '@/composables/useSwal'
import { isLightColor } from '@/utils/color'
import { resolveApiCodeMessage, resolveApiErrorMessage } from '@/utils/resolveApiError'
import { Loader2 } from 'lucide-vue-next'

// Modal Components
import DayDetailModal from '@/components/duty/DayDetailModal.vue'
import TodoAddModal from '@/components/duty/TodoAddModal.vue'
import TodoDetailModal from '@/components/duty/TodoDetailModal.vue'
import DDayModal from '@/components/duty/DDayModal.vue'
import DDayDetailModal from '@/components/duty/DDayDetailModal.vue'
import SearchResultModal from '@/components/duty/SearchResultModal.vue'
import OtherDutiesModal from '@/components/duty/OtherDutiesModal.vue'
import DutyHeaderControls from '@/components/duty/DutyHeaderControls.vue'
import DutyTodoRow from '@/components/duty/DutyTodoRow.vue'
import DutyTypesBar from '@/components/duty/DutyTypesBar.vue'
import DutyCalendarContent from '@/components/duty/DutyCalendarContent.vue'
import DDayList from '@/components/duty/DDayList.vue'
import YearMonthPicker from '@/components/common/YearMonthPicker.vue'

// API
import { todoApi } from '@/api/todo'
import { dutyApi } from '@/api/duty'
import { ddayApi, memberApi, friendApi } from '@/api/member'
import { scheduleApi, type ScheduleDto } from '@/api/schedule'
import type { DutyCalendarDay, TeamDto, DDayDto, DDaySaveDto, HolidayDto, TaggableFriend, Todo as TodoDto, TodoStatus } from '@/types'
import type { LocalTodo, DutyType, Schedule, LocalDDay, CalendarDay, OtherDuty, DutyTypeWithCount, DutyDay, TodoDueItem } from './dutyViewTypes'

import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { showError, confirm, confirmDelete, toastSuccess } = useSwal()
const { t } = useI18n()

// State
const today = new Date()
const currentYear = ref(today.getFullYear())
const currentMonth = ref(today.getMonth() + 1)
const memberName = ref('')
const memberHasProfilePhoto = ref(false)
const memberProfilePhotoVersion = ref(0)
const memberId = computed(() => {
  return parseInt(route.params.id as string)
})
const teamId = ref<number | null>(null)

// isMyCalendar: true if viewing own calendar (id matches logged-in user)
const isMyCalendar = computed(() => {
  const loggedInUserId = authStore.user?.id
  return loggedInUserId !== undefined && loggedInUserId === memberId.value
})
const amIManager = ref(false)

// canEdit: true if own calendar or manager of target member
const canEdit = computed(() => isMyCalendar.value || amIManager.value)
const canEditMyCalendar = computed(() => canEdit.value && isMyCalendar.value)

// canSearch: true if can search schedules (same as canEdit)
const canSearch = canEdit

// Loading states
const isLoading = ref(false)
const isLoadingDuties = ref(false)
const loadError = ref<string | null>(null)

// Edit mode states
const batchEditMode = ref(false)
const focusedDay = ref<number | null>(null)  // Focused day for quick duty input (1~lastDay)
const searchQuery = ref('')

const lastDayInMonth = computed(() => new Date(currentYear.value, currentMonth.value, 0).getDate())

// Modal states
const isDayDetailModalOpen = ref(false)
const isTodoAddModalOpen = ref(false)
const isTodoDetailModalOpen = ref(false)
const isDDayModalOpen = ref(false)
const isDDayDetailModalOpen = ref(false)
const isDDayEditFromDetail = ref(false)
const isSearchResultModalOpen = ref(false)
const isOtherDutiesModalOpen = ref(false)

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
const selectedTodo = ref<LocalTodo | null>(null)
const selectedDDay = ref<LocalDDay | null>(null)
const pinnedDDay = ref<LocalDDay | null>(null)

// Data
const todos = ref<LocalTodo[]>([])
const completedTodos = ref<LocalTodo[]>([])
const isLoadingTodos = ref(false)

// Todos with due dates computed from existing todos (respects filter settings)
const todosDueByDays = computed(() => {
  if (!isMyCalendar.value || !calendarDays.value.length) return []

  // Build map by date from todos that have dueDate and match filter
  const todoMap = new Map<string, TodoDueItem[]>()
  todos.value.forEach((todo) => {
    if (!todo.dueDate) return
    // Apply filter settings (IN_PROGRESS always shown)
    if (todo.status === 'TODO' && !showTodoTodo.value) return

    const key = todo.dueDate
    if (!todoMap.has(key)) {
      todoMap.set(key, [])
    }
    todoMap.get(key)!.push({
      id: todo.id,
      title: todo.title,
      status: todo.status,
    })
  })

  // Map to calendarDays structure
  return calendarDays.value.map((day) => {
    const key = `${day.year}-${String(day.month).padStart(2, '0')}-${String(day.day).padStart(2, '0')}`
    return todoMap.get(key) || []
  })
})

// Todo filter settings (stored in localStorage)
const STORAGE_KEY_TODO_FILTER = 'dutyViewTodoFilter'
const showTodoTodo = ref(false)

// Load todo filter settings from localStorage
function loadTodoFilterSettings() {
  try {
    const stored = localStorage.getItem(STORAGE_KEY_TODO_FILTER)
    if (stored) {
      const settings = JSON.parse(stored)
      showTodoTodo.value = settings.showTodo ?? false
    }
  } catch (e) {
    console.error('Failed to load todo filter settings:', e)
  }
}

// Save todo filter settings to localStorage
function saveTodoFilterSettings() {
  try {
    localStorage.setItem(STORAGE_KEY_TODO_FILTER, JSON.stringify({
      showTodo: showTodoTodo.value,
    }))
  } catch (e) {
    console.error('Failed to save todo filter settings:', e)
  }
}

// Toggle todo filter and save to localStorage
function toggleTodoFilter() {
  showTodoTodo.value = !showTodoTodo.value
  saveTodoFilterSettings()
}

// Filter todos based on selected filters (IN_PROGRESS always shown)
const filteredTodos = computed(() => {
  return todos.value.filter(t => {
    if (t.status === 'IN_PROGRESS') return true
    if (t.status === 'TODO' && showTodoTodo.value) return true
    return false
  })
})

function handleTodoBubbleClick(todo: LocalTodo | { id: string }) {
  const fullTodo = todos.value.find(t => t.id === todo.id)
  if (fullTodo) {
    openTodoDetail(fullTodo)
  }
}

// Convert API Todo to LocalTodo
function mapToLocalTodo(apiTodo: TodoDto): LocalTodo {
  return {
    id: apiTodo.id,
    title: apiTodo.title,
    content: apiTodo.content,
    position: apiTodo.position,
    status: apiTodo.status,
    createdDate: apiTodo.createdDate,
    completedDate: apiTodo.completedDate,
    dueDate: apiTodo.dueDate,
    isOverdue: apiTodo.isOverdue,
    isTagged: apiTodo.isTagged,
    owner: apiTodo.owner,
    taggedByMember: apiTodo.taggedByMember ?? null,
    tags: apiTodo.tags,
    hasAttachments: apiTodo.hasAttachments ?? false,
    attachments: [],
  }
}

function applyTodoUpdate(apiTodo: TodoDto) {
  const localTodo = mapToLocalTodo(apiTodo)

  todos.value = todos.value.filter((t) => t.id !== apiTodo.id)
  completedTodos.value = completedTodos.value.filter((t) => t.id !== apiTodo.id)

  if (apiTodo.status === 'DONE') {
    completedTodos.value.unshift(localTodo)
  } else {
    todos.value.unshift(localTodo)
  }

  selectedTodo.value = localTodo
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
    const board = await todoApi.getBoard()
    // Combine TODO and IN_PROGRESS for active todos
    todos.value = [...board.todo, ...board.inProgress].map(mapToLocalTodo)
    completedTodos.value = board.done.map(mapToLocalTodo)
  } catch (error) {
    console.error('Failed to load todos:', error)
  } finally {
    isLoadingTodos.value = false
  }
}

// Sort D-Days by date ascending (same as backend: OrderByDate)
function sortDDays() {
  dDays.value.sort((a, b) => {
    return a.date.localeCompare(b.date)
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
  const taggedByMember = dto.isTagged && dto.taggedByMember?.id != null
    ? {
      id: dto.taggedByMember.id,
      name: dto.taggedByMember.name,
      hasProfilePhoto: dto.taggedByMember.hasProfilePhoto ?? false,
      profilePhotoVersion: dto.taggedByMember.profilePhotoVersion ?? 0,
    }
    : undefined

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
    taggedBy: taggedByMember?.name ?? (dto.isTagged ? dto.owner : undefined),
    taggedByMember,
    attachments: dto.attachments.map((a) => ({
      id: a.id,
      originalFilename: a.originalFilename,
      contentType: a.contentType,
      size: a.size,
      thumbnailUrl: a.thumbnailUrl ?? undefined,
      hasThumbnail: a.hasThumbnail,
    })),
    tags: dto.tags.flatMap((tag) => tag.id == null ? [] : [{
      id: tag.id,
      name: tag.name,
      hasProfilePhoto: tag.hasProfilePhoto ?? false,
      profilePhotoVersion: tag.profilePhotoVersion ?? 0,
    }]),
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
const teamHasDutyBatchTemplate = computed(() => !!team.value?.dutyBatchTemplate)

// Raw duty data from API
const rawDuties = ref<DutyCalendarDay[]>([])

// Computed duty types with count - reactive to both dutyTypes and rawDuties
const dutyTypesWithCount = computed<DutyTypeWithCount[]>(() => {
  if (dutyTypes.value.length === 0) return []

  const daysInMonth = new Date(currentYear.value, currentMonth.value, 0).getDate()
  let offCount = daysInMonth

  const counts = new Map<string, number>()
  rawDuties.value
    .filter((d) => d.month === currentMonth.value)
    .forEach((duty) => {
      if (duty.dutyType) {
        counts.set(duty.dutyType, (counts.get(duty.dutyType) || 0) + 1)
        offCount--
      }
    })

  return dutyTypes.value.map((dt) => ({
    ...dt,
    cnt: dt.id === null ? offCount : (counts.get(dt.name) || 0),
  }))
})

const dDays = ref<LocalDDay[]>([])
const isLoadingDDays = ref(false)

const friends = ref<TaggableFriend[]>([])
const isLoadingFriends = ref(false)

const selectedFriendIds = ref<number[]>([])
const showMyDuties = ref(false)
const otherDutyCount = computed(() => selectedFriendIds.value.length + (showMyDuties.value ? 1 : 0))
const isOtherDutyActive = computed(() => otherDutyCount.value > 0)

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
const duties = computed<Array<DutyDay | null>>(() => {
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
      dutyColor: duty.dutyColor || 'var(--dp-duty-fallback)',
      dutyTypeId: dutyType?.id ?? null,
    }
  })
})

const selectedDayDuty = computed<DutyDay | undefined>(() => {
  const day = selectedDay.value
  if (!day) return undefined

  const dayIndex = calendarDays.value.findIndex(
    (calendarDay) =>
      calendarDay.year === day.year &&
      calendarDay.month === day.month &&
      calendarDay.day === day.day
  )

  if (dayIndex === -1) return undefined
  return duties.value[dayIndex] ?? undefined
})

const selectedDaySchedules = computed(() => {
  const day = selectedDay.value
  if (!day) return []

  const dayIndex = calendarDays.value.findIndex(
    (calendarDay) =>
      calendarDay.year === day.year &&
      calendarDay.month === day.month &&
      calendarDay.day === day.day
  )

  if (dayIndex === -1) return []
  return schedulesByDays.value[dayIndex] ?? []
})

// Get duty for the currently focused day (for highlighting quick input buttons)
const focusedDayDuty = computed(() => {
  if (!focusedDay.value) return null
  const dayIndex = calendarDays.value.findIndex(d => d.day === focusedDay.value && d.isCurrentMonth)
  if (dayIndex === -1) return null
  return duties.value[dayIndex]
})
const focusedDayDutyType = computed(() => focusedDayDuty.value?.dutyType ?? null)

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
  } catch (error) {
    console.error('Failed to load duties:', error)
    loadError.value = t('duty.view.loadDutiesFailed')
  } finally {
    isLoadingDuties.value = false
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
  // Listen for "go to date" event from notification navigation
  window.addEventListener('duty-go-to-date', handleGoToDate)

  // Load todo filter settings from localStorage
  loadTodoFilterSettings()

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

    // Handle pending highlight date from notification navigation
    const storedHighlight = sessionStorage.getItem('dutyHighlightDate')
    if (storedHighlight) {
      sessionStorage.removeItem('dutyHighlightDate')
      const { year, month, day } = JSON.parse(storedHighlight)
      if (year && month && day) {
        currentYear.value = year
        currentMonth.value = month
        searchDay.value = { year, month, day }
        // Reload data for the target month
        await loadCalendar()
        await Promise.all([loadDuties(), loadSchedules(), loadOtherDuties(), loadHolidays()])
      }
    }
  } catch (error) {
    console.error('Failed to initialize duty view:', error)
    loadError.value = t('duty.view.loadDataFailed')
  } finally {
    isLoading.value = false
  }
})

// Cleanup on unmount
onUnmounted(() => {
  window.removeEventListener('duty-go-to-today', goToToday)
  window.removeEventListener('duty-go-to-date', handleGoToDate)
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

// Watch for batch edit mode changes to initialize/reset focused day
watch(batchEditMode, (newVal) => {
  if (newVal) {
    focusedDay.value = 1  // Start from day 1 when entering edit mode
  } else {
    focusedDay.value = null  // Clear focus when exiting edit mode
  }
})

// Watch for route params changes (when navigating between calendars)
watch(
  () => route.params.id,
  async () => {
    isLoading.value = true
    loadError.value = null

    // Reset state
    const now = new Date()
    currentYear.value = now.getFullYear()
    currentMonth.value = now.getMonth() + 1
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
      loadError.value = t('duty.view.loadDataFailed')
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

// Handle "go to date" event from notification navigation
async function handleGoToDate(event: Event) {
  const customEvent = event as CustomEvent<{ year: number; month: number; day: number }>
  const { year, month, day } = customEvent.detail
  const needsReload = year !== currentYear.value || month !== currentMonth.value
  currentYear.value = year
  currentMonth.value = month
  searchDay.value = { year, month, day }
  if (needsReload) {
    await loadCalendar()
    await Promise.all([loadDuties(), loadSchedules(), loadOtherDuties(), loadHolidays()])
  }
}

// Day click handler
function handleDayClick(day: CalendarDay, _index: number) {
  // In batch edit mode, clicking a day moves the focus to that day
  if (batchEditMode.value) {
    if (day.isCurrentMonth) {
      focusedDay.value = day.day
    }
    return
  }

  selectedDay.value = day
  isDayDetailModalOpen.value = true
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
    showError(t('duty.view.changeDutyFailed'))
  }
}

// Debounced duty reload to avoid multiple rapid reloads
let dutyReloadTimeout: ReturnType<typeof setTimeout> | null = null
function debouncedLoadDuties() {
  if (dutyReloadTimeout) clearTimeout(dutyReloadTimeout)
  dutyReloadTimeout = setTimeout(() => {
    loadDuties()
  }, 300)
}

// Quick duty change: apply to focused day and move to next day
function handleQuickDutyChange(dutyTypeId: number | null) {
  if (!focusedDay.value || !memberId.value || !canEdit.value) return

  // Capture current day before incrementing
  const currentDay = focusedDay.value
  const year = currentYear.value
  const month = currentMonth.value

  // Move to next day immediately (stop at last day of month)
  const lastDay = lastDayInMonth.value
  if (focusedDay.value < lastDay) {
    focusedDay.value++
  }

  // Find the duty type info for optimistic update
  const dutyType = dutyTypes.value.find(dt => dt.id === dutyTypeId)
  const newDutyType = dutyType?.name || null
  const newDutyColor = dutyType?.color || null

  // Optimistic update: immediately update rawDuties
  const dutyIndex = rawDuties.value.findIndex(
    d => d.year === year && d.month === month && d.day === currentDay
  )
  const existingDuty = dutyIndex !== -1 ? rawDuties.value[dutyIndex] : null
  const previousDuty = existingDuty ? {
    year: existingDuty.year,
    month: existingDuty.month,
    day: existingDuty.day,
    dutyType: existingDuty.dutyType,
    dutyColor: existingDuty.dutyColor,
    isOff: existingDuty.isOff,
  } : null

  if (dutyIndex !== -1 && existingDuty) {
    rawDuties.value[dutyIndex] = {
      year: existingDuty.year,
      month: existingDuty.month,
      day: existingDuty.day,
      dutyType: newDutyType,
      dutyColor: newDutyColor,
      isOff: dutyTypeId === null,
    }
  }

  // Fire API call - rollback on failure
  dutyApi.updateDuty(memberId.value, year, month, currentDay, dutyTypeId)
    .then(() => debouncedLoadDuties())
    .catch((error) => {
      console.error('Failed to change duty type:', error)
      // Rollback on failure
      if (previousDuty && dutyIndex !== -1) {
        rawDuties.value[dutyIndex] = previousDuty
      }
    })
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
    showError(t('duty.dday.messages.saveFailed'))
  }
  isDDayModalOpen.value = false
  // Return to detail modal if editing from there
  if (isDDayEditFromDetail.value) {
    isDDayDetailModalOpen.value = true
    isDDayEditFromDetail.value = false
  }
}

async function deleteDDay(dday: LocalDDay) {
  if (!await confirmDelete(t('duty.dday.messages.deleteConfirm', { title: dday.title }))) return

  try {
    await ddayApi.deleteDDay(dday.id)
    dDays.value = dDays.value.filter((d) => d.id !== dday.id)
    if (pinnedDDay.value?.id === dday.id) {
      pinnedDDay.value = null
      localStorage.removeItem(`selectedDday_${memberId.value}`)
    }
  } catch (error) {
    console.error('Failed to delete D-Day:', error)
    showError(t('duty.dday.messages.deleteFailed'))
  }
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
  status: TodoStatus
  dueDate?: string | null
  tagFriendIds?: number[]
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}) {
  try {
    const updatedTodo = await todoApi.updateTodo(data.id, {
      title: data.title,
      content: data.content,
      status: data.status,
      dueDate: data.dueDate,
      tagFriendIds: data.tagFriendIds,
      attachmentSessionId: data.attachmentSessionId,
      orderedAttachmentIds: data.orderedAttachmentIds,
    })
    applyTodoUpdate(updatedTodo)
  } catch (error) {
    console.error('Failed to update todo:', error)
    showError(t('duty.todo.messages.updateFailed'))
  }
}

async function handleTodoComplete(id: string) {
  const fromDetailModal = isTodoDetailModalOpen.value
  try {
    await todoApi.completeTodo(id)
    await loadTodos()
  } catch (error) {
    console.error('Failed to complete todo:', error)
    showError(t('duty.todo.messages.completeFailed'))
  }
  // Only close detail modal and return to overview if called from detail modal
  if (fromDetailModal) {
    isTodoDetailModalOpen.value = false
  }
}

async function handleTodoReopen(id: string) {
  const fromDetailModal = isTodoDetailModalOpen.value
  try {
    await todoApi.reopenTodo(id)
    await loadTodos()
  } catch (error) {
    console.error('Failed to reopen todo:', error)
    showError(t('duty.todo.messages.reopenFailed'))
  }
  // Only close detail modal if called from detail modal
  if (fromDetailModal) {
    isTodoDetailModalOpen.value = false
  }
}

async function handleTodoStatusChange(data: { id: string; status: TodoStatus }) {
  const fromDetailModal = isTodoDetailModalOpen.value
  try {
    await todoApi.changeStatus(data.id, { status: data.status })
    await loadTodos()
    toastSuccess(t('duty.todo.messages.statusChanged'))
  } catch (error) {
    console.error('Failed to change todo status:', error)
    showError(t('duty.todo.messages.statusChangeFailed'))
  }
  if (fromDetailModal) {
    isTodoDetailModalOpen.value = false
  }
}

async function handleTodoDelete(id: string) {
  if (!await confirmDelete(t('duty.todo.messages.deleteConfirm'))) return
  const fromDetailModal = isTodoDetailModalOpen.value
  try {
    await todoApi.deleteTodo(id)
    todos.value = todos.value.filter((t) => t.id !== id)
    completedTodos.value = completedTodos.value.filter((t) => t.id !== id)
  } catch (error) {
    console.error('Failed to delete todo:', error)
    showError(t('duty.todo.messages.deleteFailed'))
  }
  // Only close detail modal if called from detail modal
  if (fromDetailModal) {
    isTodoDetailModalOpen.value = false
  }
}

async function handleTodoAdd(data: {
  title: string
  content: string
  status: TodoStatus
  dueDate?: string
  tagFriendIds?: number[]
  attachmentSessionId?: string
  orderedAttachmentIds?: string[]
}) {
  try {
    const newTodo = await todoApi.createTodo({
      title: data.title,
      content: data.content,
      status: data.status,
      dueDate: data.dueDate,
      tagFriendIds: data.tagFriendIds,
      attachmentSessionId: data.attachmentSessionId,
      orderedAttachmentIds: data.orderedAttachmentIds,
    })
    // Only add to the list if it's not DONE (active todos)
    if (newTodo.status === 'DONE') {
      completedTodos.value.unshift(mapToLocalTodo(newTodo))
    } else {
      todos.value.unshift(mapToLocalTodo(newTodo))
    }
    toastSuccess(t('duty.todo.messages.added'))
  } catch (error) {
    console.error('Failed to add todo:', error)
    showError(t('duty.todo.messages.addFailed'))
  }
  isTodoAddModalOpen.value = false
}

async function handleTodoUntagSelf(id: string) {
  if (!await confirm(t('duty.todo.messages.untagConfirm'), t('duty.todo.messages.untagTitle'))) return

  try {
    await todoApi.untagSelf(id)
    todos.value = todos.value.filter((todo) => todo.id !== id)
    completedTodos.value = completedTodos.value.filter((todo) => todo.id !== id)
    isTodoDetailModalOpen.value = false
    toastSuccess(t('duty.todo.messages.untagged'))
  } catch (error) {
    console.error('Failed to untag todo:', error)
    showError(t('duty.todo.messages.untagFailed'))
  }
}

function handleTodoBackToList() {
  isTodoDetailModalOpen.value = false
  router.push('/todo')
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
    showError(t('duty.search.failed'))
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

async function handleOtherDutiesClear() {
  if (selectedFriendIds.value.length === 0 && !showMyDuties.value) {
    return
  }

  selectedFriendIds.value = []
  showMyDuties.value = false
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
    otherDuties.value = response.map((item) => ({
      memberId: item.memberId,
      memberName: item.name,
      hasProfilePhoto: item.hasProfilePhoto ?? false,
      profilePhotoVersion: item.profilePhotoVersion ?? 0,
      duties: item.duties.map((d) => ({
        dutyType: d.dutyType || t('duty.common.off'),
        dutyColor: d.dutyColor || 'var(--dp-duty-fallback)',
      })),
    }))
  } catch (error) {
    console.error('Failed to load other duties:', error)
    showError(t('duty.view.loadOtherDutiesFailed'))
  }
}

// Load friends list
async function loadFriends() {
  if (!isMyCalendar.value) return

  isLoadingFriends.value = true
  try {
    const response = await friendApi.getFriends()
    friends.value = response.data
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
  tagFriendIds: number[]
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
      tagFriendIds: data.tagFriendIds,
      attachmentSessionId: data.attachmentSessionId || undefined,
      orderedAttachmentIds: data.orderedAttachmentIds,
    })
    await loadSchedules()
    toastSuccess(t('duty.schedule.messages.created'))
  } catch (error) {
    console.error('Failed to create schedule:', error)
    showError(t('duty.schedule.messages.createFailed'))
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
      tagFriendIds: data.tagFriendIds,
      attachmentSessionId: data.attachmentSessionId || undefined,
      orderedAttachmentIds: data.orderedAttachmentIds,
    })
    await loadSchedules()
  } catch (error) {
    console.error('Failed to update schedule:', error)
    showError(t('duty.schedule.messages.updateFailed'))
  }
}

async function handleDeleteSchedule(scheduleId: string) {
  if (!await confirmDelete(t('duty.schedule.messages.deleteConfirm'))) return

  try {
    await scheduleApi.deleteSchedule(scheduleId)
    await loadSchedules()
    toastSuccess(t('duty.schedule.messages.deleted'))
  } catch (error) {
    console.error('Failed to delete schedule:', error)
    showError(t('duty.schedule.messages.deleteFailed'))
  }
}

async function handleReorderSchedules(scheduleIds: string[]) {
  try {
    await scheduleApi.reorderSchedulePositions(scheduleIds)
    await loadSchedules()
    toastSuccess(t('duty.schedule.messages.reordered'))
  } catch (error) {
    console.error('Failed to reorder schedules:', error)
    showError(t('duty.schedule.messages.reorderFailed'))
  }
}

async function handleUntagSelf(scheduleId: string) {
  try {
    await scheduleApi.untagSelf(scheduleId)
    await loadSchedules()
    toastSuccess(t('duty.schedule.messages.untagged'))
  } catch (error) {
    console.error('Failed to untag self:', error)
    showError(t('duty.schedule.messages.untagFailed'))
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
    showError(t('duty.view.changeDutyFailed'))
  }
}

// Batch update modal - update all days in current month to a single duty type
async function showBatchUpdateModal() {
  if (!memberId.value || dutyTypes.value.length === 0) return

  const buttonsHtml = dutyTypes.value
    .map((dt) => {
      const textColor = isLightColor(dt.color) ? 'var(--dp-text-on-light)' : 'var(--dp-text-on-dark)'
      return `<button class="swal2-styled duty-type-btn" style="background-color: ${dt.color || 'var(--dp-duty-fallback)'}; color: ${textColor}; margin: 4px;" data-id="${dt.id}">${dt.name}</button>`
    })
    .join('')

  const result = await Swal.fire({
    title: t('duty.batchUpdate.title'),
    html: `
      <p>${t('duty.batchUpdate.description1', { year: currentYear.value, month: currentMonth.value })}</p>
      <p>${t('duty.batchUpdate.description2')}</p>
      <p class="text-sm text-dp-warning font-semibold mt-2">${t('duty.batchUpdate.warning')}</p>
      <div class="mt-4">${buttonsHtml}</div>
    `,
    showConfirmButton: false,
    showCancelButton: true,
    cancelButtonText: t('common.actions.cancel'),
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
            showError(t('duty.batchUpdate.failed'))
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
    title: t('duty.excelUpload.title'),
    input: 'file',
    html: `${t('duty.excelUpload.description1')}<br/>${t('duty.excelUpload.description2', { year: currentYear.value, month: currentMonth.value })}`,
    inputAttributes: {
      accept: fileExtensions.join(','),
      'aria-label': t('duty.excelUpload.ariaLabel'),
    },
    confirmButtonText: t('duty.excelUpload.confirm'),
    showCancelButton: true,
    cancelButtonText: t('common.actions.cancel'),
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
      showError(
        resolveApiCodeMessage(result, { fallbackKey: 'duty.excelUpload.failed' }, t),
        t('duty.excelUpload.failureTitle'),
      )
      return
    }

    await Swal.fire({
      icon: 'success',
      title: t('duty.excelUpload.successTitle'),
      html: t('duty.excelUpload.successSummary', {
        startDate: result.startDate,
        endDate: result.endDate,
        totalDays: result.workingDays + result.offDays,
        workingDays: result.workingDays,
        offDays: result.offDays,
      }),
      confirmButtonText: t('common.actions.confirm'),
    })

    await loadDuties()
  } catch (error) {
    console.error('Failed to upload duty batch:', error)
    showError(
      resolveApiErrorMessage(error, { fallbackKey: 'duty.excelUpload.failed' }, t),
      t('duty.excelUpload.failureTitle'),
    )
  }
}
</script>

<template>
  <div class="max-w-4xl mx-auto px-2 sm:px-4 py-2 sm:py-4">
    <!-- Loading State -->
    <div v-if="isLoading" class="flex items-center justify-center py-20">
      <Loader2 class="w-8 h-8 text-dp-accent animate-spin" />
      <span class="ml-2 text-dp-text-secondary">{{ t('duty.view.loading') }}</span>
    </div>

    <!-- Error State -->
    <div v-else-if="loadError" class="border rounded-lg p-4 mb-4" :style="{ backgroundColor: 'var(--dp-danger-bg)', borderColor: 'var(--dp-danger-border)' }">
      <p class="text-dp-danger">{{ loadError }}</p>
      <button
        @click="loadDuties"
        class="mt-2 px-4 py-2 bg-dp-danger text-dp-text-on-dark rounded hover:bg-dp-danger-hover transition cursor-pointer"
      >
        {{ t('duty.view.retry') }}
      </button>
    </div>

    <!-- Main Content -->
    <template v-else>
    <DutyHeaderControls
      :member-id="memberId"
      :member-name="memberName"
      :member-has-profile-photo="memberHasProfilePhoto"
      :member-profile-photo-version="memberProfilePhotoVersion"
      :current-year="currentYear"
      :current-month="currentMonth"
      :can-search="canSearch"
      v-model:searchQuery="searchQuery"
      @prev-month="prevMonth"
      @next-month="nextMonth"
      @open-year-month-picker="isYearMonthPickerOpen = true"
      @search="handleSearch()"
      @open-search-modal="openSearchModal"
    />

    <DutyTodoRow
      v-if="isMyCalendar"
      :show-todo-todo="showTodoTodo"
      :filtered-todos="filteredTodos"
      @toggle-filter="toggleTodoFilter"
      @open-todo-board="router.push('/todo')"
      @add-todo="isTodoAddModalOpen = true"
      @todo-click="handleTodoBubbleClick"
    />

    <DutyTypesBar
      :batch-edit-mode="batchEditMode"
      :duty-types="dutyTypes"
      :duty-types-with-count="dutyTypesWithCount"
      :is-loading-duties="isLoadingDuties"
      :focused-day="focusedDay"
      :focused-day-duty-type="focusedDayDutyType"
      :last-day-in-month="lastDayInMonth"
      :can-edit="canEdit"
      :can-edit-my-calendar="canEditMyCalendar"
      :other-duty-count="otherDutyCount"
      :is-other-duty-active="isOtherDutyActive"
      :team-has-duty-batch-template="teamHasDutyBatchTemplate"
      @toggle-other-duties="handleToggleOtherDuties"
      @clear-other-duties="handleOtherDutiesClear"
      @show-batch-update-modal="showBatchUpdateModal"
      @toggle-batch-edit="batchEditMode = $event"
      @show-excel-upload-modal="showExcelUploadModal"
      @quick-duty-change="handleQuickDutyChange"
      @update:focusedDay="focusedDay = $event"
    />

    <DutyCalendarContent
      :days="calendarDays"
      :current-year="currentYear"
      :current-month="currentMonth"
      :holidays="holidaysByDays"
      :get-duty-color-for-day="getDutyColorForDay"
      :highlight-day="searchDay"
      :batch-edit-mode="batchEditMode"
      :focused-day="focusedDay"
      :can-edit="canEdit"
      :duties="duties"
      :duty-types="dutyTypes"
      :other-duties="otherDuties"
      :schedules-by-days="schedulesByDays"
      :d-days="dDays"
      :pinned-d-day="pinnedDDay"
      :todos-due-by-days="todosDueByDays"
      :is-my-calendar="isMyCalendar"
      :member-id="memberId"
      @day-click="handleDayClick"
      @batch-duty-change="handleBatchDutyChange"
      @todo-click="handleTodoBubbleClick"
    />

    <!-- D-Day List (hidden in edit mode) -->
    <DDayList
      v-if="!batchEditMode"
      :d-days="dDays"
      :pinned-d-day-id="pinnedDDay?.id ?? null"
      :is-my-calendar="isMyCalendar"
      @open-detail="openDDayDetail"
      @toggle-pin="togglePinnedDDay"
      @add="openDDayModal()"
    />

    <!-- Modals -->
    <DayDetailModal
      :is-open="isDayDetailModalOpen"
      :date="selectedDay || { year: currentYear, month: currentMonth, day: 1 }"
      :duty="selectedDayDuty"
      :schedules="selectedDaySchedules"
      :duty-types="dutyTypes"
      :can-edit="canEdit"
      :batch-edit-mode="batchEditMode"
      :friends="friends"
      :member-id="memberId"
      :is-my-calendar="isMyCalendar"
      @close="isDayDetailModalOpen = false"
      @create-schedule="handleCreateSchedule"
      @edit-schedule="handleEditSchedule"
      @delete-schedule="handleDeleteSchedule"
      @reorder-schedules="handleReorderSchedules"
      @untag-self="handleUntagSelf"
      @change-duty-type="handleChangeDutyType"
    />

    <TodoAddModal
      :is-open="isTodoAddModalOpen"
      initial-status="IN_PROGRESS"
      :friends="friends"
      @close="isTodoAddModalOpen = false"
      @save="handleTodoAdd"
    />

    <TodoDetailModal
      :is-open="isTodoDetailModalOpen"
      :todo="selectedTodo"
      :friends="friends"
      @close="isTodoDetailModalOpen = false"
      @update="handleTodoUpdate"
      @complete="handleTodoComplete"
      @reopen="handleTodoReopen"
      @change-status="handleTodoStatusChange"
      @delete="handleTodoDelete"
      @untag-self="handleTodoUntagSelf"
      @back-to-list="handleTodoBackToList"
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
      @clear="handleOtherDutiesClear"
      @toggle="handleFriendToggle"
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
