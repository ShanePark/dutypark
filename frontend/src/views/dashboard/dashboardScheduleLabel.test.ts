import { describe, expect, it } from 'vitest'
import dashboardView from './DashboardView.vue?raw'

const script = dashboardView.slice(0, dashboardView.indexOf('<template>'))

// Multi-day schedules read "제목 (2/3)" on home, matching the day-detail schedule list.
describe('dashboard multi-day schedule label', () => {
  it('shows the day position in parentheses', () => {
    expect(script).toContain('text = `${text} (${schedule.daysFromStart}/${schedule.totalDays})`')
    expect(script).not.toContain('[${schedule.daysFromStart}/${schedule.totalDays}]')
  })
})
