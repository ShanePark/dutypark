<script setup lang="ts">
import { ref, computed, onMounted, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import {
  Calendar,
  Briefcase,
  ClipboardList,
  Heart,
  Plus,
  CheckCircle,
  Clock,
  Users,
  Star,
  GripVertical,
  ChevronDown,
  UserPlus,
  Home,
  Trash2,
  X,
  Search,
  ChevronLeft,
  ChevronRight,
  Settings,
  User,
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()

// Loading states
const myInfoLoading = ref(false)
const friendInfoLoading = ref(false)
const friendInfoInitialized = ref(true) // Set to true for dummy data display

// Today's date formatted
const today = computed(() => {
  return new Date().toLocaleDateString('ko-KR', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    weekday: 'long',
  })
})

// Dummy data for my info section
const myInfo = ref({
  member: { id: 1, name: '박성철' },
  duty: {
    dutyType: '출근',
    dutyColor: '#4CAF50',
  },
  schedules: [
    { id: '1', content: '팀 미팅', startDateTime: '2025-11-24T10:00:00', totalDays: 1, daysFromStart: 1, isTagged: false, owner: '' },
    { id: '2', content: '프로젝트 리뷰', startDateTime: '2025-11-24T14:30:00', totalDays: 1, daysFromStart: 1, isTagged: false, owner: '' },
  ],
})

// Friend request data
const friendInfo = ref({
  friends: [
    {
      member: { id: 2, name: '이동현' },
      isFamily: true,
      pinOrder: 1,
      duty: { dutyType: '휴무', dutyColor: '#9E9E9E' },
      schedules: [
        { id: '3', content: '가족 여행', startDateTime: '2025-11-24T00:00:00', totalDays: 3, daysFromStart: 2, isTagged: false, owner: '' },
      ],
    },
    {
      member: { id: 3, name: '김현주' },
      isFamily: false,
      pinOrder: 2,
      duty: { dutyType: 'OFF', dutyColor: '#FF9800' },
      schedules: [],
    },
    {
      member: { id: 4, name: '박재현' },
      isFamily: false,
      pinOrder: null,
      duty: { dutyType: 'OFF', dutyColor: '#FF9800' },
      schedules: [
        { id: '4', content: '병원 예약', startDateTime: '2025-11-24T11:00:00', totalDays: 1, daysFromStart: 1, isTagged: false, owner: '' },
      ],
    },
    {
      member: { id: 5, name: '박루나' },
      isFamily: true,
      pinOrder: null,
      duty: { dutyType: '가정보육', dutyColor: '#E91E63' },
      schedules: [],
    },
    {
      member: { id: 6, name: '이보연' },
      isFamily: false,
      pinOrder: null,
      duty: null,
      schedules: [],
    },
    {
      member: { id: 7, name: '전소이' },
      isFamily: false,
      pinOrder: null,
      duty: null,
      schedules: [],
    },
  ],
  pendingRequestsTo: [
    { fromMember: { id: 10, name: '정유진' }, requestType: 'FRIEND_REQUEST' },
    { fromMember: { id: 11, name: '최민수' }, requestType: 'FAMILY_REQUEST' },
  ],
  pendingRequestsFrom: [
    { toMember: { id: 12, name: '한지민' }, requestType: 'FRIEND_REQUEST' },
  ],
})

// Search modal state
const showSearchModal = ref(false)
const searchKeyword = ref('')
const searchResult = ref<Array<{ id: number; name: string; team: string }>>([
  { id: 20, name: '김서연', team: '개발팀' },
  { id: 21, name: '이준호', team: '디자인팀' },
  { id: 22, name: '박지은', team: '마케팅팀' },
  { id: 23, name: '최현우', team: '개발팀' },
  { id: 24, name: '정수빈', team: '기획팀' },
])
const searchPage = ref(1)
const searchTotalPage = ref(3)
const searchTotalElements = ref(15)
const searchPageSize = ref(5)

// Dropdown state for friend management
const openDropdownId = ref<number | null>(null)

// Drag state
const draggedFriend = ref<number | null>(null)

// Features for guest view
const features = [
  { icon: 'calendar', text: '일정 관리 (등록, 검색, 공개 설정)' },
  { icon: 'check', text: '할일 관리로 까먹지 않는 일상' },
  { icon: 'clock', text: '근무 관리 및 시간표 등록' },
  { icon: 'users', text: '팀원들의 시간표와 일정 공유' },
  { icon: 'heart', text: '친구 및 가족의 일정 조회와 태그 기능' },
]

// Computed: sorted friends (pinned first)
const sortedFriends = computed(() => {
  return [...friendInfo.value.friends].sort((a, b) => {
    const aPinned = a.pinOrder ? 0 : 1
    const bPinned = b.pinOrder ? 0 : 1
    if (aPinned !== bPinned) {
      return aPinned - bPinned
    }
    if (a.pinOrder && b.pinOrder) {
      return (a.pinOrder || 0) - (b.pinOrder || 0)
    }
    return 0
  })
})

// Computed: has pending requests
const hasPendingRequests = computed(() => {
  return friendInfo.value.pendingRequestsTo.length > 0 || friendInfo.value.pendingRequestsFrom.length > 0
})

// Methods
function moveTo(memberId?: number) {
  const id = memberId || myInfo.value.member.id
  router.push(`/duty/${id}`)
}

function printSchedule(schedule: { content: string; totalDays: number; daysFromStart: number; isTagged: boolean; owner: string }) {
  let text = schedule.content
  if (schedule.totalDays > 1) {
    text = `${text} [${schedule.daysFromStart}/${schedule.totalDays}]`
  }
  if (schedule.isTagged) {
    text = `${text} (by ${schedule.owner})`
  }
  return text
}

function printScheduleTime(startDateTime: string) {
  const date = new Date(startDateTime)
  const now = new Date()
  if (date.toLocaleDateString() !== now.toLocaleDateString()) {
    return ''
  }
  if (date.getHours() === 0 && date.getMinutes() === 0) {
    return ''
  }
  return date.toLocaleTimeString('ko-KR', {
    hour: '2-digit',
    minute: '2-digit',
  })
}

// Pin/Unpin friend
function pinFriend(member: { id: number; name: string }) {
  const friend = friendInfo.value.friends.find((f) => f.member.id === member.id)
  if (friend) {
    const maxOrder = Math.max(0, ...friendInfo.value.friends.map((f) => f.pinOrder || 0))
    friend.pinOrder = maxOrder + 1
    // TODO: API call - PATCH /api/friends/pin/{memberId}
    console.log('Pin friend:', member.id)
  }
}

function unpinFriend(member: { id: number; name: string }) {
  const friend = friendInfo.value.friends.find((f) => f.member.id === member.id)
  if (friend) {
    friend.pinOrder = null
    // TODO: API call - PATCH /api/friends/unpin/{memberId}
    console.log('Unpin friend:', member.id)
  }
}

// Friend request actions
function acceptFriendRequest(req: { fromMember: { id: number; name: string } }) {
  friendInfo.value.pendingRequestsTo = friendInfo.value.pendingRequestsTo.filter(
    (r) => r.fromMember.id !== req.fromMember.id
  )
  // TODO: API call - POST /api/friends/request/accept/{fromMemberId}
  console.log('Accept request from:', req.fromMember.id)
}

function rejectFriendRequest(req: { fromMember: { id: number; name: string } }) {
  friendInfo.value.pendingRequestsTo = friendInfo.value.pendingRequestsTo.filter(
    (r) => r.fromMember.id !== req.fromMember.id
  )
  // TODO: API call - POST /api/friends/request/reject/{fromMemberId}
  console.log('Reject request from:', req.fromMember.id)
}

function cancelRequest(req: { toMember: { id: number; name: string } }) {
  friendInfo.value.pendingRequestsFrom = friendInfo.value.pendingRequestsFrom.filter(
    (r) => r.toMember.id !== req.toMember.id
  )
  // TODO: API call - DELETE /api/friends/request/cancel/{toMemberId}
  console.log('Cancel request to:', req.toMember.id)
}

// Friend management actions
function addFamily(member: { id: number; name: string }) {
  // Check if already sent family request
  const alreadySent = friendInfo.value.pendingRequestsFrom.some((r) => r.toMember.id === member.id)
  if (alreadySent) {
    alert('이미 가족 요청을 보낸 상태입니다.')
    return
  }
  // TODO: API call - PUT /api/friends/family/{memberId}
  console.log('Add family:', member.id)
  closeDropdown()
}

function unfriend(member: { id: number; name: string }) {
  if (confirm(`정말로 [${member.name}]님을 친구목록에서 삭제하시겠습니까?`)) {
    friendInfo.value.friends = friendInfo.value.friends.filter((f) => f.member.id !== member.id)
    // TODO: API call - DELETE /api/friends/{memberId}
    console.log('Unfriend:', member.id)
  }
  closeDropdown()
}

// Dropdown management
function toggleDropdown(memberId: number, event: Event) {
  event.stopPropagation()
  openDropdownId.value = openDropdownId.value === memberId ? null : memberId
}

function closeDropdown() {
  openDropdownId.value = null
}

// Search modal
function openSearchModal() {
  showSearchModal.value = true
  searchKeyword.value = ''
  searchPage.value = 1
}

function closeSearchModal() {
  showSearchModal.value = false
}

function search() {
  // TODO: API call - GET /api/friends/search?keyword={keyword}&page={page}&size={size}
  console.log('Search:', searchKeyword.value, 'Page:', searchPage.value)
}

function requestFriend(member: { id: number; name: string }) {
  // TODO: API call - POST /api/friends/request/send/{memberId}
  console.log('Request friend:', member.id)
  // Remove from search results to show it's been requested
  searchResult.value = searchResult.value.filter((m) => m.id !== member.id)
}

function prevPage() {
  if (searchPage.value > 1) {
    searchPage.value--
    search()
  }
}

function nextPage() {
  if (searchPage.value < searchTotalPage.value) {
    searchPage.value++
    search()
  }
}

function goToPage(page: number) {
  searchPage.value = page
  search()
}

// Drag and drop for pinned friends
function onDragStart(event: DragEvent, friendId: number) {
  draggedFriend.value = friendId
  if (event.dataTransfer) {
    event.dataTransfer.effectAllowed = 'move'
  }
}

function onDragOver(event: DragEvent) {
  event.preventDefault()
}

function onDrop(event: DragEvent, targetFriendId: number) {
  event.preventDefault()
  if (draggedFriend.value === null || draggedFriend.value === targetFriendId) {
    draggedFriend.value = null
    return
  }

  const friends = friendInfo.value.friends
  const draggedIndex = friends.findIndex((f) => f.member.id === draggedFriend.value)
  const targetIndex = friends.findIndex((f) => f.member.id === targetFriendId)

  if (draggedIndex !== -1 && targetIndex !== -1) {
    // Swap positions
    const draggedFriendObj = friends[draggedIndex]
    const targetFriendObj = friends[targetIndex]
    if (draggedFriendObj && targetFriendObj && draggedFriendObj.pinOrder && targetFriendObj.pinOrder) {
      const tempOrder = draggedFriendObj.pinOrder
      draggedFriendObj.pinOrder = targetFriendObj.pinOrder
      targetFriendObj.pinOrder = tempOrder
    }
    // TODO: API call - PATCH /api/friends/pin/order with new order
    console.log('Reorder friends')
  }

  draggedFriend.value = null
}

function onDragEnd() {
  draggedFriend.value = null
}

// Close dropdown when clicking outside
onMounted(() => {
  document.addEventListener('click', closeDropdown)
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <!-- Logged-in Dashboard -->
    <template v-if="authStore.isLoggedIn">
      <!-- My Info Section -->
      <div
        class="bg-white rounded-xl shadow-sm border border-gray-200 mb-4 overflow-hidden cursor-pointer hover:shadow-md transition-shadow"
        @click="moveTo()"
      >
        <div class="bg-gray-600 text-center py-2 text-white font-bold uppercase">
          {{ myInfo.member.name || '로딩중...' }}
        </div>
        <div class="p-5">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- Left column: Date & Duty -->
            <div class="space-y-3">
              <div class="flex items-center gap-2 text-gray-700">
                <Calendar class="w-5 h-5 text-gray-500" />
                <span class="font-medium">{{ today }}</span>
              </div>

              <div class="flex items-center gap-2">
                <Briefcase class="w-5 h-5 text-gray-500" />
                <span class="text-gray-600">근무:</span>
                <template v-if="myInfoLoading">
                  <div class="w-4 h-4 border-2 border-gray-300 border-t-gray-600 rounded-full animate-spin"></div>
                </template>
                <template v-else-if="myInfo.duty">
                  <span
                    class="px-2 py-0.5 rounded text-white font-medium text-sm"
                    :style="{ backgroundColor: myInfo.duty.dutyColor }"
                  >
                    {{ myInfo.duty.dutyType }}
                  </span>
                </template>
                <span v-else class="text-gray-400">없음</span>
              </div>
            </div>

            <!-- Right column: Today's schedules -->
            <div class="md:border-l md:pl-6 border-gray-200">
              <div class="flex items-center gap-2 mb-2">
                <ClipboardList class="w-5 h-5 text-gray-500" />
                <span class="text-gray-700 font-medium">오늘 일정</span>
              </div>
              <template v-if="myInfoLoading">
                <div class="flex justify-center py-3">
                  <div class="w-5 h-5 border-2 border-gray-300 border-t-gray-600 rounded-full animate-spin"></div>
                </div>
              </template>
              <ul v-else class="space-y-1">
                <li
                  v-for="schedule in myInfo.schedules"
                  :key="schedule.id"
                  class="py-1 border-b border-gray-100 last:border-0 text-gray-700"
                >
                  <span>{{ printSchedule(schedule) }}</span>
                  <span class="text-gray-400 ml-2 text-sm">{{ printScheduleTime(schedule.startDateTime) }}</span>
                </li>
                <li v-if="myInfo.schedules.length === 0" class="text-gray-400 text-sm">
                  오늘의 일정이 없습니다.
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>

      <!-- Friend Request Section -->
      <div
        v-if="friendInfoInitialized && hasPendingRequests"
        class="bg-white rounded-xl shadow-sm border border-gray-200 mb-4 overflow-hidden"
      >
        <div class="bg-gray-600 text-center py-2 text-white font-bold uppercase">
          친구 요청 관리
        </div>
        <div class="p-5">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <!-- Requests received (to me) -->
            <div
              v-for="req in friendInfo.pendingRequestsTo"
              :key="'to-' + req.fromMember.id"
              class="p-4 border rounded-lg bg-blue-50 border-blue-200"
            >
              <div class="flex justify-between items-center">
                <div class="font-bold text-gray-800 flex items-center gap-2">
                  <Home v-if="req.requestType === 'FAMILY_REQUEST'" class="w-4 h-4 text-blue-600" />
                  <UserPlus v-else class="w-4 h-4 text-blue-600" />
                  {{ req.fromMember.name }}
                </div>
                <div class="flex gap-2">
                  <button
                    class="px-3 py-1 text-sm border border-green-500 text-green-600 rounded hover:bg-green-50 transition"
                    @click="acceptFriendRequest(req)"
                  >
                    승인
                  </button>
                  <button
                    class="px-3 py-1 text-sm border border-red-500 text-red-600 rounded hover:bg-red-50 transition"
                    @click="rejectFriendRequest(req)"
                  >
                    거절
                  </button>
                </div>
              </div>
            </div>

            <!-- Requests sent (from me) -->
            <div
              v-for="req in friendInfo.pendingRequestsFrom"
              :key="'from-' + req.toMember.id"
              class="p-4 border rounded-lg bg-yellow-50 border-yellow-200"
            >
              <div class="flex justify-between items-center">
                <div class="font-bold text-gray-800 flex items-center gap-2">
                  <Home v-if="req.requestType === 'FAMILY_REQUEST'" class="w-4 h-4 text-yellow-600" />
                  <UserPlus v-else class="w-4 h-4 text-yellow-600" />
                  {{ req.toMember.name }}
                </div>
                <button
                  class="px-3 py-1 text-sm border border-yellow-500 text-yellow-700 rounded hover:bg-yellow-100 transition"
                  @click="cancelRequest(req)"
                >
                  요청 취소
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Friends List Section -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 mb-4 overflow-hidden">
        <div class="bg-gray-600 text-center py-2 text-white font-bold uppercase">
          친구 목록
        </div>
        <div class="p-5">
          <template v-if="friendInfoLoading">
            <div class="flex justify-center py-10">
              <div class="w-8 h-8 border-3 border-gray-300 border-t-gray-600 rounded-full animate-spin"></div>
            </div>
          </template>
          <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <!-- Friend Cards -->
            <div
              v-for="friend in sortedFriends"
              :key="friend.member.id"
              :draggable="friend.pinOrder !== null"
              class="p-4 border rounded-lg cursor-pointer hover:bg-gray-50 transition shadow-sm flex flex-col"
              :class="{
                'border-yellow-300 bg-yellow-50': friend.pinOrder,
                'border-gray-200': !friend.pinOrder,
              }"
              @click="moveTo(friend.member.id)"
              @dragstart="(e) => friend.pinOrder && onDragStart(e, friend.member.id)"
              @dragover="onDragOver"
              @drop="(e) => friend.pinOrder && onDrop(e, friend.member.id)"
              @dragend="onDragEnd"
            >
              <div class="flex-grow">
                <!-- Header: Name & Actions -->
                <div class="flex justify-between items-center mb-2">
                  <div class="font-bold text-gray-800 flex items-center gap-1">
                    <User v-if="!friend.isFamily" class="w-4 h-4 text-gray-500" />
                    <Heart v-if="friend.isFamily" class="w-4 h-4 text-red-400" fill="currentColor" />
                    {{ friend.member.name }}
                  </div>
                  <div class="flex items-center gap-2" @click.stop>
                    <!-- Pin/Unpin button -->
                    <button
                      v-if="friend.pinOrder"
                      class="text-yellow-500 hover:text-yellow-600 transition"
                      @click.stop="unpinFriend(friend.member)"
                      title="고정 해제"
                    >
                      <Star class="w-5 h-5" fill="currentColor" />
                    </button>
                    <button
                      v-else
                      class="text-gray-400 hover:text-yellow-500 transition"
                      @click.stop="pinFriend(friend.member)"
                      title="고정"
                    >
                      <Star class="w-5 h-5" />
                    </button>

                    <!-- Dropdown toggle -->
                    <div class="relative">
                      <button
                        class="px-2 py-1 text-sm border border-gray-300 rounded hover:bg-gray-100 transition flex items-center gap-1"
                        @click="toggleDropdown(friend.member.id, $event)"
                      >
                        관리
                        <ChevronDown class="w-3 h-3" />
                      </button>
                      <!-- Dropdown menu -->
                      <div
                        v-if="openDropdownId === friend.member.id"
                        class="absolute right-0 mt-1 w-32 bg-white border border-gray-200 rounded-lg shadow-lg z-10"
                      >
                        <button
                          v-if="!friend.isFamily"
                          class="w-full px-3 py-2 text-left text-sm text-blue-600 hover:bg-blue-50 flex items-center gap-2"
                          @click="addFamily(friend.member)"
                        >
                          <Home class="w-4 h-4" />
                          가족 등록
                        </button>
                        <button
                          class="w-full px-3 py-2 text-left text-sm text-red-600 hover:bg-red-50 flex items-center gap-2"
                          @click="unfriend(friend.member)"
                        >
                          <Trash2 class="w-4 h-4" />
                          친구 삭제
                        </button>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Duty info -->
                <p class="text-sm text-gray-600 mb-2 flex items-center gap-1">
                  <Briefcase class="w-4 h-4 text-gray-400" />
                  근무:
                  <span v-if="friend.duty" class="ml-1">{{ friend.duty.dutyType }}</span>
                  <span v-else class="ml-1 text-gray-400">-</span>
                </p>

                <!-- Schedules -->
                <div v-if="friend.schedules && friend.schedules.length" class="mt-2">
                  <ul class="space-y-1">
                    <li
                      v-for="schedule in friend.schedules"
                      :key="schedule.id"
                      class="text-sm py-1 border-b border-gray-100 last:border-0 text-gray-600"
                    >
                      <span>{{ printSchedule(schedule) }}</span>
                      <span class="text-gray-400 ml-2">{{ printScheduleTime(schedule.startDateTime) }}</span>
                    </li>
                  </ul>
                </div>
              </div>

              <!-- Drag handle for pinned friends -->
              <div v-if="friend.pinOrder" class="flex justify-end mt-2" @click.stop>
                <div
                  class="bg-gray-100 rounded-full border border-gray-200 px-2 py-1 shadow-sm cursor-grab active:cursor-grabbing"
                  title="드래그하여 순서 변경"
                >
                  <GripVertical class="w-4 h-4 text-gray-400" />
                </div>
              </div>
            </div>

            <!-- Add Friend Card -->
            <div
              v-if="friendInfoInitialized"
              class="p-4 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-blue-400 hover:bg-blue-50 transition flex flex-col items-center justify-center min-h-[120px] bg-blue-600"
              @click="openSearchModal"
            >
              <UserPlus class="w-8 h-8 text-white mb-2" />
              <span class="font-bold text-white">친구 추가</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Admin Section -->
      <div
        v-if="authStore.isAdmin && friendInfoInitialized"
        class="bg-white rounded-xl shadow-sm border border-gray-200 mb-4 overflow-hidden"
      >
        <div class="bg-gray-600 text-center py-2 text-white font-bold uppercase">
          관리자
        </div>
        <div class="p-5">
          <div class="grid grid-cols-2 gap-3">
            <router-link
              to="/admin"
              class="p-4 border rounded-lg text-center hover:bg-gray-50 transition flex items-center justify-center gap-2 text-lg"
            >
              회원관리
              <Settings class="w-5 h-5" />
            </router-link>
            <router-link
              to="/admin/teams"
              class="p-4 border rounded-lg text-center hover:bg-gray-50 transition flex items-center justify-center gap-2 text-lg"
            >
              팀 관리
              <Settings class="w-5 h-5" />
            </router-link>
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
          class="inline-block border-2 border-gray-800 text-gray-800 px-8 py-3 rounded-lg font-medium hover:bg-gray-800 hover:!text-white transition"
        >
          로그인 / 회원가입
        </router-link>
      </div>

      <!-- Features Section -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-8">
        <h2 class="text-2xl font-bold text-gray-900 mb-6">주요 기능</h2>
        <ul class="space-y-4">
          <li v-for="feature in features" :key="feature.text" class="flex items-start gap-3">
            <Calendar v-if="feature.icon === 'calendar'" class="w-6 h-6 text-gray-500 mt-0.5" />
            <CheckCircle v-else-if="feature.icon === 'check'" class="w-6 h-6 text-gray-500 mt-0.5" />
            <Clock v-else-if="feature.icon === 'clock'" class="w-6 h-6 text-gray-500 mt-0.5" />
            <Users v-else-if="feature.icon === 'users'" class="w-6 h-6 text-gray-500 mt-0.5" />
            <Heart v-else-if="feature.icon === 'heart'" class="w-6 h-6 text-gray-500 mt-0.5" />
            <span class="text-gray-700">{{ feature.text }}</span>
          </li>
        </ul>
        <p class="mt-6 text-gray-600">
          지금 바로 Dutypark을 사용해보세요!<br>
          <span class="text-sm text-gray-500">(현재 회원가입은 카카오톡 로그인을 지원합니다.)</span>
        </p>
      </div>
    </template>

    <!-- Search Modal -->
    <Teleport to="body">
      <div
        v-if="showSearchModal"
        class="fixed inset-0 z-50 flex items-center justify-center"
        @click.self="closeSearchModal"
      >
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-black/50" @click="closeSearchModal"></div>

        <!-- Modal Content -->
        <div class="relative bg-white rounded-xl shadow-2xl w-full max-w-2xl mx-4 max-h-[90vh] overflow-hidden">
          <!-- Header -->
          <div class="flex items-center justify-between p-4 border-b border-gray-200">
            <h3 class="text-xl font-semibold text-gray-900">친구 추가</h3>
            <button
              class="text-gray-400 hover:text-gray-600 transition"
              @click="closeSearchModal"
            >
              <X class="w-6 h-6" />
            </button>
          </div>

          <!-- Body -->
          <div class="p-4 overflow-y-auto max-h-[calc(90vh-140px)]">
            <!-- Search Input -->
            <div class="flex gap-2 mb-4">
              <div class="flex-grow relative">
                <input
                  v-model="searchKeyword"
                  type="text"
                  placeholder="이름 또는 팀 검색"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
                  @keyup.enter="search"
                />
              </div>
              <button
                class="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition flex items-center gap-2"
                @click="search"
              >
                <Search class="w-4 h-4" />
                검색
              </button>
            </div>

            <!-- Search Results -->
            <div v-if="searchResult.length > 0">
              <table class="w-full">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-4 py-2 text-left text-sm font-medium text-gray-600 w-12">#</th>
                    <th class="px-4 py-2 text-left text-sm font-medium text-gray-600">팀</th>
                    <th class="px-4 py-2 text-left text-sm font-medium text-gray-600">이름</th>
                    <th class="px-4 py-2 text-center text-sm font-medium text-gray-600 w-24">요청</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  <tr v-for="(member, index) in searchResult" :key="member.id" class="hover:bg-gray-50">
                    <td class="px-4 py-3 text-sm text-gray-500">
                      {{ (searchPage - 1) * searchPageSize + index + 1 }}
                    </td>
                    <td class="px-4 py-3 text-sm text-gray-700">{{ member.team }}</td>
                    <td class="px-4 py-3 text-sm text-gray-900 font-medium">{{ member.name }}</td>
                    <td class="px-4 py-3 text-center">
                      <button
                        class="px-3 py-1 text-sm border border-green-500 text-green-600 rounded hover:bg-green-50 transition"
                        @click="requestFriend(member)"
                      >
                        친구 요청
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>

              <!-- Pagination -->
              <div class="flex justify-center items-center gap-2 mt-4">
                <button
                  class="p-2 rounded border border-gray-300 hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed transition"
                  :disabled="searchPage === 1"
                  @click="prevPage"
                >
                  <ChevronLeft class="w-4 h-4" />
                </button>

                <template v-for="i in searchTotalPage" :key="i">
                  <button
                    class="w-8 h-8 rounded border transition"
                    :class="i === searchPage
                      ? 'bg-blue-600 text-white border-blue-600'
                      : 'border-gray-300 hover:bg-gray-100'"
                    @click="goToPage(i)"
                  >
                    {{ i }}
                  </button>
                </template>

                <button
                  class="p-2 rounded border border-gray-300 hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed transition"
                  :disabled="searchPage === searchTotalPage"
                  @click="nextPage"
                >
                  <ChevronRight class="w-4 h-4" />
                </button>
              </div>

              <p class="text-center text-sm text-gray-500 mt-2">
                페이지 {{ searchPage }} / {{ searchTotalPage }} | 전체 결과: {{ searchTotalElements }}
              </p>
            </div>
            <p v-else class="text-center text-gray-500 py-8">
              검색 결과가 없습니다.
            </p>
          </div>

          <!-- Footer -->
          <div class="flex justify-end p-4 border-t border-gray-200">
            <button
              class="px-4 py-2 bg-gray-500 text-white rounded-lg hover:bg-gray-600 transition"
              @click="closeSearchModal"
            >
              닫기
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
