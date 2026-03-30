<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useSwal } from '@/composables/useSwal'
import { useAuthStore } from '@/stores/auth'
import { teamApi } from '@/api/team'
import MemberSearchModal from '@/components/team/MemberSearchModal.vue'
import BatchUploadModal from '@/components/team/BatchUploadModal.vue'
import DutyTypeModal from '@/components/team/DutyTypeModal.vue'
import adminApi from '@/api/admin'
import type {
  TeamDto,
  TeamMemberDto,
  DutyTypeDto,
  DutyBatchTemplateDto,
} from '@/types'
import {
  UserPlus,
  Trash2,
  Plus,
  ArrowUp,
  ArrowDown,
  Pencil,
  Check,
  Upload,
  ChevronLeft,
  Shield,
  ShieldOff,
  Crown,
  Loader2,
} from 'lucide-vue-next'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { t } = useI18n()
const { showError, toastSuccess, confirmDelete, confirm } = useSwal()
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

const workTypes = computed(() => [
  { value: 'WEEKDAY', label: t('team.manage.workTypes.weekday') },
  { value: 'WEEKEND', label: t('team.manage.workTypes.weekend') },
  { value: 'FIXED', label: t('team.manage.workTypes.fixed') },
  { value: 'FLEXIBLE', label: t('team.manage.workTypes.flexible') },
])

// Computed
const hasMember = computed(() => team.value?.members && team.value.members.length > 0)
const hasDutyType = computed(() => team.value?.dutyTypes && team.value.dutyTypes.length > 0)

// Member Search Modal
const showMemberSearchModal = ref(false)

// Duty Type Modal
const showDutyTypeModal = ref(false)
const dutyTypeModalTarget = ref<DutyTypeDto | null>(null)

// Duty Batch Upload Modal
const showBatchUploadModal = ref(false)

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
    showError(t('team.manage.messages.fetchFailed'))
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
}

function closeMemberSearchModal() {
  showMemberSearchModal.value = false
}

async function removeMember(memberId: number) {
  const member = team.value?.members.find(m => m.id === memberId)
  if (!await confirmDelete(t('team.manage.messages.removeMemberConfirm', { name: member?.name }))) return

  saving.value = true
  try {
    await teamApi.removeMember(teamId, memberId)
    toastSuccess(t('team.manage.messages.removeMemberSuccess', { name: member?.name }))
    await fetchTeam()
  } catch (error) {
    console.error('Failed to remove member:', error)
    showError(t('team.manage.messages.removeMemberFailed'))
  } finally {
    saving.value = false
  }
}

async function assignManager(member: TeamMemberDto) {
  if (!await confirm(t('team.manage.messages.assignManagerConfirm', { name: member.name }))) return

  saving.value = true
  try {
    await teamApi.addManager(teamId, member.id)
    toastSuccess(t('team.manage.messages.assignManagerSuccess', { name: member.name }))
    await fetchTeam()
  } catch (error) {
    console.error('Failed to assign manager:', error)
    showError(t('team.manage.messages.assignManagerFailed'))
  } finally {
    saving.value = false
  }
}

async function unAssignManager(member: TeamMemberDto) {
  if (!await confirm(t('team.manage.messages.unassignManagerConfirm', { name: member.name }))) return

  saving.value = true
  try {
    await teamApi.removeManager(teamId, member.id)
    toastSuccess(t('team.manage.messages.unassignManagerSuccess', { name: member.name }))
    await fetchTeam()
  } catch (error) {
    console.error('Failed to unassign manager:', error)
    showError(t('team.manage.messages.unassignManagerFailed'))
  } finally {
    saving.value = false
  }
}

async function changeAdmin(member?: TeamMemberDto) {
  const message = member
    ? t('team.manage.messages.changeAdminConfirm', { name: member.name })
    : t('team.manage.messages.resetAdminConfirm')

  if (!await confirm(message)) return

  saving.value = true
  try {
    await teamApi.changeAdmin(teamId, member?.id ?? null)
    toastSuccess(
      member
        ? t('team.manage.messages.changeAdminSuccess', { name: member.name })
        : t('team.manage.messages.resetAdminSuccess')
    )
    await fetchTeam()
  } catch (error) {
    console.error('Failed to change admin:', error)
    showError(t('team.manage.messages.changeAdminFailed'))
  } finally {
    saving.value = false
  }
}

