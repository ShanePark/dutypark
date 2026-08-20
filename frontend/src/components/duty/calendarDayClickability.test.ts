import { describe, expect, it } from 'vitest'
import calendarGrid from '@/components/common/CalendarGrid.vue?raw'
import dayDetailModal from '@/components/duty/DayDetailModal.vue?raw'
import dutyCalendarContent from '@/components/duty/DutyCalendarContent.vue?raw'

describe('calendar cell clickability', () => {
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
