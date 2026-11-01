<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { Flag, MessageSquareText, CheckSquare } from '@lucide/vue'
import { isLightColor } from '@/utils/color'
import { dutyTypeLabel } from '@/utils/dutyAbbreviation'
import { parseDateOnly } from '@/utils/date'
import CalendarGrid from '@/components/common/CalendarGrid.vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import VisibilityHintIcon from '@/components/common/VisibilityHintIcon.vue'
import type { HolidayDto } from '@/types'
import type { CalendarDay, DutyType, Schedule, OtherDuty, LocalDDay, DutyDay, TodoDueItem } from '@/views/duty/dutyViewTypes'
import { buildDisplayTagMembers } from '@/utils/tagMembers'
import { canOpenCalendarDay } from '@/utils/calendarDayOpening'
import { orderForCalendarCell } from '@/utils/calendarScheduleOrder'
import { useCalendarMonthSwipe } from '@/composables/useCalendarMonthSwipe'

const props = defineProps<{
  days: CalendarDay[]
  currentYear: number
  currentMonth: number
  calendarDataYear: number
  calendarDataMonth: number
  isCalendarMonthLoaded: boolean
  isMonthLoading?: boolean
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
  (e: 'todo-click', todo: TodoDueItem): void
  (e: 'dday-click', dday: LocalDDay): void
  (e: 'prev-month'): void
  (e: 'next-month'): void
}>()

// Swiping the grid sideways is the quick way through the months; the header
// chevrons stay for taps and for keyboard and assistive-technology users.
const swipeContainer = ref<HTMLElement | null>(null)
const calendarGridTrack = ref<HTMLElement | null>(null)
const calendarHeight = ref<number | null>(null)
let calendarTrackResizeObserver: ResizeObserver | null = null

function syncCalendarHeight() {
  const track = calendarGridTrack.value
  if (!track || props.isMonthLoading) return

  const height = track.getBoundingClientRect().height
  if (height > 0) calendarHeight.value = height
}

onMounted(() => {
  if (!calendarGridTrack.value || typeof ResizeObserver === 'undefined') return

  calendarTrackResizeObserver = new ResizeObserver(syncCalendarHeight)
  calendarTrackResizeObserver.observe(calendarGridTrack.value)
})

// Calendar rows and their contents arrive separately. Keep the old footprint
// until the complete month is ready, then move the D-Day list once.
watch(() => props.isMonthLoading, loading => {
  if (!loading) syncCalendarHeight()
}, { flush: 'post' })

onUnmounted(() => {
  calendarTrackResizeObserver?.disconnect()
  calendarTrackResizeObserver = null
})

const monthSwipe = useCalendarMonthSwipe({
  onPrevMonth: () => emit('prev-month'),
  onNextMonth: () => emit('next-month'),
  getWidth: () => swipeContainer.value?.clientWidth ?? 0,
})

const focusedCalendarDay = computed(() => {
  if (!props.batchEditMode || !props.focusedDay || !props.isCalendarMonthLoaded) return null
  return { year: props.currentYear, month: props.currentMonth, day: props.focusedDay }
})

const displayHolidays = computed(() => (props.batchEditMode ? [] : props.holidays))
const MOBILE_VISIBLE_CALENDAR_TAGS = 3

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

const dDaysByDate = computed(() => {
  const byDate = new Map<string, LocalDDay[]>()
  for (const dday of props.dDays) {
    const ddayDate = parseDateOnly(dday.date)
    const key = `${ddayDate.getFullYear()}-${ddayDate.getMonth() + 1}-${ddayDate.getDate()}`
    const entries = byDate.get(key)
    if (entries) entries.push(dday)
    else byDate.set(key, [dday])
  }
  return byDate
})

function getDDaysForDay(day: CalendarDay): LocalDDay[] {
  return dDaysByDate.value.get(`${day.year}-${day.month}-${day.day}`) ?? []
}

