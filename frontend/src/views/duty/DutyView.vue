<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
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
  GripVertical,
  FileText,
  Star,
  RotateCcw,
} from 'lucide-vue-next'

// Modal Components
import DayDetailModal from '@/components/duty/DayDetailModal.vue'
import TodoAddModal from '@/components/duty/TodoAddModal.vue'
import TodoDetailModal from '@/components/duty/TodoDetailModal.vue'
import TodoOverviewModal from '@/components/duty/TodoOverviewModal.vue'
import DDayModal from '@/components/duty/DDayModal.vue'
import SearchResultModal from '@/components/duty/SearchResultModal.vue'
import OtherDutiesModal from '@/components/duty/OtherDutiesModal.vue'

// Types
interface Todo {
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
  color: string
  cnt?: number
}

interface Schedule {
  id: string
  content: string
  contentWithoutTime?: string
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
  daysFromStart?: number
  totalDays?: number
}

interface DDay {
  id: number
  title: string
  date: string
  isPrivate: boolean
  calc: number
  dDayText?: string
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
const currentYear = ref(2025)
const currentMonth = ref(11)
const memberName = ref('박세현')
const memberId = ref(route.params.id as string || 'me')
// isMyCalendar: true if viewing own calendar (no id param, or id matches logged-in user)
const isMyCalendar = computed(() => {
  const paramId = route.params.id as string | undefined
  if (!paramId || paramId === 'me') return true
  // Compare with logged-in user's ID
  const loggedInUserId = authStore.user?.id
  return loggedInUserId !== undefined && String(loggedInUserId) === paramId
})
const amIManager = ref(false)

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
const selectedTodo = ref<Todo | null>(null)
const selectedDDay = ref<DDay | null>(null)
const pinnedDDay = ref<DDay | null>(null)

// Data
const todos = ref<Todo[]>([
  {
    id: '1',
    title: 'API 문서 작성',
    content: 'REST API 문서 Swagger로 작성하기',
    status: 'ACTIVE',
    createdDate: '2025-11-20T10:00:00',
    hasAttachments: false,
    attachments: [],
  },
  {
    id: '2',
    title: '프론트엔드 리팩토링',
    content: 'Vue 3 Composition API로 마이그레이션',
    status: 'ACTIVE',
    createdDate: '2025-11-18T14:30:00',
    hasAttachments: true,
    attachments: [
      {
        id: 'att1',
        name: 'migration-plan.pdf',
        originalFilename: 'migration-plan.pdf',
        size: 1024000,
        contentType: 'application/pdf',
        isImage: false,
        hasThumbnail: false,
        downloadUrl: '/api/attachments/att1/download',
      },
    ],
  },
  {
    id: '3',
    title: '테스트 코드 추가',
    content: '',
    status: 'ACTIVE',
    createdDate: '2025-11-15T09:00:00',
    hasAttachments: false,
    attachments: [],
  },
])

const completedTodos = ref<Todo[]>([
  {
    id: '4',
    title: '로그인 버그 수정',
    content: '세션 만료 시 리다이렉트 이슈',
    status: 'COMPLETED',
    createdDate: '2025-11-10T11:00:00',
    completedDate: '2025-11-12T16:00:00',
    hasAttachments: false,
    attachments: [],
  },
])

const dutyTypes = ref<DutyType[]>([
  { id: null, name: 'OFF', color: '#6c757d', cnt: 10 },
  { id: 1, name: '출근', color: '#0d6efd', cnt: 15 },
  { id: 2, name: '야근', color: '#dc3545', cnt: 5 },
])

const dDays = ref<DDay[]>([
  { id: 1, title: '루나 생일', date: '2023-09-13', isPrivate: false, calc: -804, dDayText: 'D+804' },
  { id: 2, title: '정수기 필터교체', date: '2025-12-19', isPrivate: false, calc: 25, dDayText: 'D-25' },
  { id: 3, title: '최근 세차', date: '2025-08-23', isPrivate: true, calc: -93, dDayText: 'D+93' },
  { id: 4, title: 'dutypark-ssl 갱신', date: '2026-02-20', isPrivate: false, calc: 88, dDayText: 'D-88' },
])

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

// Dummy duties for each day
const duties = computed(() => {
  return calendarDays.value.map((day, idx) => {
    if (!day.isCurrentMonth) return null
    const dayNum = day.day
    if (dayNum % 7 === 0) return { dutyType: 'OFF', dutyColor: '#6c757d', dutyTypeId: null }
    if (dayNum % 7 === 6) return { dutyType: '야근', dutyColor: '#dc3545', dutyTypeId: 2 }
    return { dutyType: '출근', dutyColor: '#0d6efd', dutyTypeId: 1 }
  })
})

// Initialize schedules
onMounted(() => {
  // Create empty schedule arrays for each day
  schedulesByDays.value = calendarDays.value.map(() => [])

  // Add some dummy schedules
  const todayIndex = calendarDays.value.findIndex(
    (d) => d.isCurrentMonth && d.day === 24
  )
  if (todayIndex >= 0) {
    schedulesByDays.value[todayIndex] = [
      {
        id: 's1',
        content: '팀 미팅',
        description: '주간 업무 보고 및 다음 주 계획 수립',
        startDateTime: '2025-11-24T10:00:00',
        endDateTime: '2025-11-24T11:00:00',
        visibility: 'FAMILY',
        isMine: true,
        isTagged: false,
        attachments: [],
        tags: [{ id: 1, name: '김철수' }],
      },
      {
        id: 's2',
        content: '점심 약속',
        startDateTime: '2025-11-24T12:00:00',
        endDateTime: '2025-11-24T13:00:00',
        visibility: 'PRIVATE',
        isMine: true,
        isTagged: false,
      },
    ]
  }

  // Add schedule on day 26
  const day26Index = calendarDays.value.findIndex(
    (d) => d.isCurrentMonth && d.day === 26
  )
  if (day26Index >= 0) {
    schedulesByDays.value[day26Index] = [
      {
        id: 's3',
        content: '프로젝트 마감',
        description: '1차 버전 릴리즈',
        startDateTime: '2025-11-26T00:00:00',
        endDateTime: '2025-11-26T23:59:00',
        visibility: 'FAMILY',
        isMine: true,
        isTagged: false,
        attachments: [
          {
            id: 'a1',
            originalFilename: 'release-notes.pdf',
            contentType: 'application/pdf',
            size: 512000,
            hasThumbnail: false,
          },
        ],
      },
    ]
  }

  // Set pinned DDay
  const storedDDay = localStorage.getItem(`selectedDday_${memberId.value}`)
  if (storedDDay) {
    const id = parseInt(storedDDay)
    pinnedDDay.value = dDays.value.find((d) => d.id === id) || null
  }
})

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
function togglePinnedDDay(dday: DDay) {
  if (pinnedDDay.value?.id === dday.id) {
    pinnedDDay.value = null
    localStorage.removeItem(`selectedDday_${memberId.value}`)
  } else {
    pinnedDDay.value = dday
    localStorage.setItem(`selectedDday_${memberId.value}`, String(dday.id))
  }
}

function openDDayModal(dday?: DDay) {
  selectedDDay.value = dday || null
  isDDayModalOpen.value = true
}

function handleDDaySave(dday: { id?: number; title: string; date: string; isPrivate: boolean }) {
  if (dday.id) {
    // Update existing
    const idx = dDays.value.findIndex((d) => d.id === dday.id)
    const existing = dDays.value[idx]
    if (idx >= 0 && existing) {
      existing.title = dday.title
      existing.date = dday.date
      existing.isPrivate = dday.isPrivate
    }
  } else {
    // Create new
    const newId = Math.max(...dDays.value.map((d) => d.id)) + 1
    const today = new Date()
    const targetDate = new Date(dday.date)
    const diffDays = Math.ceil((targetDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24))
    dDays.value.push({
      ...dday,
      id: newId,
      calc: diffDays,
      dDayText: diffDays <= 0 ? `D+${Math.abs(diffDays)}` : `D-${diffDays}`,
    })
  }
  isDDayModalOpen.value = false
}

function deleteDDay(dday: DDay) {
  if (confirm(`[${dday.title}]을(를) 정말로 삭제하시겠습니까?`)) {
    dDays.value = dDays.value.filter((d) => d.id !== dday.id)
    if (pinnedDDay.value?.id === dday.id) {
      pinnedDDay.value = null
      localStorage.removeItem(`selectedDday_${memberId.value}`)
    }
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

// Todo handlers
function openTodoDetail(todo: Todo) {
  selectedTodo.value = todo
  isTodoDetailModalOpen.value = true
}

function handleTodoUpdate(data: { id: string; title: string; content: string }) {
  const todo = todos.value.find((t) => t.id === data.id)
  if (todo) {
    todo.title = data.title
    todo.content = data.content
  }
  isTodoDetailModalOpen.value = false
}

function handleTodoComplete(id: string) {
  const idx = todos.value.findIndex((t) => t.id === id)
  if (idx >= 0) {
    const todo = todos.value.splice(idx, 1)[0]
    if (todo) {
      todo.status = 'COMPLETED'
      todo.completedDate = new Date().toISOString()
      completedTodos.value.unshift(todo)
    }
  }
  isTodoDetailModalOpen.value = false
}

function handleTodoReopen(id: string) {
  const idx = completedTodos.value.findIndex((t) => t.id === id)
  if (idx >= 0) {
    const todo = completedTodos.value.splice(idx, 1)[0]
    if (todo) {
      todo.status = 'ACTIVE'
      todo.completedDate = undefined
      todos.value.push(todo)
    }
  }
  isTodoDetailModalOpen.value = false
}

function handleTodoDelete(id: string) {
  if (!confirm('할 일을 삭제하시겠습니까?')) return
  todos.value = todos.value.filter((t) => t.id !== id)
  completedTodos.value = completedTodos.value.filter((t) => t.id !== id)
  isTodoDetailModalOpen.value = false
}

function handleTodoAdd(data: { title: string; content: string }) {
  const newTodo: Todo = {
    id: `t${Date.now()}`,
    title: data.title,
    content: data.content,
    status: 'ACTIVE',
    createdDate: new Date().toISOString(),
    hasAttachments: false,
    attachments: [],
  }
  todos.value.unshift(newTodo)
  isTodoAddModalOpen.value = false
}

// Search handler
function handleSearch() {
  if (!searchQuery.value.trim()) return
  // Dummy search results
  searchResults.value = [
    {
      id: 'sr1',
      content: '팀 미팅',
      description: '주간 업무 보고',
      startDateTime: '2025-11-24T10:00:00',
      endDateTime: '2025-11-24T11:00:00',
      hasAttachments: false,
    },
    {
      id: 'sr2',
      content: '프로젝트 마감',
      description: '1차 버전 릴리즈',
      startDateTime: '2025-11-26T00:00:00',
      endDateTime: '2025-11-26T23:59:00',
      hasAttachments: true,
    },
  ]
  searchPageInfo.value = {
    pageNumber: 0,
    pageSize: 10,
    totalPages: 1,
    totalElements: 2,
  }
  isSearchResultModalOpen.value = true
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
            <span class="text-gray-400 mr-2 cursor-grab">
              <GripVertical class="w-4 h-4" />
            </span>
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
          @keyup.enter="handleSearch"
          class="px-3 py-1.5 border border-gray-300 rounded-l-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent w-24"
        />
        <button
          @click="handleSearch"
          class="px-3 py-1.5 bg-gray-800 text-white rounded-r-lg hover:bg-gray-700 transition"
        >
          <Search class="w-4 h-4" />
        </button>
      </div>
    </div>

    <!-- Duty Types & Buttons -->
    <div class="flex flex-wrap items-center justify-between gap-2 mb-4">
      <div class="flex items-center gap-4">
        <div v-for="dutyType in dutyTypes" :key="dutyType.name" class="flex items-center gap-1">
          <span
            class="w-4 h-4 rounded border-2 border-gray-200"
            :style="{ backgroundColor: dutyType.color }"
          ></span>
          <span class="text-sm text-gray-600">{{ dutyType.name }}</span>
          <span class="text-sm font-bold text-gray-800">{{ dutyType.cnt }}</span>
        </div>
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
              {{ schedule.contentWithoutTime || schedule.content }}
              <span class="text-gray-400">{{ formatScheduleTime(schedule) }}</span>
            </div>
            <div
              v-if="(schedulesByDays[idx]?.length ?? 0) > 2"
              class="text-xs text-gray-400"
            >
              +{{ (schedulesByDays[idx]?.length ?? 0) - 2 }} more
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
              class="text-lg font-bold"
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
      @show-detail="(todo: Todo) => { selectedTodo = todo; isTodoDetailModalOpen = true; isTodoOverviewModalOpen = false; }"
      @complete="handleTodoComplete"
      @reopen="handleTodoReopen"
      @delete="handleTodoDelete"
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
      @change-page="() => {}"
    />

    <OtherDutiesModal
      :is-open="isOtherDutiesModalOpen"
      :friends="friends"
      :selected-friend-ids="selectedFriendIds"
      @close="isOtherDutiesModalOpen = false"
      @toggle="handleFriendToggle"
    />

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
