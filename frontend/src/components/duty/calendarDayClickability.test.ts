import { describe, expect, it } from 'vitest'
import calendarGrid from '@/components/common/CalendarGrid.vue?raw'
import dayDetailModal from '@/components/duty/DayDetailModal.vue?raw'
import dutyCalendarContent from '@/components/duty/DutyCalendarContent.vue?raw'

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
    expect(calendarGrid).toContain("clickable && isDayClickable(day, idx) ? 'cursor-pointer")
  })

  it('shuts a read-only day holding no schedule and leaves batch edit untouched', () => {
    expect(dutyCalendarContent).toContain(
      "import { canOpenCalendarDay } from '@/utils/calendarDayOpening'"
    )
    expect(dutyCalendarContent).toMatch(
      /function isDayClickable\(_day: CalendarDay, index: number\): boolean \{\s*if \(props\.batchEditMode\) return true\s*return canOpenCalendarDay\(props\.canEdit, props\.schedulesByDays\[index\]\?\.length \?\? 0\)/
    )
    expect(dutyCalendarContent).toContain(':is-day-clickable="isDayClickable"')
  })

  // The rule above only holds while the modal has nothing but schedules to show a
  // reader who cannot edit: the duty is already told by the colour of the cell.
  it('keeps the duty out of the modal for a reader who cannot change it', () => {
    expect(dayDetailModal).not.toContain('v-else-if="duty && !canEdit"')
  })
})
