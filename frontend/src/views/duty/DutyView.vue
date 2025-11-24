<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useSwal } from '@/composables/useSwal'
import {
  Plus,
  ClipboardList,
  ChevronLeft,
  ChevronRight,
  Search,
  Pencil,
  Trash2,
  Users,
  FileText,
  Star,
  Loader2,
  Lock,
  CalendarCheck,
} from 'lucide-vue-next'

// Modal Components
import DayDetailModal from '@/components/duty/DayDetailModal.vue'
import TodoAddModal from '@/components/duty/TodoAddModal.vue'
import TodoDetailModal from '@/components/duty/TodoDetailModal.vue'
import TodoOverviewModal from '@/components/duty/TodoOverviewModal.vue'
import DDayModal from '@/components/duty/DDayModal.vue'
import SearchResultModal from '@/components/duty/SearchResultModal.vue'
import OtherDutiesModal from '@/components/duty/OtherDutiesModal.vue'
import ScheduleDetailModal from '@/components/duty/ScheduleDetailModal.vue'
import YearMonthPicker from '@/components/common/YearMonthPicker.vue'

// API
import { todoApi } from '@/api/todo'
import { dutyApi } from '@/api/duty'
import { ddayApi, memberApi } from '@/api/member'
import { scheduleApi, type ScheduleDto, type ScheduleSearchResult } from '@/api/schedule'
import type { DutyCalendarDay, TeamDto, DDayDto, DDaySaveDto, CalendarVisibility } from '@/types'

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
  profileImage?: string
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
    day: number
    dutyType: string
    dutyColor: string
  }>
}

import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const authStore = useAuthStore()
const { showError, confirmDelete } = useSwal()

// State
const today = new Date()
const currentYear = ref(today.getFullYear())
const currentMonth = ref(today.getMonth() + 1)
const memberName = ref('')
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
const isTodoDetailModalOpen = ref(false)
const isTodoOverviewModalOpen = ref(false)
const isDDayModalOpen = ref(false)
const isSearchResultModalOpen = ref(false)
const isOtherDutiesModalOpen = ref(false)
const isScheduleDetailModalOpen = ref(false)
const isYearMonthPickerOpen = ref(false)

function handleYearMonthSelect(year: number, month: number) {
  currentYear.value = year
  currentMonth.value = month
  isYearMonthPickerOpen.value = false
}

// Selected items
const selectedDay = ref<CalendarDay | null>(null)
const selectedDayDuty = ref<{ dutyType: string; dutyColor: string } | undefined>(undefined)
const selectedTodo = ref<LocalTodo | null>(null)
const selectedDDay = ref<LocalDDay | null>(null)
const pinnedDDay = ref<LocalDDay | null>(null)
const selectedScheduleForDetail = ref<Schedule | null>(null)

// Data
const todos = ref<LocalTodo[]>([])
const completedTodos = ref<LocalTodo[]>([])
const isLoadingTodos = ref(false)

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
      thumbnailUrl: a.thumbnailUrl,
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

// Team and duty types from API
const team = ref<TeamDto | null>(null)
const dutyTypes = ref<DutyType[]>([])

// Raw duty data from API
const rawDuties = ref<DutyCalendarDay[]>([])

const dDays = ref<LocalDDay[]>([])
const isLoadingDDays = ref(false)

const friends = ref<Friend[]>([
  { id: 1, name: '김철수' },
  { id: 2, name: '이영희' },
  { id: 3, name: '박지민' },
  { id: 4, name: '최수진' },
])

const selectedFriendIds = ref<number[]>([])

const otherDuties = ref<OtherDuty[]>([])

// Schedules by day index
const schedulesByDays = ref<Schedule[][]>([])

// Search results
const searchResults = ref<any[]>([])
const searchPageInfo = ref({
  pageNumber: 0,
  pageSize: 10,
  totalPages: 0,
  totalElements: 0,
})

// Week days
const weekDays = ['일', '월', '화', '수', '목', '금', '토']

