<script setup lang="ts">
import { computed } from 'vue'
import { CalendarCheck, Lock, MessageSquareText, CheckSquare } from 'lucide-vue-next'
import { isLightColor } from '@/utils/color'
import CalendarGrid from '@/components/common/CalendarGrid.vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import type { HolidayDto } from '@/types'
import type { CalendarDay, DutyType, Schedule, OtherDuty, LocalDDay, DutyDay, TodoDueItem } from '@/views/duty/dutyViewTypes'

const props = defineProps<{
  days: CalendarDay[]
  currentYear: number
  currentMonth: number
  holidays: HolidayDto[][]
  getDutyColorForDay: (day: CalendarDay) => string | null
  highlightDay: { year: number; month: number; day: number } | null
  batchEditMode: boolean
  focusedDay: number | null
  canEdit: boolean
  duties: Array<DutyDay | null>
  dutyTypes: DutyType[]
  otherDuties: OtherDuty[]
  schedulesByDays: Schedule[][]
  dDays: LocalDDay[]
  pinnedDDay: LocalDDay | null
  todosDueByDays: TodoDueItem[][]
  isMyCalendar: boolean
  memberId: number
}>()

const emit = defineEmits<{
  (e: 'day-click', day: CalendarDay, index: number): void
  (e: 'batch-duty-change', day: CalendarDay, dutyTypeId: number | null): void
  (e: 'schedule-click', schedule: Schedule): void
  (e: 'todo-click', todo: TodoDueItem): void
}>()

type DisplayTagMember = {
  key: string
  id?: number
  name: string
  hasProfilePhoto?: boolean
  profilePhotoVersion?: number
}

const focusedCalendarDay = computed(() => {
  if (!props.batchEditMode || !props.focusedDay) return null
  return { year: props.currentYear, month: props.currentMonth, day: props.focusedDay }
})

const displayHolidays = computed(() => (props.batchEditMode ? [] : props.holidays))

function getDutyColorAt(index: number): string | null {
  return props.duties[index]?.dutyColor ?? null
}

function getMutedTextColor(dutyColor: string | null): string {
  if (!dutyColor) return 'var(--dp-text-muted)'
  return isLightColor(dutyColor) ? 'var(--dp-text-muted)' : 'var(--dp-text-on-dark-muted)'
}

function getPrimaryTextColor(dutyColor: string | null): string {
  if (!dutyColor) return 'var(--dp-text-primary)'
  return isLightColor(dutyColor) ? 'var(--dp-text-on-light)' : 'var(--dp-text-on-dark)'
}

function getIconTextColor(dutyColor: string | null): string {
  if (!dutyColor) return 'var(--dp-text-primary)'
  return isLightColor(dutyColor) ? 'var(--dp-text-on-light)' : 'var(--dp-text-on-dark)'
}

function getBorderColor(dutyColor: string | null): string {
  if (!dutyColor) return 'var(--dp-border-primary)'
  return isLightColor(dutyColor) ? 'var(--dp-border-on-light)' : 'var(--dp-border-on-dark)'
}

function getOtherDutyTextColor(dutyColor: string | null): string {
  return isLightColor(dutyColor) ? 'var(--dp-text-on-light)' : 'var(--dp-text-on-dark)'
}

function calcDDayForDay(day: CalendarDay) {
  if (!props.pinnedDDay) return null
  const [y, m, d] = props.pinnedDDay.date.split('-').map(Number) as [number, number, number]
  const targetDate = new Date(y, m - 1, d)
  const cellDate = new Date(day.year, day.month - 1, day.day)
  const diffDays = Math.floor((cellDate.getTime() - targetDate.getTime()) / (1000 * 60 * 60 * 24))
  if (diffDays === 0) return 'D-Day'
  return diffDays < 0 ? `D${diffDays}` : `D+${diffDays + 1}`
}

