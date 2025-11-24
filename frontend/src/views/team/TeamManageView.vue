<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  UserPlus,
  Trash2,
  Plus,
  ArrowUp,
  ArrowDown,
  Pencil,
  Check,
  X,
  Upload,
  Search,
  ChevronLeft,
  ChevronRight,
  Shield,
  ShieldOff,
  Crown,
} from 'lucide-vue-next'

const route = useRoute()
const router = useRouter()
const teamId = route.params.teamId

// State
const isAdmin = ref(true) // Is team admin
const isAppAdmin = ref(false) // Is application admin
const loginId = ref(1)
const teamLoaded = ref(true)

// Team data
const team = ref({
  id: Number(teamId),
  name: '개발팀',
  description: '프론트엔드 및 백엔드 개발을 담당하는 팀입니다.',
  adminId: 1,
  adminName: '김철수',
  workType: 'WEEKDAY',
  dutyBatchTemplate: null as { name: string; label: string } | null,
  members: [
    { id: 1, name: '김철수', isManager: true, isAdmin: true },
    { id: 2, name: '이영희', isManager: true, isAdmin: false },
    { id: 3, name: '박지민', isManager: false, isAdmin: false },
    { id: 4, name: '정수현', isManager: false, isAdmin: false },
    { id: 5, name: '최민수', isManager: false, isAdmin: false },
  ],
  dutyTypes: [
    { id: null, name: 'OFF', color: '#ffffba' }, // Default off duty (no id)
    { id: 1, name: '주간', color: '#bae1ff' },
    { id: 2, name: '야간', color: '#baffc9' },
    { id: 3, name: '당직', color: '#ffdfba' },
  ],
})

const dutyBatchTemplates = ref([
  { name: 'SUNGSIM_CAKE', label: '성심케익 근무표' },
  { name: 'STANDARD', label: '표준 근무표' },
])

const workTypes = [
  { value: 'WEEKDAY', label: '평일 근무' },
  { value: 'WEEKEND', label: '주말 근무' },
  { value: 'FIXED', label: '고정 근무' },
  { value: 'FLEXIBLE', label: '유연 근무' },
]

// Computed
const hasMember = computed(() => team.value.members && team.value.members.length > 0)
const hasDutyType = computed(() => team.value.dutyTypes && team.value.dutyTypes.length > 0)

// Member Search Modal
const showMemberSearchModal = ref(false)
const searchKeyword = ref('')
const searchResult = ref<Array<{
  id: number
  name: string
  email: string
  team?: string
}>>([])
const currentPage = ref(1)
const totalPages = ref(1)
const totalElements = ref(0)
const pageSize = 5

// Dummy search results
const allMembers: Array<{ id: number; name: string; email: string; team?: string }> = [
  { id: 10, name: '홍길동', email: 'hong@example.com' },
  { id: 11, name: '임꺽정', email: 'im@example.com' },
  { id: 12, name: '장보고', email: 'jang@example.com', team: '마케팅팀' },
  { id: 13, name: '이순신', email: 'lee@example.com' },
  { id: 14, name: '강감찬', email: 'kang@example.com' },
  { id: 15, name: '을지문덕', email: 'eulji@example.com', team: '디자인팀' },
  { id: 16, name: '계백', email: 'gye@example.com' },
  { id: 17, name: '김유신', email: 'kimy@example.com' },
]

// Duty Type Modal
const showDutyTypeModal = ref(false)
const dutyTypeForm = ref({
  id: null as number | null,
  name: '',
  color: '#ffb3ba',
  isDefault: false,
})

// Duty Batch Upload Modal
const showBatchUploadModal = ref(false)
const batchForm = ref({
  file: null as File | null,
  year: new Date().getFullYear(),
  month: new Date().getMonth() + 1,
})

// Color presets
const colorPresets = [
  '#ffb3ba', '#ffdfba', '#ffffba', '#baffc9', '#bae1ff',
  '#e0bbff', '#ffd1dc', '#c1e1c1', '#aec6cf', '#f5f5dc',
]

// Methods
function openMemberSearchModal() {
  showMemberSearchModal.value = true
  searchKeyword.value = ''
  currentPage.value = 1
  searchMembers()
}

function closeMemberSearchModal() {
  showMemberSearchModal.value = false
}

