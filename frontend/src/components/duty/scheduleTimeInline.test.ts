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

  it('separates the monthly cell title and time with a space', () => {
    expect(dutyCalendarContent).toMatch(
      /<span v-if="formatScheduleTime\(schedule\)" class="calendar-schedule-time">\s+\{\{ formatScheduleTime\(schedule\) \}\}<\/span>/
    )
    expect(dutyCalendarContent).toContain('> ({{ schedule.daysFromStart }}/{{ schedule.totalDays }})</template>')
  })
})