function isDayClickable(_day: CalendarDay, index: number): boolean {
  if (!props.isCalendarMonthLoaded) return false
  if (props.batchEditMode) return true
  return canOpenCalendarDay(props.canEdit, props.schedulesByDays[index]?.length ?? 0)
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
    return `${startHour}:${startMin}~${endHour}:${endMin}`
  }
  if (showStartTime) {
    return `${startHour}:${startMin}`
  }
  if (showEndTime) {
    return `~${endHour}:${endMin}`
  }
  return ''
}

const cellSchedulesByDays = computed(() => props.schedulesByDays.map(orderForCalendarCell))

function hasScheduleDetails(schedule: Schedule) {
  return !!(schedule.description || schedule.attachments?.length)
}

const displayTagMembersBySchedule = computed(() => {
  const bySchedule = new Map<Schedule, ReturnType<typeof buildDisplayTagMembers>>()
  for (let index = 0; index < props.days.length; index++) {
    // Keep identity-based keys because separate daily occurrences may share an id
    // but carry different data.
    for (const schedule of props.schedulesByDays[index] ?? []) {
      if (bySchedule.has(schedule)) continue
      bySchedule.set(schedule, buildDisplayTagMembers({
        itemKey: schedule.id,
        isTagged: schedule.isTagged,
        owner: schedule.owner,
        taggedBy: schedule.taggedBy,
        taggedByMember: schedule.taggedByMember,
        tags: schedule.tags,
        excludeMemberId: props.memberId,
      }))
    }
  }
  return bySchedule
})

function getDisplayTagMembers(schedule: Schedule) {
  return displayTagMembersBySchedule.value.get(schedule) ?? []
}

function getCalendarTagLabel(name: string) {
  const chars = Array.from(name)
  return chars.length > 3 ? `${chars.slice(0, 2).join('')}…` : name
}

const MOBILE_CALENDAR_TODO_TITLE_LIMIT = 6

function truncateMobileCalendarText(text: string, limit: number) {
  const chars = Array.from(text)
  return chars.length > limit
    ? `${chars.slice(0, limit).join('')}…`
    : text
}

function getMobileCalendarTodoTitle(todo: TodoDueItem) {
  return truncateMobileCalendarText(todo.title, MOBILE_CALENDAR_TODO_TITLE_LIMIT)
}

function getMobileCalendarTagMembers(schedule: Schedule) {
  return getDisplayTagMembers(schedule).slice(0, MOBILE_VISIBLE_CALENDAR_TAGS)
}

function getHiddenMobileCalendarTagCount(schedule: Schedule) {
  return Math.max(getDisplayTagMembers(schedule).length - MOBILE_VISIBLE_CALENDAR_TAGS, 0)
}

function shouldShowPrivateVisibility(schedule: Schedule) {
  return props.isMyCalendar && schedule.isMine && schedule.visibility === 'PRIVATE'
}

</script>