function searchMembers() {
  const keyword = searchKeyword.value.toLowerCase()
  const filtered = allMembers.filter(m =>
    m.name.includes(keyword) || m.email.includes(keyword)
  )
  totalElements.value = filtered.length
  totalPages.value = Math.ceil(filtered.length / pageSize) || 1
  const start = (currentPage.value - 1) * pageSize
  searchResult.value = filtered.slice(start, start + pageSize)
}

function prevPage() {
  if (currentPage.value > 1) {
    currentPage.value--
    searchMembers()
  }
}

function nextPage() {
  if (currentPage.value < totalPages.value) {
    currentPage.value++
    searchMembers()
  }
}

function goToPage(page: number) {
  currentPage.value = page
  searchMembers()
}

function addMember(member: { id: number; name: string }) {
  if (confirm(`${member.name} 님을 팀에 추가하시겠습니까?`)) {
    console.log('Adding member:', member.id)
    closeMemberSearchModal()
  }
}

function removeMember(memberId: number) {
  const member = team.value.members.find(m => m.id === memberId)
  if (confirm(`정말로 ${member?.name} 님을 팀에서 제외하시겠습니까?`)) {
    console.log('Removing member:', memberId)
  }
}

function assignManager(member: { id: number; name: string }) {
  if (confirm(`${member.name} 님에게 매니저 권한을 부여하시겠습니까?`)) {
    console.log('Assigning manager:', member.id)
  }
}

function unAssignManager(member: { id: number; name: string }) {
  if (confirm(`${member.name} 님의 매니저 권한을 취소하시겠습니까?`)) {
    console.log('Unassigning manager:', member.id)
  }
}

function changeAdmin(member?: { id: number; name: string }) {
  const message = member
    ? `정말 ${member.name} 님을 대표로 변경하시겠습니까?\n다시 대표 권한을 획득하려면 ${member.name} 님에게 요청해야합니다.`
    : '팀의 대표를 초기화 하시겠습니까?'

  if (confirm(message)) {
    console.log('Changing admin to:', member?.id || 'null')
  }
}

function updateWorkType(workType: string) {
  console.log('Updating work type:', workType)
  alert('근무 형태가 성공적으로 변경되었습니다.')
}

function updateBatchTemplate(templateName: string) {
  console.log('Updating batch template:', templateName)
  team.value.dutyBatchTemplate = templateName
    ? dutyBatchTemplates.value.find(t => t.name === templateName) || null
    : null
}

// Duty Type Methods
function openAddDutyTypeModal() {
  dutyTypeForm.value = {
    id: null,
    name: '',
    color: '#ffb3ba',
    isDefault: false,
  }
  showDutyTypeModal.value = true
}

function openEditDutyTypeModal(dutyType: { id: number | null; name: string; color: string }) {
  dutyTypeForm.value = {
    id: dutyType.id,
    name: dutyType.name,
    color: dutyType.color,
    isDefault: dutyType.id === null,
  }
  showDutyTypeModal.value = true
}

function closeDutyTypeModal() {
  showDutyTypeModal.value = false
}

function saveDutyType() {
  if (!dutyTypeForm.value.name) {
    alert('근무유형 이름을 입력해주세요.')
    return
  }

  const exists = team.value.dutyTypes.some(
    dt => dt.name === dutyTypeForm.value.name && dt.id !== dutyTypeForm.value.id
  )
  if (exists) {
    alert(`${dutyTypeForm.value.name} 이름의 근무유형이 이미 존재합니다.`)
    return
  }

  console.log('Saving duty type:', dutyTypeForm.value)
  closeDutyTypeModal()
}

function removeDutyType(dutyType: { id: number | null; name: string }) {
  if (confirm(`[ ${dutyType.name} ] 근무 유형을 삭제하시겠습니까?\n삭제는 되돌릴 수 없으며 해당 유형으로 표시된 근무는 모두 제거됩니다.`)) {
    console.log('Removing duty type:', dutyType.id)
  }
}

function swapPosition(index1: number, index2: number) {
  console.log('Swapping positions:', index1, index2)
  const temp = team.value.dutyTypes[index1]
  const other = team.value.dutyTypes[index2]
  if (temp && other) {
    team.value.dutyTypes[index1] = other
    team.value.dutyTypes[index2] = temp
  }
}

// Batch Upload Methods
function openBatchUploadModal() {
  batchForm.value = {
    file: null,
    year: new Date().getFullYear(),
    month: new Date().getMonth() + 1,
  }
  showBatchUploadModal.value = true
}

function closeBatchUploadModal() {
  showBatchUploadModal.value = false
}

