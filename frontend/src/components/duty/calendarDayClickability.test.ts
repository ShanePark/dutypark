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
  it('preserves duty colours while using inset today and search borders with hover corner markers', () => {
    expect(calendarGrid).not.toContain('hover:brightness-95')
    expect(calendarGrid).not.toContain('dark:hover:brightness-110')
    expect(calendarGrid).not.toContain('hover:outline-2')
    expect(calendarGrid).not.toContain('hover:-outline-offset-4')
    expect(calendarGrid).toContain('calendar-day-hoverable')
    expect(calendarGrid).not.toContain('calendar-day-today-dot')
    expect(calendarGrid).toContain('calendar-day-today-bar')
    expect(calendarGrid).toContain('calendar-day-today-border')
    expect(calendarGrid).toMatch(
      /v-if="!focusedDay && isHighlighted\(day\)"[\s\S]*class="calendar-day-highlight-border"/
    )
    expect(calendarGrid).toContain(":aria-current=\"isToday(day) ? 'date' : undefined\"")
    expect(calendarGrid).not.toContain("'ring-2 ring-dp-danger ring-inset'")
    expect(calendarGrid).toContain("'ring-2 ring-dp-accent ring-inset': !focusedDay && isSelected(day) && !isHighlighted(day)")
    expect(calendarGrid).toContain('@media (hover: hover) and (pointer: fine)')
    expect(calendarGrid).toContain('.calendar-day-hoverable:hover::before')
    expect(calendarGrid).toContain('.calendar-day-hoverable:hover::after')
    expect(calendarGrid).toContain('width: 70%')
    expect(calendarGrid).toContain('height: 4px')
    expect(calendarGrid).toContain('background: var(--dp-danger)')
    expect(calendarGrid).toContain('border: 1px solid var(--dp-danger)')
    expect(calendarGrid).toContain('border: 1px solid var(--dp-warning)')
    expect(calendarGrid).toContain('inset: 0')
    expect(calendarGrid).toContain('left: 15%')
    expect(calendarGrid).toContain('top: 0')
    expect(calendarGrid).toContain('left: 0')
    expect(calendarGrid).toContain('right: 0')
    expect(calendarGrid).toContain('bottom: 1px')
    expect(calendarGrid).toContain('border-top: 2px solid var(--dp-accent)')
    expect(calendarGrid).toContain('border-left: 2px solid var(--dp-accent)')
    expect(calendarGrid).toContain('border-right: 2px solid var(--dp-accent)')
    expect(calendarGrid).toContain('border-bottom: 2px solid var(--dp-accent)')
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
