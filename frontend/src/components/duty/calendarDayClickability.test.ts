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
    expect(calendarGrid).not.toContain('.calendar-day--today .calendar-day-top {')
    expect(calendarGrid).toMatch(/v-if="isToday\(day\)"\s*class="calendar-day-lift"/)
    expect(calendarGrid).not.toContain('calendar-day-today-label')
    expect(calendarGrid).toMatch(
      /v-if="hasTodaySelectionBorder\(day\)"[\s\S]*class="calendar-day-selection-border"/
    )
    expect(calendarGrid).toMatch(
      /v-if="hasSpotlight"\s*:key="flashKey"\s*class="calendar-grid-spotlight"[\s\S]*@animationstart="startSpotlight"[\s\S]*@animationend="endFlash"/
    )
    expect(calendarGrid).not.toContain('calendar-day-highlight-flash')
    expect(calendarGrid).toContain(":aria-current=\"isToday(day) ? 'date' : undefined\"")
    expect(calendarGrid).toContain("'ring-2 ring-dp-accent ring-inset': !focusedDay && isSelected(day) && !isHighlighted(day) && !isToday(day)")
    expect(calendarGrid).toContain('@media (hover: hover) and (pointer: fine)')
    expect(calendarGrid).toContain('.calendar-day-hoverable:hover::before')
    expect(calendarGrid).not.toContain('--dp-warning')
  })

  // Same timing as iOS: 0.25s ease-in to 40% black, hold until 1.05s, then a
  // 0.9s ease-out, 1.95s in all. Dimming is not motion, so reduced motion keeps it.
  it('dims the grid to 40% black and back over 1.95s, resting invisible', () => {
    const overlayRule = calendarGrid.match(/\.calendar-grid-spotlight \{[^}]*\}/)?.[0] ?? ''
    expect(overlayRule).toContain('position: absolute;')
    expect(overlayRule).toContain('inset: 0;')
    expect(overlayRule).toContain('background: rgb(0 0 0 / 40%);')
    expect(overlayRule).toContain('opacity: 0;')
    expect(overlayRule).toContain('pointer-events: none;')
    expect(overlayRule).toContain('animation: calendar-grid-spotlight 1.95s ease-in;')
    expect(overlayRule).not.toMatch(/forwards|infinite|filter|blur|scale/)
    const keyframes = calendarGrid.match(/@keyframes calendar-grid-spotlight \{([\s\S]*?)\n\}/)?.[1] ?? ''
    expect(keyframes).toMatch(/0% \{ opacity: 0; \}\s*12\.8205% \{ opacity: 1; \}\s*53\.8462% \{ opacity: 1; animation-timing-function: ease-out; \}\s*100% \{ opacity: 0; \}/)
    // The overlay dims the multi-day bands (z-index 2) too; the lit day is a hole
    // cut in it, not a raised tile, so a band crossing that day stays visible there.
    expect(calendarGrid).toMatch(/\.calendar-grid-spotlight \{[^}]*z-index: 3;/)
    expect(calendarGrid).not.toMatch(/\.calendar-day--highlighted \{[^}]*z-index/)
    expect(calendarGrid).not.toContain('prefers-reduced-motion')
    expect(calendarGrid).not.toContain('backdrop-filter')
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
