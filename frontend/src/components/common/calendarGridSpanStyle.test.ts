import { describe, expect, it } from 'vitest'
import calendarGrid from './CalendarGrid.vue?raw'

const style = calendarGrid.slice(calendarGrid.indexOf('<style scoped>'))
const mobileStart = style.indexOf('@media (max-width: 639.98px)')
const mobileBlock = style.slice(mobileStart, style.indexOf('@media (min-width: 640px)', mobileStart))

function ruleBody(block: string, selector: string): string {
  const start = block.indexOf(`${selector} {`)
  expect(start, `${selector} rule`).toBeGreaterThan(-1)
  return block.slice(block.indexOf('{', start) + 1, block.indexOf('}', start))
}

// On narrow tiles a multi-day schedule names itself only where a reader starts
// following it: its first day and the first day of each later week row.
describe('narrow multi-day schedule styling', () => {
  it('keeps continuation titles for assistive technology but out of sight', () => {
    const body = ruleBody(mobileBlock, ':slotted(.calendar-item--span:not(.calendar-item--span-start) .calendar-item__line)')
    expect(body).toContain('position: absolute')
    expect(body).toContain('clip-path: inset(50%)')
    expect(body).not.toContain('display: none')
  })

  it('shows the title again at the start of each week row, wrapping to two lines', () => {
    const body = ruleBody(mobileBlock, '.calendar-day--week-start :slotted(.calendar-item--span .calendar-item__line)')
    expect(body).toContain('position: static')
    expect(mobileBlock).not.toContain('white-space: nowrap')
  })

  it('draws the joining bar at the top so a wrapped title cannot push it out of line', () => {
    const body = ruleBody(mobileBlock, ':slotted(.calendar-item--span)::after')
    expect(body).toMatch(/top: \d/)
    expect(body).toContain('bottom: auto')
  })
})
