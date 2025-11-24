<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
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
  RotateCcw,
  Loader2,
} from 'lucide-vue-next'

// Modal Components
import DayDetailModal from '@/components/duty/DayDetailModal.vue'
import TodoAddModal from '@/components/duty/TodoAddModal.vue'
import TodoDetailModal from '@/components/duty/TodoDetailModal.vue'
import TodoOverviewModal from '@/components/duty/TodoOverviewModal.vue'
import DDayModal from '@/components/duty/DDayModal.vue'
import SearchResultModal from '@/components/duty/SearchResultModal.vue'
import OtherDutiesModal from '@/components/duty/OtherDutiesModal.vue'

// API
import { todoApi } from '@/api/todo'
import { dutyApi } from '@/api/duty'
import { ddayApi } from '@/api/member'
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
const isYearMonthPickerOpen = ref(false)

// Year-Month Picker
const pickerYear = ref(currentYear.value)
const pickerMonth = ref(currentMonth.value)
const monthNames = ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월']

function openYearMonthPicker() {
  pickerYear.value = currentYear.value
  pickerMonth.value = currentMonth.value
  isYearMonthPickerOpen.value = true
}

function selectYearMonth(month: number) {
  currentYear.value = pickerYear.value
  currentMonth.value = month
  isYearMonthPickerOpen.value = false
}

function pickerPrevYear() {
  pickerYear.value--
}

function pickerNextYear() {
  pickerYear.value++
}

// Selected items
const selectedDay = ref<CalendarDay | null>(null)
const selectedDayDuty = ref<{ dutyType: string; dutyColor: string } | undefined>(undefined)
const selectedTodo = ref<LocalTodo | null>(null)
const selectedDDay = ref<LocalDDay | null>(null)
const pinnedDDay = ref<LocalDDay | null>(null)

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
      originalFilename: a.originalFileName,
      contentType: 'application/octet-stream', // Default, actual type not provided
      size: 0, // Default, actual size not provided
      thumbnailUrl: a.thumbnailAvailable ? `/api/attachments/${a.id}/thumbnail` : undefined,
      hasThumbnail: a.thumbnailAvailable,
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