async function updateWorkType(workType: string) {
  saving.value = true
  try {
    await teamApi.updateWorkType(teamId, workType)
    if (team.value) team.value.workType = workType
    toastSuccess(t('team.manage.messages.updateWorkTypeSuccess'))
  } catch (error) {
    console.error('Failed to update work type:', error)
    showError(t('team.manage.messages.updateWorkTypeFailed'))
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
    toastSuccess(t('team.manage.messages.updateBatchTemplateSuccess'))
  } catch (error) {
    console.error('Failed to update batch template:', error)
    showError(t('team.manage.messages.updateBatchTemplateFailed'))
  } finally {
    saving.value = false
  }
}

function openAddDutyTypeModal() {
  dutyTypeModalTarget.value = null
  showDutyTypeModal.value = true
}

function openEditDutyTypeModal(dutyType: DutyTypeDto) {
  dutyTypeModalTarget.value = dutyType
  showDutyTypeModal.value = true
}

function closeDutyTypeModal() {
  showDutyTypeModal.value = false
}

async function removeDutyType(dutyType: DutyTypeDto) {
  if (!dutyType.id) return
  if (!await confirmDelete(t('team.manage.messages.deleteDutyTypeConfirm', { name: dutyType.name }))) return

  saving.value = true
  try {
    await teamApi.deleteDutyType(teamId, dutyType.id)
    toastSuccess(t('team.manage.messages.deleteDutyTypeSuccess'))
    await fetchTeam()
  } catch (error) {
    console.error('Failed to delete duty type:', error)
    showError(t('team.manage.messages.deleteDutyTypeFailed'))
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
    toastSuccess(t('team.manage.messages.reorderDutyTypesSuccess'))
  } catch (error) {
    console.error('Failed to swap duty type positions:', error)
    showError(t('team.manage.messages.reorderDutyTypesFailed'))
    await fetchTeam()
  } finally {
    saving.value = false
  }
}

// Batch Upload Methods
function openBatchUploadModal() {
  showBatchUploadModal.value = true
}

function closeBatchUploadModal() {
  showBatchUploadModal.value = false
}

async function removeTeam() {
  const confirmed = await confirmDelete(
    t('team.manage.messages.deleteTeamConfirm'),
    t('team.manage.actions.deleteTeam')
  )
  if (!confirmed) return

  try {
    await adminApi.deleteTeam(teamId)
    toastSuccess(t('team.manage.messages.deleteTeamSuccess'))
    router.push('/admin/teams')
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : t('team.manage.messages.deleteTeamFailed')
    showError(message)
  }
}