<template>
  <div
    ref="swipeContainer"
    class="calendar-month-swipe"
    @touchstart.passive="monthSwipe.handleTouchStart"
    @touchmove.passive="monthSwipe.handleTouchMove"
    @touchend="monthSwipe.handleTouchEnd"
    @touchcancel="monthSwipe.handleTouchCancel"
    @pointerdown.capture="monthSwipe.dragClickGuard.handlePointerDown"
    @click.capture="monthSwipe.dragClickGuard.handleClick"
  >
    <div class="calendar-month-swipe__track" :style="monthSwipe.trackStyle.value">
      <div
        class="calendar-month-swipe__frame"
        :style="calendarHeight === null ? undefined : { height: `${calendarHeight}px` }"
        :class="{ 'calendar-month-swipe__frame--loading': isMonthLoading }"
      >
        <div ref="calendarGridTrack" class="calendar-month-swipe__grid">
      <CalendarGrid
        :days="days"
        :current-year="calendarDataYear"
        :current-month="calendarDataMonth"
        :holidays="displayHolidays"
        :get-duty-color="getDutyColorForDay"
        :highlight-day="highlightDay"
        :focused-day="focusedCalendarDay"
        :clickable="isCalendarMonthLoaded && (!batchEditMode || canEdit)"
        :is-day-clickable="isDayClickable"
        @day-click="(day, index) => emit('day-click', day, index)"
      >
        <template #day-header="{ day }">
          <span
            v-if="!batchEditMode && calcDDayForDay(day)"
            class="calendar-pin-label"
            :class="{ 'calendar-pin-label--zero': calcDDayForDay(day) === 'D-Day' }"
          >
            {{ calcDDayForDay(day) }}
          </span>
        </template>

        <template #day-content="{ day, index }">
          <div v-if="batchEditMode && day.isCurrentMonth" class="mt-1 hidden sm:grid grid-cols-2 gap-0.5">
            <button
              v-for="dutyType in dutyTypes"
              :key="dutyType.id ?? 'off'"
              :disabled="!isCalendarMonthLoaded"
              @click.stop="emit('batch-duty-change', day, dutyType.id)"
              :title="dutyType.name"
              :aria-label="dutyType.name"
              class="text-[10px] sm:text-xs px-1 py-1 rounded border transition-all min-h-[22px] sm:min-h-[26px] cursor-pointer"
              :class="{
                'ring-2 ring-(--calendar-ink) font-bold shadow-sm':
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
              <span class="break-all">{{ dutyTypeLabel(dutyType, isMyCalendar) }}</span>
            </button>
          </div>

          <div v-if="!batchEditMode" class="calendar-items">
            <div v-if="otherDuties.length > 0" class="mb-1 grid gap-0.5 sm:flex sm:flex-wrap sm:justify-center sm:gap-1">
              <div
                v-for="otherDuty in otherDuties"
                :key="otherDuty.memberId"
                class="other-duty-chip w-full max-w-full border border-dp-overlay-light/50 sm:w-auto"
                :title="`${otherDuty.memberName}: ${otherDuty.duties[index]?.dutyType ?? ''}`"
                :style="{
                  backgroundColor: otherDuty.duties[index]?.dutyColor || 'var(--dp-duty-fallback)',
                  color: getOtherDutyTextColor(otherDuty.duties[index]?.dutyColor || null),
                }"
              >
                <ProfileAvatar
                  :member-id="otherDuty.memberId"
                  :name="otherDuty.memberName"
                  :has-profile-photo="otherDuty.hasProfilePhoto"
                  :profile-photo-version="otherDuty.profilePhotoVersion"
                  size="xs"
                  class="other-duty-chip__avatar"
                />
                <span class="other-duty-chip__label">
                  {{ otherDuty.duties[index]?.dutyType ?? '' }}
                </span>
              </div>
            </div>

            <button
              v-for="dday in getDDaysForDay(day)"
              :key="dday.id"
              type="button"
              :disabled="!isCalendarMonthLoaded"
              :aria-label="dday.title"
              :title="dday.title"
              @click.stop="emit('dday-click', dday)"
              class="calendar-item calendar-dday-marker"
            >
              <span class="calendar-item__line"><Flag class="calendar-dday-marker__icon" aria-hidden="true" />{{ dday.title }}</span>
            </button>

            <div
              v-for="schedule in cellSchedulesByDays[index]"
              :key="schedule.id"
              class="calendar-item"
              :data-calendar-span-key="schedule.totalDays > 1 ? JSON.stringify([schedule.id, schedule.startDateTime]) : undefined"
              :data-calendar-span-part="schedule.daysFromStart"
              :class="schedule.totalDays > 1 ? ['calendar-item--span', {
                'calendar-item--span-start': schedule.daysFromStart === 1,
                'calendar-item--span-end': schedule.daysFromStart === schedule.totalDays,
              }] : null"
            >
              <div class="calendar-item__line">
                <span class="calendar-item__text"><VisibilityHintIcon
                  v-if="shouldShowPrivateVisibility(schedule)"
                  :visibility="schedule.visibility"
                  size="xs"
                  class="calendar-visibility-hint mr-0.5 inline-flex align-[-2px] sm:align-[-3px]"
                /><span v-if="formatScheduleTime(schedule)" class="calendar-item__time">{{ formatScheduleTime(schedule) }}</span>{{ schedule.contentWithoutTime || schedule.content }}<MessageSquareText
                  v-if="hasScheduleDetails(schedule)"
                  class="calendar-schedule-detail-icon"
                /><span v-if="schedule.totalDays > 1" class="calendar-item__part"> ({{ schedule.daysFromStart }}/{{ schedule.totalDays }})</span></span>
              </div>
              <div
                v-if="getDisplayTagMembers(schedule).length"
                class="calendar-item__tags mt-px flex flex-wrap justify-end gap-px sm:hidden"
              >
                <span
                  v-for="tag in getMobileCalendarTagMembers(schedule)"
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
                <span
                  v-if="getHiddenMobileCalendarTagCount(schedule) > 0"
                  class="schedule-tag schedule-tag-count"
                >
                  +{{ getHiddenMobileCalendarTagCount(schedule) }}
                </span>
              </div>
              <div
                v-if="getDisplayTagMembers(schedule).length"
                class="mt-px hidden flex-wrap justify-end gap-px sm:mt-0.5 sm:flex sm:gap-0.5"
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

            <template v-if="isMyCalendar && todosDueByDays[index]?.length">
              <button
                v-for="todo in todosDueByDays[index]"
                :key="'due-' + todo.id"
                type="button"
                :disabled="!isCalendarMonthLoaded"
                :aria-label="todo.title"
                :title="todo.title"
                @click.stop="emit('todo-click', todo)"
                class="calendar-action-bubble mt-0.5 text-[10px] sm:text-xs"
                :class="todo.status === 'IN_PROGRESS' ? 'calendar-action-bubble--progress' : 'calendar-action-bubble--todo'"
              >
                <span class="calendar-action-bubble__text">
                  <CheckSquare class="calendar-action-bubble__icon" />
                  <span class="sm:hidden">{{ getMobileCalendarTodoTitle(todo) }}</span>
                  <span class="hidden sm:inline">{{ todo.title }}</span>
                </span>
              </button>
            </template>
          </div>
        </template>
      </CalendarGrid>
        </div>
      </div>
      <slot />
    </div>
  </div>
