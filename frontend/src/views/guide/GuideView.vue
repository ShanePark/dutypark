<script setup lang="ts">
import { ref } from 'vue'
import {
  BookOpen,
  Home,
  ArrowLeft,
  Calendar,
  Users,
  UserPlus,
  Settings,
  Star,
  GripVertical,
  CalendarCheck,
  ClipboardList,
  Search,
  FileSpreadsheet,
  Eye,
  Shield,
  Smartphone,
  Link,
  Lock,
  Sun,
  Moon,
  ChevronDown,
  ChevronUp,
  Building2,
  Pencil,
  Plus,
  Trash2,
  Bell,
  Tag,
  Sparkles,
  Camera,
  Palette,
  UserCog,
} from 'lucide-vue-next'

interface GuideSection {
  id: string
  title: string
  icon: typeof Home
  isOpen: boolean
}

const sections = ref<GuideSection[]>([
  { id: 'dashboard', title: '대시보드 (홈)', icon: Home, isOpen: true },
  { id: 'calendar', title: '내 달력', icon: Calendar, isOpen: false },
  { id: 'team', title: '내 팀', icon: Building2, isOpen: false },
  { id: 'friends', title: '친구 관리', icon: UserPlus, isOpen: false },
  { id: 'settings', title: '설정', icon: Settings, isOpen: false },
])

function toggleSection(id: string) {
  const section = sections.value.find(s => s.id === id)
  if (section) {
    section.isOpen = !section.isOpen
  }
}

function openAllSections() {
  sections.value.forEach(s => s.isOpen = true)
}

