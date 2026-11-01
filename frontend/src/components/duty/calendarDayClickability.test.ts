import { describe, expect, it, vi } from 'vitest'
import { defineComponent, h } from 'vue'
import { createHostWrapper, findHostNode, mountHost, triggerHost } from '@/test/hostRenderer'
import calendarGrid from '@/components/common/CalendarGrid.vue?raw'
import dayDetailModal from '@/components/duty/DayDetailModal.vue?raw'
vi.mock('@/i18n', () => ({ getCurrentLocale: () => 'ko' }))
vi.mock('vue-i18n', () => ({ useI18n: () => ({ locale: { value: 'ko' } }) }))
vi.mock('@/components/common/CalendarGrid.vue', () => ({
  default: defineComponent({
    props: ['days', 'isDayClickable'],
    emits: ['day-click'],
    setup: (props, { emit }) => () => h('button', {
      'data-test': 'calendar-day',
      disabled: !props.isDayClickable(props.days[0], 0),
      onClick: () => {
        if (props.isDayClickable(props.days[0], 0)) emit('day-click', props.days[0], 0)
      },
    }),
  }),
}))
import DutyCalendarContent from '@/components/duty/DutyCalendarContent.vue'

describe('calendar cell clickability', () => {
  it('marks today, search results and hover without tinting the duty colour', () => {
    expect(calendarGrid).not.toContain('hover:brightness-95')
    expect(calendarGrid).not.toContain('opacity: isCurrentMonth(day) ? 1 : 0.5')
    expect(calendarGrid).toContain('calendar-day-hoverable')
    expect(calendarGrid).toContain('calendar-day-today-border')
    expect(calendarGrid).toContain('calendar-day-today-circle')
    expect(calendarGrid).toMatch(
      /v-if="!focusedDay && isHighlighted\(day\)"[\s\S]*class="calendar-day-highlight-border"/
    )
    expect(calendarGrid).toContain(":aria-current=\"isToday(day) ? 'date' : undefined\"")
    expect(calendarGrid).toContain("'ring-2 ring-dp-accent ring-inset': !focusedDay && isSelected(day) && !isHighlighted(day)")
    expect(calendarGrid).toContain('@media (hover: hover) and (pointer: fine)')
    expect(calendarGrid).toContain('.calendar-day-hoverable:hover::before')
    expect(calendarGrid).toContain('border: 2px solid var(--dp-warning)')
  })

  it('asks the caller about each day, for the cursor and for the click alike', () => {
    expect(calendarGrid).toContain('isDayClickable?: (day: CalendarDay, index: number) => boolean')
    expect(calendarGrid).toContain('isDayClickable: () => true')
    expect(calendarGrid).toMatch(
      /function handleDayClick\(day: CalendarDay, index: number\) \{\s*if \(!props\.isDayClickable\(day, index\)\) return\s*emit\('day-click', day, index\)/
    )
    expect(calendarGrid).toContain("clickable && isDayClickable(day, getSourceIndex(idx)) ? 'cursor-pointer")
  })

  it.each([
    { loaded: true, canEdit: false, batch: false, schedules: false, clickable: false },
    { loaded: true, canEdit: false, batch: false, schedules: true, clickable: true },
    { loaded: true, canEdit: true, batch: false, schedules: false, clickable: true },
    { loaded: true, canEdit: true, batch: true, schedules: false, clickable: true },
    { loaded: false, canEdit: true, batch: false, schedules: false, clickable: false },
    { loaded: false, canEdit: true, batch: true, schedules: true, clickable: false },
  ])('guards calendar day clicks for $loaded loaded, $canEdit editing, $batch batch, $schedules schedules', (testCase) => {
    const clicked = vi.fn()
    const day = { year: 2026, month: 10, day: 2, isCurrentMonth: true }
    const props = {
      days: [day], currentYear: 2026, currentMonth: 10, calendarDataYear: 2026, calendarDataMonth: 10,
      isCalendarMonthLoaded: testCase.loaded, holidays: [], getDutyColorForDay: () => null,
      highlightDay: null, batchEditMode: testCase.batch, focusedDay: null, canEdit: testCase.canEdit,
      duties: [], dutyTypes: [], otherDuties: [], dDays: [], pinnedDDay: null, todosDueByDays: [],
      isMyCalendar: true, memberId: 1,
      schedulesByDays: testCase.schedules ? [[{ id: 'test', content: 'Schedule' }]] : [],
      'onDay-click': clicked,
    } as unknown as InstanceType<typeof DutyCalendarContent>['$props']
    const mounted = mountHost(createHostWrapper(() => h(DutyCalendarContent, props)))
    try {
      const cell = findHostNode(mounted.root, node => node.props['data-test'] === 'calendar-day')!
      expect(cell.props.disabled).toBe(!testCase.clickable)
      triggerHost(cell, 'onClick')
      expect(clicked).toHaveBeenCalledTimes(testCase.clickable ? 1 : 0)
      if (testCase.clickable) expect(clicked).toHaveBeenCalledWith(day, 0)
    } finally {
      mounted.app.unmount()
    }
  })

  // The rule above only holds while the modal has nothing but schedules to show a
  // reader who cannot edit: the duty is already told by the colour of the cell.
  it('keeps the duty out of the modal for a reader who cannot change it', () => {
    expect(dayDetailModal).not.toContain('v-else-if="duty && !canEdit"')
  })
})
