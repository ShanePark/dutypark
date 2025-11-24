<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()

// Dummy data
const currentYear = ref(2025)
const currentMonth = ref(11)
const _memberName = ref('박세현') // Will be displayed in header
const _memberId = route.params.id // Will be used for API calls

const todos = ref([
  { id: '1', title: 'zz', hasContent: false },
  { id: '2', title: '할일2', hasContent: true },
  { id: '3', title: '할일1d', hasContent: false },
])

const dutyTypes = ref([
  { name: 'OFF', count: 10, color: '#6c757d' },
  { name: '출근', count: 20, color: '#0d6efd' },
])

const weekDays = ['일', '월', '화', '수', '목', '금', '토']

// Generate calendar days
const calendarDays = computed(() => {
  const days = []
  const firstDay = new Date(currentYear.value, currentMonth.value - 1, 1)
  const lastDay = new Date(currentYear.value, currentMonth.value, 0)
  const startDayOfWeek = firstDay.getDay()

  // Previous month days
  const prevMonthLastDay = new Date(currentYear.value, currentMonth.value - 1, 0).getDate()
  for (let i = startDayOfWeek - 1; i >= 0; i--) {
    days.push({
      day: prevMonthLastDay - i,
      isCurrentMonth: false,
      isPrev: true,
      date: `${currentMonth.value - 1}/${prevMonthLastDay - i}`,
    })
  }

  // Current month days
  for (let i = 1; i <= lastDay.getDate(); i++) {
    const isToday = i === 24 && currentMonth.value === 11 && currentYear.value === 2025
    days.push({
      day: i,
      isCurrentMonth: true,
      isPrev: false,
      isNext: false,
      isToday,
      date: String(i),
      schedules: i === 24 ? [{ content: '추가일정', time: '~11:59PM' }] : [],
      duty: i % 3 === 0 ? 'OFF' : '출근',
    })
  }

  // Next month days
  const remainingDays = 42 - days.length
  for (let i = 1; i <= remainingDays; i++) {
    days.push({
      day: i,
      isCurrentMonth: false,
      isNext: true,
      date: `12/${i}`,
    })
  }

  return days
})

const dDays = ref([
  { id: 1, title: '루나 생일', date: '2023-09-13', daysAgo: 804 },
  { id: 2, title: '정수기 필터교체', date: '2025-08-19', daysAgo: 98 },
  { id: 3, title: '최근 세차', date: '2025-08-23', daysAgo: 94 },
  { id: 4, title: 'dutypark-ssl', date: '2025-11-20', daysAgo: 5 },
])

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
  currentYear.value = 2025
  currentMonth.value = 11
}
</script>