</template>

<style scoped>
.calendar-month-swipe {
  /* The grid slides a full width out and back in, and only the horizontal overflow
     may be hidden: day bubbles and tooltips still need to spill downwards. */
  overflow-x: clip;
  /* Leave room for D-Day card hover scaling and focus rings at either edge. */
  padding-inline: 8px;
  margin-inline: -8px;
  /* The browser keeps the vertical scroll; sideways is this component's gesture. */
  touch-action: pan-y;
}

.calendar-month-swipe__frame {
  transition: height 220ms ease-out;
}

.calendar-month-swipe__frame--loading {
  overflow: clip;
}

.calendar-month-swipe__grid {
  display: flow-root;
}

@media (prefers-reduced-motion: reduce) {
  .calendar-month-swipe__frame {
    transition: none;
  }
}

.calendar-pin-label {
  flex: none;
  color: var(--calendar-ink-muted);
  font-size: 8px;
  letter-spacing: -0.03em;
  font-variant-numeric: tabular-nums;
}

.calendar-pin-label--zero {
  color: var(--calendar-ink);
  font-weight: 700;
}

.calendar-schedule-detail-icon {
  display: inline;
  width: 0.625rem;
  height: 0.625rem;
  margin-left: 0.125rem;
  vertical-align: -1px;
}

.calendar-item.calendar-dday-marker {
  display: block;
  width: 100%;
  border: 0;
  background: none;
  color: var(--calendar-ink);
  font: inherit;
  font-size: 10px;
  font-weight: 700;
  text-align: left;
  appearance: none;
  cursor: pointer;
}

.calendar-item + .calendar-item.calendar-dday-marker {
  border-top: 1px solid var(--calendar-rule);
}

.calendar-item.calendar-dday-marker::before {
  content: none;
}

.calendar-dday-marker__icon {
  display: inline;
  width: 8px;
  height: 8px;
  margin-right: 1px;
  vertical-align: -0.5px;
  fill: currentColor;
}

