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

function expectSingleLine(body: string) {
  expect(body).toContain('display: block')
  expect(body).toContain('overflow: hidden')
  expect(body).toContain('text-overflow: ellipsis')
  expect(body).toContain('white-space: nowrap')
}

// Every day of a multi-day schedule shows its title, tags, and one bottom bar,
// with a one-line title so the bar lines up across neighbouring tiles.
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

  it('keeps a multi-day title on one ellipsised line at every width', () => {
    expectSingleLine(ruleBody(mobileBlock, ':slotted(.calendar-item--span .calendar-item__line)'))
    expectSingleLine(ruleBody(desktopBlock, ':slotted(.calendar-item--span .calendar-item__text)'))
    // The desktop rule must follow the two-line clamp of split titles to win the cascade.
    expect(desktopBlock.indexOf(':slotted(.calendar-item--span .calendar-item__text) {'))
      .toBeGreaterThan(desktopBlock.indexOf(':slotted(.calendar-item__line--split .calendar-item__text) {'))
  })

  it('keeps the day counter off narrow tiles only', () => {
    expect(ruleBody(mobileBlock, ':slotted(.calendar-item--span .calendar-item__part)')).toContain('display: none')
  })
})
