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
// with the same two-line title clamp as single-day items. Measured connectors
// bridge baseline differences caused by holidays, wrapping, and tags.
describe('multi-day schedule styling', () => {
  it('keeps SVG runs decorative and preserves measurable CSS fallbacks', () => {
    const overlay = ruleBody(baseBlock, '.calendar-span-connectors')
    expect(overlay).toContain('position: absolute')
    expect(overlay).toContain('pointer-events: none')
    expect(template).toContain('aria-hidden="true" focusable="false"')
    const underline = ruleBody(baseBlock, ':slotted(.calendar-item--span)::after')
    expect(underline).toContain('visibility: var(--calendar-span-visibility, visible)')
    expect(underline).not.toContain('display: none')
  })

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
    expectTwoLineClamp(ruleBody(baseBlock, ':slotted(.calendar-item__line)'))
    expect(style).not.toContain('.calendar-item__line--split')
    expect(style).not.toContain('.calendar-item--span .calendar-item__line')
    expect(style).not.toContain('.calendar-item--span .calendar-item__text')
  })

  it('flows the day counter inline as the end of the title', () => {
    expect(style).not.toContain('.calendar-item--span .calendar-item__part')
    expect(mobileBlock).not.toContain('.calendar-item__part')
    expect(desktopBlock).not.toContain('.calendar-item__part')

    const part = ruleBody(baseBlock, ':slotted(.calendar-item__part)')
    expect(part).not.toContain('display')
    expect(part).not.toContain('flex')
    // A leading space separates it from the title instead, so a wrapped counter starts flush.
    expect(part).not.toContain('margin-left')
    expect(part).toContain('color: var(--calendar-ink-muted)')
    expect(part).toContain('font-variant-numeric: tabular-nums')
  })
})

describe('responsive calendar day headers', () => {
  it('wraps the full D-Day header while keeping the date and today badge intact', () => {
    expect(ruleBody(baseBlock, '.calendar-day-top')).toContain('flex-wrap: wrap')
    expect(ruleBody(baseBlock, '.calendar-day-top')).toContain('container: calendar-day-header / inline-size')
    expect(ruleBody(baseBlock, '.calendar-day-number')).toContain('flex: none')
    expect(ruleBody(baseBlock, '.calendar-day-number')).toContain('white-space: nowrap')
    expect(ruleBody(baseBlock, '.calendar-day-today-circle')).toContain('flex: none')
  })

  it('shows the optional today word only when the actual header has enough room', () => {
    expect(ruleBody(baseBlock, '.calendar-day-today-label')).toContain('display: none')
    expect(desktopBlock).not.toContain('.calendar-day-today-label')
    expect(style).toContain('@container calendar-day-header (min-width: 6rem)')
    expect(ruleBody(baseBlock, '.calendar-day-today-label')).toContain('white-space: nowrap')
  })
})