.calendar-dday-marker:disabled {
  cursor: default;
}

@media (hover: hover) and (pointer: fine) {
  .calendar-dday-marker:not(:disabled):hover {
    text-decoration: underline;
    text-underline-offset: 2px;
  }
}

.calendar-dday-marker:focus-visible,
.calendar-action-bubble:focus-visible {
  outline: 2px solid var(--dp-accent);
  outline-offset: 1px;
  border-radius: 3px;
}

@media (min-width: 640px) {
  .calendar-pin-label {
    font-size: 10.5px;
    letter-spacing: -0.01em;
  }

  .calendar-schedule-detail-icon {
    width: 0.75rem;
    height: 0.75rem;
    vertical-align: -2px;
  }

  .calendar-item.calendar-dday-marker {
    padding-left: 0;
    font-size: 12px;
  }

  .calendar-item + .calendar-item.calendar-dday-marker {
    border-top: 0;
  }

  .calendar-dday-marker__icon {
    width: 11px;
    height: 11px;
    margin-right: 3px;
    vertical-align: -1px;
  }
}

.calendar-action-bubble {
  display: block;
  width: 100%;
  min-height: 1.35rem;
  padding: 0.14rem 0.35rem;
  border: 1px solid transparent;
  border-radius: 4px;
  box-sizing: border-box;
  appearance: none;
  line-height: 1.2;
  text-align: left;
  transition: transform 0.15s ease, box-shadow 0.15s ease, background-color 0.15s ease, border-color 0.15s ease;
  cursor: pointer;
}

.calendar-action-bubble:hover {
  transform: translateY(-1px);
  box-shadow: var(--dp-shadow-sm);
}

.calendar-action-bubble__icon {
  display: inline-block;
  width: 0.7rem;
  height: 0.7rem;
  margin-right: 0.18rem;
  vertical-align: -0.08rem;
  flex-shrink: 0;
}

.calendar-action-bubble__text {
  display: block;
  min-width: 0;
  white-space: normal;
  overflow-wrap: anywhere;
}

.calendar-action-bubble--todo {
  background-color: var(--dp-accent-bg);
  border-color: var(--dp-accent-border);
  color: var(--dp-accent);
}

.calendar-action-bubble--todo:hover {
  background-color: var(--dp-accent-bg-hover);
}

.calendar-action-bubble--progress {
  background-color: var(--dp-warning-bg);
  border-color: var(--dp-warning-border);
  color: var(--dp-warning);
}

.calendar-action-bubble--progress:hover {
  background-color: color-mix(in srgb, var(--dp-warning-bg) 78%, var(--dp-warning-border));
}

@media (min-width: 640px) {
  .calendar-action-bubble {
    min-height: 1.5rem;
    padding: 0.16rem 0.42rem;
  }

  .calendar-action-bubble__icon {
    width: 0.8rem;
    height: 0.8rem;
    margin-right: 0.22rem;
    vertical-align: -0.12rem;
  }
}

.other-duty-chip {
  display: inline-flex;
  align-items: center;
  min-width: 0;
  min-height: 1.05rem;
  gap: 0.18rem;
  padding: 0.08rem 0.22rem 0.08rem 0.12rem;
  border-radius: 9999px;
  box-sizing: border-box;
  font-size: 10px;
  line-height: 1.1;
}

.other-duty-chip__label {
  flex: 1 1 auto;
  min-width: 0;
  white-space: normal;
  overflow-wrap: anywhere;
  line-height: 1.15;
}

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
  min-width: 0;
  min-height: 1.05rem;
  gap: 0.04rem;
  padding-right: 0.12rem;
  padding-left: 0.04rem;
  font-size: 10px;
  line-height: 1.05;
}

.schedule-tag-label {
  display: block;
  min-width: 0;
  max-width: 3em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  line-height: 1;
  letter-spacing: -0.05em;
}

.schedule-tag-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 1.05rem;
  padding: 0 0.28rem;
  font-size: 9px;
  font-weight: 600;
}

