import { describe, expect, it } from 'vitest'
import scheduleList from './ScheduleList.vue?raw'
import dutyCalendarContent from './DutyCalendarContent.vue?raw'

describe('schedule time inline display', () => {
  it('keeps the day-detail time beside the schedule title', () => {
    expect(scheduleList).toMatch(
      /<span class="schedule-primary-title[^"]*">[\s\S]*?<span v-if="formatScheduleTime\(schedule\)" class="schedule-primary-time[^"]*">[\s\S]*?\{\{ formatScheduleTime\(schedule\) \}\}[\s\S]*?<\/span>[\s\S]*?<\/span>/
    )
    expect(scheduleList).not.toMatch(
      /class="schedule-primary-extra[^"]*"[\s\S]*?class="schedule-primary-time"/
    )
  })

  it('leads the monthly cell title with its time and keeps the multi-day part beside it', () => {
    expect(dutyCalendarContent).toMatch(
      /<span v-if="formatScheduleTime\(schedule\)" class="calendar-item__time">\{\{ formatScheduleTime\(schedule\) \}\}<\/span>\{\{ schedule\.contentWithoutTime \|\| schedule\.content \}\}/
    )
    expect(dutyCalendarContent).toContain('class="calendar-item__part">{{ schedule.daysFromStart }}/{{ schedule.totalDays }}</span>')
  })
})
