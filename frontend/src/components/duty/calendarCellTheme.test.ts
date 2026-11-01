import { describe, expect, it } from 'vitest'
import dutyCalendarContent from './DutyCalendarContent.vue?raw'

const style = dutyCalendarContent.slice(dutyCalendarContent.indexOf('<style scoped>'))

function ruleBody(selector: string): string {
  const start = style.indexOf(selector)
  expect(start, `${selector} rule`).toBeGreaterThan(-1)
  return style.slice(style.indexOf('{', start) + 1, style.indexOf('}', start))
}

// A duty fill is identical in light and dark, so anything drawn on it must not
// pick up theme tokens (they are redefined under .dark).
describe('duty calendar in-cell styling', () => {
  it('never switches on the dark theme class', () => {
    expect(style).not.toMatch(/\.dark\b/)
  })

  it.each([
    '.calendar-day--on-light .schedule-tag',
    '.calendar-day--on-light .calendar-items :deep(.schedule-tag-avatar.profile-avatar)',
    '.calendar-day--on-light .calendar-items :deep(.other-duty-chip__avatar.profile-avatar)',
    '.calendar-day--on-light .calendar-items :deep(.calendar-visibility-hint .visibility-hint-button--xs)',
    '.calendar-day--on-light .calendar-action-bubble--todo',
    '.calendar-day--on-light .calendar-action-bubble--progress',
  ])('gives duty tiles a fixed look for %s', selector => {
    const body = ruleBody(selector)
    expect(body).not.toContain('var(--dp-')
  })

  it('keeps the todo overflow count on the cell ink', () => {
    expect(dutyCalendarContent).not.toContain("color: 'var(--dp-text-muted)'")
  })
})
