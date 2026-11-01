import { describe, expect, it } from 'vitest'
import calendarGrid from './CalendarGrid.vue?raw'

const template = calendarGrid.slice(0, calendarGrid.indexOf('<style scoped>'))
const style = calendarGrid.slice(calendarGrid.indexOf('<style scoped>'))
const mobileStart = style.indexOf('@media (max-width: 639.98px)')
const desktopStart = style.indexOf('@media (min-width: 640px)')
const baseBlock = style.slice(0, mobileStart)
const mobileBlock = style.slice(mobileStart, desktopStart)
const desktopBlock = style.slice(desktopStart, style.indexOf('@media (min-width: 768px)'))

function ruleBody(block: string, selector: string): string {
  const start = block.indexOf(`${selector} {`)
  expect(start, `${selector} rule`).toBeGreaterThan(-1)
  return block.slice(block.indexOf('{', start) + 1, block.indexOf('}', start))
}

function expectTwoLineClamp(body: string) {
  expect(body).toContain('display: -webkit-box')
  expect(body).toContain('overflow: hidden')
  expect(body).toContain('-webkit-line-clamp: 2')
  expect(body).not.toContain('white-space: nowrap')
}

// Every day of a multi-day schedule shows its title, tags, and one bottom bar,
// with the same two-line title clamp as single-day items: the same title wraps the
// same way in every equal-width tile, so the bar still lines up across days.
describe('multi-day schedule styling', () => {
  it('shows the title and tags on every day at every width', () => {
    expect(style).not.toContain('clip-path')
    expect(style).not.toContain('calendar-day--week-start')
    expect(template).not.toContain('calendar-day--week-start')
    expect(mobileBlock).not.toContain('.calendar-item__tags')
  })

  it('draws the joining bar only at the bottom of the item', () => {
    const body = ruleBody(baseBlock, ':slotted(.calendar-item--span)::after')
    expect(body).toContain('bottom: 0')
    expect(style).not.toMatch(/calendar-item--span\)::after \{[^}]*top:/)
  })

  it('wraps a multi-day title to two lines like any other title', () => {
    expectTwoLineClamp(ruleBody(mobileBlock, ':slotted(.calendar-item--span .calendar-item__text)'))
    expectTwoLineClamp(ruleBody(desktopBlock, ':slotted(.calendar-item__line--split .calendar-item__text)'))
    expect(desktopBlock).not.toContain(':slotted(.calendar-item--span .calendar-item__text)')
  })

  it('shows the day counter at the end of the title line on narrow tiles', () => {
    const line = ruleBody(mobileBlock, ':slotted(.calendar-item--span .calendar-item__line)')
    expect(line).toContain('display: flex')
    expect(ruleBody(mobileBlock, ':slotted(.calendar-item--span .calendar-item__text)')).toContain('min-width: 0')

    const part = ruleBody(mobileBlock, ':slotted(.calendar-item--span .calendar-item__part)')
    expect(part).not.toContain('display: none')
    expect(part).toContain('flex: none')
    expect(ruleBody(baseBlock, ':slotted(.calendar-item__part)')).toContain('color: var(--calendar-ink-muted)')
    expect(ruleBody(baseBlock, ':slotted(.calendar-item__part)')).toContain('font-variant-numeric: tabular-nums')
  })
})