onMounted(() => {
  fetchTeam()
  fetchDutyBatchTemplates()
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-2 sm:px-4 py-4">
    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center py-20">
      <Loader2 class="w-8 h-8 animate-spin text-dp-accent" />
    </div>

    <template v-else-if="team">
      <!-- Header -->
      <div class="font-bold text-xl py-3 rounded-t-lg flex items-center justify-between px-4" :style="{ backgroundColor: 'var(--dp-modal-header-bg)', color: 'var(--dp-text-on-dark)' }">
        <button
          @click="router.back()"
          class="px-3 py-1 text-dp-text-on-dark text-sm rounded-lg hover:bg-dp-border-secondary transition flex items-center gap-1 cursor-pointer bg-dp-surface-strong-alt"
        >
          <ChevronLeft class="w-4 h-4" />
          {{ t('team.manage.actions.back') }}
        </button>
        <span>{{ t('team.manage.title', { name: team.name }) }}</span>
        <button
          v-if="isAppAdmin && teamLoaded && !hasMember"
          @click="removeTeam"
          class="px-3 py-1 bg-dp-danger text-dp-text-on-dark text-sm rounded-lg hover:bg-dp-danger-hover transition cursor-pointer"
        >
          {{ t('team.manage.actions.deleteTeam') }}
        </button>
        <span v-else class="w-16"></span>
      </div>

    <!-- Team Info Card -->
    <div class="border rounded-b-lg overflow-hidden mb-4 bg-dp-bg-card border-dp-border-primary">
      <div class="sm:hidden divide-y divide-dp-border-primary">
        <div class="px-4 py-3">
          <p class="text-xs font-medium text-dp-text-muted">
            {{ t('team.manage.fields.description') }}
          </p>
          <p class="mt-1.5 text-sm text-dp-text-primary break-words">
            {{ team.description || t('team.manage.labels.notAvailable') }}
          </p>
        </div>

        <div v-if="isAdmin" class="px-4 py-3">
          <p class="text-xs font-medium text-dp-text-muted">
            {{ t('team.manage.fields.admin') }}
          </p>
          <div class="mt-1.5 flex flex-wrap items-center gap-2 text-dp-text-primary">
            <span class="font-medium">{{ team.adminName || t('team.manage.labels.notAvailable') }}</span>
            <button
              v-if="team.adminId && loginId !== team.adminId"
              @click="changeAdmin()"
              class="px-2 py-1 text-sm border border-dp-danger-border text-dp-danger rounded hover:bg-dp-danger-soft transition flex items-center gap-1 cursor-pointer"
            >
              <Trash2 class="w-3 h-3" />
              {{ t('team.manage.actions.cancelAdmin') }}
            </button>
          </div>
        </div>

        <div class="px-4 py-3">
          <label class="text-xs font-medium text-dp-text-muted">
            {{ t('team.manage.fields.workType') }}
          </label>
          <select
            :value="team.workType"
            @change="updateWorkType(($event.target as HTMLSelectElement).value)"
            class="mt-1.5 w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-dp-accent focus:border-transparent bg-dp-bg-input border-dp-border-input text-dp-text-primary"
          >
            <option v-for="wt in workTypes" :key="wt.value" :value="wt.value">
              {{ wt.label }}
            </option>
          </select>
        </div>

        <div class="px-4 py-3">
          <label class="text-xs font-medium text-dp-text-muted">
            {{ t('team.manage.fields.batchTemplate') }}
          </label>
          <select
            :value="team.dutyBatchTemplate?.name || ''"
            @change="updateBatchTemplate(($event.target as HTMLSelectElement).value)"
            class="mt-1.5 w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-dp-accent focus:border-transparent bg-dp-bg-input border-dp-border-input text-dp-text-primary"
          >
            <option value="">{{ t('team.manage.labels.none') }}</option>
            <option v-for="template in dutyBatchTemplates" :key="template.name" :value="template.name">
              {{ template.label }}
            </option>
          </select>
        </div>

        <div v-if="team.dutyBatchTemplate" class="px-4 py-3">
          <p class="text-xs font-medium text-dp-text-muted">
            {{ t('team.manage.fields.dutyUpload') }}
          </p>
          <button
            @click="openBatchUploadModal"
            class="mt-1.5 w-full px-4 py-2 bg-dp-accent text-dp-text-on-dark rounded-lg font-medium hover:bg-dp-accent-hover transition flex items-center justify-center gap-1 cursor-pointer"
          >
            <Upload class="w-4 h-4" />
            {{ t('team.manage.actions.upload') }}
          </button>
        </div>
      </div>

      <div class="hidden sm:block overflow-x-auto">
        <table class="w-full min-w-[300px]">
          <tbody class="border-dp-border-primary">
            <tr class="border-b border-dp-border-primary">
              <th class="px-4 py-3 text-left w-1/4 font-medium bg-dp-bg-secondary text-dp-text-secondary">
                {{ t('team.manage.fields.description') }}
              </th>
              <td class="px-4 py-3 text-dp-text-primary">
                {{ team.description }}
              </td>
            </tr>
            <tr class="border-b border-dp-border-primary" v-if="isAdmin">
              <th class="px-4 py-3 text-left font-medium bg-dp-bg-secondary text-dp-text-secondary">
                {{ t('team.manage.fields.admin') }}
              </th>
              <td class="px-4 py-3 text-dp-text-primary">
                <div class="flex items-center gap-2">
                  <span class="font-medium">{{ team.adminName || t('team.manage.labels.notAvailable') }}</span>
                  <button
                    v-if="team.adminId && loginId !== team.adminId"
                    @click="changeAdmin()"
                    class="px-2 py-1 text-sm border border-dp-danger-border text-dp-danger rounded hover:bg-dp-danger-soft transition flex items-center gap-1 cursor-pointer"
                  >
                    <Trash2 class="w-3 h-3" />
                    {{ t('team.manage.actions.cancelAdmin') }}
                  </button>
                </div>
              </td>
            </tr>
            <tr class="border-b border-dp-border-primary">
              <th class="px-4 py-3 text-left font-medium bg-dp-bg-secondary text-dp-text-secondary">
                {{ t('team.manage.fields.workType') }}
              </th>
              <td class="px-4 py-3">
                <select
                  :value="team.workType"
                  @change="updateWorkType(($event.target as HTMLSelectElement).value)"
                  class="px-3 py-2 border rounded-lg focus:ring-2 focus:ring-dp-accent focus:border-transparent bg-dp-bg-input border-dp-border-input text-dp-text-primary"
                >
                  <option v-for="wt in workTypes" :key="wt.value" :value="wt.value">
                    {{ wt.label }}
                  </option>
                </select>
              </td>
            </tr>
            <tr class="border-b border-dp-border-primary">
              <th class="px-4 py-3 text-left font-medium bg-dp-bg-secondary text-dp-text-secondary">
                {{ t('team.manage.fields.batchTemplate') }}
              </th>
              <td class="px-4 py-3">
                <select
                  :value="team.dutyBatchTemplate?.name || ''"
                  @change="updateBatchTemplate(($event.target as HTMLSelectElement).value)"
                  class="px-3 py-2 border rounded-lg focus:ring-2 focus:ring-dp-accent focus:border-transparent bg-dp-bg-input border-dp-border-input text-dp-text-primary"
                >
                  <option value="">{{ t('team.manage.labels.none') }}</option>
                  <option v-for="template in dutyBatchTemplates" :key="template.name" :value="template.name">
                    {{ template.label }}
                  </option>
                </select>
              </td>
            </tr>
            <tr v-if="team.dutyBatchTemplate">
              <th class="px-4 py-3 text-left font-medium bg-dp-bg-secondary text-dp-text-secondary">
                {{ t('team.manage.fields.dutyUpload') }}
              </th>
              <td class="px-4 py-3">
                <button
                  @click="openBatchUploadModal"
                  class="px-4 py-2 bg-dp-accent text-dp-text-on-dark rounded-lg font-medium hover:bg-dp-accent-hover transition flex items-center gap-1 cursor-pointer"
                >
                  <Upload class="w-4 h-4" />
                  {{ t('team.manage.actions.upload') }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Members Section -->
    <div class="border rounded-lg overflow-hidden mb-4 bg-dp-bg-card border-dp-border-primary">
      <div class="text-dp-text-on-dark px-4 py-3 flex flex-wrap items-center justify-between gap-2 bg-dp-surface-strong">
        <h3 class="font-bold">{{ t('team.manage.fields.members') }}</h3>
        <button
          @click="openMemberSearchModal"
          class="px-3 py-1.5 bg-dp-accent text-dp-text-on-dark rounded-lg text-sm font-medium hover:bg-dp-accent-hover transition flex items-center gap-1"
        >
          <UserPlus class="w-4 h-4" />
          {{ t('team.manage.actions.addMember') }}
        </button>
      </div>

      <!-- Desktop Table View -->
      <div v-if="hasMember" class="hidden sm:block overflow-x-auto">
        <table class="w-full">
          <thead class="text-dp-text-on-dark bg-dp-bg-footer">
            <tr>
              <th class="px-4 py-2 text-center w-12">#</th>
              <th class="px-4 py-2 text-left">{{ t('team.manage.fields.name') }}</th>
              <th class="px-4 py-2 text-center">{{ t('team.manage.fields.manager') }}</th>
              <th class="px-4 py-2 text-center">{{ t('team.manage.fields.tools') }}</th>
            </tr>
          </thead>
          <tbody class="border-dp-border-primary">
            <tr v-for="(member, index) in team.members" :key="member.id" class="hover-bg-light border-b border-dp-border-primary">
              <td class="px-4 py-3 text-center text-dp-text-muted">{{ index + 1 }}</td>
              <td class="px-4 py-3 font-medium text-dp-text-primary">{{ member.name }}</td>
              <td class="px-4 py-3 text-center">
                <template v-if="!isAdmin">
                  <Check v-if="member.isManager" class="w-5 h-5 text-dp-success mx-auto" />
                </template>
                <template v-else>
                  <button
                    v-if="!member.isManager"
                    @click="assignManager(member)"
                    class="text-dp-success hover:text-dp-success transition"
                  >
                    <Plus class="w-5 h-5 mx-auto" />
                  </button>
                  <div v-else-if="member.isManager && !member.isAdmin" class="flex items-center justify-center gap-1">
                    <button
                      @click="unAssignManager(member)"
                      class="px-2 py-1 text-xs border border-dp-warning-border text-dp-warning rounded hover:bg-dp-warning-soft transition flex items-center gap-1"
                    >
                      <ShieldOff class="w-3 h-3" />
                      {{ t('team.manage.actions.revokeManager') }}
                    </button>
                    <button
                      @click="changeAdmin(member)"
                      class="px-2 py-1 text-xs border border-dp-accent-border text-dp-accent rounded hover:bg-dp-accent-soft transition flex items-center gap-1"
                    >
                      <Crown class="w-3 h-3" />
                      {{ t('team.manage.actions.transferAdmin') }}
                    </button>
                  </div>
                  <span class="text-dp-text-muted" v-else-if="member.isAdmin">-</span>
                </template>
              </td>
              <td class="px-4 py-3 text-center">
                <button
                  @click="removeMember(member.id)"
                  class="px-2 py-1 text-sm bg-dp-danger text-dp-text-on-dark rounded hover:bg-dp-danger-hover transition flex items-center gap-1 mx-auto"
                >
                  <Trash2 class="w-3 h-3" />
                  {{ t('team.manage.actions.removeMember') }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Mobile Card View -->
      <div v-if="hasMember" class="sm:hidden border-dp-border-primary">
        <div
          v-for="(member, index) in team.members"
          :key="member.id"
          class="p-3 hover-bg-light border-b border-dp-border-primary"
        >
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center gap-2">
              <span class="text-sm text-dp-text-muted">{{ index + 1 }}</span>
              <span class="font-medium text-dp-text-primary">{{ member.name }}</span>
              <Check v-if="member.isManager" class="w-4 h-4 text-dp-success" />
            </div>
            <button
              @click="removeMember(member.id)"
              class="px-2 py-1 text-xs bg-dp-danger text-dp-text-on-dark rounded hover:bg-dp-danger-hover transition flex items-center gap-1"
            >
              <Trash2 class="w-3 h-3" />
              {{ t('team.manage.actions.removeMember') }}
            </button>
          </div>
          <div v-if="isAdmin && !member.isAdmin" class="flex flex-wrap gap-1">
            <button
              v-if="!member.isManager"
              @click="assignManager(member)"
              class="px-2 py-1 text-xs border border-dp-success-border text-dp-success rounded hover:bg-dp-success-soft transition flex items-center gap-1"
            >
              <Plus class="w-3 h-3" />
              {{ t('team.manage.actions.assignManager') }}
            </button>
            <template v-else-if="member.isManager">
              <button
                @click="unAssignManager(member)"
                class="px-2 py-1 text-xs border border-dp-warning-border text-dp-warning rounded hover:bg-dp-warning-soft transition flex items-center gap-1"
              >
                <ShieldOff class="w-3 h-3" />
                {{ t('team.manage.actions.revokeManager') }}
              </button>
              <button
                @click="changeAdmin(member)"
                class="px-2 py-1 text-xs border border-dp-accent-border text-dp-accent rounded hover:bg-dp-accent-soft transition flex items-center gap-1"
              >
                <Crown class="w-3 h-3" />
                {{ t('team.manage.actions.transferAdmin') }}
              </button>
            </template>
          </div>
        </div>
      </div>
      <div v-else class="p-6 text-center text-dp-text-muted">
        {{ t('team.manage.labels.noMembers') }}
      </div>
    </div>

    <!-- Duty Types Section -->
    <div class="border rounded-lg overflow-hidden bg-dp-bg-card border-dp-border-primary">
      <div class="text-dp-text-on-dark px-4 py-3 flex items-center justify-between bg-dp-surface-strong">
        <h3 class="font-bold">{{ t('team.manage.fields.dutyTypes') }}</h3>
        <button
          @click="openAddDutyTypeModal"
          class="px-3 py-1.5 rounded-lg text-sm font-medium hover-interactive cursor-pointer flex items-center gap-1 bg-dp-bg-card text-dp-text-primary"
        >
          <Plus class="w-4 h-4" />
          {{ t('team.manage.actions.addDutyType') }}
        </button>
      </div>

      <div v-if="hasDutyType" class="overflow-x-auto">
        <table class="w-full">
          <thead class="text-dp-text-on-dark bg-dp-bg-footer">
            <tr>
              <th class="px-4 py-2 text-center w-12">#</th>
              <th class="px-4 py-2 text-left">{{ t('team.manage.fields.dutyName') }}</th>
              <th class="px-4 py-2 text-center">{{ t('team.manage.fields.color') }}</th>
              <th class="px-4 py-2 text-center">{{ t('team.manage.fields.tools') }}</th>
            </tr>
          </thead>
          <tbody class="border-dp-border-primary">
            <tr v-for="(dutyType, index) in team.dutyTypes" :key="dutyType.id || 'default'" class="hover-bg-light border-b border-dp-border-primary">
              <td class="px-4 py-3 text-center text-dp-text-muted">{{ index + 1 }}</td>
              <td class="px-4 py-3 font-medium text-dp-text-primary">
                {{ dutyType.name }}
                <span v-if="dutyType.id === null" class="text-xs font-normal text-dp-text-muted">({{ t('team.manage.labels.offDuty') }})</span>
              </td>
              <td class="px-4 py-3 text-center">
                <span
                  @click="openEditDutyTypeModal(dutyType)"
                  class="inline-block w-6 h-6 rounded-full border-2 cursor-pointer color-picker-swatch"
                  :style="{ backgroundColor: dutyType.color || 'var(--dp-duty-type-fallback)', borderColor: 'var(--dp-border-primary)' }"
                ></span>
              </td>
              <td class="px-4 py-3">
                <div class="flex flex-wrap items-center justify-center gap-1">
                  <button
                    v-if="dutyType.id"
                    :disabled="index === 0 || index === team.dutyTypes.length - 1"
                    @click="swapPosition(index, index + 1)"
                    class="p-1 sm:p-1.5 border rounded hover-bg-light transition disabled:opacity-50 disabled:cursor-not-allowed border-dp-border-secondary"
                  >
                    <ArrowDown class="w-3 h-3 sm:w-4 sm:h-4" />
                  </button>
                  <button
                    v-if="dutyType.id"
                    :disabled="index <= 1"
                    @click="swapPosition(index, index - 1)"
                    class="p-1 sm:p-1.5 border rounded hover-bg-light transition disabled:opacity-50 disabled:cursor-not-allowed border-dp-border-secondary"
                  >
                    <ArrowUp class="w-3 h-3 sm:w-4 sm:h-4" />
                  </button>
                  <button
                    @click="openEditDutyTypeModal(dutyType)"
                    class="p-1 sm:p-1.5 border border-dp-accent-border text-dp-accent rounded hover:bg-dp-accent-soft transition"
                  >
                    <Pencil class="w-3 h-3 sm:w-4 sm:h-4" />
                  </button>
                  <button
                    v-if="dutyType.id"
                    @click="removeDutyType(dutyType)"
                    class="p-1 sm:p-1.5 border border-dp-danger-border text-dp-danger rounded hover:bg-dp-danger-soft transition"
                  >
                    <Trash2 class="w-3 h-3 sm:w-4 sm:h-4" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div v-else class="p-6 text-center text-dp-text-muted">
        {{ t('team.manage.labels.noDutyTypes') }}
      </div>
    </div>


    <MemberSearchModal
      :is-open="showMemberSearchModal"
      :team-id="teamId"
      v-model:saving="saving"
      @close="closeMemberSearchModal"
      @member-added="fetchTeam"
    />

    <DutyTypeModal
      :is-open="showDutyTypeModal"
      :team-id="teamId"
      :duty-type="dutyTypeModalTarget"
      :duty-types="team?.dutyTypes ?? []"
      v-model:saving="saving"
      @close="closeDutyTypeModal"
      @saved="fetchTeam"
    />

    <BatchUploadModal
      :is-open="showBatchUploadModal"
      :team-id="teamId"
      v-model:saving="saving"
      @close="closeBatchUploadModal"
    />
    </template>
  </div>
</template>
