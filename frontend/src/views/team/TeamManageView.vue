<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useSwal } from '@/composables/useSwal'
import { useNavigateBack } from '@/composables/useNavigateBack'
import { useAuthStore } from '@/stores/auth'
import { teamApi } from '@/api/team'
import MemberSearchModal from '@/components/team/MemberSearchModal.vue'
import BatchUploadModal from '@/components/team/BatchUploadModal.vue'
import DutyTypeModal from '@/components/team/DutyTypeModal.vue'
import adminApi from '@/api/admin'
import { resolveApiErrorMessage } from '@/utils/resolveApiError'
import {
  findVisibleDutyTypeNeighbor,
} from '@/utils/dutyTypeVisibility'
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
  ShieldOff,
  Crown,
  Loader2,
  Eye,
  EyeOff,
  UserCog,
} from '@lucide/vue'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { t } = useI18n()
const { showError, toastSuccess, confirmDelete, confirm } = useSwal()
const { goBack } = useNavigateBack()
const teamId = Number(route.params.teamId)

const loading = ref(false)
const saving = ref(false)

const isAdmin = ref(false)
const isAppAdmin = computed(() => authStore.user?.isAdmin ?? false)
const canAssignFirstAdmin = computed(() => isAppAdmin.value && team.value?.adminId === null)
const loginId = computed(() => authStore.user?.id ?? 0)
const teamLoaded = ref(false)

const team = ref<TeamDto | null>(null)

const dutyBatchTemplates = ref<DutyBatchTemplateDto[]>([])

const hasMember = computed(() => team.value?.members && team.value.members.length > 0)
const hasDutyType = computed(() => team.value?.dutyTypes && team.value.dutyTypes.length > 0)

const showMemberSearchModal = ref(false)

const showDutyTypeModal = ref(false)
const dutyTypeModalTarget = ref<DutyTypeDto | null>(null)

const showBatchUploadModal = ref(false)

async function fetchTeam() {
  loading.value = true
  try {
    const response = await teamApi.getTeamForManage(teamId)
    team.value = response.data
    teamLoaded.value = true
    isAdmin.value = isAppAdmin.value ||
      team.value.adminId === loginId.value ||
      team.value.members.some(m => m.id === loginId.value && m.isManager)
  } catch (error) {
    console.error('Failed to fetch team:', error)
    showError(t('team.manage.messages.fetchFailed'))
    // Replace so back does not re-enter the page that just failed and re-fire the error.
    router.replace('/team')
  } finally {
    loading.value = false
  }
}

async function fetchDutyBatchTemplates() {
  try {
    const response = await teamApi.getDutyBatchTemplates()
    dutyBatchTemplates.value = response.data
  } catch (error) {
    console.error('Failed to fetch duty batch templates:', error)
  }
}

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
    ? t(
        canAssignFirstAdmin.value
          ? 'team.manage.messages.assignAdminConfirm'
          : 'team.manage.messages.changeAdminConfirm',
        { name: member.name },
      )
    : t('team.manage.messages.resetAdminConfirm', { name: team.value?.adminName })

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
  if (saving.value) return
  dutyTypeModalTarget.value = null
  showDutyTypeModal.value = true
}

function openEditDutyTypeModal(dutyType: DutyTypeDto) {
  if (saving.value) return
  dutyTypeModalTarget.value = dutyType
  showDutyTypeModal.value = true
}

function closeDutyTypeModal() {
  if (saving.value) return
  showDutyTypeModal.value = false
}

async function updateDutyTypeVisibility(dutyType: DutyTypeDto) {
  if (saving.value || !dutyType.id) return
  saving.value = true
  const nextHidden = !dutyType.hidden
  const messageKey = nextHidden
    ? 'team.manage.messages.hideDutyTypeConfirm'
    : 'team.manage.messages.restoreDutyTypeConfirm'
  try {
    if (!await confirm(t(messageKey, { name: dutyType.name }))) return
    await teamApi.updateDutyTypeVisibility(teamId, dutyType.id, nextHidden)
    toastSuccess(t(nextHidden
      ? 'team.manage.messages.hideDutyTypeSuccess'
      : 'team.manage.messages.restoreDutyTypeSuccess'))
    await fetchTeam()
  } catch (error) {
    console.error('Failed to update duty type visibility:', error)
    await fetchTeam()
    showError(resolveApiErrorMessage(error, {
      fallbackKey: 'team.manage.messages.updateDutyTypeVisibilityFailed',
    }, t))
  } finally {
    saving.value = false
  }
}

