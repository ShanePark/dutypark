<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import {
  Settings,
  CalendarPlus,
  Pencil,
  Trash2,
  Building2,
  X,
  Loader2,
  Plus,
  Check,
  AlertCircle,
} from 'lucide-vue-next'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import DatePickerField from '@/components/common/DatePickerField.vue'
import { useAuthStore } from '@/stores/auth'
import { teamApi } from '@/api/team'
import { dutyApi } from '@/api/duty'
import { useSwal } from '@/composables/useSwal'
import { useContentFilterStore } from '@/stores/contentFilter'
import { isLightColor } from '@/utils/color'
import { extractApiError } from '@/utils/resolveApiError'
import BaseModal from '@/components/common/BaseModal.vue'
import CalendarMonthNavigator from '@/components/common/CalendarMonthNavigator.vue'
import YearMonthPicker from '@/components/common/YearMonthPicker.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import CalendarGrid from '@/components/common/CalendarGrid.vue'
import type {
  TeamDto,
  TeamScheduleDto,
  DutyByShift,
  MemberPreviewDto,
  DutyCalendarDay,
  HolidayDto,
  TeamCreateDto,
  TeamNameCheckResult,
} from '@/types'

const router = useRouter()
const authStore = useAuthStore()
const { t } = useI18n()
const { showError, confirmDelete, toastSuccess } = useSwal()
const contentFilterStore = useContentFilterStore()

const loading = ref(false)
const shiftLoading = ref(false)
const saving = ref(false)
const showCreateTeamModal = ref(false)
const newTeamName = ref('')
const newTeamDescription = ref('')
const nameCheckResult = ref<TeamNameCheckResult | null>(null)
const checkedTeamName = ref('')
const isCheckingName = ref(false)
const isCreatingTeam = ref(false)
const newTeamNameFeedbackId = 'new-team-name-feedback'
const createTeamModalTitleId = 'create-team-modal-title'
const trimmedNewTeamName = computed(() => newTeamName.value.trim())
const trimmedNewTeamDescription = computed(() => newTeamDescription.value.trim())
const isCreateTeamDisabled = computed(() =>
  nameCheckResult.value !== 'OK' ||
  checkedTeamName.value !== trimmedNewTeamName.value ||
  trimmedNewTeamDescription.value.length > 50 ||
  isCheckingName.value ||
  isCreatingTeam.value
)

const hasTeam = ref(false)
const isTeamManager = ref(false)
const loginMemberId = computed(() => authStore.user?.id ?? 0)
const team = ref<TeamDto | null>(null)

const now = new Date()
const currentYear = ref(now.getFullYear())
const currentMonth = ref(now.getMonth() + 1)

const isYearMonthPickerOpen = ref(false)

function handleYearMonthSelect(year: number, month: number) {
  isYearMonthPickerOpen.value = false
  void updateCurrentMonth(year, month)
}

const today = {
  year: now.getFullYear(),
  month: now.getMonth() + 1,
  day: now.getDate(),
}

function getLastDayOfMonth(year: number, month: number) {
  return new Date(year, month, 0).getDate()
}

const selectedDay = ref({
  year: today.year,
  month: today.month,
  day: today.day,
  index: -1,
})

const teamSchedules = ref<TeamScheduleDto[][]>([])

const shift = ref<(DutyByShift & { isMyGroup: boolean })[]>([])

const myDuties = ref<DutyCalendarDay[]>([])

const holidaysByDays = ref<HolidayDto[][]>([])

const rawCalendarDays = ref<Array<{ year: number; month: number; day: number }>>([])

const showScheduleModal = ref(false)
const scheduleForm = ref({
  id: null as string | null,
  content: '',
  description: '',
  startDate: '',
  endDate: '',
})
const isTeamScheduleTitleMissing = computed(() => !scheduleForm.value.content.trim())
const isTeamScheduleDateRangeInvalid = computed(() => {
  const { startDate, endDate } = scheduleForm.value
  if (!startDate || !endDate) return true
  return endDate < startDate
})
const isTeamScheduleSaveDisabled = computed(() =>
  saving.value || isTeamScheduleTitleMissing.value || isTeamScheduleDateRangeInvalid.value
)