function getDDaysForDay(day: CalendarDay): LocalDDay[] {
  return props.dDays.filter((dday) => {
    const ddayDate = new Date(dday.date)
    return (
      ddayDate.getFullYear() === day.year &&
      ddayDate.getMonth() + 1 === day.month &&
      ddayDate.getDate() === day.day
    )
  })
}

function formatScheduleTime(schedule: Schedule) {
  const start = new Date(schedule.startDateTime)
  const end = new Date(schedule.endDateTime)
  const startHour = start.getHours().toString().padStart(2, '0')
  const startMin = start.getMinutes().toString().padStart(2, '0')
  const endHour = end.getHours().toString().padStart(2, '0')
  const endMin = end.getMinutes().toString().padStart(2, '0')

  const isStartMidnight = startHour === '00' && startMin === '00'
  const isEndMidnight = endHour === '00' && endMin === '00'
  const isSameDateTime = start.getTime() === end.getTime()

  const showStartTime = schedule.daysFromStart === 1 && !isStartMidnight
  const showEndTime = schedule.daysFromStart === schedule.totalDays &&
    !isEndMidnight &&
    !(schedule.totalDays === 1 && isSameDateTime)

  if (showStartTime && showEndTime) {
    return `(${startHour}:${startMin}~${endHour}:${endMin})`
  }
  if (showStartTime) {
    return `(${startHour}:${startMin})`
  }
  if (showEndTime) {
    return `(~${endHour}:${endMin})`
  }
  return ''
}

function hasScheduleDetails(schedule: Schedule) {
  return !!(schedule.description || schedule.attachments?.length)
}

function getVisibleTags(schedule: Schedule) {
  return (schedule.tags ?? []).filter((tag) => tag.id !== props.memberId)
}

function getDisplayTagMembers(schedule: Schedule) {
  const visibleTags: DisplayTagMember[] = getVisibleTags(schedule).map((tag) => ({
    key: `tag-${tag.id}`,
    id: tag.id,
    name: tag.name,
    hasProfilePhoto: tag.hasProfilePhoto,
    profilePhotoVersion: tag.profilePhotoVersion,
  }))

  const taggedByMember = schedule.taggedByMember
  if (schedule.isTagged && taggedByMember && !visibleTags.some((tag) => tag.id === taggedByMember.id)) {
    visibleTags.unshift({
      key: `tagged-by-${taggedByMember.id}`,
      id: taggedByMember.id,
      name: taggedByMember.name,
      hasProfilePhoto: taggedByMember.hasProfilePhoto,
      profilePhotoVersion: taggedByMember.profilePhotoVersion,
    })
  } else if (schedule.isTagged && !taggedByMember && (schedule.taggedBy || schedule.owner)) {
    visibleTags.unshift({
      key: `tagged-by-${schedule.id}`,
      name: schedule.taggedBy || schedule.owner || '',
    })
  }

  return visibleTags.filter((tag) => tag.name)
}

function getCalendarTagLabel(name: string) {
  const chars = Array.from(name)
  return chars.length > 3 ? `${chars.slice(0, 2).join('')}…` : name
}

function handleScheduleClick(schedule: Schedule, event: Event) {
  event.stopPropagation()
  emit('schedule-click', schedule)
}
</script>

