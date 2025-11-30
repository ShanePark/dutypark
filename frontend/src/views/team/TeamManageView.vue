<script setup lang="ts">
import { ref, computed, onMounted, nextTick, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useSwal } from '@/composables/useSwal'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
import { useAuthStore } from '@/stores/auth'
import { teamApi } from '@/api/team'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import adminApi from '@/api/admin'
import Pickr from '@simonwep/pickr'
import '@simonwep/pickr/dist/themes/monolith.min.css'
import type {
  TeamDto,
  TeamMemberDto,
  DutyTypeDto,
  DutyBatchTemplateDto,
  MemberDto,
} from '@/types'
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
  Loader2,
} from 'lucide-vue-next'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { showWarning, showError, toastSuccess, confirmDelete, confirm } = useSwal()
const teamId = Number(route.params.teamId)

// Loading state
const loading = ref(false)
const saving = ref(false)

// State
const isAdmin = ref(false) // Is team admin
const isAppAdmin = computed(() => authStore.user?.isAdmin ?? false)
const loginId = computed(() => authStore.user?.id ?? 0)
const teamLoaded = ref(false)

// Team data
const team = ref<TeamDto | null>(null)

const dutyBatchTemplates = ref<DutyBatchTemplateDto[]>([])

const workTypes = [
  { value: 'WEEKDAY', label: '평일 근무' },
  { value: 'WEEKEND', label: '주말 근무' },
  { value: 'FIXED', label: '고정 근무' },
  { value: 'FLEXIBLE', label: '유연 근무' },
]

// Computed
const hasMember = computed(() => team.value?.members && team.value.members.length > 0)
const hasDutyType = computed(() => team.value?.dutyTypes && team.value.dutyTypes.length > 0)

// Member Search Modal
const showMemberSearchModal = ref(false)
useBodyScrollLock(showMemberSearchModal)
useEscapeKey(showMemberSearchModal, () => { showMemberSearchModal.value = false })
const searchKeyword = ref('')
const searchLoading = ref(false)
const searchResult = ref<MemberDto[]>([])
const currentPage = ref(0) // 0-indexed for API
const totalPages = ref(1)
const totalElements = ref(0)
const pageSize = 5

// Duty Type Modal
const showDutyTypeModal = ref(false)
useBodyScrollLock(showDutyTypeModal)
useEscapeKey(showDutyTypeModal, () => { showDutyTypeModal.value = false })
const dutyTypeForm = ref({
  id: null as number | null,
  name: '',
  color: '#ffb3ba',
  isDefault: false,
})

// Duty Batch Upload Modal
const showBatchUploadModal = ref(false)
useBodyScrollLock(showBatchUploadModal)
useEscapeKey(showBatchUploadModal, () => { showBatchUploadModal.value = false })
const batchForm = ref({
  file: null as File | null,
  year: new Date().getFullYear(),
  month: new Date().getMonth() + 1,
})

// Pickr instance
let pickrInstance: Pickr | null = null
const colorPickerRef = ref<HTMLElement | null>(null)

// Fetch team data
async function fetchTeam() {
  loading.value = true
  try {
    const response = await teamApi.getTeamForManage(teamId)
    team.value = response.data
    teamLoaded.value = true
    // Check if current user is admin
    isAdmin.value = team.value.adminId === loginId.value ||
      team.value.members.some(m => m.id === loginId.value && m.isManager)
  } catch (error) {
    console.error('Failed to fetch team:', error)
    showError('팀 정보를 불러오는데 실패했습니다.')
    router.push('/team')
  } finally {
    loading.value = false
  }
}

// Fetch duty batch templates
async function fetchDutyBatchTemplates() {
  try {
    const response = await teamApi.getDutyBatchTemplates()
    dutyBatchTemplates.value = response.data
  } catch (error) {
    console.error('Failed to fetch duty batch templates:', error)
  }
}

// Methods
function openMemberSearchModal() {
  showMemberSearchModal.value = true
  searchKeyword.value = ''
  currentPage.value = 0
  searchMembers()
}

function closeMemberSearchModal() {
  showMemberSearchModal.value = false
}

async function searchMembers() {
  searchLoading.value = true
  try {
    const response = await teamApi.searchMembersToInvite(
      searchKeyword.value,
      currentPage.value,
      pageSize
    )
    searchResult.value = response.data.content
    totalElements.value = response.data.totalElements
    totalPages.value = response.data.totalPages || 1
  } catch (error) {
    console.error('Failed to search members:', error)
  } finally {
    searchLoading.value = false
  }
}

function prevPage() {
  if (currentPage.value > 0) {
    currentPage.value--
    searchMembers()
  }
}