async function loadCalendar() {
  try {
    rawCalendarDays.value = await dutyApi.getCalendar(currentYear.value, currentMonth.value)
  } catch (error) {
    console.error('Failed to load calendar:', error)
    rawCalendarDays.value = []
  }
}

const teamDays = computed(() => {
  return rawCalendarDays.value.map((raw) => ({
    year: raw.year,
    month: raw.month,
    day: raw.day,
    isCurrentMonth: raw.year === currentYear.value && raw.month === currentMonth.value,
  }))
})

async function fetchTeamSummary() {
  loading.value = true
  try {
    // Load calendar first to ensure index alignment with holidays
    await loadCalendar()

    const response = await teamApi.getMyTeamSummary(currentYear.value, currentMonth.value)
    const data = response.data

    if (data.team) {
      hasTeam.value = true
      team.value = data.team
      isTeamManager.value = data.isTeamManager

      await Promise.all([
        fetchMyDuties(),
        fetchTeamSchedules(),
        loadHolidays(),
      ])
    } else {
      hasTeam.value = false
      team.value = null
      isTeamManager.value = false
      teamSchedules.value = []
    }
  } catch (error) {
    console.error('Failed to fetch team summary:', error)
    hasTeam.value = false
  } finally {
    loading.value = false
  }
}

async function fetchTeamSchedules() {
  if (!team.value) return

  try {
    const response = await teamApi.getTeamSchedules(
      team.value.id,
      currentYear.value,
      currentMonth.value
    )
    teamSchedules.value = response.data
  } catch (error) {
    console.error('Failed to fetch team schedules:', error)
    teamSchedules.value = []
  }
}

async function fetchShift() {
  if (!hasTeam.value) return

  shiftLoading.value = true
  try {
    const response = await teamApi.getShift(
      selectedDay.value.year,
      selectedDay.value.month,
      selectedDay.value.day
    )

    shift.value = response.data.map(group => ({
      ...group,
      isMyGroup: group.members.some((m: MemberPreviewDto) => m.id === loginMemberId.value),
    }))
  } catch (error) {
    console.error('Failed to fetch shift:', error)
    shift.value = []
  } finally {
    shiftLoading.value = false
  }
}

async function fetchMyDuties() {
  if (!loginMemberId.value) return

  try {
    myDuties.value = await dutyApi.getDuties(
      loginMemberId.value,
      currentYear.value,
      currentMonth.value
    )
  } catch (error) {
    console.error('Failed to fetch my duties:', error)
    myDuties.value = []
  }
}

function getDutyColor(day: { year: number; month: number; day: number }): string | null {
  const duty = myDuties.value.find(
    d => d.year === day.year && d.month === day.month && d.day === day.day
  )
  return duty?.dutyColor ?? null
}

function getDutyTypeHeaderTextColor(color: string | null | undefined): string {
  if (!color) return 'var(--dp-text-primary)'
  return isLightColor(color) ? 'var(--dp-text-on-light)' : 'var(--dp-text-on-dark)'
}

async function loadHolidays() {
  try {
    holidaysByDays.value = await dutyApi.getHolidays(
      currentYear.value,
      currentMonth.value
    )
  } catch (error) {
    console.error('Failed to load holidays:', error)
    holidaysByDays.value = []
  }
}

function findSelectedDayIndex() {
  const index = teamDays.value.findIndex(day =>
    day.year === selectedDay.value.year &&
    day.month === selectedDay.value.month &&
    day.day === selectedDay.value.day
  )
  selectedDay.value.index = index
}

function selectDay(day: { year: number; month: number; day: number }, index: number) {
  selectedDay.value = { ...day, index }
  fetchShift()
}

function syncSelectedDayToMonth(year: number, month: number, day = 1) {
  selectedDay.value = {
    year,
    month,
    day: Math.min(day, getLastDayOfMonth(year, month)),
    index: -1,
  }
}