<template>
  <div class="max-w-4xl mx-auto px-2 sm:px-4 py-4">
    <!-- Todo List Section -->
    <div class="bg-white rounded-lg border border-gray-800 mb-4 flex">
      <!-- Add Todo Button -->
      <button class="flex-shrink-0 w-24 bg-green-500 text-white rounded-l-lg flex items-center justify-center gap-1 border-r border-gray-800 hover:bg-green-600 transition">
        <span class="text-sm font-medium">Todo</span>
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
      </button>

      <!-- Todo Items -->
      <div class="flex-1 overflow-x-auto py-2 px-2">
        <div class="flex gap-2">
          <div
            v-for="todo in todos"
            :key="todo.id"
            class="flex-shrink-0 flex items-center bg-gray-50 border border-gray-200 rounded-lg px-3 py-2 cursor-pointer hover:bg-gray-100 transition"
          >
            <span class="text-gray-400 mr-2 cursor-grab">⋮⋮</span>
            <span class="font-medium text-gray-800">{{ todo.title }}</span>
          </div>
        </div>
      </div>

      <!-- Todo Count Badge -->
      <button class="flex-shrink-0 px-4 py-2 flex items-center gap-2 text-gray-600 hover:bg-gray-50 rounded-r-lg transition">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
        </svg>
        <span>Todo List</span>
        <span class="bg-blue-600 text-white text-xs px-2 py-0.5 rounded-full">{{ todos.length }}</span>
      </button>
    </div>

    <!-- Month Control -->
    <div class="flex flex-wrap items-center justify-between gap-2 mb-4">
      <div class="flex items-center gap-2">
        <button
          @click="goToToday"
          class="px-3 py-1.5 bg-sky-300 text-gray-800 rounded-full text-sm font-medium hover:bg-sky-400 transition"
        >
          Today
          <svg class="w-4 h-4 inline ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
          </svg>
        </button>

        <div class="flex items-center">
          <button @click="prevMonth" class="p-2 hover:bg-gray-100 rounded-full transition">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <button class="px-3 py-1 text-lg font-semibold hover:bg-gray-100 rounded transition">
            {{ currentYear }}-{{ String(currentMonth).padStart(2, '0') }}
          </button>
          <button @click="nextMonth" class="p-2 hover:bg-gray-100 rounded-full transition">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>
      </div>

      <!-- Search -->
      <div class="flex items-center">
        <input
          type="text"
          placeholder="검색"
          class="px-3 py-1.5 border border-gray-300 rounded-l-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent w-32"
        />
        <button class="px-3 py-1.5 bg-gray-800 text-white rounded-r-lg hover:bg-gray-700 transition">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
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
          <span class="text-sm font-bold text-gray-800">{{ dutyType.count }}</span>
        </div>
      </div>
      <div class="flex gap-2">
        <button class="px-3 py-1.5 border border-gray-300 rounded-lg text-sm hover:bg-gray-50 transition">
          함께보기
        </button>
        <button class="px-3 py-1.5 border border-gray-300 rounded-lg text-sm hover:bg-gray-50 transition">
          편집모드
        </button>
      </div>
    </div>

    <!-- Calendar Grid -->
    <div class="bg-white rounded-lg border border-gray-300 overflow-hidden mb-4">
      <!-- Week Days Header -->
      <div class="grid grid-cols-7 bg-gray-200">
        <div
          v-for="(day, idx) in weekDays"
          :key="day"
          class="py-2 text-center font-bold border border-gray-800 text-sm"
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
          class="min-h-[80px] sm:min-h-[100px] border border-gray-800 p-1 cursor-pointer hover:bg-gray-50 transition"
          :class="{
            'opacity-50 bg-white': !day.isCurrentMonth,
            'border-3 border-red-500': day.isToday,
            'bg-blue-50': day.duty === '출근' && day.isCurrentMonth,
            'bg-gray-100': day.duty === 'OFF' && day.isCurrentMonth,
          }"
        >
          <div class="text-center">
            <span
              class="text-sm font-medium"
              :class="{
                'text-red-500': idx % 7 === 0,
                'text-blue-500': idx % 7 === 6,
                'underline decoration-red-500 decoration-2 underline-offset-2 font-bold': day.isToday,
              }"
            >
              {{ day.date }}
            </span>
          </div>

          <!-- Schedules -->
          <div v-if="day.schedules?.length" class="mt-1">
            <div
              v-for="schedule in day.schedules"
              :key="schedule.content"
              class="text-xs text-gray-700 truncate"
            >
              {{ schedule.content }}
              <span v-if="schedule.time" class="text-gray-400">({{ schedule.time }})</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- D-Day List -->
    <div class="bg-white rounded-lg border border-gray-200 p-4">
      <div class="grid grid-cols-2 gap-3">
        <div
          v-for="dday in dDays"
          :key="dday.id"
          class="bg-gray-50 rounded-lg p-3 border border-gray-200 cursor-pointer hover:bg-gray-100 transition"
        >
          <div class="flex justify-between items-start mb-2">
            <span class="text-lg font-bold text-blue-600">D+{{ dday.daysAgo }}</span>
            <div class="flex gap-1">
              <button class="text-gray-400 hover:text-gray-600">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                </svg>
              </button>
              <button class="text-gray-400 hover:text-red-600">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
              </button>
            </div>
          </div>
          <p class="text-xs text-gray-500 mb-1">{{ dday.date }}</p>
          <p class="text-sm text-gray-800 font-medium truncate">{{ dday.title }}</p>
        </div>

        <!-- Add D-Day Button -->
        <div class="bg-gray-50 rounded-lg p-3 border-2 border-dashed border-gray-300 cursor-pointer hover:bg-blue-50 hover:border-blue-400 transition flex flex-col items-center justify-center min-h-[100px]">
          <svg class="w-6 h-6 text-gray-400 mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          <span class="text-sm text-gray-500">디데이 추가</span>
        </div>
      </div>
    </div>
  </div>
</template>