function nextPage() {
  if (currentPage.value < totalPages.value - 1) {
    currentPage.value++
    searchMembers()
  }
}

function goToPage(page: number) {
  currentPage.value = page
  searchMembers()
}

async function addMember(member: MemberDto) {
  if (!member.id) return
  if (!await confirm(`${member.name} 님을 팀에 추가하시겠습니까?`)) return

  saving.value = true
  try {
    await teamApi.addMember(teamId, member.id)
    toastSuccess(`${member.name} 님이 팀에 추가되었습니다.`)
    closeMemberSearchModal()
    await fetchTeam()
  } catch (error) {
    console.error('Failed to add member:', error)
    showError('멤버 추가에 실패했습니다.')
  } finally {
    saving.value = false
  }
}

async function removeMember(memberId: number) {
  const member = team.value?.members.find(m => m.id === memberId)
  if (!await confirmDelete(`정말로 ${member?.name} 님을 팀에서 제외하시겠습니까?`)) return

  saving.value = true
  try {
    await teamApi.removeMember(teamId, memberId)
    toastSuccess(`${member?.name} 님이 팀에서 제외되었습니다.`)
    await fetchTeam()
  } catch (error) {
    console.error('Failed to remove member:', error)
    showError('멤버 제외에 실패했습니다.')
  } finally {
    saving.value = false
  }
}

async function assignManager(member: TeamMemberDto) {
  if (!await confirm(`${member.name} 님에게 매니저 권한을 부여하시겠습니까?`)) return

  saving.value = true
  try {
    await teamApi.addManager(teamId, member.id)
    toastSuccess(`${member.name} 님에게 매니저 권한이 부여되었습니다.`)
    await fetchTeam()
  } catch (error) {
    console.error('Failed to assign manager:', error)
    showError('매니저 권한 부여에 실패했습니다.')
  } finally {
    saving.value = false
  }
}

async function unAssignManager(member: TeamMemberDto) {
  if (!await confirm(`${member.name} 님의 매니저 권한을 취소하시겠습니까?`)) return

  saving.value = true
  try {
    await teamApi.removeManager(teamId, member.id)
    toastSuccess(`${member.name} 님의 매니저 권한이 취소되었습니다.`)
    await fetchTeam()
  } catch (error) {
    console.error('Failed to unassign manager:', error)
    showError('매니저 권한 취소에 실패했습니다.')
  } finally {
    saving.value = false
  }
}

async function changeAdmin(member?: TeamMemberDto) {
  const message = member
    ? `정말 ${member.name} 님을 대표로 변경하시겠습니까?\n다시 대표 권한을 획득하려면 ${member.name} 님에게 요청해야합니다.`
    : '팀의 대표를 초기화 하시겠습니까?'

  if (!await confirm(message)) return

  saving.value = true
  try {
    await teamApi.changeAdmin(teamId, member?.id ?? null)
    toastSuccess(member ? `${member.name} 님이 대표로 변경되었습니다.` : '대표가 초기화되었습니다.')
    await fetchTeam()
  } catch (error) {
    console.error('Failed to change admin:', error)
    showError('대표 변경에 실패했습니다.')
  } finally {
    saving.value = false
  }
}

async function updateWorkType(workType: string) {
  saving.value = true
  try {
    await teamApi.updateWorkType(teamId, workType)
    if (team.value) team.value.workType = workType
    toastSuccess('근무 형태가 변경되었습니다.')
  } catch (error) {
    console.error('Failed to update work type:', error)
    showError('근무 형태 변경에 실패했습니다.')
  } finally {
    saving.value = false
  }
}

async function updateBatchTemplate(templateName: string) {
  saving.value = true
  try {
    await teamApi.updateBatchTemplate(teamId, templateName || null)
    if (team.value) {
      team.value.dutyBatchTemplate = templateName
        ? dutyBatchTemplates.value.find(t => t.name === templateName) || null
        : null
    }
    toastSuccess('근무 반입 양식이 변경되었습니다.')
  } catch (error) {
    console.error('Failed to update batch template:', error)
    showError('근무 반입 양식 변경에 실패했습니다.')
  } finally {
    saving.value = false
  }
}

// Duty Type Methods
function initPickr(defaultColor: string) {
  nextTick(() => {
    if (colorPickerRef.value && !pickrInstance) {
      pickrInstance = Pickr.create({
        el: colorPickerRef.value,
        theme: 'monolith',
        default: defaultColor,
        inline: true,
        showAlways: true,
        components: {
          preview: true,
          opacity: false,
          hue: true,
          interaction: {
            hex: true,
            rgba: false,
            hsla: false,
            hsva: false,
            cmyk: false,
            input: true,
            save: false
          }
        }
      })

      pickrInstance.on('change', (color: Pickr.HSVaColor) => {
        const hexColor = color.toHEXA().toString()
        dutyTypeForm.value.color = hexColor
      })
    }
  })
}