async function updateCurrentMonth(year: number, month: number, day = 1) {
  currentYear.value = year
  currentMonth.value = month
  syncSelectedDayToMonth(year, month, day)
  await fetchTeamSummary()
  findSelectedDayIndex()
  await fetchShift()
}

function prevMonth() {
  const year = currentMonth.value === 1 ? currentYear.value - 1 : currentYear.value
  const month = currentMonth.value === 1 ? 12 : currentMonth.value - 1
  void updateCurrentMonth(year, month)
}

function nextMonth() {
  const year = currentMonth.value === 12 ? currentYear.value + 1 : currentYear.value
  const month = currentMonth.value === 12 ? 1 : currentMonth.value + 1
  void updateCurrentMonth(year, month)
}

function goToToday() {
  void updateCurrentMonth(today.year, today.month, today.day)
}

function goToTeamManage() {
  if (team.value) {
    router.push(`/team/manage/${team.value.id}`)
  }
}

function openCreateTeamModal() {
  newTeamName.value = ''
  newTeamDescription.value = ''
  nameCheckResult.value = null
  checkedTeamName.value = ''
  showCreateTeamModal.value = true
}

function closeCreateTeamModal() {
  showCreateTeamModal.value = false
}

async function checkTeamName() {
  const nameLength = trimmedNewTeamName.value.length
  checkedTeamName.value = ''
  if (nameLength < 2) {
    nameCheckResult.value = 'TOO_SHORT'
    return
  }
  if (nameLength > 20) {
    nameCheckResult.value = 'TOO_LONG'
    return
  }

  isCheckingName.value = true
  const requestedName = trimmedNewTeamName.value
  try {
    const response = await teamApi.checkTeamName(requestedName)
    if (trimmedNewTeamName.value === requestedName) {
      nameCheckResult.value = response.data
      checkedTeamName.value = requestedName
    }
  } catch (error) {
    console.error('Failed to check team name:', error)
    nameCheckResult.value = null
    showError(t('team.view.createTeam.messages.nameCheckFailed'))
  } finally {
    isCheckingName.value = false
  }
}

function getNameCheckMessage(): string {
  switch (nameCheckResult.value) {
    case 'TOO_SHORT':
      return t('team.view.createTeam.nameCheck.tooShort')
    case 'TOO_LONG':
      return t('team.view.createTeam.nameCheck.tooLong')
    case 'DUPLICATED':
      return t('team.view.createTeam.nameCheck.duplicated')
    case 'OK':
      return t('team.view.createTeam.nameCheck.ok')
    default:
      return ''
  }
}

async function handleCreateTeam() {
  if (isCreateTeamDisabled.value) return

  isCreatingTeam.value = true
  try {
    const createDto: TeamCreateDto = {
      name: trimmedNewTeamName.value,
      description: trimmedNewTeamDescription.value,
    }
    const response = await teamApi.createTeam(createDto)
    const createdTeamId = response.data.id
    const memberBeforeRefresh = authStore.user

    // Keep the local session useful even if the follow-up status request is
    // temporarily unavailable. A successful create has already assigned this
    // member to the returned team.
    if (memberBeforeRefresh) {
      authStore.setUser({
        ...memberBeforeRefresh,
        teamId: createdTeamId,
        team: response.data.name,
      })
    }

    // Team creation also changes the member's team claim. Refresh the auth
    // store before navigating so the rest of the app sees the new membership.
    try {
      await authStore.checkAuth()
    } catch (error) {
      console.error('Failed to refresh member team after creation:', error)
      // checkAuth clears the store for 401/403 responses. Keep that
      // unauthenticated state instead of restoring the pre-refresh member.
    }

    toastSuccess(t('team.view.createTeam.messages.createSuccess'))
    closeCreateTeamModal()
    router.push(`/team/manage/${response.data.id}`)
  } catch (error) {
    console.error('Failed to create team:', error)
    if (extractApiError(error)?.code === 'team.name.duplicated') {
      checkedTeamName.value = trimmedNewTeamName.value
      nameCheckResult.value = 'DUPLICATED'
      showError(t('team.view.createTeam.messages.nameDuplicated'))
    } else {
      showError(t('team.view.createTeam.messages.createFailed'))
    }
  } finally {
    isCreatingTeam.value = false
  }
}

