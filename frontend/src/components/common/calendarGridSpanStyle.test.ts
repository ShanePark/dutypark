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

// A multi-day schedule is one white ribbon per week row, drawn in a lane under
// the date so its days line up across the week.
describe('multi-day schedule bands', () => {
  it('aligns lanes across a week through a shared header row', () => {
    const day = ruleBody(baseBlock, '.calendar-day')
    expect(day).toContain('grid-row: span 2')
    expect(day).toContain('grid-template-rows: subgrid')
    // A subgrid ignores its own min-height, so the body keeps the tile minimum.
    expect(day).not.toContain('min-height')
    expect(ruleBody(baseBlock, '.calendar-day-body')).toContain('min-height')
    expect(template.indexOf('class="calendar-span-lanes"')).toBeGreaterThan(template.indexOf('class="calendar-day-top"'))
    expect(template.indexOf('class="calendar-span-lanes"')).toBeLessThan(template.indexOf('class="calendar-day-holiday"'))
  })

  it('sizes lanes and ribbons per breakpoint', () => {
    expect(ruleBody(baseBlock, '.calendar-span-lane')).toContain('height: 16px')
    expect(ruleBody(desktopBlock, '.calendar-span-lane')).toContain('height: 23px')
    expect(ruleBody(baseBlock, '.calendar-span')).toContain('--calendar-span-inset: 2px')
    expect(ruleBody(baseBlock, '.calendar-span')).toContain('--calendar-span-radius: 4px')
    expect(ruleBody(desktopBlock, '.calendar-span')).toContain('--calendar-span-inset: 4px')
    expect(ruleBody(desktopBlock, '.calendar-span')).toContain('--calendar-span-radius: 7px')
  })

  it('bridges the gutters and squares the edges where the schedule continues', () => {
    const band = style.slice(style.indexOf('.calendar-span {'), style.indexOf('}', style.indexOf('.calendar-span {')))
    expect(band).toContain('position: absolute')
    expect(band).toContain('var(--calendar-span-days) * (100% + 2 * var(--calendar-pad-x))')
    expect(band).toContain('(var(--calendar-span-days) - 1) * var(--calendar-gap)')
    expect(band).toContain('pointer-events: none')
    expect(band).toContain('white-space: nowrap')
    expect(band).toContain('background: rgba(255, 255, 255, 0.84)')
    expect(band).toContain('box-shadow: inset 0 0 0 1px rgba(31, 41, 55, 0.14), 0 1px 2px rgba(31, 41, 55, 0.08)')
    expect(band).toContain('color: #1f2937')
    expect(band).not.toContain('border-radius')
    expect(ruleBody(baseBlock, '.calendar-span--start')).toContain('border-top-left-radius: var(--calendar-span-radius)')
    expect(ruleBody(baseBlock, '.calendar-span--end')).toContain('border-bottom-right-radius: var(--calendar-span-radius)')
    expect(ruleBody(baseBlock, ':slotted(.calendar-span__title)')).toContain('text-overflow: ellipsis')
  })

  it('drops the times before the title in a segment too narrow for both', () => {
    const band = style.slice(style.indexOf('.calendar-span {'), style.indexOf('}', style.indexOf('.calendar-span {')))
    expect(band).toContain('container-type: inline-size')
    expect(style).toMatch(/@container \(max-width: 7em\) \{\s*:slotted\(\.calendar-span__time\) \{\s*display: none;/)
  })

  it('leaves the old underline, connectors, and day counter behind', () => {
    expect(style).not.toContain('calendar-item--span')
    expect(style).not.toContain('calendar-item__part')
    expect(style).not.toContain('calendar-span-connectors')
    expect(template).not.toContain('<svg')
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