function visibleNeighborIndex(index: number, direction: -1 | 1): number | null {
  return findVisibleDutyTypeNeighbor(team.value?.dutyTypes ?? [], index, direction)
}

function canMoveDutyType(index: number, direction: -1 | 1): boolean {
  const dutyType = team.value?.dutyTypes[index]
  return !!dutyType?.id && !dutyType.hidden && visibleNeighborIndex(index, direction) !== null
}

function moveDutyType(index: number, direction: -1 | 1) {
  const neighborIndex = visibleNeighborIndex(index, direction)
  if (neighborIndex !== null) void swapPosition(index, neighborIndex)
}

async function swapPosition(index1: number, index2: number) {
  if (saving.value || !team.value) return
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

function openBatchUploadModal() {
  showBatchUploadModal.value = true
}

function closeBatchUploadModal() {
  showBatchUploadModal.value = false
}

async function removeTeam() {
  const confirmed = await confirmDelete(
    t('team.manage.messages.deleteTeamConfirm', { name: team.value?.name }),
    t('team.manage.actions.deleteTeam')
  )
  if (!confirmed) return

  try {
    await adminApi.deleteTeam(teamId)
    toastSuccess(t('team.manage.messages.deleteTeamSuccess'))
    // The team is gone, so its manage page must not stay reachable through back.
    router.replace('/admin/teams')
  } catch (e: unknown) {
    const message = resolveApiErrorMessage(e, { fallbackKey: 'team.manage.messages.deleteTeamFailed' }, t)
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
    <div v-if="loading" class="flex items-center justify-center py-20">
      <Loader2 class="w-8 h-8 animate-spin text-dp-accent" />
    </div>

    <template v-else-if="team">
      <div class="font-bold text-xl py-3 rounded-t-lg flex items-center justify-between px-4" :style="{ backgroundColor: 'var(--dp-modal-header-bg)', color: 'var(--dp-text-on-dark)' }">
        <button
          type="button"
          @click="goBack('/team')"
          class="inline-flex min-h-10 items-center gap-1.5 rounded-lg bg-dp-surface-strong-alt px-3 text-sm font-medium text-dp-text-on-dark transition-colors hover:bg-dp-surface-strong-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring cursor-pointer"
        >
          <ChevronLeft class="w-4 h-4" />
          {{ t('team.manage.actions.back') }}
        </button>
        <span>{{ t('team.manage.title', { name: team.name }) }}</span>
        <button
          v-if="isAppAdmin && teamLoaded && !hasMember"
          type="button"
          @click="removeTeam"
          class="inline-flex min-h-10 items-center justify-center rounded-lg bg-dp-danger px-3 text-sm font-semibold text-dp-text-on-dark transition-colors hover:bg-dp-danger-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring cursor-pointer"
        >
          {{ t('team.manage.actions.deleteTeam') }}
        </button>
        <span v-else class="w-16"></span>
      </div>

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
              type="button"
              @click="changeAdmin()"
              class="inline-flex min-h-10 items-center gap-1.5 rounded-lg border border-dp-danger-border bg-dp-danger-soft px-2.5 py-2 text-sm font-medium text-dp-danger transition-colors hover:bg-dp-danger-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring cursor-pointer"
            >
              <Trash2 class="w-3 h-3" />
              {{ t('team.manage.actions.cancelAdmin') }}
            </button>
          </div>
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
            type="button"
            @click="openBatchUploadModal"
            class="mt-1.5 inline-flex min-h-11 w-full items-center justify-center gap-1.5 rounded-lg bg-dp-accent px-4 py-2 font-semibold text-dp-text-on-dark transition-colors hover:bg-dp-accent-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring cursor-pointer"
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
                    type="button"
                    @click="changeAdmin()"
                    class="inline-flex min-h-10 items-center gap-1.5 rounded-lg border border-dp-danger-border bg-dp-danger-soft px-2.5 py-2 text-sm font-medium text-dp-danger transition-colors hover:bg-dp-danger-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring cursor-pointer"
                  >
                    <Trash2 class="w-3 h-3" />
                    {{ t('team.manage.actions.cancelAdmin') }}
                  </button>
                </div>
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
                  type="button"
                  @click="openBatchUploadModal"
                  class="inline-flex min-h-11 items-center justify-center gap-1.5 rounded-lg bg-dp-accent px-4 py-2 font-semibold text-dp-text-on-dark transition-colors hover:bg-dp-accent-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring cursor-pointer"
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

    <div class="border rounded-lg overflow-hidden mb-4 bg-dp-bg-card border-dp-border-primary">
      <div class="text-dp-text-on-dark px-4 py-3 flex flex-wrap items-center justify-between gap-2 bg-dp-surface-strong">
        <h3 class="font-bold">{{ t('team.manage.fields.members') }}</h3>
        <button
          type="button"
          @click="openMemberSearchModal"
          class="inline-flex min-h-10 items-center justify-center gap-1.5 rounded-lg bg-dp-accent px-3 text-sm font-semibold text-dp-text-on-dark shadow-sm transition-colors hover:bg-dp-accent-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring cursor-pointer"
        >
          <UserPlus class="w-4 h-4" />
          {{ t('team.manage.actions.addMember') }}
        </button>
      </div>

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
                  <div v-if="!member.isManager" class="flex items-center justify-center gap-1">
                    <button
                      v-if="canAssignFirstAdmin && !member.isAdmin"
                      type="button"
                      @click="changeAdmin(member)"
                      class="inline-flex min-h-10 items-center justify-center gap-1.5 whitespace-nowrap rounded-lg border border-dp-accent-border bg-dp-accent-soft px-2.5 py-2 text-xs font-medium text-dp-accent transition-colors hover:bg-dp-accent-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
                    >
                      <Crown class="w-3 h-3" />
                      {{ t('team.manage.actions.assignAdmin') }}
                    </button>
                    <button
                      type="button"
                      @click="assignManager(member)"
                      :title="t('team.manage.actions.assignManager')"
                      :aria-label="t('team.manage.actions.assignManager')"
                      class="inline-flex min-h-10 items-center justify-center gap-1.5 whitespace-nowrap rounded-lg border border-dp-accent-border bg-dp-accent-soft px-2.5 py-2 text-xs font-medium text-dp-accent transition-colors hover:bg-dp-accent-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
                    >
                      <UserCog class="w-3.5 h-3.5" />
                      <span>{{ t('team.manage.actions.assignManager') }}</span>
                    </button>
                  </div>
                  <div v-else-if="member.isManager && !member.isAdmin" class="flex items-center justify-center gap-1">
                    <button
                      type="button"
                      @click="unAssignManager(member)"
                      class="inline-flex min-h-10 items-center justify-center gap-1.5 whitespace-nowrap rounded-lg border border-dp-warning-border bg-dp-warning-soft px-2.5 py-2 text-xs font-medium text-dp-warning transition-colors hover:bg-dp-warning-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
                    >
                      <ShieldOff class="w-3 h-3" />
                      {{ t('team.manage.actions.revokeManager') }}
                    </button>
                    <button
                      type="button"
                      @click="changeAdmin(member)"
                      class="inline-flex min-h-10 items-center justify-center gap-1.5 whitespace-nowrap rounded-lg border border-dp-accent-border bg-dp-accent-soft px-2.5 py-2 text-xs font-medium text-dp-accent transition-colors hover:bg-dp-accent-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
                    >
                      <Crown class="w-3 h-3" />
                      {{ t(canAssignFirstAdmin ? 'team.manage.actions.assignAdmin' : 'team.manage.actions.transferAdmin') }}
                    </button>
                  </div>
                  <span class="text-dp-text-muted" v-else-if="member.isAdmin">-</span>
                </template>
              </td>
              <td class="px-4 py-3 text-center">
                <button
                  type="button"
                  @click="removeMember(member.id)"
                  class="inline-flex min-h-10 items-center justify-center gap-1.5 whitespace-nowrap rounded-lg border border-dp-danger-border bg-dp-danger-soft px-2.5 py-2 text-sm font-medium text-dp-danger transition-colors hover:bg-dp-danger-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring mx-auto"
                >
                  <Trash2 class="w-3 h-3" />
                  {{ t('team.manage.actions.removeMember') }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

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
              type="button"
              @click="removeMember(member.id)"
              class="inline-flex min-h-10 items-center justify-center gap-1.5 whitespace-nowrap rounded-lg border border-dp-danger-border bg-dp-danger-soft px-2.5 py-2 text-xs font-medium text-dp-danger transition-colors hover:bg-dp-danger-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
            >
              <Trash2 class="w-3 h-3" />
              {{ t('team.manage.actions.removeMember') }}
            </button>
          </div>
          <div v-if="isAdmin && !member.isAdmin" class="flex flex-wrap gap-1">
            <template v-if="!member.isManager">
              <button
                v-if="canAssignFirstAdmin"
                type="button"
                @click="changeAdmin(member)"
                class="inline-flex min-h-10 items-center justify-center gap-1.5 whitespace-nowrap rounded-lg border border-dp-accent-border bg-dp-accent-soft px-2.5 py-2 text-xs font-medium text-dp-accent transition-colors hover:bg-dp-accent-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
              >
                <Crown class="w-3 h-3" />
                {{ t('team.manage.actions.assignAdmin') }}
              </button>
              <button
                type="button"
                @click="assignManager(member)"
                :title="t('team.manage.actions.assignManager')"
                class="inline-flex min-h-10 items-center justify-center gap-1.5 whitespace-nowrap rounded-lg border border-dp-accent-border bg-dp-accent-soft px-2.5 py-2 text-xs font-medium text-dp-accent transition-colors hover:bg-dp-accent-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
              >
                <UserCog class="w-3.5 h-3.5" />
                {{ t('team.manage.actions.assignManager') }}
              </button>
            </template>
            <template v-else-if="member.isManager">
              <button
                type="button"
                @click="unAssignManager(member)"
                class="inline-flex min-h-10 items-center justify-center gap-1.5 whitespace-nowrap rounded-lg border border-dp-warning-border bg-dp-warning-soft px-2.5 py-2 text-xs font-medium text-dp-warning transition-colors hover:bg-dp-warning-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
              >
                <ShieldOff class="w-3 h-3" />
                {{ t('team.manage.actions.revokeManager') }}
              </button>
              <button
                type="button"
                @click="changeAdmin(member)"
                class="inline-flex min-h-10 items-center justify-center gap-1.5 whitespace-nowrap rounded-lg border border-dp-accent-border bg-dp-accent-soft px-2.5 py-2 text-xs font-medium text-dp-accent transition-colors hover:bg-dp-accent-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
              >
                <Crown class="w-3 h-3" />
                {{ t(canAssignFirstAdmin ? 'team.manage.actions.assignAdmin' : 'team.manage.actions.transferAdmin') }}
              </button>
            </template>
          </div>
        </div>
      </div>
      <div v-else class="p-6 text-center text-dp-text-muted">
        {{ t('team.manage.labels.noMembers') }}
      </div>
    </div>

    <div class="border rounded-lg overflow-hidden bg-dp-bg-card border-dp-border-primary">
      <div class="text-dp-text-on-dark px-4 py-3 flex items-center justify-between bg-dp-surface-strong">
        <h3 class="font-bold">{{ t('team.manage.fields.dutyTypes') }}</h3>
        <button
          type="button"
          @click="openAddDutyTypeModal"
          :disabled="saving"
          class="inline-flex min-h-10 items-center justify-center gap-1.5 rounded-lg bg-dp-accent px-3 text-sm font-semibold text-dp-text-on-dark shadow-sm transition-colors hover:bg-dp-accent-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring cursor-pointer disabled:cursor-not-allowed disabled:opacity-50"
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
              <th class="px-4 py-2 text-center">{{ t('team.manage.fields.status') }}</th>
              <th class="px-4 py-2 text-center">{{ t('team.manage.fields.tools') }}</th>
            </tr>
          </thead>
          <tbody class="border-dp-border-primary">
            <tr
              v-for="(dutyType, index) in team.dutyTypes"
              :key="dutyType.id || 'default'"
              class="hover-bg-light border-b border-dp-border-primary"
              :class="{ 'opacity-60': dutyType.hidden }"
            >
              <td class="px-4 py-3 text-center text-dp-text-muted">{{ index + 1 }}</td>
              <td class="px-4 py-3 font-medium text-dp-text-primary">
                {{ dutyType.name }}
                <span v-if="dutyType.id === null" class="text-xs font-normal text-dp-text-muted">({{ t('team.manage.labels.offDuty') }})</span>
              </td>
              <td class="px-4 py-3 text-center">
                <button
                  type="button"
                  @click="openEditDutyTypeModal(dutyType)"
                  :aria-label="t('team.manage.actions.editDutyType')"
                  :title="t('team.manage.actions.editDutyType')"
                  class="inline-block h-6 w-6 cursor-pointer rounded-full border-2 color-picker-swatch focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
                  :style="{ backgroundColor: dutyType.color || 'var(--dp-duty-type-fallback)', borderColor: 'var(--dp-border-primary)' }"
                ></button>
              </td>
              <td class="px-4 py-3 text-center">
                <span
                  class="inline-flex items-center gap-1 rounded-full px-2 py-1 text-xs font-medium"
                  :class="dutyType.hidden
                    ? 'bg-dp-bg-tertiary text-dp-text-muted'
                    : 'bg-dp-success-soft text-dp-success'"
                >
                  <EyeOff v-if="dutyType.hidden" class="w-3 h-3" />
                  <Eye v-else class="w-3 h-3" />
                  {{ dutyType.hidden ? t('team.manage.labels.hidden') : t('team.manage.labels.visible') }}
                </span>
              </td>
              <td class="px-4 py-3">
                <div class="flex flex-wrap items-center justify-center gap-1">
                  <button
                    v-if="dutyType.id"
                    type="button"
                    :disabled="saving || !canMoveDutyType(index, 1)"
                    @click="moveDutyType(index, 1)"
                    :aria-label="t('team.manage.actions.moveDutyTypeDown')"
                    :title="t('team.manage.actions.moveDutyTypeDown')"
                    class="inline-flex min-h-11 min-w-11 items-center justify-center rounded-lg border border-dp-border-secondary bg-dp-bg-secondary p-2 text-dp-text-secondary transition-colors hover:bg-dp-bg-hover hover:text-dp-text-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    <ArrowDown class="w-3 h-3 sm:w-4 sm:h-4" />
                  </button>
                  <button
                    v-if="dutyType.id"
                    type="button"
                    :disabled="saving || !canMoveDutyType(index, -1)"
                    @click="moveDutyType(index, -1)"
                    :aria-label="t('team.manage.actions.moveDutyTypeUp')"
                    :title="t('team.manage.actions.moveDutyTypeUp')"
                    class="inline-flex min-h-11 min-w-11 items-center justify-center rounded-lg border border-dp-border-secondary bg-dp-bg-secondary p-2 text-dp-text-secondary transition-colors hover:bg-dp-bg-hover hover:text-dp-text-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    <ArrowUp class="w-3 h-3 sm:w-4 sm:h-4" />
                  </button>
                  <button
                    type="button"
                    @click="openEditDutyTypeModal(dutyType)"
                    :disabled="saving"
                    :aria-label="t('team.manage.actions.editDutyType')"
                    :title="t('team.manage.actions.editDutyType')"
                    class="inline-flex min-h-11 min-w-11 items-center justify-center rounded-lg border border-dp-accent-border bg-dp-accent-soft p-2 text-dp-accent transition-colors hover:bg-dp-accent-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    <Pencil class="w-3 h-3 sm:w-4 sm:h-4" />
                  </button>
                  <button
                    v-if="dutyType.id"
                    type="button"
                    @click="updateDutyTypeVisibility(dutyType)"
                    :disabled="saving"
                    :aria-label="dutyType.hidden ? t('team.manage.actions.restoreDutyType') : t('team.manage.actions.hideDutyType')"
                    class="inline-flex min-h-11 min-w-11 items-center justify-center rounded-lg border p-2 transition-colors focus-visible:outline-none focus-visible:ring-2 disabled:cursor-not-allowed disabled:opacity-50"
                    :class="dutyType.hidden
                      ? 'border-dp-success-border bg-dp-success-soft text-dp-success hover:bg-dp-success-soft-hover focus-visible:ring-dp-accent-ring'
                      : 'border-dp-warning-border bg-dp-warning-soft text-dp-warning hover:bg-dp-warning-soft-hover focus-visible:ring-dp-accent-ring'"
                    :title="dutyType.hidden ? t('team.manage.actions.restoreDutyType') : t('team.manage.actions.hideDutyType')"
                  >
                    <Eye v-if="dutyType.hidden" class="w-4 h-4 mx-auto" />
                    <EyeOff v-else class="w-4 h-4 mx-auto" />
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