// Generate calendar days
const calendarDays = computed(() => {
  const days: CalendarDay[] = []
  const firstDay = new Date(currentYear.value, currentMonth.value - 1, 1)
  const lastDay = new Date(currentYear.value, currentMonth.value, 0)
  const startDayOfWeek = firstDay.getDay()
  const today = new Date()

  // Previous month days
  const prevMonthLastDay = new Date(currentYear.value, currentMonth.value - 1, 0).getDate()
  for (let i = startDayOfWeek - 1; i >= 0; i--) {
    const day = prevMonthLastDay - i
    days.push({
      year: currentMonth.value === 1 ? currentYear.value - 1 : currentYear.value,
      month: currentMonth.value === 1 ? 12 : currentMonth.value - 1,
      day,
      isCurrentMonth: false,
      isPrev: true,
    })
  }

  // Current month days
  for (let i = 1; i <= lastDay.getDate(); i++) {
    const isToday =
      i === today.getDate() &&
      currentMonth.value === today.getMonth() + 1 &&
      currentYear.value === today.getFullYear()
    days.push({
      year: currentYear.value,
      month: currentMonth.value,
      day: i,
      isCurrentMonth: true,
      isToday,
    })
  }

  // Next month days
  const remainingDays = 42 - days.length
  for (let i = 1; i <= remainingDays; i++) {
    days.push({
      year: currentMonth.value === 12 ? currentYear.value + 1 : currentYear.value,
      month: currentMonth.value === 12 ? 1 : currentMonth.value + 1,
      day: i,
      isCurrentMonth: false,
      isNext: true,
    })
  }

  return days
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

// Load member info (for friend's calendar)
async function loadMemberInfo() {
  if (isMyCalendar.value) {
    // Use auth store for own calendar
    if (authStore.user) {
      memberName.value = authStore.user.name
      teamId.value = authStore.user.teamId
    }
  } else {
    // Fetch member info for friend's calendar
    try {
      const response = await memberApi.getMemberById(memberId.value)
      memberName.value = response.data.name
      teamId.value = response.data.teamId
    } catch (error) {
      console.error('Failed to load member info:', error)
    }
  }
}

// Initialize on mount
onMounted(async () => {
  isLoading.value = true
  loadError.value = null

  try {
    // Load member info first to get teamId
    await loadMemberInfo()

    // Load data in parallel
    await Promise.all([
      loadTodos(),
      loadDuties(),
      loadDDays(),
      loadSchedules(),
      checkCanManage(),
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

// Watch for month changes to reload data
watch(
  () => [currentYear.value, currentMonth.value],
  async () => {
    await Promise.all([loadDuties(), loadSchedules()])
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
    dutyTypes.value = []
    team.value = null
    pinnedDDay.value = null

    try {
      await loadMemberInfo()
      await Promise.all([
        loadTodos(),
        loadDuties(),
        loadDDays(),
        loadSchedules(),
        checkCanManage(),
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
  if (currentMonth.value === 1) {
    currentMonth.value = 12
    currentYear.value--
  } else {
    currentMonth.value--
  }
}

function nextMonth() {
  if (currentMonth.value === 12) {
    currentMonth.value = 1
    currentYear.value++
  } else {
    currentMonth.value++
  }
}

function goToToday() {
  const today = new Date()
  currentYear.value = today.getFullYear()
  currentMonth.value = today.getMonth() + 1
}

// Day click handler
function handleDayClick(day: CalendarDay, index: number) {
  if (!isMyCalendar.value) return // Disable click on friend's calendar
  if (batchEditMode.value) return
  selectedDay.value = day
  selectedDayDuty.value = duties.value[index] || undefined
  isDayDetailModalOpen.value = true
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

function openDDayModal(dday?: LocalDDay) {
  selectedDDay.value = dday || null
  isDDayModalOpen.value = true
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
    } else {
      // Add new to local list
      dDays.value.push(localDDay)
    }
  } catch (error) {
    console.error('Failed to save D-Day:', error)
    showError('D-Day 저장에 실패했습니다.')
  }
  isDDayModalOpen.value = false
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

// Calculate D-Day for calendar cell
function calcDDayForDay(day: CalendarDay) {
  if (!pinnedDDay.value) return null
  const targetDate = new Date(pinnedDDay.value.date)
  const cellDate = new Date(day.year, day.month - 1, day.day)
  const diffDays = Math.ceil((cellDate.getTime() - targetDate.getTime()) / (1000 * 60 * 60 * 24)) + 1
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
  } catch (error) {
    console.error('Failed to update todo:', error)
    showError('할 일 수정에 실패했습니다.')
  }
  isTodoDetailModalOpen.value = false
}

async function handleTodoComplete(id: string) {
  try {
    const completedTodo = await todoApi.completeTodo(id)
    // Remove from active todos
    todos.value = todos.value.filter((t) => t.id !== id)
    // Add to completed todos
    completedTodos.value.unshift(mapToLocalTodo(completedTodo))
  } catch (error) {
    console.error('Failed to complete todo:', error)
    showError('할 일 완료 처리에 실패했습니다.')
  }
  isTodoDetailModalOpen.value = false
}

async function handleTodoReopen(id: string) {
  try {
    const reopenedTodo = await todoApi.reopenTodo(id)
    // Remove from completed todos
    completedTodos.value = completedTodos.value.filter((t) => t.id !== id)
    // Add to active todos
    todos.value.push(mapToLocalTodo(reopenedTodo))
  } catch (error) {
    console.error('Failed to reopen todo:', error)
    showError('할 일 재오픈에 실패했습니다.')
  }
  isTodoDetailModalOpen.value = false
}

async function handleTodoDelete(id: string) {
  if (!await confirmDelete('할 일을 삭제하시겠습니까?')) return
  try {
    await todoApi.deleteTodo(id)
    todos.value = todos.value.filter((t) => t.id !== id)
    completedTodos.value = completedTodos.value.filter((t) => t.id !== id)
  } catch (error) {
    console.error('Failed to delete todo:', error)
    showError('할 일 삭제에 실패했습니다.')
  }
  isTodoDetailModalOpen.value = false
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
  } catch (error) {
    console.error('Failed to add todo:', error)
    showError('할 일 추가에 실패했습니다.')
  }
  isTodoAddModalOpen.value = false
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

function handleSearchGoToDate(result: any) {
  const date = new Date(result.startDateTime)
  currentYear.value = date.getFullYear()
  currentMonth.value = date.getMonth() + 1
  isSearchResultModalOpen.value = false
}

// Other duties (함께보기)
function handleFriendToggle(friendId: number) {
  const idx = selectedFriendIds.value.indexOf(friendId)
  if (idx >= 0) {
    selectedFriendIds.value.splice(idx, 1)
  } else {
    selectedFriendIds.value.push(friendId)
  }
  // Load other duties (dummy)
  loadOtherDuties()
}

function loadOtherDuties() {
  if (selectedFriendIds.value.length === 0) {
    otherDuties.value = []
    return
  }
  // Dummy data
  otherDuties.value = selectedFriendIds.value.map((friendId) => {
    const friend = friends.value.find((f) => f.id === friendId)
    return {
      memberId: friendId,
      memberName: friend?.name || '',
      duties: Array.from({ length: 31 }, (_, i) => ({
        day: i + 1,
        dutyType: i % 5 === 0 ? 'OFF' : '출근',
        dutyColor: i % 5 === 0 ? '#6c757d' : '#0d6efd',
      })),
    }
  })
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
    isDayDetailModalOpen.value = false
    await loadSchedules()
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
    isDayDetailModalOpen.value = false
    await loadSchedules()
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
  } catch (error) {
    console.error('Failed to delete schedule:', error)
    showError('일정 삭제에 실패했습니다.')
  }
}

async function handleSwapSchedule(id1: string, id2: string) {
  try {
    await scheduleApi.swapSchedulePosition(id1, id2)
    await loadSchedules()
  } catch (error) {
    console.error('Failed to swap schedules:', error)
    showError('일정 순서 변경에 실패했습니다.')
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

// Show schedule detail modal
function handleShowDescription(schedule: Schedule) {
  selectedScheduleForDetail.value = schedule
  isScheduleDetailModalOpen.value = true
}

// Get schedule time display
function formatScheduleTime(schedule: Schedule) {
  const start = new Date(schedule.startDateTime)
  const startHour = start.getHours().toString().padStart(2, '0')
  const startMin = start.getMinutes().toString().padStart(2, '0')

  if (startHour === '00' && startMin === '00') {
    return ''
  }
  return `(${startHour}:${startMin})`
}

// Get other duty for a specific day
function getOtherDutyForDay(day: CalendarDay, memberDuties: OtherDuty) {
  if (!day.isCurrentMonth) return null
  return memberDuties.duties.find((d) => d.day === day.day)
}
</script>

<template>
  <div class="max-w-4xl mx-auto px-2 sm:px-4 py-4">
    <!-- Loading State -->
    <div v-if="isLoading" class="flex items-center justify-center py-20">
      <Loader2 class="w-8 h-8 text-blue-500 animate-spin" />
      <span class="ml-2 text-gray-600">데이터를 불러오는 중...</span>
    </div>

    <!-- Error State -->
    <div v-else-if="loadError" class="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
      <p class="text-red-700">{{ loadError }}</p>
      <button
        @click="loadDuties"
        class="mt-2 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 transition"
      >
        다시 시도
      </button>
    </div>

    <!-- Main Content -->
    <template v-else>
    <!-- Todo List Section -->
    <div v-if="isMyCalendar" class="bg-white rounded-lg border border-gray-300 shadow-sm mb-4 flex">
      <!-- Add Todo Button -->
      <button
        @click="isTodoAddModalOpen = true"
        class="flex-shrink-0 w-16 sm:w-24 min-h-[44px] bg-green-500 text-white rounded-l-lg flex items-center justify-center gap-1 border-r border-gray-300 hover:bg-green-600 transition"
      >
        <span class="text-xs sm:text-sm font-medium">Todo</span>
        <Plus class="w-4 h-4" />
      </button>

      <!-- Todo Items -->
      <div class="flex-1 min-w-0 overflow-x-auto py-2 px-2">
        <div class="flex gap-2">
          <div
            v-for="todo in todos"
            :key="todo.id"
            @click="openTodoDetail(todo)"
            class="flex-shrink-0 max-w-[150px] sm:max-w-[200px] flex items-center bg-gray-50 border border-gray-200 rounded-lg px-2 sm:px-3 py-2 min-h-[44px] cursor-pointer hover:bg-gray-100 transition"
          >
            <span class="font-medium text-gray-800 truncate">{{ todo.title }}</span>
            <FileText v-if="todo.content || todo.hasAttachments" class="w-4 h-4 text-gray-400 ml-1 flex-shrink-0" />
          </div>
        </div>
      </div>

      <!-- Todo Count Badge -->
      <button
        @click="isTodoOverviewModalOpen = true"
        class="flex-shrink-0 px-2 sm:px-4 py-2 min-h-[44px] flex items-center gap-1 sm:gap-2 text-gray-600 hover:bg-gray-50 rounded-r-lg transition border-l border-gray-200"
      >
        <ClipboardList class="w-5 h-5" />
        <span class="hidden sm:inline">Todo List</span>
        <span class="bg-blue-600 text-white text-xs px-2 py-0.5 rounded-full">
          {{ todos.length }}
        </span>
      </button>
    </div>

    <!-- Month Control -->
    <div class="flex flex-col sm:flex-row items-center justify-between gap-2 mb-4">
      <!-- Left: Member name (for friend's calendar) or Spacer -->
      <div class="hidden sm:block w-32">
        <h1 v-if="!isMyCalendar && memberName" class="text-lg font-bold text-gray-800 truncate">
          {{ memberName }}
        </h1>
      </div>
      <!-- Mobile: Member name shown above navigation -->
      <h1 v-if="!isMyCalendar && memberName" class="sm:hidden text-lg font-bold text-gray-800 truncate w-full text-center">
        {{ memberName }}
      </h1>

      <!-- Center: Year-Month Navigation -->
      <div class="flex items-center justify-center">
        <button @click="prevMonth" class="p-2 min-w-[44px] min-h-[44px] hover:bg-gray-100 rounded-full transition flex items-center justify-center">
          <ChevronLeft class="w-5 h-5" />
        </button>
        <button
          @click="isYearMonthPickerOpen = true"
          class="px-2 sm:px-3 py-1 text-base sm:text-lg font-semibold hover:bg-gray-100 rounded transition min-w-[100px] sm:min-w-[120px] min-h-[44px]"
        >
          {{ currentYear }}-{{ String(currentMonth).padStart(2, '0') }}
        </button>
        <button @click="nextMonth" class="p-2 min-w-[44px] min-h-[44px] hover:bg-gray-100 rounded-full transition flex items-center justify-center">
          <ChevronRight class="w-5 h-5" />
        </button>
      </div>

      <!-- Right: Search -->
      <div class="flex items-center w-full sm:w-32 justify-center sm:justify-end">
        <input
          v-model="searchQuery"
          type="text"
          placeholder="검색"
          @keyup.enter="handleSearch()"
          class="px-3 py-1.5 min-h-[44px] border border-gray-300 rounded-l-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent w-full sm:w-24 max-w-[200px]"
        />
        <button
          @click="handleSearch()"
          class="px-3 py-1.5 min-h-[44px] min-w-[44px] bg-gray-800 text-white rounded-r-lg hover:bg-gray-700 transition flex items-center justify-center"
        >
          <Search class="w-4 h-4" />
        </button>
      </div>
    </div>

    <!-- Duty Types & Buttons -->
    <div class="flex flex-wrap items-center justify-between gap-2 mb-4">
      <div class="flex flex-wrap items-center gap-2 sm:gap-4">
        <template v-if="dutyTypes.length > 0">
          <div v-for="dutyType in dutyTypes" :key="dutyType.name" class="flex items-center gap-1">
            <span
              class="w-4 h-4 rounded border-2 border-gray-200"
              :style="{ backgroundColor: dutyType.color || '#6c757d' }"
            ></span>
            <span class="text-xs sm:text-sm text-gray-600">{{ dutyType.name }}</span>
            <span class="text-xs sm:text-sm font-bold text-gray-800">{{ dutyType.cnt }}</span>
          </div>
        </template>
        <span v-else-if="isLoadingDuties" class="text-sm text-gray-400">
          <Loader2 class="w-4 h-4 animate-spin inline mr-1" />
          로딩 중...
        </span>
        <span v-else class="text-sm text-gray-400">
          근무 타입 정보 없음
        </span>
      </div>
      <div class="flex flex-wrap gap-2">
        <button
          @click="isOtherDutiesModalOpen = true"
          class="px-2 sm:px-3 py-1.5 min-h-[44px] border rounded-lg text-xs sm:text-sm hover:bg-gray-50 transition flex items-center gap-1"
          :class="selectedFriendIds.length > 0 ? 'border-blue-500 bg-blue-50 text-blue-700' : 'border-gray-300'"
        >
          <Users class="w-4 h-4" />
          <span class="hidden xs:inline">함께보기</span>
          <span v-if="selectedFriendIds.length > 0" class="text-xs">
            ({{ selectedFriendIds.length }})
          </span>
        </button>
        <button
          v-if="isMyCalendar"
          @click="batchEditMode = !batchEditMode"
          class="px-2 sm:px-3 py-1.5 min-h-[44px] border rounded-lg text-xs sm:text-sm transition"
          :class="batchEditMode ? 'border-orange-500 bg-orange-50 text-orange-700' : 'border-gray-300 hover:bg-gray-50'"
        >
          편집모드
        </button>
      </div>
    </div>

    <!-- Calendar Grid -->
    <div class="bg-white rounded-lg border border-gray-300 overflow-hidden mb-4 shadow-sm">
      <!-- Week Days Header -->
      <div class="grid grid-cols-7 bg-gray-100">
        <div
          v-for="(day, idx) in weekDays"
          :key="day"
          class="py-2 text-center font-bold border-b border-gray-300 text-sm"
          :class="{
            'text-red-500': idx === 0,
            'text-blue-500': idx === 6,
          }"
        >
          {{ day }}
        </div>
      </div>

      <!-- Calendar Days -->
      <div class="grid grid-cols-7">
        <div
          v-for="(day, idx) in calendarDays"
          :key="idx"
          @click="handleDayClick(day, idx)"
          class="min-h-[60px] sm:min-h-[80px] md:min-h-[100px] border-b border-r border-gray-200 p-0.5 sm:p-1 transition relative"
          :class="{
            'opacity-40 bg-gray-50': !day.isCurrentMonth,
            'ring-2 ring-red-500 ring-inset': day.isToday,
            'cursor-pointer hover:bg-gray-50': isMyCalendar,
          }"
          :style="day.isCurrentMonth && duties[idx]?.dutyColor ? { backgroundColor: duties[idx].dutyColor + '80' } : {}"
        >
          <!-- Day Number -->
          <div class="flex items-center justify-between">
            <span
              class="text-sm font-medium"
              :class="{
                'text-red-500': idx % 7 === 0,
                'text-blue-500': idx % 7 === 6,
                'font-bold': day.isToday,
              }"
            >
              {{ day.day }}
            </span>
            <!-- D-Day indicator -->
            <span
              v-if="pinnedDDay && day.isCurrentMonth"
              class="text-xs text-gray-500 font-medium"
            >
              {{ calcDDayForDay(day) }}
            </span>
          </div>

          <!-- Schedules -->
          <div class="mt-1 space-y-0.5">
            <div
              v-for="schedule in schedulesByDays[idx]?.slice(0, 2)"
              :key="schedule.id"
              class="text-xs truncate text-gray-700 bg-white/60 rounded px-1 flex items-center gap-0.5"
            >
              <Lock v-if="schedule.visibility === 'PRIVATE'" class="w-3 h-3 text-gray-400 flex-shrink-0" />
              <span class="truncate">{{ schedule.contentWithoutTime || schedule.content }}</span>
              <span class="text-gray-400 flex-shrink-0">{{ formatScheduleTime(schedule) }}</span>
              <button
                v-if="schedule.description || schedule.attachments?.length"
                @click.stop="handleShowDescription(schedule)"
                class="flex-shrink-0 text-blue-500 hover:text-blue-700"
                title="상세보기"
              >
                <FileText class="w-3 h-3" />
              </button>
              <span v-if="schedule.isTagged" class="flex-shrink-0 text-[10px] bg-gray-200 text-gray-600 px-1 rounded-full whitespace-nowrap">by{{ schedule.owner }}</span>
            </div>
            <div
              v-if="(schedulesByDays[idx]?.length ?? 0) > 2"
              class="text-xs text-gray-400"
            >
              +{{ (schedulesByDays[idx]?.length ?? 0) - 2 }} more
            </div>
          </div>

          <!-- D-Days on this date -->
          <div v-if="day.isCurrentMonth && getDDaysForDay(day).length > 0" class="mt-1 space-y-0.5">
            <div
              v-for="dday in getDDaysForDay(day)"
              :key="dday.id"
              class="text-xs truncate text-gray-600 bg-gray-100 rounded px-1"
            >
              <Lock v-if="dday.isPrivate" class="w-3 h-3 inline-block" />
              <CalendarCheck v-else class="w-3 h-3 inline-block" />
              {{ dday.title }}
            </div>
          </div>

          <!-- Other Duties (함께보기) -->
          <div v-if="otherDuties.length > 0 && day.isCurrentMonth" class="mt-1 space-y-0.5">
            <div
              v-for="otherDuty in otherDuties"
              :key="otherDuty.memberId"
              class="text-xs px-1.5 py-0.5 rounded-full border border-gray-300 bg-white inline-block mr-1"
            >
              {{ otherDuty.memberName }}:{{ getOtherDutyForDay(day, otherDuty)?.dutyType || '-' }}
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- D-Day List -->
    <div class="bg-white rounded-lg border border-gray-200 p-3 sm:p-4 shadow-sm">
      <h3 class="text-sm font-medium text-gray-700 mb-3">D-Day</h3>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2 sm:gap-3">
        <div
          v-for="dday in dDays"
          :key="dday.id"
          class="bg-gray-50 rounded-lg p-3 border border-gray-200 cursor-pointer hover:bg-gray-100 transition min-h-[44px]"
          :class="{ 'ring-2 ring-blue-500': pinnedDDay?.id === dday.id }"
          @click="togglePinnedDDay(dday)"
        >
          <div class="flex justify-between items-start mb-2">
            <span
              class="text-sm font-bold"
              :class="dday.calc <= 0 ? 'text-gray-500' : 'text-blue-600'"
            >
              {{ dday.dDayText }}
            </span>
            <div v-if="isMyCalendar" class="flex gap-1">
              <button
                @click.stop="openDDayModal(dday)"
                class="text-gray-400 hover:text-gray-600 p-1.5 min-w-[44px] min-h-[44px] -m-1.5 flex items-center justify-center"
              >
                <Pencil class="w-4 h-4" />
              </button>
              <button
                @click.stop="deleteDDay(dday)"
                class="text-gray-400 hover:text-red-600 p-1.5 min-w-[44px] min-h-[44px] -m-1.5 flex items-center justify-center"
              >
                <Trash2 class="w-4 h-4" />
              </button>
            </div>
          </div>
          <p class="text-xs text-gray-500 mb-1">{{ dday.date }}</p>
          <p class="text-sm text-gray-800 font-medium truncate flex items-center gap-1">
            <Lock v-if="dday.isPrivate" class="w-3 h-3 flex-shrink-0" />
            <span class="truncate">{{ dday.title }}</span>
          </p>
        </div>

        <!-- Add D-Day Button (only for my calendar) -->
        <div
          v-if="isMyCalendar"
          @click="openDDayModal()"
          class="bg-gray-50 rounded-lg p-3 border-2 border-dashed border-gray-300 cursor-pointer hover:bg-blue-50 hover:border-blue-400 transition flex flex-col items-center justify-center min-h-[80px] sm:min-h-[100px]"
        >
          <Plus class="w-6 h-6 text-gray-400 mb-1" />
          <span class="text-sm text-gray-500">디데이 추가</span>
        </div>
      </div>
    </div>

    <!-- Modals -->
    <DayDetailModal
      :is-open="isDayDetailModalOpen"
      :date="selectedDay || { year: currentYear, month: currentMonth, day: 1 }"
      :duty="selectedDayDuty"
      :schedules="selectedDay ? (schedulesByDays[calendarDays.findIndex(d => d.year === selectedDay!.year && d.month === selectedDay!.month && d.day === selectedDay!.day)] ?? []) : []"
      :duty-types="dutyTypes"
      :is-my-calendar="isMyCalendar"
      :batch-edit-mode="batchEditMode"
      :friends="friends"
      @close="isDayDetailModalOpen = false"
      @create-schedule="handleCreateSchedule"
      @edit-schedule="handleEditSchedule"
      @delete-schedule="handleDeleteSchedule"
      @swap-schedule="handleSwapSchedule"
      @add-tag="isDayDetailModalOpen = false"
      @remove-tag="isDayDetailModalOpen = false"
      @change-duty-type="handleChangeDutyType"
    />

    <ScheduleDetailModal
      :is-open="isScheduleDetailModalOpen"
      :schedule="selectedScheduleForDetail"
      @close="isScheduleDetailModalOpen = false"
    />

    <TodoAddModal
      :is-open="isTodoAddModalOpen"
      @close="isTodoAddModalOpen = false"
      @save="handleTodoAdd"
    />

    <TodoDetailModal
      :is-open="isTodoDetailModalOpen"
      :todo="selectedTodo"
      @close="isTodoDetailModalOpen = false"
      @update="handleTodoUpdate"
      @complete="handleTodoComplete"
      @reopen="handleTodoReopen"
      @delete="handleTodoDelete"
    />

    <TodoOverviewModal
      :is-open="isTodoOverviewModalOpen"
      :todos="todos"
      :completed-todos="completedTodos"
      @close="isTodoOverviewModalOpen = false"
      @show-detail="(todo: LocalTodo) => { selectedTodo = todo; isTodoDetailModalOpen = true; isTodoOverviewModalOpen = false; }"
      @complete="handleTodoComplete"
      @reopen="handleTodoReopen"
      @delete="handleTodoDelete"
      @reorder="handleTodoPositionUpdate"
    />

    <DDayModal
      :is-open="isDDayModalOpen"
      :dday="selectedDDay"
      @close="isDDayModalOpen = false"
      @save="handleDDaySave"
    />

    <SearchResultModal
      :is-open="isSearchResultModalOpen"
      :query="searchQuery"
      :results="searchResults"
      :page-info="searchPageInfo"
      @close="isSearchResultModalOpen = false"
      @go-to-date="handleSearchGoToDate"
      @change-page="handleSearchPageChange"
    />

    <OtherDutiesModal
      :is-open="isOtherDutiesModalOpen"
      :friends="friends"
      :selected-friend-ids="selectedFriendIds"
      @close="isOtherDutiesModalOpen = false"
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
