<script setup lang="ts">
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()

// Dummy data for logged-in view
const todayInfo = ref({
  date: '2025년 11월 24일 월요일',
  duty: '출근',
  schedules: ['추가일정'],
})

const friends = ref([
  { id: 1, name: '이동현', duty: '휴무', isFamily: true },
  { id: 2, name: '김현주', duty: 'OFF', isFamily: false },
  { id: 3, name: '박재현', duty: 'OFF', isFamily: false },
  { id: 4, name: '박루나', duty: '가정보육', isFamily: true },
  { id: 5, name: '이보연', duty: '휴무', isFamily: false },
  { id: 6, name: '전소이', duty: '-', isFamily: false },
  { id: 7, name: '전웅배', duty: '출근', isFamily: false },
  { id: 8, name: '전이재', duty: '-', isFamily: false },
])

const features = [
  { icon: 'calendar', text: '일정 관리 (등록, 검색, 공개 설정)' },
  { icon: 'check', text: '할일 관리로 까먹지 않는 일상' },
  { icon: 'clock', text: '근무 관리 및 시간표 등록' },
  { icon: 'users', text: '팀원들의 시간표와 일정 공유' },
  { icon: 'heart', text: '친구 및 가족의 일정 조회와 태그 기능' },
]
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <!-- Logged-in Dashboard -->
    <template v-if="authStore.isLoggedIn">
      <!-- User Info Section -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-5 mb-4">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-bold text-gray-900">{{ authStore.user?.name || '사용자' }}</h2>
        </div>

        <!-- Today Info -->
        <div class="space-y-3">
          <div class="flex items-center gap-2 text-gray-700">
            <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
            <span class="font-medium">{{ todayInfo.date }}</span>
          </div>

          <div class="flex items-center gap-2">
            <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
            </svg>
            <span class="text-gray-600">근무:</span>
            <span class="px-2 py-0.5 bg-blue-100 text-blue-800 rounded font-medium">{{ todayInfo.duty }}</span>
          </div>

          <div>
            <div class="flex items-center gap-2 mb-2">
              <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
              </svg>
              <span class="text-gray-600">오늘 일정</span>
            </div>
            <ul class="ml-7 space-y-1">
              <li v-for="schedule in todayInfo.schedules" :key="schedule" class="text-gray-700">
                {{ schedule }}
              </li>
              <li v-if="todayInfo.schedules.length === 0" class="text-gray-400 text-sm">
                오늘 일정이 없습니다
              </li>
            </ul>
          </div>
        </div>
      </div>

      <!-- Friends Section -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-5">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">친구 목록</h3>
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
          <div
            v-for="friend in friends"
            :key="friend.id"
            class="bg-gray-50 rounded-lg p-4 hover:bg-gray-100 transition cursor-pointer border border-gray-200"
          >
            <div class="flex items-center justify-between mb-2">
              <span class="font-medium text-gray-900">
                <svg v-if="friend.isFamily" class="w-4 h-4 inline text-red-400 mr-1" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>
                </svg>
                {{ friend.name }}
              </span>
              <button class="text-xs text-gray-400 hover:text-gray-600">관리</button>
            </div>
            <p class="text-sm text-gray-600">
              <svg class="w-4 h-4 inline text-gray-400 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
              근무: {{ friend.duty }}
            </p>
          </div>

          <!-- Add Friend Card -->
          <div class="bg-gray-50 rounded-lg p-4 border-2 border-dashed border-gray-300 hover:border-blue-400 hover:bg-blue-50 transition cursor-pointer flex flex-col items-center justify-center min-h-[100px]">
            <svg class="w-8 h-8 text-gray-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
            </svg>
            <span class="text-sm text-gray-500">친구 추가</span>
          </div>
        </div>
      </div>
    </template>

    <!-- Guest Dashboard -->
    <template v-else>
      <!-- Hero Section -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-8 text-center mb-6">
        <h1 class="text-4xl font-bold text-gray-900 mb-4">Dutypark</h1>
        <p class="text-gray-600 mb-6 max-w-lg mx-auto">
          Dutypark는 근무 관리, 시간표 등록, 일정 관리, 할일 관리 및 팀원들의 시간표 조회, 친구 및 가족의 일정 공유 등 다양한 기능을 통해 여러분의 일상을 도와줍니다.
        </p>
        <router-link
          to="/auth/login"
          class="inline-block bg-gray-900 text-white px-8 py-3 rounded-lg font-medium hover:bg-gray-800 transition"
        >
          로그인 / 회원가입
        </router-link>
      </div>

      <!-- Features Section -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-8">
        <h2 class="text-2xl font-bold text-gray-900 mb-6">주요 기능</h2>
        <ul class="space-y-4">
          <li v-for="feature in features" :key="feature.text" class="flex items-start gap-3">
            <svg v-if="feature.icon === 'calendar'" class="w-6 h-6 text-blue-500 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
            <svg v-else-if="feature.icon === 'check'" class="w-6 h-6 text-green-500 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <svg v-else-if="feature.icon === 'clock'" class="w-6 h-6 text-yellow-500 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <svg v-else-if="feature.icon === 'users'" class="w-6 h-6 text-purple-500 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
            </svg>
            <svg v-else-if="feature.icon === 'heart'" class="w-6 h-6 text-red-500 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
            </svg>
            <span class="text-gray-700">{{ feature.text }}</span>
          </li>
        </ul>
        <p class="mt-6 text-gray-600">
          지금 바로 Dutypark을 사용해보세요!<br>
          <span class="text-sm text-gray-500">(현재 회원가입은 카카오톡 로그인을 지원합니다.)</span>
        </p>
      </div>
    </template>
  </div>
</template>