function goToMemberDuty(memberId: number) {
  router.push(`/duty/${memberId}`)
}

function goToMemberDutyIfAvailable(member: MemberPreviewDto) {
  if (member.id == null) {
    return
  }
  goToMemberDuty(member.id)
}

function getShiftMemberKey(group: DutyByShift, member: MemberPreviewDto) {
  return member.id ?? `${group.dutyType.id ?? group.dutyType.name}-${member.name}`
}

function openNewScheduleModal() {
  const dateStr = `${selectedDay.value.year}-${String(selectedDay.value.month).padStart(2, '0')}-${String(selectedDay.value.day).padStart(2, '0')}`
  scheduleForm.value = {
    id: null,
    content: '',
    description: '',
    startDate: dateStr,
    endDate: dateStr,
  }
  showScheduleModal.value = true
}

function openEditScheduleModal(schedule: TeamScheduleDto) {
  scheduleForm.value = {
    id: schedule.id,
    content: schedule.content,
    description: schedule.description || '',
    startDate: schedule.startDateTime.slice(0, 10),
    endDate: schedule.endDateTime.slice(0, 10),
  }
  showScheduleModal.value = true
}

function closeScheduleModal() {
  showScheduleModal.value = false
}

async function saveSchedule() {
  if (!team.value) return
  if (isTeamScheduleTitleMissing.value || isTeamScheduleDateRangeInvalid.value) {
    return
  }

  if (contentFilterStore.isBlocked(scheduleForm.value.content, scheduleForm.value.description)) {
    showError(t('contentFilter.blocked'))
    return
  }

  saving.value = true
  const isNew = !scheduleForm.value.id
  try {
    await teamApi.saveTeamSchedule({
      id: scheduleForm.value.id ?? undefined,
      teamId: team.value.id,
      content: scheduleForm.value.content,
      description: scheduleForm.value.description,
      startDateTime: `${scheduleForm.value.startDate}T00:00:00`,
      endDateTime: `${scheduleForm.value.endDate}T23:59:59`,
    })
    showScheduleModal.value = false
    await fetchTeamSchedules()
    if (isNew) {
      toastSuccess(t('team.view.schedule.saveSuccess'))
    }
  } catch (error) {
    console.error('Failed to save schedule:', error)
    showError(t('team.view.schedule.saveFailed'))
  } finally {
    saving.value = false
  }
}

async function deleteSchedule(schedule: TeamScheduleDto) {
  if (!await confirmDelete(t('team.view.schedule.deleteConfirm', { title: schedule.content }))) return

  try {
    await teamApi.deleteTeamSchedule(schedule.id)
    await fetchTeamSchedules()
    toastSuccess(t('team.view.schedule.deleteSuccess'))
  } catch (error) {
    console.error('Failed to delete schedule:', error)
    showError(t('team.view.schedule.deleteFailed'))
  }
}