function destroyPickr() {
  if (pickrInstance) {
    pickrInstance.destroyAndRemove()
    pickrInstance = null
  }
}

function openAddDutyTypeModal() {
  dutyTypeForm.value = {
    id: null,
    name: '',
    color: '#ffb3ba',
    isDefault: false,
  }
  showDutyTypeModal.value = true
  initPickr('#ffb3ba')
}

function openEditDutyTypeModal(dutyType: DutyTypeDto) {
  dutyTypeForm.value = {
    id: dutyType.id,
    name: dutyType.name,
    color: dutyType.color || '#ffb3ba',
    isDefault: dutyType.position === -1,
  }
  showDutyTypeModal.value = true
  initPickr(dutyType.color || '#ffb3ba')
}

function closeDutyTypeModal() {
  destroyPickr()
  showDutyTypeModal.value = false
}

async function saveDutyType() {
  if (!dutyTypeForm.value.name) {
    showWarning('근무유형 이름을 입력해주세요.')
    return
  }

  const exists = team.value?.dutyTypes.some(
    dt => dt.name === dutyTypeForm.value.name && dt.id !== dutyTypeForm.value.id
  )
  if (exists) {
    showWarning(`${dutyTypeForm.value.name} 이름의 근무유형이 이미 존재합니다.`)
    return
  }

  saving.value = true
  try {
    if (dutyTypeForm.value.isDefault) {
      // Update default duty (OFF)
      await teamApi.updateDefaultDuty(teamId, dutyTypeForm.value.name, dutyTypeForm.value.color)
    } else if (dutyTypeForm.value.id) {
      // Update existing duty type
      await teamApi.updateDutyType(teamId, {
        id: dutyTypeForm.value.id,
        name: dutyTypeForm.value.name,
        color: dutyTypeForm.value.color,
      })
    } else {
      // Create new duty type
      await teamApi.addDutyType(teamId, {
        teamId,
        name: dutyTypeForm.value.name,
        color: dutyTypeForm.value.color,
      })
    }
    toastSuccess('근무 유형이 저장되었습니다.')
    closeDutyTypeModal()
    await fetchTeam()
  } catch (error) {
    console.error('Failed to save duty type:', error)
    showError('근무 유형 저장에 실패했습니다.')
  } finally {
    saving.value = false
  }
}

async function removeDutyType(dutyType: DutyTypeDto) {
  if (!dutyType.id) return
  if (!await confirmDelete(`[ ${dutyType.name} ] 근무 유형을 삭제하시겠습니까?\n삭제는 되돌릴 수 없으며 해당 유형으로 표시된 근무는 모두 제거됩니다.`)) return

  saving.value = true
  try {
    await teamApi.deleteDutyType(teamId, dutyType.id)
    toastSuccess('근무 유형이 삭제되었습니다.')
    await fetchTeam()
  } catch (error) {
    console.error('Failed to delete duty type:', error)
    showError('근무 유형 삭제에 실패했습니다.')
  } finally {
    saving.value = false
  }
}