:deep(.other-duty-chip__avatar.profile-avatar) {
  box-sizing: border-box;
  border-width: 1px;
  width: 0.62rem;
  height: 0.62rem;
}

:deep(.schedule-tag-avatar.profile-avatar) {
  box-sizing: border-box;
  border-width: 1px;
  width: 0.58rem;
  height: 0.58rem;
}

/* Duty fills are identical in light and dark, so everything drawn on them uses
   fixed colours; theme tokens above apply only to empty (no-duty) tiles.
   The ancestor tile class comes from CalendarGrid, hence the unscoped prefix. */
.calendar-day--on-light .schedule-tag,
.calendar-day--on-dark .schedule-tag {
  background: rgba(255, 255, 255, 0.72);
  border-color: rgba(31, 41, 55, 0.14);
  color: #374151;
}

.calendar-day--on-light .calendar-items :deep(.schedule-tag-avatar.profile-avatar),
.calendar-day--on-dark .calendar-items :deep(.schedule-tag-avatar.profile-avatar),
.calendar-day--on-light .calendar-items :deep(.other-duty-chip__avatar.profile-avatar),
.calendar-day--on-dark .calendar-items :deep(.other-duty-chip__avatar.profile-avatar) {
  border-color: rgba(255, 255, 255, 0.9);
  background-color: #e5e7eb;
}

.calendar-day--on-light .calendar-items :deep(.calendar-visibility-hint .visibility-hint-button--xs),
.calendar-day--on-dark .calendar-items :deep(.calendar-visibility-hint .visibility-hint-button--xs) {
  border-color: color-mix(in srgb, var(--visibility-hint-accent) 30%, #ffffff);
  background-color: color-mix(in srgb, var(--visibility-hint-accent) 10%, #ffffff);
}

.calendar-day--on-light .calendar-items :deep(.calendar-visibility-hint .visibility-hint-button--xs:hover),
.calendar-day--on-dark .calendar-items :deep(.calendar-visibility-hint .visibility-hint-button--xs:hover) {
  background-color: color-mix(in srgb, var(--visibility-hint-accent) 20%, #ffffff);
}

.calendar-day--on-light .calendar-action-bubble--todo,
.calendar-day--on-dark .calendar-action-bubble--todo {
  background-color: #eff6ff;
  border-color: #93c5fd;
  color: #1d4ed8;
}

.calendar-day--on-light .calendar-action-bubble--progress,
.calendar-day--on-dark .calendar-action-bubble--progress {
  background-color: #fffbeb;
  border-color: #fcd34d;
  color: #b45309;
}

.calendar-day--on-light .calendar-action-bubble:hover,
.calendar-day--on-dark .calendar-action-bubble:hover {
  box-shadow: 0 1px 2px rgba(17, 24, 39, 0.12);
}

.calendar-day--on-light .calendar-action-bubble--todo:hover,
.calendar-day--on-dark .calendar-action-bubble--todo:hover {
  background-color: #dbeafe;
}

.calendar-day--on-light .calendar-action-bubble--progress:hover,
.calendar-day--on-dark .calendar-action-bubble--progress:hover {
  background-color: #fef3c7;
}

@media (min-width: 640px) {
  .other-duty-chip {
    gap: 0.28rem;
    min-height: 1.5rem;
    padding: 0.15rem 0.42rem 0.15rem 0.18rem;
    font-size: 14px;
  }

  .other-duty-chip__label {
    max-width: 4.5rem;
  }

  .schedule-tag-with-avatar {
    min-height: 1.5rem;
    gap: 0.1rem;
    padding-right: 0.28rem;
    padding-left: 0.1rem;
    font-size: 14px;
  }

  .schedule-tag-label {
    max-width: 3em;
  }

  .schedule-tag-count {
    min-height: 1.5rem;
    padding: 0 0.4rem;
    font-size: 12px;
  }

  :deep(.other-duty-chip__avatar.profile-avatar) {
    width: 0.94rem;
    height: 0.94rem;
  }

  :deep(.schedule-tag-avatar.profile-avatar) {
    width: 0.94rem;
    height: 0.94rem;
  }
}
</style>