<template>
  <CalendarGrid
    :days="days"
    :current-year="currentYear"
    :current-month="currentMonth"
    :holidays="displayHolidays"
    :get-duty-color="getDutyColorForDay"
    :highlight-day="highlightDay"
    :focused-day="focusedCalendarDay"
    :clickable="canEdit"
    @day-click="(day, index) => emit('day-click', day, index)"
  >
    <!-- D-Day indicator in header -->
    <template #day-header="{ day, index }">
      <span
        v-if="!batchEditMode && calcDDayForDay(day)"
        class="text-[9px] sm:text-xs"
        :style="{ color: getMutedTextColor(getDutyColorAt(index)) }"
      >
        {{ calcDDayForDay(day) }}
      </span>
    </template>

    <!-- Day content slot -->
    <template #day-content="{ day, index }">
      <!-- Batch Edit Mode: Duty Type Buttons (hidden on mobile, use top bar instead) -->
      <div v-if="batchEditMode && day.isCurrentMonth" class="mt-1 hidden sm:grid grid-cols-2 gap-0.5">
        <button
          v-for="dutyType in dutyTypes"
          :key="dutyType.id ?? 'off'"
          @click.stop="emit('batch-duty-change', day, dutyType.id)"
          class="text-[10px] sm:text-xs px-1 py-1 rounded border transition-all min-h-[22px] sm:min-h-[26px] cursor-pointer"
          :class="{
            'ring-2 ring-dp-text-primary font-bold shadow-sm':
              (duties[index]?.dutyType === dutyType.name) ||
              (!duties[index]?.dutyType && dutyType.id === null),
            'hover:opacity-80': true,
          }"
          :style="{
            backgroundColor: dutyType.color || 'var(--dp-duty-fallback)',
            color: isLightColor(dutyType.color) ? 'var(--dp-text-on-light)' : 'var(--dp-text-on-dark)',
            borderColor: dutyType.color || 'var(--dp-duty-fallback)',
          }"
        >
          <span class="sm:hidden">{{ dutyType.name.charAt(0) }}</span>
          <span class="hidden sm:inline">{{ dutyType.name.length > 4 ? dutyType.name.substring(0, 4) : dutyType.name }}</span>
        </button>
      </div>

      <div v-if="!batchEditMode" class="mt-0.5">
        <!-- Other duties -->
        <div v-if="otherDuties.length > 0" class="flex flex-wrap justify-center gap-1 mb-1">
          <div
            v-for="otherDuty in otherDuties"
            :key="otherDuty.memberId"
            class="text-[10px] sm:text-sm px-1.5 py-0.5 rounded-full border border-dp-overlay-light/50"
            :style="{
              backgroundColor: otherDuty.duties[index]?.dutyColor || 'var(--dp-duty-fallback)',
              color: getOtherDutyTextColor(otherDuty.duties[index]?.dutyColor || null),
            }"
          >
            {{ otherDuty.memberName }}<template v-if="otherDuty.duties[index]?.dutyType">:{{ otherDuty.duties[index].dutyType.slice(0, 4) }}</template>
          </div>
        </div>

        <!-- D-Days -->
        <div
          v-for="dday in getDDaysForDay(day)"
          :key="dday.id"
          class="text-[10px] sm:text-sm leading-snug px-0.5 break-words"
          :style="{ color: getPrimaryTextColor(getDutyColorAt(index)) }"
        ><CalendarCheck class="w-2.5 h-2.5 sm:w-3.5 sm:h-3.5 inline align-[-1px] sm:align-[-2px]" />{{ dday.title }}</div>

        <!-- Schedules -->
        <div
          v-for="schedule in schedulesByDays[index]?.slice(0, 3)"
          :key="schedule.id"
          class="text-[10px] sm:text-sm leading-snug px-0.5 border-t-2 border-dashed break-words"
          :class="{ 'cursor-pointer hover:underline': !canEdit && hasScheduleDetails(schedule) }"
          :style="{ color: getPrimaryTextColor(getDutyColorAt(index)), borderColor: getBorderColor(getDutyColorAt(index)) }"
          @click="!canEdit && hasScheduleDetails(schedule) ? handleScheduleClick(schedule, $event) : null"
        ><Lock v-if="schedule.visibility === 'PRIVATE'" class="w-2.5 h-2.5 sm:w-3.5 sm:h-3.5 inline align-[-1px] sm:align-[-2px]" :style="{ color: getMutedTextColor(getDutyColorAt(index)) }" />{{ schedule.contentWithoutTime || schedule.content }}{{ formatScheduleTime(schedule) }}<template v-if="schedule.totalDays > 1">({{ schedule.daysFromStart }}/{{ schedule.totalDays }})</template><MessageSquareText
          v-if="hasScheduleDetails(schedule)"
          class="w-2.5 h-2.5 sm:w-3 sm:h-3 inline align-[-1px] sm:align-[-2px] ml-0.5"
          :style="{ color: getIconTextColor(getDutyColorAt(index)) }"
        />
          <!-- Tags display -->
          <div
            v-if="getDisplayTagMembers(schedule).length"
            class="mt-px flex flex-wrap gap-px justify-end sm:mt-0.5 sm:gap-0.5"
          >
            <span
              v-for="tag in getDisplayTagMembers(schedule)"
              :key="tag.key"
              class="schedule-tag schedule-tag-with-avatar"
            >
              <ProfileAvatar
                :member-id="tag.id ?? null"
                :name="tag.name"
                :has-profile-photo="tag.hasProfilePhoto"
                :profile-photo-version="tag.profilePhotoVersion"
                size="xs"
                class="schedule-tag-avatar"
              />
              <span class="schedule-tag-label">{{ getCalendarTagLabel(tag.name) }}</span>
            </span>
          </div>
        </div>
        <div
          v-if="(schedulesByDays[index]?.length ?? 0) > 3"
          class="text-[10px] font-medium"
          :style="{ color: getMutedTextColor(getDutyColorAt(index)) }"
        >
          +{{ (schedulesByDays[index]?.length ?? 0) - 3 }}
        </div>

        <!-- Due Todos (마감일 할일) - 내 달력에서만 표시 -->
        <template v-if="isMyCalendar && todosDueByDays[index]?.length">
          <div
            v-for="todo in todosDueByDays[index].slice(0, 2)"
            :key="'due-' + todo.id"
            @click.stop="emit('todo-click', todo)"
            class="todo-due-bubble text-[10px] sm:text-xs leading-snug px-1 py-0.5 rounded cursor-pointer truncate mt-0.5"
            :class="todo.status === 'IN_PROGRESS' ? 'todo-due-progress' : 'todo-due-todo'"
          >
            <CheckSquare class="w-2.5 h-2.5 sm:w-3 sm:h-3 inline align-[-1px] sm:align-[-2px]" />
            {{ todo.title }}
          </div>
          <div
            v-if="todosDueByDays[index].length > 2"
            class="text-[10px] font-medium"
            :style="{ color: 'var(--dp-text-muted)' }"
          >
            +{{ todosDueByDays[index].length - 2 }}
          </div>
        </template>
      </div>
    </template>
  </CalendarGrid>