// Initialize on mount
onMounted(async () => {
  isLoading.value = true
  loadError.value = null

  try {
    // Get member info from auth store
    if (isMyCalendar.value && authStore.user) {
      memberName.value = authStore.user.name
      teamId.value = authStore.user.teamId
    }

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
    alert('D-Day 저장에 실패했습니다.')
  }
  isDDayModalOpen.value = false
}

async function deleteDDay(dday: LocalDDay) {
  if (!confirm(`[${dday.title}]을(를) 정말로 삭제하시겠습니까?`)) return

  try {
    await ddayApi.deleteDDay(dday.id)
    dDays.value = dDays.value.filter((d) => d.id !== dday.id)
    if (pinnedDDay.value?.id === dday.id) {
      pinnedDDay.value = null
      localStorage.removeItem(`selectedDday_${memberId.value}`)
    }
  } catch (error) {
    console.error('Failed to delete D-Day:', error)
    alert('D-Day 삭제에 실패했습니다.')
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
    alert('할 일 수정에 실패했습니다.')
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
    alert('할 일 완료 처리에 실패했습니다.')
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
    alert('할 일 재오픈에 실패했습니다.')
  }
  isTodoDetailModalOpen.value = false
}

async function handleTodoDelete(id: string) {
  if (!confirm('할 일을 삭제하시겠습니까?')) return
  try {
    await todoApi.deleteTodo(id)
    todos.value = todos.value.filter((t) => t.id !== id)
    completedTodos.value = completedTodos.value.filter((t) => t.id !== id)
  } catch (error) {
    console.error('Failed to delete todo:', error)
    alert('할 일 삭제에 실패했습니다.')
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
    alert('할 일 추가에 실패했습니다.')
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
    alert('할 일 순서 변경에 실패했습니다.')
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
    alert('검색에 실패했습니다.')
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
        class="flex-shrink-0 w-24 bg-green-500 text-white rounded-l-lg flex items-center justify-center gap-1 border-r border-gray-300 hover:bg-green-600 transition"
      >
        <span class="text-sm font-medium">Todo</span>
        <Plus class="w-4 h-4" />
      </button>

      <!-- Todo Items -->
      <div class="flex-1 overflow-x-auto py-2 px-2">
        <div class="flex gap-2">
          <div
            v-for="todo in todos"
            :key="todo.id"
            @click="openTodoDetail(todo)"
            class="flex-shrink-0 flex items-center bg-gray-50 border border-gray-200 rounded-lg px-3 py-2 cursor-pointer hover:bg-gray-100 transition"
          >
            <span class="font-medium text-gray-800">{{ todo.title }}</span>
            <FileText v-if="todo.content || todo.hasAttachments" class="w-4 h-4 text-gray-400 ml-1" />
          </div>
        </div>
      </div>

      <!-- Todo Count Badge -->
      <button
        @click="isTodoOverviewModalOpen = true"
        class="flex-shrink-0 px-4 py-2 flex items-center gap-2 text-gray-600 hover:bg-gray-50 rounded-r-lg transition border-l border-gray-200"
      >
        <ClipboardList class="w-5 h-5" />
        <span class="hidden sm:inline">Todo List</span>
        <span class="bg-blue-600 text-white text-xs px-2 py-0.5 rounded-full">
          {{ todos.length }}
        </span>
      </button>
    </div>

    <!-- Month Control -->
    <div class="flex items-center justify-between gap-2 mb-4">
      <!-- Left: Today Button -->
      <div class="flex items-center gap-2 w-32">
        <button
          @click="goToToday"
          class="px-3 py-1.5 bg-sky-300 text-gray-800 rounded-full text-sm font-medium hover:bg-sky-400 transition flex items-center gap-1"
        >
          <RotateCcw class="w-3.5 h-3.5" />
          Today
        </button>
      </div>

      <!-- Center: Year-Month Navigation -->
      <div class="flex items-center justify-center flex-1">
        <button @click="prevMonth" class="p-2 hover:bg-gray-100 rounded-full transition">
          <ChevronLeft class="w-5 h-5" />
        </button>
        <button
          @click="openYearMonthPicker"
          class="px-3 py-1 text-lg font-semibold hover:bg-gray-100 rounded transition min-w-[120px]"
        >
          {{ currentYear }}-{{ String(currentMonth).padStart(2, '0') }}
        </button>
        <button @click="nextMonth" class="p-2 hover:bg-gray-100 rounded-full transition">
          <ChevronRight class="w-5 h-5" />
        </button>
      </div>

      <!-- Right: Search -->
      <div class="flex items-center w-32 justify-end">
        <input
          v-model="searchQuery"
          type="text"
          placeholder="검색"
          @keyup.enter="handleSearch()"
          class="px-3 py-1.5 border border-gray-300 rounded-l-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent w-24"
        />
        <button
          @click="handleSearch()"
          class="px-3 py-1.5 bg-gray-800 text-white rounded-r-lg hover:bg-gray-700 transition"
        >
          <Search class="w-4 h-4" />
        </button>
      </div>
    </div>

    <!-- Duty Types & Buttons -->
    <div class="flex flex-wrap items-center justify-between gap-2 mb-4">
      <div class="flex items-center gap-4">
        <template v-if="dutyTypes.length > 0">
          <div v-for="dutyType in dutyTypes" :key="dutyType.name" class="flex items-center gap-1">
            <span
              class="w-4 h-4 rounded border-2 border-gray-200"
              :style="{ backgroundColor: dutyType.color || '#6c757d' }"
            ></span>
            <span class="text-sm text-gray-600">{{ dutyType.name }}</span>
            <span class="text-sm font-bold text-gray-800">{{ dutyType.cnt }}</span>
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
      <div class="flex gap-2">
        <button
          @click="isOtherDutiesModalOpen = true"
          class="px-3 py-1.5 border rounded-lg text-sm hover:bg-gray-50 transition flex items-center gap-1"
          :class="selectedFriendIds.length > 0 ? 'border-blue-500 bg-blue-50 text-blue-700' : 'border-gray-300'"
        >
          <Users class="w-4 h-4" />
          함께보기
          <span v-if="selectedFriendIds.length > 0" class="text-xs">
            ({{ selectedFriendIds.length }})
          </span>
        </button>
        <button
          v-if="isMyCalendar"
          @click="batchEditMode = !batchEditMode"
          class="px-3 py-1.5 border rounded-lg text-sm transition"
          :class="batchEditMode ? 'border-orange-500 bg-orange-50 text-orange-700' : 'border-gray-300 hover:bg-gray-50'"
        >
          편집모드
        </button>
      </div>
    </div>

    <!-- Pinned D-Day Display -->
    <div v-if="pinnedDDay" class="mb-4 p-3 bg-gradient-to-r from-blue-50 to-indigo-50 rounded-lg border border-blue-200">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <Star class="w-5 h-5 text-yellow-500 fill-yellow-500" />
          <span class="font-bold text-blue-700">{{ pinnedDDay.dDayText }}</span>
          <span class="text-gray-600">{{ pinnedDDay.title }}</span>
        </div>
        <span class="text-sm text-gray-500">{{ pinnedDDay.date }}</span>
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
          class="min-h-[80px] sm:min-h-[100px] border-b border-r border-gray-200 p-1 cursor-pointer hover:bg-gray-50 transition relative"
          :class="{
            'opacity-40 bg-gray-50': !day.isCurrentMonth,
            'ring-2 ring-red-500 ring-inset': day.isToday,
          }"
          :style="day.isCurrentMonth && duties[idx] ? { backgroundColor: duties[idx]?.dutyColor + '15' } : {}"
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
              class="text-xs text-purple-600 font-medium"
            >
              {{ calcDDayForDay(day) }}
            </span>
          </div>

          <!-- Schedules -->
          <div class="mt-1 space-y-0.5">
            <div
              v-for="schedule in schedulesByDays[idx]?.slice(0, 2)"
              :key="schedule.id"
              class="text-xs truncate text-gray-700 bg-white/60 rounded px-1"
            >
              <span v-if="schedule.isTagged" class="text-gray-400 mr-0.5">{{ schedule.visibility === 'PRIVATE' ? '🔒' : '' }}</span>
              {{ schedule.contentWithoutTime || schedule.content }}
              <span class="text-gray-400">{{ formatScheduleTime(schedule) }}</span>
              <span v-if="schedule.isTagged" class="ml-1 text-[10px] bg-gray-200 text-gray-600 px-1 rounded-full whitespace-nowrap">by{{ schedule.owner }}</span>
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
              class="text-xs truncate text-purple-600 bg-purple-50 rounded px-1"
            >
              🎯 {{ dday.title }}
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
    <div class="bg-white rounded-lg border border-gray-200 p-4 shadow-sm">
      <h3 class="text-sm font-medium text-gray-700 mb-3">D-Day</h3>
      <div class="grid grid-cols-2 gap-3">
        <div
          v-for="dday in dDays"
          :key="dday.id"
          class="bg-gray-50 rounded-lg p-3 border border-gray-200 cursor-pointer hover:bg-gray-100 transition"
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
            <div class="flex gap-1">
              <button
                @click.stop="openDDayModal(dday)"
                class="text-gray-400 hover:text-gray-600 p-1"
              >
                <Pencil class="w-4 h-4" />
              </button>
              <button
                @click.stop="deleteDDay(dday)"
                class="text-gray-400 hover:text-red-600 p-1"
              >
                <Trash2 class="w-4 h-4" />
              </button>
            </div>
          </div>
          <p class="text-xs text-gray-500 mb-1">{{ dday.date }}</p>
          <p class="text-sm text-gray-800 font-medium truncate">{{ dday.title }}</p>
        </div>

        <!-- Add D-Day Button -->
        <div
          @click="openDDayModal()"
          class="bg-gray-50 rounded-lg p-3 border-2 border-dashed border-gray-300 cursor-pointer hover:bg-blue-50 hover:border-blue-400 transition flex flex-col items-center justify-center min-h-[100px]"
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
      @create-schedule="isDayDetailModalOpen = false"
      @edit-schedule="isDayDetailModalOpen = false"
      @delete-schedule="isDayDetailModalOpen = false"
      @swap-schedule="isDayDetailModalOpen = false"
      @add-tag="isDayDetailModalOpen = false"
      @remove-tag="isDayDetailModalOpen = false"
      @show-description="isDayDetailModalOpen = false"
      @change-duty-type="isDayDetailModalOpen = false"
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

    <!-- Year-Month Picker Modal -->
    <Teleport to="body">
      <div
        v-if="isYearMonthPickerOpen"
        class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
        @click.self="isYearMonthPickerOpen = false"
      >
        <div class="bg-white rounded-xl shadow-xl w-full max-w-sm">
          <!-- Year Navigation -->
          <div class="flex items-center justify-between p-4 border-b border-gray-200">
            <button
              @click="pickerPrevYear"
              class="p-2 hover:bg-gray-100 rounded-full transition"
            >
              <ChevronLeft class="w-5 h-5" />
            </button>
            <span class="text-xl font-bold text-gray-900">{{ pickerYear }}년</span>
            <button
              @click="pickerNextYear"
              class="p-2 hover:bg-gray-100 rounded-full transition"
            >
              <ChevronRight class="w-5 h-5" />
            </button>
          </div>

          <!-- Month Grid -->
          <div class="p-4">
            <div class="grid grid-cols-4 gap-2">
              <button
                v-for="(name, idx) in monthNames"
                :key="idx"
                @click="selectYearMonth(idx + 1)"
                class="py-3 px-2 rounded-lg text-sm font-medium transition"
                :class="
                  pickerYear === currentYear && idx + 1 === currentMonth
                    ? 'bg-blue-600 text-white'
                    : 'hover:bg-gray-100 text-gray-700'
                "
              >
                {{ name }}
              </button>
            </div>
          </div>

          <!-- Close Button -->
          <div class="p-4 border-t border-gray-200">
            <button
              @click="isYearMonthPickerOpen = false"
              class="w-full px-4 py-2 bg-gray-100 hover:bg-gray-200 rounded-lg text-gray-700 font-medium transition"
            >
              닫기
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