function closeAllSections() {
  sections.value.forEach(s => s.isOpen = false)
}
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <!-- Header -->
    <div class="mb-8">
      <!-- Back to home -->
      <router-link
        to="/"
        class="inline-flex items-center gap-1.5 mb-4 text-sm transition-colors hover:opacity-80"
        :style="{ color: 'var(--dp-text-secondary)' }"
      >
        <ArrowLeft class="w-4 h-4" />
        홈으로 돌아가기
      </router-link>

      <div class="flex items-center gap-3 mb-4">
        <div class="w-12 h-12 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-xl flex items-center justify-center">
          <BookOpen class="w-6 h-6 text-white" />
        </div>
        <div>
          <h1 class="text-2xl font-bold" :style="{ color: 'var(--dp-text-primary)' }">이용 안내</h1>
          <p class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">Dutypark의 주요 기능과 사용 방법을 안내합니다</p>
        </div>
      </div>

      <!-- Quick Actions -->
      <div class="flex gap-2">
        <button
          @click="openAllSections"
          class="px-3 py-1.5 text-sm rounded-lg border transition hover:bg-opacity-80 cursor-pointer"
          :style="{ borderColor: 'var(--dp-border-secondary)', color: 'var(--dp-text-secondary)' }"
        >
          모두 펼치기
        </button>
        <button
          @click="closeAllSections"
          class="px-3 py-1.5 text-sm rounded-lg border transition hover:bg-opacity-80 cursor-pointer"
          :style="{ borderColor: 'var(--dp-border-secondary)', color: 'var(--dp-text-secondary)' }"
        >
          모두 접기
        </button>
      </div>
    </div>

    <!-- Guide Sections -->
    <div class="space-y-4">
      <!-- Dashboard Section -->
      <section
        class="rounded-xl border shadow-sm overflow-hidden"
        :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' }"
      >
        <button
          @click="toggleSection('dashboard')"
          class="w-full px-5 py-4 flex items-center justify-between cursor-pointer hover:bg-opacity-50 transition"
          :style="{ backgroundColor: 'var(--dp-bg-secondary)' }"
        >
          <div class="flex items-center gap-3">
            <Home class="w-5 h-5 text-blue-500" />
            <span class="font-semibold" :style="{ color: 'var(--dp-text-primary)' }">대시보드 (홈)</span>
          </div>
          <ChevronUp v-if="sections.find(s => s.id === 'dashboard')?.isOpen" class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
          <ChevronDown v-else class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
        </button>

        <div v-if="sections.find(s => s.id === 'dashboard')?.isOpen" class="p-5 space-y-6">
          <p :style="{ color: 'var(--dp-text-secondary)' }">
            대시보드는 로그인 후 가장 먼저 보이는 화면입니다. 오늘의 근무와 일정을 한눈에 확인하고, 친구들의 상태도 빠르게 파악할 수 있습니다.
          </p>

          <div class="space-y-4">
            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Calendar class="w-4 h-4 text-blue-500" />
                오늘의 정보 확인
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>오늘 날짜와 요일을 확인할 수 있습니다.</li>
                <li>현재 배정된 근무 타입이 표시됩니다.</li>
                <li>오늘 예정된 일정 목록이 표시됩니다.</li>
                <li>친구가 태그한 일정도 "(by 이름)" 형태로 함께 표시됩니다.</li>
                <li>상단 영역을 클릭하면 내 달력으로 이동합니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Users class="w-4 h-4 text-slate-600" />
                친구 목록
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>등록된 친구들의 오늘 근무와 일정을 확인할 수 있습니다.</li>
                <li>친구 카드를 클릭하면 해당 친구의 달력으로 이동합니다.</li>
                <li class="flex items-center gap-1">
                  <Star class="w-3 h-3 text-amber-500" fill="currentColor" />
                  버튼으로 자주 보는 친구를 상단에 고정할 수 있습니다.
                </li>
                <li class="flex items-center gap-1">
                  <GripVertical class="w-3 h-3" :style="{ color: 'var(--dp-text-muted)' }" />
                  아이콘을 드래그하여 고정된 친구의 순서를 변경할 수 있습니다.
                </li>
              </ul>
            </div>

          </div>
        </div>
      </section>

      <!-- Calendar Section -->
      <section
        class="rounded-xl border shadow-sm overflow-hidden"
        :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' }"
      >
        <button
          @click="toggleSection('calendar')"
          class="w-full px-5 py-4 flex items-center justify-between cursor-pointer hover:bg-opacity-50 transition"
          :style="{ backgroundColor: 'var(--dp-bg-secondary)' }"
        >
          <div class="flex items-center gap-3">
            <Calendar class="w-5 h-5 text-green-500" />
            <span class="font-semibold" :style="{ color: 'var(--dp-text-primary)' }">내 달력</span>
          </div>
          <ChevronUp v-if="sections.find(s => s.id === 'calendar')?.isOpen" class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
          <ChevronDown v-else class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
        </button>

        <div v-if="sections.find(s => s.id === 'calendar')?.isOpen" class="p-5 space-y-6">
          <p :style="{ color: 'var(--dp-text-secondary)' }">
            내 달력에서는 월별 근무 일정을 관리하고, 개인 일정과 D-Day, Todo를 등록할 수 있습니다.
          </p>

          <div class="space-y-4">
            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Pencil class="w-4 h-4 text-orange-500" />
                근무 관리
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>캘린더에서 각 날짜의 근무가 색상으로 표시됩니다.</li>
                <li>날짜를 클릭하면 해당 날짜의 상세 정보를 볼 수 있습니다.</li>
                <li><strong>편집모드</strong> 버튼을 누르면 근무를 빠르게 수정할 수 있습니다.</li>
                <li>편집모드에서는 상단의 근무 타입 버튼을 클릭하면 해당 날짜에 근무가 적용되고 자동으로 다음 날로 이동합니다.</li>
                <li><strong>일괄수정</strong>으로 한 달 전체를 특정 근무로 설정할 수 있습니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <FileSpreadsheet class="w-4 h-4 text-green-600" />
                엑셀 업로드 (일부 팀 지원)
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>팀에서 제공하는 시간표 파일이 있다면 엑셀 업로드로 한번에 근무를 등록할 수 있습니다.</li>
                <li>엑셀 버튼은 해당 기능을 지원하는 팀에서만 표시됩니다.</li>
                <li>업로드 전 반드시 해당 월에 맞는 파일인지 확인해주세요.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Plus class="w-4 h-4 text-blue-500" />
                일정 관리
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>날짜를 클릭하여 새 일정을 추가할 수 있습니다.</li>
                <li>일정에는 제목, 상세 설명, 시작/종료 시간을 입력할 수 있습니다.</li>
                <li>파일이나 이미지를 첨부할 수 있습니다.</li>
                <li>공개 범위를 설정하여 누가 이 일정을 볼 수 있는지 지정할 수 있습니다.</li>
                <li class="flex items-center gap-1">
                  <Tag class="w-3 h-3 text-blue-500" />
                  친구를 태그하면 해당 친구의 달력에도 일정이 표시됩니다.
                </li>
                <li>태그된 친구는 자신의 달력에서 태그를 제거할 수 있습니다.</li>
                <li>여러 날에 걸친 일정은 자동으로 "[1/3]"과 같은 형태로 표시됩니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Sparkles class="w-4 h-4 text-violet-500" />
                AI 시간 자동 인식
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>일정 제목에 시간 정보를 포함하면 AI가 자동으로 시간을 인식합니다.</li>
                <li>예: "오후 3시 미팅" → 시작 시간 15:00으로 자동 설정</li>
                <li>예: "10시~12시 회의" → 시작 10:00, 종료 12:00으로 자동 설정</li>
                <li>시간이 인식되면 캘린더에 시간 정보가 함께 표시됩니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Eye class="w-4 h-4 text-emerald-500" />
                일정 공개 범위
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li><strong>전체공개</strong>: 모든 사용자가 볼 수 있습니다.</li>
                <li><strong>친구공개</strong>: 친구로 등록된 사용자만 볼 수 있습니다.</li>
                <li><strong>가족공개</strong>: 가족으로 등록된 사용자만 볼 수 있습니다.</li>
                <li><strong>비공개</strong>: 나만 볼 수 있습니다. 캘린더에 자물쇠 아이콘이 표시됩니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <CalendarCheck class="w-4 h-4 text-purple-500" />
                D-Day 관리
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>중요한 날짜를 D-Day로 등록하면 캘린더 하단에 카드로 표시됩니다.</li>
                <li>D-Day 카드에서 별 아이콘을 클릭하면 캘린더에 D-Day 카운트가 표시됩니다.</li>
                <li>한국식 D-Day 표기: 당일은 "D-Day", 5일 남으면 "D-5", 3일 지나면 "D+3"</li>
                <li>비공개로 설정하면 친구에게 보이지 않습니다.</li>
                <li>날짜 빠른 조정 버튼으로 ±1일, ±7일씩 쉽게 조정할 수 있습니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <ClipboardList class="w-4 h-4 text-indigo-500" />
                Todo (할 일) 관리
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>캘린더 상단에 Todo 버튼이 있습니다.</li>
                <li>할 일을 추가하고, 완료 처리하거나 다시 열 수 있습니다.</li>
                <li>드래그로 Todo의 순서를 변경할 수 있습니다.</li>
                <li>파일을 첨부할 수 있습니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Search class="w-4 h-4 text-gray-600" />
                일정 검색
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>우측 상단 검색창에서 내 일정을 검색할 수 있습니다.</li>
                <li>검색 결과를 클릭하면 해당 날짜로 이동합니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Users class="w-4 h-4 text-teal-500" />
                함께보기
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li><strong>함께보기</strong> 버튼을 누르면 친구의 근무를 내 캘린더에 함께 표시할 수 있습니다.</li>
                <li>최대 3명의 친구를 선택할 수 있습니다.</li>
                <li>여러 친구를 선택하여 근무가 겹치는 날을 쉽게 찾을 수 있습니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <UserPlus class="w-4 h-4 text-cyan-500" />
                다른 사람 달력 보기
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>대시보드나 친구 목록에서 친구를 클릭하면 해당 친구의 달력을 볼 수 있습니다.</li>
                <li>친구의 달력에서 <strong>내 근무</strong> 토글을 켜면 내 근무도 함께 표시됩니다.</li>
                <li>친구가 공개한 일정만 볼 수 있으며, 비공개 일정은 표시되지 않습니다.</li>
                <li>팀원의 경우 시간표 공개 설정과 관계없이 근무를 확인할 수 있습니다.</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      <!-- Team Section -->
      <section
        class="rounded-xl border shadow-sm overflow-hidden"
        :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' }"
      >
        <button
          @click="toggleSection('team')"
          class="w-full px-5 py-4 flex items-center justify-between cursor-pointer hover:bg-opacity-50 transition"
          :style="{ backgroundColor: 'var(--dp-bg-secondary)' }"
        >
          <div class="flex items-center gap-3">
            <Building2 class="w-5 h-5 text-purple-500" />
            <span class="font-semibold" :style="{ color: 'var(--dp-text-primary)' }">내 팀</span>
          </div>
          <ChevronUp v-if="sections.find(s => s.id === 'team')?.isOpen" class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
          <ChevronDown v-else class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
        </button>

        <div v-if="sections.find(s => s.id === 'team')?.isOpen" class="p-5 space-y-6">
          <p :style="{ color: 'var(--dp-text-secondary)' }">
            소속된 팀이 있다면 팀 캘린더에서 팀원들의 근무 현황과 팀 일정을 확인할 수 있습니다.
          </p>

          <div class="space-y-4">
            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Calendar class="w-4 h-4 text-purple-500" />
                팀 캘린더
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>캘린더에 내 근무가 배경색으로 표시됩니다.</li>
                <li>팀 일정이 날짜 칸에 표시됩니다.</li>
                <li>날짜를 클릭하면 해당 날짜의 팀 일정 상세와 근무자 목록을 볼 수 있습니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Users class="w-4 h-4 text-indigo-500" />
                근무자 확인
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>날짜를 선택하면 해당 날짜에 각 근무 타입별로 누가 일하는지 확인할 수 있습니다.</li>
                <li>내가 속한 근무 그룹은 테두리로 강조 표시됩니다.</li>
                <li>팀원 이름을 클릭하면 해당 팀원의 달력으로 이동합니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Plus class="w-4 h-4 text-green-500" />
                팀 일정 (팀 관리자)
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>팀 관리자는 팀 일정을 추가/수정/삭제할 수 있습니다.</li>
                <li>팀 일정은 모든 팀원의 팀 캘린더에 표시됩니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <UserCog class="w-4 h-4 text-blue-500" />
                멤버 관리 (팀 관리자)
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>팀 관리자는 팀 설정 페이지에서 멤버를 추가/삭제할 수 있습니다.</li>
                <li>기존 사용자를 검색하여 팀에 초대할 수 있습니다.</li>
                <li>특정 멤버에게 매니저 권한을 부여할 수 있습니다.</li>
                <li>매니저는 팀원들의 근무를 대신 수정할 수 있습니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Palette class="w-4 h-4 text-pink-500" />
                근무 타입 관리 (팀 관리자)
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>팀에서 사용할 근무 타입을 추가/수정/삭제할 수 있습니다.</li>
                <li>각 근무 타입의 이름과 색상을 설정할 수 있습니다.</li>
                <li>근무 타입의 표시 순서를 변경할 수 있습니다.</li>
                <li>기본 휴무(OFF) 타입의 이름과 색상도 변경 가능합니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <FileSpreadsheet class="w-4 h-4 text-emerald-600" />
                팀 엑셀 업로드 (팀 관리자)
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>팀 전체의 근무를 엑셀 파일로 한번에 등록할 수 있습니다.</li>
                <li>지원되는 템플릿 형식을 선택한 후 업로드합니다.</li>
                <li>업로드된 파일에서 이름을 매칭하여 자동으로 근무가 배정됩니다.</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      <!-- Friends Section -->
      <section
        class="rounded-xl border shadow-sm overflow-hidden"
        :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' }"
      >
        <button
          @click="toggleSection('friends')"
          class="w-full px-5 py-4 flex items-center justify-between cursor-pointer hover:bg-opacity-50 transition"
          :style="{ backgroundColor: 'var(--dp-bg-secondary)' }"
        >
          <div class="flex items-center gap-3">
            <UserPlus class="w-5 h-5 text-amber-500" />
            <span class="font-semibold" :style="{ color: 'var(--dp-text-primary)' }">친구 관리</span>
          </div>
          <ChevronUp v-if="sections.find(s => s.id === 'friends')?.isOpen" class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
          <ChevronDown v-else class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
        </button>

        <div v-if="sections.find(s => s.id === 'friends')?.isOpen" class="p-5 space-y-6">
          <p :style="{ color: 'var(--dp-text-secondary)' }">
            친구를 등록하면 서로의 근무와 일정을 공유할 수 있습니다. 가족으로 등록하면 더 많은 정보를 공유할 수 있습니다.
          </p>

          <div class="space-y-4">
            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <UserPlus class="w-4 h-4 text-blue-500" />
                친구 추가
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li><strong>친구 추가</strong> 버튼을 클릭하면 다른 사용자를 검색할 수 있습니다.</li>
                <li>이름이나 팀명으로 검색할 수 있습니다.</li>
                <li>친구 요청을 보내면 상대방이 승인해야 친구가 됩니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Bell class="w-4 h-4 text-rose-500" />
                친구 요청 관리
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>받은 친구/가족 요청을 확인하고 수락하거나 거절할 수 있습니다.</li>
                <li>내가 보낸 요청의 상태를 확인하고, 필요시 요청을 취소할 수 있습니다.</li>
                <li>새로운 요청이 있으면 메뉴에 알림 배지가 표시됩니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Home class="w-4 h-4 text-amber-500" />
                가족 등록
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>친구 카드에서 메뉴(⋮)를 클릭하고 <strong>가족 등록</strong>을 선택합니다.</li>
                <li>가족 요청을 보내면 상대방이 승인해야 가족이 됩니다.</li>
                <li>가족은 집 아이콘으로 표시됩니다.</li>
                <li>가족으로 등록하면 "가족만" 공개 일정도 볼 수 있습니다.</li>
                <li>가족만 관리 권한 위임을 받을 수 있습니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Star class="w-4 h-4 text-amber-500" />
                친구 고정 및 순서 변경
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>별 아이콘을 클릭하면 해당 친구가 목록 상단에 고정됩니다.</li>
                <li>고정된 친구는 드래그하여 순서를 변경할 수 있습니다.</li>
                <li>고정 및 순서는 대시보드에서도 동일하게 적용됩니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Trash2 class="w-4 h-4 text-red-500" />
                친구 삭제
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>친구 카드에서 메뉴(⋮)를 클릭하고 <strong>친구 삭제</strong>를 선택합니다.</li>
                <li>삭제 후에는 서로의 일정을 볼 수 없게 됩니다.</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      <!-- Settings Section -->
      <section
        class="rounded-xl border shadow-sm overflow-hidden"
        :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' }"
      >
        <button
          @click="toggleSection('settings')"
          class="w-full px-5 py-4 flex items-center justify-between cursor-pointer hover:bg-opacity-50 transition"
          :style="{ backgroundColor: 'var(--dp-bg-secondary)' }"
        >
          <div class="flex items-center gap-3">
            <Settings class="w-5 h-5 text-gray-500" />
            <span class="font-semibold" :style="{ color: 'var(--dp-text-primary)' }">설정</span>
          </div>
          <ChevronUp v-if="sections.find(s => s.id === 'settings')?.isOpen" class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
          <ChevronDown v-else class="w-5 h-5" :style="{ color: 'var(--dp-text-muted)' }" />
        </button>

        <div v-if="sections.find(s => s.id === 'settings')?.isOpen" class="p-5 space-y-6">
          <p :style="{ color: 'var(--dp-text-secondary)' }">
            설정에서 프로필, 공개 범위, 테마 등 다양한 개인 설정을 관리할 수 있습니다.
          </p>

          <div class="space-y-4">
            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Camera class="w-4 h-4 text-violet-500" />
                프로필 사진 설정
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>프로필 사진을 업로드하면 대시보드와 친구 목록에 표시됩니다.</li>
                <li>사진 업로드 후 자르기 영역을 조정할 수 있습니다.</li>
                <li>등록된 사진은 언제든 삭제할 수 있습니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Eye class="w-4 h-4 text-blue-500" />
                시간표 공개 설정
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li><strong>누구나</strong>: 모든 사용자가 내 시간표를 볼 수 있습니다.</li>
                <li><strong>친구만</strong>: 친구로 등록된 사용자만 볼 수 있습니다.</li>
                <li><strong>가족만</strong>: 가족으로 등록된 사용자만 볼 수 있습니다.</li>
                <li><strong>비공개</strong>: 나만 볼 수 있습니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Sun class="w-4 h-4 text-amber-500" />
                <Moon class="w-4 h-4 text-indigo-500" />
                화면 테마 설정
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li><strong>라이트 모드</strong>: 밝은 배경의 기본 테마입니다.</li>
                <li><strong>다크 모드</strong>: 어두운 배경으로 눈의 피로를 줄여줍니다.</li>
                <li>헤더의 달/해 아이콘으로도 빠르게 변경할 수 있습니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Shield class="w-4 h-4 text-green-500" />
                관리 권한 위임
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>가족으로 등록된 사용자에게 내 계정 관리 권한을 위임할 수 있습니다.</li>
                <li>관리자는 내 근무를 대신 수정할 수 있습니다.</li>
                <li>관리자로 지정된 사용자는 내 계정으로 로그인할 수 있습니다.</li>
                <li>언제든 관리자 권한을 해제할 수 있습니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Smartphone class="w-4 h-4 text-purple-500" />
                접속 세션 관리
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>현재 로그인된 모든 기기 목록을 확인할 수 있습니다.</li>
                <li>특정 기기를 선택하여 로그아웃 시킬 수 있습니다.</li>
                <li><strong>전체 접속 종료</strong>로 현재 기기를 제외한 모든 세션을 종료할 수 있습니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Link class="w-4 h-4 text-yellow-600" />
                소셜 계정 연동
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>카카오 계정을 연동하면 카카오 로그인으로 간편하게 접속할 수 있습니다.</li>
                <li>연동된 계정은 "연동중" 상태로 표시됩니다.</li>
              </ul>
            </div>

            <div class="p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
              <h4 class="font-medium mb-2 flex items-center gap-2" :style="{ color: 'var(--dp-text-primary)' }">
                <Lock class="w-4 h-4 text-gray-600" />
                비밀번호 변경
              </h4>
              <ul class="text-sm space-y-1.5 ml-6" :style="{ color: 'var(--dp-text-secondary)' }">
                <li>현재 비밀번호를 확인한 후 새 비밀번호로 변경할 수 있습니다.</li>
                <li>비밀번호는 8-20자 사이여야 합니다.</li>
                <li>변경 후 자동으로 로그아웃되며 새 비밀번호로 다시 로그인해야 합니다.</li>
              </ul>
            </div>
          </div>
        </div>
      </section>
    </div>

    <!-- Footer -->
    <div class="mt-8 p-4 rounded-lg text-center" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
      <p class="text-sm" :style="{ color: 'var(--dp-text-muted)' }">
        더 궁금한 점이 있으시면 관리자에게 문의해주세요.
      </p>
    </div>
  </div>
</template>