</template>

<style scoped>
.schedule-tag {
  padding: 0;
  border-radius: 9999px;
  box-shadow: none;
  background: var(--dp-bg-primary);
  border-color: var(--dp-border-primary);
  color: var(--dp-text-secondary);
}

.schedule-tag-with-avatar {
  display: inline-flex;
  width: fit-content;
  max-width: 100%;
  box-sizing: border-box;
  align-items: center;
  min-height: 1.05rem;
  gap: 0.08rem;
  padding-right: 0.18rem;
  padding-left: 0.08rem;
  font-size: 10px;
  line-height: 1.05;
}

.schedule-tag-label {
  display: block;
  width: 3em;
  min-width: 3em;
  overflow: hidden;
  text-overflow: ellipsis;
  text-align: right;
  white-space: nowrap;
  line-height: 1;
  letter-spacing: -0.03em;
}

:deep(.schedule-tag-avatar.profile-avatar) {
  border-width: 1px;
  width: 0.62rem;
  height: 0.62rem;
}

@media (min-width: 640px) {
  .schedule-tag-with-avatar {
    min-height: 1.5rem;
    gap: 0.16rem;
    padding-right: 0.34rem;
    padding-left: 0.12rem;
    font-size: 14px;
  }

  .schedule-tag-label {
    width: 3em;
    min-width: 3em;
  }

  :deep(.schedule-tag-avatar.profile-avatar) {
    width: 1rem;
    height: 1rem;
  }
}
</style>
