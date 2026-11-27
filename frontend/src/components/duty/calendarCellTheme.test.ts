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
    '.calendar-day--on-light .other-duty-chips :deep(.other-duty-chip__avatar.profile-avatar)',
    '.calendar-day--on-light .calendar-items :deep(.calendar-visibility-hint .visibility-hint-button--xs)',
    '.calendar-day--on-light .calendar-action-bubble--todo',
    '.calendar-day--on-light .calendar-action-bubble--progress',
  ])('gives duty tiles a fixed look for %s', selector => {
    const body = ruleBody(selector)
    expect(body).not.toContain('var(--dp-')
  })
})

describe('in-cell tag chip gloss', () => {
  it('glosses chips on empty tiles with the theme tokens, scaled down', () => {
    const chip = ruleBody('.schedule-tag {')
    expect(chip).toContain('background-color: var(--dp-bg-primary);')
    expect(chip).toContain('background-image: var(--dp-tag-chip-sheen);')
    expect(chip).toContain('box-shadow: inset 0 0.5px 0 var(--dp-tag-chip-highlight), var(--dp-tag-chip-drop-mini);')
  })

  // White glass over any duty fill: the gradient averages the former 0.72 white.
  it('glosses chips on duty fills with fixed white glass', () => {
    const chip = ruleBody('.calendar-day--on-light .schedule-tag')
    expect(chip).toContain('background-color: transparent;')
    expect(chip).toContain('background-image: linear-gradient(180deg, rgb(255 255 255 / 0.84) 0%, rgb(255 255 255 / 0.62) 100%);')
    expect(chip).toContain('box-shadow: inset 0 0.5px 0 rgb(255 255 255 / 0.95), 0 0.5px 1px rgb(15 23 42 / 0.14);')
    expect(style).not.toContain('backdrop-filter')
  })
})