function handleFileChange(event: Event) {
  const target = event.target as HTMLInputElement
  if (target.files && target.files[0]) {
    batchForm.value.file = target.files[0]
  }
}

function uploadBatch() {
  if (!batchForm.value.file) {
    alert('파일을 선택해주세요.')
    return
  }
  console.log('Uploading batch:', batchForm.value)
  alert('근무표가 성공적으로 업로드되었습니다.')
  closeBatchUploadModal()
}

function removeTeam() {
  if (confirm('정말로 이 팀을 삭제하겠습니까?')) {
    console.log('Removing team:', team.value.id)
    router.push('/admin/team')
  }
}

function goBack() {
  router.push('/team')
}
</script>

<template>
  <div class="max-w-4xl mx-auto px-2 sm:px-4 py-4">
    <!-- Header -->
    <div class="bg-gray-600 text-white font-bold text-xl text-center py-3 rounded-t-lg flex items-center justify-center gap-2">
      {{ team.name }} 관리
      <a
        v-if="isAppAdmin"
        href="/admin/team"
        class="px-3 py-1 bg-blue-500 text-white text-sm rounded-lg hover:bg-blue-600 transition"
      >
        팀 목록
      </a>
      <button
        v-if="isAdmin && teamLoaded && !hasMember"
        @click="removeTeam"
        class="px-3 py-1 bg-red-500 text-white text-sm rounded-lg hover:bg-red-600 transition"
      >
        팀 삭제
      </button>
    </div>

    <!-- Team Info Card -->
    <div class="bg-white border border-gray-200 rounded-b-lg overflow-hidden mb-4">
      <table class="w-full">
        <tbody class="divide-y divide-gray-200">
          <tr>
            <th class="px-4 py-3 text-left bg-gray-50 w-1/4 font-medium text-gray-700">
              팀 설명
            </th>
            <td class="px-4 py-3 text-gray-800">
              {{ team.description }}
            </td>
          </tr>
          <tr v-if="isAdmin">
            <th class="px-4 py-3 text-left bg-gray-50 font-medium text-gray-700">
              팀 대표
            </th>
            <td class="px-4 py-3 text-gray-800">
              <div class="flex items-center gap-2">
                <span class="font-bold">{{ team.adminName || 'N/A' }}</span>
                <button
                  v-if="team.adminId && loginId !== team.adminId"
                  @click="changeAdmin()"
                  class="px-2 py-1 text-sm border border-red-500 text-red-500 rounded hover:bg-red-50 transition flex items-center gap-1"
                >
                  <Trash2 class="w-3 h-3" />
                  대표 취소
                </button>
              </div>
            </td>
          </tr>
          <tr>
            <th class="px-4 py-3 text-left bg-gray-50 font-medium text-gray-700">
              근무 형태
            </th>
            <td class="px-4 py-3">
              <select
                :value="team.workType"
                @change="updateWorkType(($event.target as HTMLSelectElement).value)"
                class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option v-for="wt in workTypes" :key="wt.value" :value="wt.value">
                  {{ wt.label }}
                </option>
              </select>
            </td>
          </tr>
          <tr>
            <th class="px-4 py-3 text-left bg-gray-50 font-medium text-gray-700">
              근무 반입 양식
            </th>
            <td class="px-4 py-3">
              <select
                :value="team.dutyBatchTemplate?.name || ''"
                @change="updateBatchTemplate(($event.target as HTMLSelectElement).value)"
                class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                <option value="">없음</option>
                <option v-for="template in dutyBatchTemplates" :key="template.name" :value="template.name">
                  {{ template.label }}
                </option>
              </select>
            </td>
          </tr>
          <tr v-if="team.dutyBatchTemplate">
            <th class="px-4 py-3 text-left bg-gray-50 font-medium text-gray-700">
              근무표 업로드
            </th>
            <td class="px-4 py-3">
              <button
                @click="openBatchUploadModal"
                class="px-4 py-2 bg-blue-500 text-white rounded-lg font-medium hover:bg-blue-600 transition flex items-center gap-1"
              >
                <Upload class="w-4 h-4" />
                등록
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Members Section -->
    <div class="bg-white border border-gray-200 rounded-lg overflow-hidden mb-4">
      <div class="bg-gray-600 text-white px-4 py-3 flex items-center justify-between">
        <h3 class="font-bold">팀 멤버</h3>
        <button
          @click="openMemberSearchModal"
          class="px-3 py-1.5 bg-blue-500 text-white rounded-lg text-sm font-medium hover:bg-blue-600 transition flex items-center gap-1"
        >
          <UserPlus class="w-4 h-4" />
          멤버 추가
        </button>
      </div>

      <div v-if="hasMember" class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-gray-800 text-white">
            <tr>
              <th class="px-4 py-2 text-center w-12">#</th>
              <th class="px-4 py-2 text-left">이름</th>
              <th class="px-4 py-2 text-center">매니저</th>
              <th class="px-4 py-2 text-center">도구</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="(member, index) in team.members" :key="member.id" class="hover:bg-gray-50">
              <td class="px-4 py-3 text-center text-gray-600">{{ index + 1 }}</td>
              <td class="px-4 py-3 font-medium text-gray-800">{{ member.name }}</td>
              <td class="px-4 py-3 text-center">
                <template v-if="!isAdmin">
                  <Check v-if="member.isManager" class="w-5 h-5 text-green-500 mx-auto" />
                </template>
                <template v-else>
                  <button
                    v-if="!member.isManager"
                    @click="assignManager(member)"
                    class="text-green-500 hover:text-green-700 transition"
                  >
                    <Plus class="w-5 h-5 mx-auto" />
                  </button>
                  <div v-else-if="member.isManager && !member.isAdmin" class="flex items-center justify-center gap-1">
                    <button
                      @click="unAssignManager(member)"
                      class="px-2 py-1 text-xs border border-yellow-500 text-yellow-600 rounded hover:bg-yellow-50 transition flex items-center gap-1"
                    >
                      <ShieldOff class="w-3 h-3" />
                      권한 취소
                    </button>
                    <button
                      @click="changeAdmin(member)"
                      class="px-2 py-1 text-xs border border-blue-500 text-blue-500 rounded hover:bg-blue-50 transition flex items-center gap-1"
                    >
                      <Crown class="w-3 h-3" />
                      대표 위임
                    </button>
                  </div>
                  <span v-else-if="member.isAdmin" class="text-gray-400">-</span>
                </template>
              </td>
              <td class="px-4 py-3 text-center">
                <button
                  @click="removeMember(member.id)"
                  class="px-2 py-1 text-sm bg-red-500 text-white rounded hover:bg-red-600 transition flex items-center gap-1 mx-auto"
                >
                  <Trash2 class="w-3 h-3" />
                  탈퇴
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div v-else class="p-6 text-center text-gray-500">
        이 팀에 멤버가 없습니다.
      </div>
    </div>

    <!-- Duty Types Section -->
    <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
      <div class="bg-gray-600 text-white px-4 py-3 flex items-center justify-between">
        <h3 class="font-bold">근무 유형</h3>
        <button
          @click="openAddDutyTypeModal"
          class="px-3 py-1.5 bg-white text-gray-800 rounded-lg text-sm font-medium hover:bg-gray-100 transition flex items-center gap-1"
        >
          <Plus class="w-4 h-4" />
          추가
        </button>
      </div>

      <div v-if="hasDutyType" class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-gray-800 text-white">
            <tr>
              <th class="px-4 py-2 text-center w-12">#</th>
              <th class="px-4 py-2 text-left">근무명</th>
              <th class="px-4 py-2 text-center">색상</th>
              <th class="px-4 py-2 text-center">도구</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="(dutyType, index) in team.dutyTypes" :key="dutyType.id || 'default'" class="hover:bg-gray-50">
              <td class="px-4 py-3 text-center text-gray-600">{{ index + 1 }}</td>
              <td class="px-4 py-3 font-bold text-gray-800">
                {{ dutyType.name }}
                <span v-if="dutyType.id === null" class="text-xs text-gray-400 font-normal">(휴무)</span>
              </td>
              <td class="px-4 py-3 text-center">
                <span
                  class="inline-block w-6 h-6 rounded-full border-2 border-gray-200"
                  :style="{ backgroundColor: dutyType.color }"
                ></span>
              </td>
              <td class="px-4 py-3">
                <div class="flex items-center justify-center gap-1">
                  <button
                    v-if="dutyType.id"
                    :disabled="index === 0 || index === team.dutyTypes.length - 1"
                    @click="swapPosition(index, index + 1)"
                    class="p-1.5 border border-gray-300 rounded hover:bg-gray-100 transition disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <ArrowDown class="w-4 h-4" />
                  </button>
                  <button
                    v-if="dutyType.id"
                    :disabled="index <= 1"
                    @click="swapPosition(index, index - 1)"
                    class="p-1.5 border border-gray-300 rounded hover:bg-gray-100 transition disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <ArrowUp class="w-4 h-4" />
                  </button>
                  <button
                    @click="openEditDutyTypeModal(dutyType)"
                    class="p-1.5 border border-blue-500 text-blue-500 rounded hover:bg-blue-50 transition"
                  >
                    <Pencil class="w-4 h-4" />
                  </button>
                  <button
                    v-if="dutyType.id"
                    @click="removeDutyType(dutyType)"
                    class="p-1.5 border border-red-500 text-red-500 rounded hover:bg-red-50 transition"
                  >
                    <Trash2 class="w-4 h-4" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div v-else class="p-6 text-center text-gray-500">
        근무 유형이 없습니다.
      </div>
    </div>

    <!-- Back Button -->
    <div class="mt-4">
      <button
        @click="goBack"
        class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-100 transition flex items-center gap-1"
      >
        <ChevronLeft class="w-4 h-4" />
        팀으로 돌아가기
      </button>
    </div>

    <!-- Member Search Modal -->
    <div
      v-if="showMemberSearchModal"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
      @click.self="closeMemberSearchModal"
    >
      <div class="bg-white rounded-lg shadow-xl w-full max-w-lg">
        <div class="flex items-center justify-between p-4 border-b">
          <h3 class="text-lg font-bold">멤버 추가</h3>
          <button
            @click="closeMemberSearchModal"
            class="p-1 hover:bg-gray-100 rounded transition"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="p-4">
          <!-- Search Input -->
          <div class="flex gap-2 mb-4">
            <input
              v-model="searchKeyword"
              type="text"
              placeholder="이름 또는 이메일로 검색"
              class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              @keyup.enter="searchMembers"
            />
            <button
              @click="searchMembers"
              class="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition"
            >
              <Search class="w-5 h-5" />
            </button>
          </div>

          <!-- Search Results -->
          <div v-if="searchResult.length > 0" class="overflow-x-auto">
            <table class="w-full">
              <thead class="bg-gray-100">
                <tr>
                  <th class="px-3 py-2 text-left text-sm">#</th>
                  <th class="px-3 py-2 text-left text-sm">이름</th>
                  <th class="px-3 py-2 text-left text-sm">이메일</th>
                  <th class="px-3 py-2 text-center text-sm">추가</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200">
                <tr v-for="(member, index) in searchResult" :key="member.id" class="hover:bg-gray-50">
                  <td class="px-3 py-2 text-sm text-gray-600">
                    {{ (currentPage - 1) * pageSize + index + 1 }}
                  </td>
                  <td class="px-3 py-2 text-sm font-medium">{{ member.name }}</td>
                  <td class="px-3 py-2 text-sm text-gray-600">{{ member.email }}</td>
                  <td class="px-3 py-2 text-center">
                    <button
                      @click="addMember(member)"
                      :disabled="!!member.team"
                      class="px-3 py-1 bg-blue-500 text-white text-sm rounded hover:bg-blue-600 transition disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      추가
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div v-else class="text-center text-gray-500 py-4">
            검색 결과가 없습니다.
          </div>

          <!-- Pagination -->
          <div v-if="searchResult.length > 0" class="mt-4">
            <div class="text-sm text-gray-600 mb-2">
              Page {{ currentPage }} of {{ totalPages }} | Total: {{ totalElements }}
            </div>
            <div class="flex items-center gap-1">
              <button
                @click="prevPage"
                :disabled="currentPage === 1"
                class="px-3 py-1 border border-gray-300 rounded hover:bg-gray-100 transition disabled:opacity-50"
              >
                <ChevronLeft class="w-4 h-4" />
              </button>
              <button
                v-for="i in totalPages"
                :key="i"
                @click="goToPage(i)"
                class="px-3 py-1 border rounded transition"
                :class="i === currentPage ? 'bg-blue-500 text-white border-blue-500' : 'border-gray-300 hover:bg-gray-100'"
              >
                {{ i }}
              </button>
              <button
                @click="nextPage"
                :disabled="currentPage === totalPages"
                class="px-3 py-1 border border-gray-300 rounded hover:bg-gray-100 transition disabled:opacity-50"
              >
                <ChevronRight class="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>

        <div class="flex justify-end p-4 border-t">
          <button
            @click="closeMemberSearchModal"
            class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg font-medium hover:bg-gray-300 transition"
          >
            닫기
          </button>
        </div>
      </div>
    </div>

    <!-- Duty Type Modal -->
    <div
      v-if="showDutyTypeModal"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
      @click.self="closeDutyTypeModal"
    >
      <div class="bg-white rounded-lg shadow-xl w-full max-w-md">
        <div class="flex items-center justify-between p-4 border-b">
          <h3 class="text-lg font-bold">
            {{ dutyTypeForm.id !== null || dutyTypeForm.isDefault ? '근무 유형 수정' : '근무 유형 추가' }}
          </h3>
          <button
            @click="closeDutyTypeModal"
            class="p-1 hover:bg-gray-100 rounded transition"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="p-4 space-y-4">
          <p class="text-sm text-gray-600">
            해당 근무유형의 명칭 및 색상을 선택해주세요.
          </p>

          <div
            v-if="dutyTypeForm.isDefault"
            class="bg-blue-50 border border-blue-200 rounded-lg p-3 text-sm text-blue-700"
          >
            현재 선택한 근무 유형은 <strong>휴무일</strong>에 해당합니다.
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              근무유형
            </label>
            <input
              v-model="dutyTypeForm.name"
              type="text"
              maxlength="10"
              placeholder="근무유형"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">
              색상 선택
            </label>
            <div class="flex flex-wrap gap-2 mb-3">
              <button
                v-for="color in colorPresets"
                :key="color"
                @click="dutyTypeForm.color = color"
                class="w-8 h-8 rounded-full border-2 transition"
                :class="dutyTypeForm.color === color ? 'border-gray-800 ring-2 ring-offset-1 ring-gray-400' : 'border-gray-200 hover:border-gray-400'"
                :style="{ backgroundColor: color }"
              ></button>
            </div>
            <div class="flex items-center gap-2">
              <span class="text-sm text-gray-600">직접 입력:</span>
              <input
                v-model="dutyTypeForm.color"
                type="color"
                class="w-10 h-10 rounded cursor-pointer"
              />
              <input
                v-model="dutyTypeForm.color"
                type="text"
                class="px-2 py-1 border border-gray-300 rounded text-sm w-24"
              />
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              미리보기
            </label>
            <div
              class="inline-block px-4 py-2 rounded-lg border font-medium"
              :style="{ backgroundColor: dutyTypeForm.color }"
            >
              {{ dutyTypeForm.name || '근무명 입력' }}
            </div>
          </div>
        </div>

        <div class="flex justify-end gap-2 p-4 border-t">
          <button
            @click="saveDutyType"
            class="px-4 py-2 bg-green-500 text-white rounded-lg font-medium hover:bg-green-600 transition"
          >
            {{ dutyTypeForm.id !== null || dutyTypeForm.isDefault ? '저장' : '추가' }}
          </button>
          <button
            @click="closeDutyTypeModal"
            class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg font-medium hover:bg-gray-300 transition"
          >
            취소
          </button>
        </div>
      </div>
    </div>

    <!-- Batch Upload Modal -->
    <div
      v-if="showBatchUploadModal"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
      @click.self="closeBatchUploadModal"
    >
      <div class="bg-white rounded-lg shadow-xl w-full max-w-md">
        <div class="flex items-center justify-between p-4 border-b">
          <h3 class="text-lg font-bold">근무표 업로드</h3>
          <button
            @click="closeBatchUploadModal"
            class="p-1 hover:bg-gray-100 rounded transition"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="p-4 space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              근무표 파일 업로드 (.xlsx)
            </label>
            <input
              type="file"
              accept=".xlsx"
              @change="handleFileChange"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                연도
              </label>
              <input
                v-model.number="batchForm.year"
                type="number"
                :min="new Date().getFullYear()"
                :max="new Date().getFullYear() + 1"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                월
              </label>
              <input
                v-model.number="batchForm.month"
                type="number"
                min="1"
                max="12"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
          </div>
        </div>

        <div class="flex justify-end gap-2 p-4 border-t">
          <button
            @click="uploadBatch"
            class="px-4 py-2 bg-blue-500 text-white rounded-lg font-medium hover:bg-blue-600 transition"
          >
            업로드
          </button>
          <button
            @click="closeBatchUploadModal"
            class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg font-medium hover:bg-gray-300 transition"
          >
            취소
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