onMounted(() => {
  fetchTeamSummary().then(() => {
    findSelectedDayIndex()
    fetchShift()
  })
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-2 sm:px-4 py-4">
    <div v-if="loading" class="flex items-center justify-center py-20">
      <Loader2 class="w-8 h-8 animate-spin text-dp-accent" />
    </div>

    <template v-else-if="!hasTeam">
      <div class="rounded-lg shadow overflow-hidden bg-dp-bg-card">
        <div class="bg-dp-surface-strong text-dp-text-on-dark font-bold text-xl text-center py-3">
          {{ t('header.menu.myTeam') }}
        </div>
        <div class="flex flex-col items-center justify-center p-8 text-dp-text-secondary sm:p-12">
          <Building2 class="w-16 h-16 mb-4 text-dp-text-muted" />
          <p class="text-xl font-bold mb-2">{{ t('team.view.emptyTitle') }}</p>
          <p class="text-center text-lg">{{ t('team.view.emptyDescription') }}</p>
          <button
            type="button"
            class="mt-6 flex min-h-[44px] items-center justify-center gap-2 rounded-lg bg-dp-accent px-5 py-2.5 font-bold text-dp-text-on-dark transition hover:bg-dp-accent-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-dp-accent cursor-pointer"
            @click="openCreateTeamModal"
          >
            <Plus class="w-4 h-4" />
            {{ t('team.view.actions.createTeam') }}
          </button>
        </div>
      </div>
    </template>

    <template v-else-if="team">
      <div class="flex items-center justify-between gap-1 mb-1">
        <div class="w-20 sm:w-24 flex-shrink-0 flex items-center justify-start">
          <div class="flex items-center gap-1.5 px-2 py-1 rounded-full border bg-dp-bg-tertiary border-dp-border-secondary">
            <Building2 class="w-3.5 h-3.5 flex-shrink-0 text-dp-text-secondary" />
            <span class="text-xs sm:text-sm font-semibold truncate max-w-[60px] sm:max-w-[72px] text-dp-text-primary">{{ team.name }}</span>
          </div>
        </div>

        <CalendarMonthNavigator
          :current-year="currentYear"
          :current-month="currentMonth"
          @prev-month="prevMonth"
          @next-month="nextMonth"
          @open-year-month-picker="isYearMonthPickerOpen = true"
          @go-to-this-month="goToToday"
        />

        <div class="flex-shrink-0">
          <button
            v-if="isTeamManager"
            @click="goToTeamManage"
            class="px-3 py-2 border rounded-lg flex items-center gap-1 hover-interactive cursor-pointer border-dp-border-secondary"
          >
            <Settings class="w-4 h-4" />
            <span class="hidden sm:inline">{{ t('team.view.actions.manage') }}</span>
          </button>
          <div v-else class="w-16 sm:w-20"></div>
        </div>
      </div>

      <CalendarGrid
        :days="teamDays"
        :current-year="currentYear"
        :current-month="currentMonth"
        :holidays="holidaysByDays"
        :get-duty-color="getDutyColor"
        :selected-day="selectedDay"
        :use-adaptive-border="true"
        @day-click="selectDay"
      >
        <template #day-content="{ day, index }">
          <div v-if="teamSchedules[index]?.length" class="mt-0.5">
            <div
              v-for="schedule in teamSchedules[index].slice(0, 2)"
              :key="schedule.id"
              class="text-[10px] sm:text-sm leading-snug px-0.5 border-t-2 border-dashed break-words"
              :style="{
                color: getDutyColor(day) ? (isLightColor(getDutyColor(day)) ? 'var(--dp-text-on-light)' : 'var(--dp-text-on-dark)') : 'var(--dp-text-primary)',
                borderColor: getDutyColor(day) ? (isLightColor(getDutyColor(day)) ? 'var(--dp-border-on-light)' : 'var(--dp-border-on-dark)') : 'var(--dp-border-primary)'
              }"
            >
              {{ schedule.content }}
              <span
                v-if="schedule.totalDays && schedule.totalDays > 1"
                class="text-[9px] sm:text-xs"
                :style="{ color: getDutyColor(day) ? (isLightColor(getDutyColor(day)) ? 'var(--dp-text-muted)' : 'var(--dp-text-on-dark-muted)') : 'var(--dp-text-muted)' }"
              >
                ({{ schedule.daysFromStart }}/{{ schedule.totalDays }})
              </span>
            </div>
            <div
              v-if="teamSchedules[index].length > 2"
              class="text-[10px] font-medium"
              :style="{ color: getDutyColor(day) ? (isLightColor(getDutyColor(day)) ? 'var(--dp-text-muted)' : 'var(--dp-text-on-dark-soft)') : 'var(--dp-text-muted)' }"
            >
              +{{ teamSchedules[index].length - 2 }}
            </div>
          </div>
        </template>
      </CalendarGrid>

      <div class="rounded-lg border shadow-sm p-3 bg-dp-bg-card border-dp-border-secondary">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-3">
          <h3 class="text-lg font-bold text-dp-text-primary">
            {{ t('team.view.selectedDate', selectedDay) }}
          </h3>
          <button
            v-if="isTeamManager"
            @click="openNewScheduleModal"
            class="px-3 py-1.5 bg-dp-success text-dp-text-on-dark rounded-lg font-medium hover:bg-dp-success-hover transition flex items-center gap-1 w-full sm:w-auto justify-center cursor-pointer"
          >
            <CalendarPlus class="w-4 h-4" />
            {{ t('team.view.actions.addSchedule') }}
          </button>
        </div>

        <div
          v-if="selectedDay.index >= 0 && teamSchedules[selectedDay.index]?.length"
          class="space-y-2"
        >
          <div
            v-for="schedule in teamSchedules[selectedDay.index]"
            :key="schedule.id"
            class="rounded-lg p-3 border transition-all duration-150 hover:shadow-md bg-dp-bg-secondary border-dp-border-primary"
          >
            <div class="flex items-start justify-between">
              <div class="flex-1 min-w-0">
                <div class="font-bold mb-1 text-dp-text-primary">
                  {{ schedule.content }}
                  <span class="text-sm font-normal text-dp-text-secondary">
                    ({{ t('team.view.schedule.createdBy') }} <strong>{{ schedule.createMember }}</strong>)
                  </span>
                </div>
                <div v-if="schedule.description" class="text-sm whitespace-pre-wrap break-words text-dp-text-secondary">
                  {{ schedule.description }}
                </div>
              </div>
              <div v-if="isTeamManager" class="flex gap-1 ml-2 flex-shrink-0">
                <button
                  @click="openEditScheduleModal(schedule)"
                  class="p-1.5 text-dp-accent rounded-lg hover:bg-dp-accent-soft transition cursor-pointer"
                  :title="t('team.view.actions.editSchedule')"
                >
                  <Pencil class="w-4 h-4" />
                </button>
                <button
                  @click="deleteSchedule(schedule)"
                  class="p-1.5 text-dp-danger rounded-lg hover:bg-dp-danger-soft transition cursor-pointer"
                  :title="t('team.view.actions.deleteSchedule')"
                >
                  <Trash2 class="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>
        <div v-else class="text-center py-6 text-dp-text-muted">
          {{ t('team.view.schedule.empty') }}
        </div>
      </div>

      <div v-if="shiftLoading" class="mt-3 flex items-center justify-center py-8">
        <Loader2 class="w-6 h-6 animate-spin text-dp-accent" />
      </div>
      <div v-else-if="shift.length > 0" class="mt-3 space-y-3">
        <template v-for="group in shift" :key="group.dutyType.id">
          <div
            v-if="group.members.length > 0"
            class="rounded-lg border overflow-hidden shadow-sm"
            :class="{ 'ring-2': group.isMyGroup }"
            :style="{
              backgroundColor: 'var(--dp-bg-card)',
              borderColor: 'var(--dp-border-secondary)',
              '--tw-ring-color': 'var(--dp-text-primary)'
            }"
          >
            <div
              class="p-3 flex items-center justify-between"
              :style="{ backgroundColor: group.dutyType.color ?? 'var(--dp-duty-type-fallback)' }"
            >
              <span class="font-bold" :style="{ color: getDutyTypeHeaderTextColor(group.dutyType.color) }">{{ group.dutyType.name }}</span>
              <span class="px-2 py-0.5 rounded-full text-sm font-medium" :style="{ backgroundColor: 'var(--dp-chip-on-dark-bg)', color: 'var(--dp-text-on-light)' }">
                {{ t('team.view.shift.memberCount', { count: group.members.length }) }}
              </span>
            </div>

            <div class="p-3 grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2">
              <div
                v-for="member in group.members"
                :key="getShiftMemberKey(group, member)"
                @click="goToMemberDutyIfAvailable(member)"
                class="flex flex-col items-center p-2 border rounded-lg hover-card-select"
                :class="{
                  'cursor-pointer': member.id != null,
                  'cursor-default': member.id == null,
                  'ring-2': member.id === loginMemberId,
                }"
                :style="{
                  borderColor: 'var(--dp-border-secondary)',
                  backgroundColor: 'var(--dp-bg-secondary)',
                  '--tw-ring-color': 'var(--dp-text-primary)'
                }"
              >
                <ProfileAvatar :member-id="member.id" :has-profile-photo="member.hasProfilePhoto" :profile-photo-version="member.profilePhotoVersion" size="sm" class="mb-1" />
                <span class="text-sm font-medium truncate w-full text-center text-dp-text-primary">
                  {{ member.name }}
                </span>
              </div>
            </div>
          </div>
        </template>
      </div>
    </template>

    <BaseModal
      :is-open="showCreateTeamModal"
      size="md"
      height="fit"
      rounded
      :aria-labelledby="createTeamModalTitleId"
      @close="closeCreateTeamModal"
    >
      <div class="modal-header">
        <h2 :id="createTeamModalTitleId">{{ t('team.view.createTeam.title') }}</h2>
        <button
          type="button"
          @click="closeCreateTeamModal"
          class="p-1.5 rounded-full hover-close-btn cursor-pointer text-dp-text-muted"
          :aria-label="t('common.actions.close')"
          :title="t('common.actions.close')"
        >
          <X class="w-5 h-5" />
        </button>
      </div>

      <div class="modal-body-form">
        <div>
          <label class="form-label" for="new-team-name">
            {{ t('team.view.createTeam.nameLabel') }}
            <CharacterCounter :current="newTeamName.length" :max="20" />
          </label>
          <div class="flex gap-2">
            <input
              v-model="newTeamName"
              id="new-team-name"
              type="text"
              maxlength="20"
              minlength="2"
              class="form-control-neutral flex-1"
              :placeholder="t('team.view.createTeam.namePlaceholder')"
              :aria-invalid="!trimmedNewTeamName || nameCheckResult === 'TOO_SHORT' || nameCheckResult === 'TOO_LONG' || nameCheckResult === 'DUPLICATED'"
              :aria-describedby="nameCheckResult ? newTeamNameFeedbackId : undefined"
              @input="nameCheckResult = null; checkedTeamName = ''"
            />
            <button
              type="button"
              @click="checkTeamName"
              :disabled="isCheckingName || trimmedNewTeamName.length < 2"
              class="flex items-center gap-2 rounded-lg bg-dp-accent px-4 py-2 text-sm font-medium text-dp-text-on-dark transition hover:bg-dp-accent-hover disabled:cursor-not-allowed disabled:opacity-50 cursor-pointer"
            >
              <Loader2 v-if="isCheckingName" class="w-4 h-4 animate-spin" />
              {{ t('team.view.createTeam.checkButton') }}
            </button>
          </div>
          <p
            v-if="nameCheckResult"
            :id="newTeamNameFeedbackId"
            class="mt-1 flex items-center gap-1 text-sm"
            :class="nameCheckResult === 'OK' ? 'text-dp-success' : 'text-dp-danger'"
          >
            <Check v-if="nameCheckResult === 'OK'" class="w-4 h-4" />
            <AlertCircle v-else class="w-4 h-4" />
            {{ getNameCheckMessage() }}
          </p>
        </div>

        <div>
          <label class="form-label" for="new-team-description">
            {{ t('team.view.createTeam.descriptionLabel') }}
            <CharacterCounter :current="newTeamDescription.length" :max="50" />
          </label>
          <input
            v-model="newTeamDescription"
            id="new-team-description"
            type="text"
            maxlength="50"
            class="form-control-neutral"
            :placeholder="t('team.view.createTeam.descriptionPlaceholder')"
            :aria-invalid="trimmedNewTeamDescription.length > 50"
          />
        </div>
      </div>

      <div class="modal-actions modal-actions-end modal-footer-safe">
        <button
          type="button"
          @click="closeCreateTeamModal"
          class="flex-1 rounded-lg bg-dp-bg-tertiary px-4 py-2 text-sm font-medium text-dp-text-primary transition hover-interactive cursor-pointer sm:flex-none"
        >
          {{ t('common.actions.close') }}
        </button>
        <button
          type="button"
          @click="handleCreateTeam"
          :disabled="isCreateTeamDisabled"
          class="flex flex-1 items-center justify-center gap-2 rounded-lg bg-dp-accent px-4 py-2 text-sm font-medium text-dp-text-on-dark transition hover:bg-dp-accent-hover disabled:cursor-not-allowed disabled:opacity-50 cursor-pointer sm:flex-none"
        >
          <Loader2 v-if="isCreatingTeam" class="w-4 h-4 animate-spin" />
          {{ t('team.view.createTeam.createButton') }}
        </button>
      </div>
    </BaseModal>

    <BaseModal
      :is-open="showScheduleModal"
      size="lg"
      height="fit"
      @close="closeScheduleModal"
    >
      <div class="modal-header">
        <h2>{{ t('team.view.schedule.modal.title') }}</h2>
        <button
          @click="closeScheduleModal"
          class="p-1.5 rounded-full hover-close-btn cursor-pointer"
        >
          <X class="w-5 h-5 text-dp-text-primary" />
        </button>
      </div>

      <div class="modal-body-form">
        <div>
          <label class="form-label text-dp-text-primary">
            {{ t('team.view.schedule.modal.contentLabel') }}
            <CharacterCounter :current="scheduleForm.content.length" :max="50" />
          </label>
          <input
            v-model="scheduleForm.content"
            type="text"
            maxlength="50"
            class="form-control"
            :placeholder="t('team.view.schedule.modal.contentPlaceholder')"
            :aria-invalid="isTeamScheduleTitleMissing"
          />
        </div>

        <div>
          <label class="form-label text-dp-text-primary">
            {{ t('team.view.schedule.modal.descriptionLabel') }}
          </label>
          <textarea
            v-model="scheduleForm.description"
            rows="4"
            class="form-control resize-none"
            :placeholder="t('team.view.schedule.modal.descriptionPlaceholder')"
          ></textarea>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="form-label text-dp-text-primary">
              {{ t('team.view.schedule.modal.startDate') }}
            </label>
            <DatePickerField
              v-model="scheduleForm.startDate"
              readonly
              :aria-label="t('team.view.schedule.modal.startDate')"
            />
          </div>
          <div>
            <label class="form-label text-dp-text-primary">
              {{ t('team.view.schedule.modal.endDate') }}
            </label>
            <!-- Range mode makes the anchor the floor, so `invalid` is left for what the control
                 cannot reach: a schedule opened without a start date, where there is no anchor. -->
            <DatePickerField
              v-model="scheduleForm.endDate"
              mode="range"
              :range-start="scheduleForm.startDate"
              :invalid="isTeamScheduleDateRangeInvalid"
              :aria-label="t('team.view.schedule.modal.endDate')"
            />
          </div>
        </div>
      </div>

      <div class="modal-actions modal-actions-end modal-footer-safe">
        <button
          @click="closeScheduleModal"
          class="flex-1 sm:flex-none px-4 py-2 rounded-lg font-medium hover-interactive cursor-pointer bg-dp-bg-tertiary text-dp-text-primary"
        >
          {{ t('common.actions.close') }}
        </button>
        <button
          @click="saveSchedule"
          :disabled="isTeamScheduleSaveDisabled"
          class="flex-1 sm:flex-none px-4 py-2 bg-dp-accent text-dp-text-on-dark rounded-lg font-medium hover:bg-dp-accent-hover transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 cursor-pointer"
        >
          <Loader2 v-if="saving" class="w-4 h-4 animate-spin" />
          {{ t('team.view.schedule.modal.save') }}
        </button>
      </div>
    </BaseModal>

    <YearMonthPicker
      :is-open="isYearMonthPickerOpen"
      :current-year="currentYear"
      :current-month="currentMonth"
      @close="isYearMonthPickerOpen = false"
      @select="handleYearMonthSelect"
      @go-to-this-month="goToToday(); isYearMonthPickerOpen = false"
    />
  </div>
</template>