async function swapPosition(index1: number, index2: number) {
  if (!team.value) return
  const dt1 = team.value.dutyTypes[index1]
  const dt2 = team.value.dutyTypes[index2]
  if (!dt1?.id || !dt2?.id) return

  saving.value = true
  try {
    await teamApi.swapDutyTypePosition(teamId, dt1.id, dt2.id)
    // Swap locally for immediate feedback
    team.value.dutyTypes[index1] = dt2
    team.value.dutyTypes[index2] = dt1
    toastSuccess('순서가 변경되었습니다.')
  } catch (error) {
    console.error('Failed to swap duty type positions:', error)
    showError('순서 변경에 실패했습니다.')
    await fetchTeam()
  } finally {
    saving.value = false
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

async function uploadBatch() {
  if (!batchForm.value.file) {
    showWarning('파일을 선택해주세요.')
    return
  }

  saving.value = true
  try {
    const result = await teamApi.uploadDutyBatch(
      teamId,
      batchForm.value.file,
      batchForm.value.year,
      batchForm.value.month
    )
    if (result.data.success) {
      toastSuccess('근무표가 업로드되었습니다.')
      closeBatchUploadModal()
    } else {
      showError(result.data.message || '근무표 업로드에 실패했습니다.')
    }
  } catch (error: any) {
    console.error('Failed to upload batch:', error)
    const message = error.response?.data?.message || '근무표 업로드에 실패했습니다.'
    showError(message)
  } finally {
    saving.value = false
  }
}

async function removeTeam() {
  const confirmed = await confirmDelete('팀 삭제', '정말로 이 팀을 삭제하겠습니까?')
  if (!confirmed) return

  try {
    await adminApi.deleteTeam(teamId)
    toastSuccess('팀이 삭제되었습니다.')
    router.push('/admin/teams')
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : '팀 삭제에 실패했습니다.'
    showError(message)
  }
}

onMounted(() => {
  fetchTeam()
  fetchDutyBatchTemplates()
})

onUnmounted(() => {
  destroyPickr()
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-2 sm:px-4 py-4">
    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center py-20">
      <Loader2 class="w-8 h-8 animate-spin text-blue-500" />
    </div>

    <template v-else-if="team">
      <!-- Header -->
      <div class="font-bold text-xl py-3 rounded-t-lg flex items-center justify-between px-4" :style="{ backgroundColor: '#4b5563', color: 'white' }">
        <button
          @click="router.back()"
          class="px-3 py-1 text-white text-sm rounded-lg hover:bg-gray-400 transition flex items-center gap-1 cursor-pointer"
          :style="{ backgroundColor: '#6b7280' }"
        >
          <ChevronLeft class="w-4 h-4" />
          뒤로
        </button>
        <span>{{ team.name }} 관리</span>
        <button
          v-if="isAppAdmin && teamLoaded && !hasMember"
          @click="removeTeam"
          class="px-3 py-1 bg-red-500 text-white text-sm rounded-lg hover:bg-red-600 transition cursor-pointer"
        >
          팀 삭제
        </button>
        <span v-else class="w-16"></span>
      </div>

    <!-- Team Info Card -->
    <div class="border rounded-b-lg overflow-hidden mb-4" :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' }">
      <div class="overflow-x-auto">
      <table class="w-full min-w-[300px]">
        <tbody :style="{ borderColor: 'var(--dp-border-primary)' }">
          <tr :style="{ borderBottomWidth: '1px', borderBottomStyle: 'solid', borderBottomColor: 'var(--dp-border-primary)' }">
            <th class="px-4 py-3 text-left w-1/4 font-medium" :style="{ backgroundColor: 'var(--dp-bg-secondary)', color: 'var(--dp-text-secondary)' }">
              팀 설명
            </th>
            <td class="px-4 py-3" :style="{ color: 'var(--dp-text-primary)' }">
              {{ team.description }}
            </td>
          </tr>
          <tr v-if="isAdmin" :style="{ borderBottomWidth: '1px', borderBottomStyle: 'solid', borderBottomColor: 'var(--dp-border-primary)' }">
            <th class="px-4 py-3 text-left font-medium" :style="{ backgroundColor: 'var(--dp-bg-secondary)', color: 'var(--dp-text-secondary)' }">
              팀 대표
            </th>
            <td class="px-4 py-3" :style="{ color: 'var(--dp-text-primary)' }">
              <div class="flex items-center gap-2">
                <span class="font-medium">{{ team.adminName || 'N/A' }}</span>
                <button
                  v-if="team.adminId && loginId !== team.adminId"
                  @click="changeAdmin()"
                  class="px-2 py-1 text-sm border border-red-500 text-red-500 rounded hover:bg-red-50 transition flex items-center gap-1 cursor-pointer"
                >
                  <Trash2 class="w-3 h-3" />
                  대표 취소
                </button>
              </div>
            </td>
          </tr>
          <tr :style="{ borderBottomWidth: '1px', borderBottomStyle: 'solid', borderBottomColor: 'var(--dp-border-primary)' }">
            <th class="px-4 py-3 text-left font-medium" :style="{ backgroundColor: 'var(--dp-bg-secondary)', color: 'var(--dp-text-secondary)' }">
              근무 형태
            </th>
            <td class="px-4 py-3">
              <select
                :value="team.workType"
                @change="updateWorkType(($event.target as HTMLSelectElement).value)"
                class="px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                :style="{ backgroundColor: 'var(--dp-bg-input)', borderColor: 'var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
              >
                <option v-for="wt in workTypes" :key="wt.value" :value="wt.value">
                  {{ wt.label }}
                </option>
              </select>
            </td>
          </tr>
          <tr :style="{ borderBottomWidth: '1px', borderBottomStyle: 'solid', borderBottomColor: 'var(--dp-border-primary)' }">
            <th class="px-4 py-3 text-left font-medium" :style="{ backgroundColor: 'var(--dp-bg-secondary)', color: 'var(--dp-text-secondary)' }">
              근무 반입 양식
            </th>
            <td class="px-4 py-3">
              <select
                :value="team.dutyBatchTemplate?.name || ''"
                @change="updateBatchTemplate(($event.target as HTMLSelectElement).value)"
                class="px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                :style="{ backgroundColor: 'var(--dp-bg-input)', borderColor: 'var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
              >
                <option value="">없음</option>
                <option v-for="template in dutyBatchTemplates" :key="template.name" :value="template.name">
                  {{ template.label }}
                </option>
              </select>
            </td>
          </tr>
          <tr v-if="team.dutyBatchTemplate">
            <th class="px-4 py-3 text-left font-medium" :style="{ backgroundColor: 'var(--dp-bg-secondary)', color: 'var(--dp-text-secondary)' }">
              근무표 업로드
            </th>
            <td class="px-4 py-3">
              <button
                @click="openBatchUploadModal"
                class="px-4 py-2 bg-blue-500 text-white rounded-lg font-medium hover:bg-blue-600 transition flex items-center gap-1 cursor-pointer"
              >
                <Upload class="w-4 h-4" />
                등록
              </button>
            </td>
          </tr>
        </tbody>
      </table>
      </div>
    </div>

    <!-- Members Section -->
    <div class="border rounded-lg overflow-hidden mb-4" :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' }">
      <div class="text-white px-4 py-3 flex flex-wrap items-center justify-between gap-2" :style="{ backgroundColor: '#4b5563' }">
        <h3 class="font-bold">팀 멤버</h3>
        <button
          @click="openMemberSearchModal"
          class="px-3 py-1.5 bg-blue-500 text-white rounded-lg text-sm font-medium hover:bg-blue-600 transition flex items-center gap-1"
        >
          <UserPlus class="w-4 h-4" />
          멤버 추가
        </button>
      </div>

      <!-- Desktop Table View -->
      <div v-if="hasMember" class="hidden sm:block overflow-x-auto">
        <table class="w-full">
          <thead class="text-white" :style="{ backgroundColor: '#1f2937' }">
            <tr>
              <th class="px-4 py-2 text-center w-12">#</th>
              <th class="px-4 py-2 text-left">이름</th>
              <th class="px-4 py-2 text-center">매니저</th>
              <th class="px-4 py-2 text-center">도구</th>
            </tr>
          </thead>
          <tbody :style="{ borderColor: 'var(--dp-border-primary)' }">
            <tr v-for="(member, index) in team.members" :key="member.id" :style="{ borderBottomWidth: '1px', borderBottomStyle: 'solid', borderBottomColor: 'var(--dp-border-primary)' }" class="hover-bg-light">
              <td class="px-4 py-3 text-center" :style="{ color: 'var(--dp-text-muted)' }">{{ index + 1 }}</td>
              <td class="px-4 py-3 font-medium" :style="{ color: 'var(--dp-text-primary)' }">{{ member.name }}</td>
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
                  <span v-else-if="member.isAdmin" :style="{ color: 'var(--dp-text-muted)' }">-</span>
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

      <!-- Mobile Card View -->
      <div v-if="hasMember" class="sm:hidden" :style="{ borderColor: 'var(--dp-border-primary)' }">
        <div
          v-for="(member, index) in team.members"
          :key="member.id"
          class="p-3 hover-bg-light"
          :style="{ borderBottomWidth: '1px', borderBottomStyle: 'solid', borderBottomColor: 'var(--dp-border-primary)' }"
        >
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center gap-2">
              <span class="text-sm" :style="{ color: 'var(--dp-text-muted)' }">{{ index + 1 }}</span>
              <span class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">{{ member.name }}</span>
              <Check v-if="member.isManager" class="w-4 h-4 text-green-500" />
            </div>
            <button
              @click="removeMember(member.id)"
              class="px-2 py-1 text-xs bg-red-500 text-white rounded hover:bg-red-600 transition flex items-center gap-1"
            >
              <Trash2 class="w-3 h-3" />
              탈퇴
            </button>
          </div>
          <div v-if="isAdmin && !member.isAdmin" class="flex flex-wrap gap-1">
            <button
              v-if="!member.isManager"
              @click="assignManager(member)"
              class="px-2 py-1 text-xs border border-green-500 text-green-600 rounded hover:bg-green-50 transition flex items-center gap-1"
            >
              <Plus class="w-3 h-3" />
              매니저 지정
            </button>
            <template v-else-if="member.isManager">
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
            </template>
          </div>
        </div>
      </div>
      <div v-else class="p-6 text-center" :style="{ color: 'var(--dp-text-muted)' }">
        이 팀에 멤버가 없습니다.
      </div>
    </div>

    <!-- Duty Types Section -->
    <div class="border rounded-lg overflow-hidden" :style="{ backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' }">
      <div class="text-white px-4 py-3 flex items-center justify-between" :style="{ backgroundColor: '#4b5563' }">
        <h3 class="font-bold">근무 유형</h3>
        <button
          @click="openAddDutyTypeModal"
          class="px-3 py-1.5 rounded-lg text-sm font-medium hover-interactive cursor-pointer flex items-center gap-1"
          :style="{ backgroundColor: 'var(--dp-bg-card)', color: 'var(--dp-text-primary)' }"
        >
          <Plus class="w-4 h-4" />
          추가
        </button>
      </div>

      <div v-if="hasDutyType" class="overflow-x-auto">
        <table class="w-full">
          <thead class="text-white" :style="{ backgroundColor: '#1f2937' }">
            <tr>
              <th class="px-4 py-2 text-center w-12">#</th>
              <th class="px-4 py-2 text-left">근무명</th>
              <th class="px-4 py-2 text-center">색상</th>
              <th class="px-4 py-2 text-center">도구</th>
            </tr>
          </thead>
          <tbody :style="{ borderColor: 'var(--dp-border-primary)' }">
            <tr v-for="(dutyType, index) in team.dutyTypes" :key="dutyType.id || 'default'" class="hover-bg-light" :style="{ borderBottomWidth: '1px', borderBottomStyle: 'solid', borderBottomColor: 'var(--dp-border-primary)' }">
              <td class="px-4 py-3 text-center" :style="{ color: 'var(--dp-text-muted)' }">{{ index + 1 }}</td>
              <td class="px-4 py-3 font-medium" :style="{ color: 'var(--dp-text-primary)' }">
                {{ dutyType.name }}
                <span v-if="dutyType.id === null" class="text-xs font-normal" :style="{ color: 'var(--dp-text-muted)' }">(휴무)</span>
              </td>
              <td class="px-4 py-3 text-center">
                <span
                  @click="openEditDutyTypeModal(dutyType)"
                  class="inline-block w-6 h-6 rounded-full border-2 cursor-pointer color-picker-swatch"
                  :style="{ backgroundColor: dutyType.color || '#e8e8e8', borderColor: 'var(--dp-border-primary)' }"
                ></span>
              </td>
              <td class="px-4 py-3">
                <div class="flex flex-wrap items-center justify-center gap-1">
                  <button
                    v-if="dutyType.id"
                    :disabled="index === 0 || index === team.dutyTypes.length - 1"
                    @click="swapPosition(index, index + 1)"
                    class="p-1 sm:p-1.5 border rounded hover-bg-light transition disabled:opacity-50 disabled:cursor-not-allowed"
                    :style="{ borderColor: 'var(--dp-border-secondary)' }"
                  >
                    <ArrowDown class="w-3 h-3 sm:w-4 sm:h-4" />
                  </button>
                  <button
                    v-if="dutyType.id"
                    :disabled="index <= 1"
                    @click="swapPosition(index, index - 1)"
                    class="p-1 sm:p-1.5 border rounded hover-bg-light transition disabled:opacity-50 disabled:cursor-not-allowed"
                    :style="{ borderColor: 'var(--dp-border-secondary)' }"
                  >
                    <ArrowUp class="w-3 h-3 sm:w-4 sm:h-4" />
                  </button>
                  <button
                    @click="openEditDutyTypeModal(dutyType)"
                    class="p-1 sm:p-1.5 border border-blue-500 text-blue-500 rounded hover:bg-blue-50 transition"
                  >
                    <Pencil class="w-3 h-3 sm:w-4 sm:h-4" />
                  </button>
                  <button
                    v-if="dutyType.id"
                    @click="removeDutyType(dutyType)"
                    class="p-1 sm:p-1.5 border border-red-500 text-red-500 rounded hover:bg-red-50 transition"
                  >
                    <Trash2 class="w-3 h-3 sm:w-4 sm:h-4" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div v-else class="p-6 text-center" :style="{ color: 'var(--dp-text-muted)' }">
        근무 유형이 없습니다.
      </div>
    </div>


    <!-- Member Search Modal -->
    <div
      v-if="showMemberSearchModal"
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
      @click.self="closeMemberSearchModal"
    >
      <div class="rounded-lg shadow-xl w-full max-w-lg" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
        <div class="flex items-center justify-between p-4 border-b" :style="{ borderColor: 'var(--dp-border-primary)' }">
          <h3 class="text-lg font-bold" :style="{ color: 'var(--dp-text-primary)' }">멤버 추가</h3>
          <button
            @click="closeMemberSearchModal"
            class="p-1.5 rounded-full hover-close-btn cursor-pointer"
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
              class="flex-1 px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              :style="{ backgroundColor: 'var(--dp-bg-input)', borderColor: 'var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
              @keyup.enter="searchMembers"
            />
            <button
              @click="searchMembers"
              class="px-4 py-2 text-white rounded-lg hover:bg-gray-700 transition"
              :style="{ backgroundColor: '#4b5563' }"
            >
              <Search class="w-5 h-5" />
            </button>
          </div>

          <!-- Search Results -->
          <div v-if="searchLoading" class="flex items-center justify-center py-8">
            <Loader2 class="w-6 h-6 animate-spin text-blue-500" />
          </div>
          <div v-else-if="searchResult.length > 0" class="overflow-x-auto">
            <table class="w-full">
              <thead :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
                <tr>
                  <th class="px-3 py-2 text-left text-sm" :style="{ color: 'var(--dp-text-secondary)' }">#</th>
                  <th class="px-3 py-2 text-left text-sm" :style="{ color: 'var(--dp-text-secondary)' }">이름</th>
                  <th class="px-3 py-2 text-left text-sm" :style="{ color: 'var(--dp-text-secondary)' }">이메일</th>
                  <th class="px-3 py-2 text-center text-sm" :style="{ color: 'var(--dp-text-secondary)' }">추가</th>
                </tr>
              </thead>
              <tbody :style="{ borderColor: 'var(--dp-border-primary)' }">
                <tr v-for="(member, index) in searchResult" :key="member.id ?? index" class="hover-bg-light" :style="{ borderBottomWidth: '1px', borderBottomStyle: 'solid', borderBottomColor: 'var(--dp-border-primary)' }">
                  <td class="px-3 py-2 text-sm" :style="{ color: 'var(--dp-text-muted)' }">
                    {{ currentPage * pageSize + index + 1 }}
                  </td>
                  <td class="px-3 py-2 text-sm font-medium" :style="{ color: 'var(--dp-text-primary)' }">{{ member.name }}</td>
                  <td class="px-3 py-2 text-sm" :style="{ color: 'var(--dp-text-muted)' }">{{ member.email }}</td>
                  <td class="px-3 py-2 text-center">
                    <button
                      @click="addMember(member)"
                      :disabled="!!member.teamId || saving"
                      class="px-3 py-1 bg-blue-500 text-white text-sm rounded hover:bg-blue-600 transition disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {{ member.teamId ? '소속 있음' : '추가' }}
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div v-else class="text-center py-4" :style="{ color: 'var(--dp-text-muted)' }">
            검색 결과가 없습니다.
          </div>

          <!-- Pagination -->
          <div v-if="searchResult.length > 0" class="mt-4">
            <div class="text-sm mb-2" :style="{ color: 'var(--dp-text-muted)' }">
              Page {{ currentPage + 1 }} of {{ totalPages }} | Total: {{ totalElements }}
            </div>
            <div class="flex flex-wrap items-center gap-1">
              <button
                @click="prevPage"
                :disabled="currentPage === 0"
                class="px-2 sm:px-3 py-1 border rounded hover-bg-light transition disabled:opacity-50"
                :style="{ borderColor: 'var(--dp-border-secondary)' }"
              >
                <ChevronLeft class="w-4 h-4" />
              </button>
              <button
                v-for="i in totalPages"
                :key="i"
                @click="goToPage(i - 1)"
                class="px-2 sm:px-3 py-1 text-sm border rounded transition"
                :class="i - 1 === currentPage ? 'bg-blue-500 text-white border-blue-500' : ''"
                :style="i - 1 !== currentPage ? { borderColor: 'var(--dp-border-secondary)' } : {}"
              >
                {{ i }}
              </button>
              <button
                @click="nextPage"
                :disabled="currentPage >= totalPages - 1"
                class="px-2 sm:px-3 py-1 border rounded hover-bg-light transition disabled:opacity-50"
                :style="{ borderColor: 'var(--dp-border-secondary)' }"
              >
                <ChevronRight class="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>

        <div class="flex justify-end p-4 border-t" :style="{ borderColor: 'var(--dp-border-primary)' }">
          <button
            @click="closeMemberSearchModal"
            class="px-4 py-2 rounded-lg font-medium hover-interactive cursor-pointer"
            :style="{ backgroundColor: 'var(--dp-bg-tertiary)', color: 'var(--dp-text-secondary)' }"
          >
            닫기
          </button>
        </div>
      </div>
    </div>

    <!-- Duty Type Modal -->
    <div
      v-if="showDutyTypeModal"
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
      @click.self="closeDutyTypeModal"
    >
      <div class="rounded-lg shadow-xl w-full max-w-md" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
        <div class="flex items-center justify-between p-4 border-b" :style="{ borderColor: 'var(--dp-border-primary)' }">
          <h3 class="text-lg font-bold" :style="{ color: 'var(--dp-text-primary)' }">
            {{ dutyTypeForm.id !== null || dutyTypeForm.isDefault ? '근무 유형 수정' : '근무 유형 추가' }}
          </h3>
          <button
            @click="closeDutyTypeModal"
            class="p-1.5 rounded-full hover-close-btn cursor-pointer"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="p-4 space-y-4">
          <p class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">
            해당 근무유형의 명칭 및 색상을 선택해주세요.
          </p>

          <div
            v-if="dutyTypeForm.isDefault"
            class="bg-blue-50 border border-blue-200 rounded-lg p-3 text-sm text-blue-700"
          >
            현재 선택한 근무 유형은 <strong>휴무일</strong>에 해당합니다.
          </div>

          <div>
            <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
              근무명
              <CharacterCounter :current="dutyTypeForm.name.length" :max="10" />
            </label>
            <input
              v-model="dutyTypeForm.name"
              type="text"
              maxlength="10"
              placeholder="근무명"
              class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              :style="{ backgroundColor: 'var(--dp-bg-input)', borderColor: 'var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
            />
          </div>

          <div class="color-picker-container">
            <label class="block text-sm font-medium mb-2" :style="{ color: 'var(--dp-text-secondary)' }">
              색상 선택
            </label>
            <div class="color-picker-wrapper flex justify-center items-center">
              <div ref="colorPickerRef" class="color-picker"></div>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
              미리보기
            </label>
            <div
              class="inline-block px-4 py-2 rounded-lg border font-medium"
              :style="{ backgroundColor: dutyTypeForm.color, borderColor: 'var(--dp-border-primary)' }"
            >
              {{ dutyTypeForm.name || '근무명 입력' }}
            </div>
          </div>
        </div>

        <div class="flex justify-end gap-2 p-4 border-t" :style="{ borderColor: 'var(--dp-border-primary)' }">
          <button
            @click="saveDutyType"
            :disabled="!dutyTypeForm.name.trim()"
            class="px-4 py-2 bg-green-500 text-white rounded-lg font-medium hover:bg-green-600 transition disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ dutyTypeForm.id !== null || dutyTypeForm.isDefault ? '저장' : '추가' }}
          </button>
          <button
            @click="closeDutyTypeModal"
            class="px-4 py-2 rounded-lg font-medium hover-interactive cursor-pointer"
            :style="{ backgroundColor: 'var(--dp-bg-tertiary)', color: 'var(--dp-text-secondary)' }"
          >
            취소
          </button>
        </div>
      </div>
    </div>

    <!-- Batch Upload Modal -->
    <div
      v-if="showBatchUploadModal"
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
      @click.self="closeBatchUploadModal"
    >
      <div class="rounded-lg shadow-xl w-full max-w-md" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
        <div class="flex items-center justify-between p-4 border-b" :style="{ borderColor: 'var(--dp-border-primary)' }">
          <h3 class="text-lg font-bold" :style="{ color: 'var(--dp-text-primary)' }">근무표 업로드</h3>
          <button
            @click="closeBatchUploadModal"
            class="p-1.5 rounded-full hover-close-btn cursor-pointer"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="p-4 space-y-4">
          <div>
            <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
              근무표 파일 업로드 (.xlsx)
            </label>
            <input
              type="file"
              accept=".xlsx"
              @change="handleFileChange"
              class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              :style="{ backgroundColor: 'var(--dp-bg-input)', borderColor: 'var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
            />
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
                연도
              </label>
              <input
                v-model.number="batchForm.year"
                type="number"
                :min="new Date().getFullYear()"
                :max="new Date().getFullYear() + 1"
                class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                :style="{ backgroundColor: 'var(--dp-bg-input)', borderColor: 'var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
              />
            </div>
            <div>
              <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
                월
              </label>
              <input
                v-model.number="batchForm.month"
                type="number"
                min="1"
                max="12"
                class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                :style="{ backgroundColor: 'var(--dp-bg-input)', borderColor: 'var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
              />
            </div>
          </div>
        </div>

        <div class="flex justify-end gap-2 p-4 border-t" :style="{ borderColor: 'var(--dp-border-primary)' }">
          <button
            @click="uploadBatch"
            :disabled="saving || !batchForm.file"
            class="px-4 py-2 bg-blue-500 text-white rounded-lg font-medium hover:bg-blue-600 transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          >
            <Loader2 v-if="saving" class="w-4 h-4 animate-spin" />
            업로드
          </button>
          <button
            @click="closeBatchUploadModal"
            class="px-4 py-2 rounded-lg font-medium hover-interactive cursor-pointer"
            :style="{ backgroundColor: 'var(--dp-bg-tertiary)', color: 'var(--dp-text-secondary)' }"
          >
            취소
          </button>
        </div>
      </div>
    </div>
    </template>
  </div>
</template>
