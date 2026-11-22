import { describe, expect, it } from 'vitest'
import calendarGrid from './CalendarGrid.vue?raw'
import calendarSpanTags from '../duty/CalendarSpanTags.vue?raw'

const template = calendarGrid.slice(0, calendarGrid.indexOf('<style scoped>'))
const style = calendarGrid.slice(calendarGrid.indexOf('<style scoped>'))
const mobileStart = style.indexOf('@media (max-width: 639.98px)')
const desktopStart = style.indexOf('@media (min-width: 640px)')
const baseBlock = style.slice(0, mobileStart)
const mobileBlock = style.slice(mobileStart, desktopStart)
const spanTags = calendarSpanTags.slice(calendarSpanTags.indexOf('<style scoped>'))
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

// A multi-day schedule is one glass ribbon per week row, drawn in a lane under
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
    expect(band).not.toContain('border-radius')
    expect(ruleBody(baseBlock, '.calendar-span--start')).toContain('border-top-left-radius: var(--calendar-span-radius)')
    expect(ruleBody(baseBlock, '.calendar-span--end')).toContain('border-bottom-right-radius: var(--calendar-span-radius)')
    expect(ruleBody(baseBlock, ':slotted(.calendar-span__title)')).toContain('text-overflow: ellipsis')
  })

  // Soft glass: an opaque band painted per day as glass over that day's fill
  // (see CalendarGrid.test.ts), with a hairline edge and no drop shadow. The
  // title follows the tile the band starts in; the end time, chevron and tags
  // follow the tile it ends in.
  it('paints the band as soft glass in the tile ink', () => {
    const band = ruleBody(baseBlock, '.calendar-span')
    expect(band).toContain('--calendar-span-edge: rgb(255 255 255 / 60%)')
    expect(band).toContain('background: var(--calendar-span-fill)')
    expect(band).toContain('box-shadow: inset 0 0 0 1px var(--calendar-span-edge)')
    expect(band).toContain('color: var(--calendar-ink)')
    expect(band).not.toContain('rgba(31, 41, 55')
    expect(band).not.toContain('#1f2937')
    expect(ruleBody(baseBlock, ':slotted(.calendar-span__time)'))
      .toContain('color: color-mix(in srgb, var(--calendar-ink) 62%, transparent)')
    expect(baseBlock).toMatch(/\n:slotted\(\.calendar-span__time--end\) \{[^}]*color: color-mix\(in srgb, var\(--calendar-span-end-ink\) 62%, transparent\)/)
    expect(baseBlock).toMatch(/\n\.calendar-span__more \{[^}]*color: color-mix\(in srgb, var\(--calendar-span-end-ink\) 45%, transparent\)/)
    expect(ruleBody(spanTags, '.calendar-span__tags')).toContain('--calendar-ink: var(--calendar-span-end-ink)')
  })

  it('fades the edge on dark fills and tints empty tiles by theme', () => {
    expect(ruleBody(baseBlock, '.calendar-day--on-dark .calendar-span')).toContain('--calendar-span-edge: rgb(255 255 255 / 16%)')
    expect(ruleBody(baseBlock, '.calendar-day:not(.calendar-day--on-light):not(.calendar-day--on-dark) .calendar-span'))
      .toContain('--calendar-span-edge: var(--calendar-span-empty-edge)')
    // White glass would vanish on a light empty tile, so light-theme empty
    // tiles take a faint ink tint and an ink hairline instead.
    const grid = ruleBody(baseBlock, '.calendar-grid')
    expect(grid).toContain('--calendar-span-empty-tint: var(--dp-text-primary)')
    expect(grid).toContain('--calendar-span-empty-glass: 6%')
    expect(grid).toContain('--calendar-span-empty-edge: color-mix(in srgb, var(--dp-text-primary) 10%, transparent)')
    const dark = ruleBody(baseBlock, ':global(.dark .calendar-grid)')
    expect(dark).toContain('--calendar-span-empty-tint: #fff')
    expect(dark).toContain('--calendar-span-empty-glass: 10%')
    expect(dark).toContain('--calendar-span-empty-edge: rgb(255 255 255 / 16%)')
  })

  // The tightest tag level is the "+N" pill with the first member's avatar
  // inside it, sized to the pill, instead of a person icon and a total.
  it('fits the first avatar inside the compact tag pill', () => {
    expect(calendarSpanTags).not.toMatch(/\bUser\b/)
    const desktopTags = spanTags.slice(spanTags.indexOf('@media (min-width: 640px)'))
    expect(ruleBody(spanTags, '.span-tag-pill--compact .span-tag-avatar')).toContain('width: 10px')
    expect(ruleBody(desktopTags, '.span-tag-pill--compact .span-tag-avatar')).toContain('width: 14px')
  })

  // The lone level is the first member's avatar, ringed like the stack, with
  // the other members counted in a tiny "+N" badge on its bottom-right corner.
  it('draws the lone tag level as one avatar with a "+N" badge for the rest', () => {
    const lone = calendarSpanTags.slice(
      calendarSpanTags.indexOf(`v-else-if="fit.level === 'lone'"`),
      calendarSpanTags.indexOf('</span>', calendarSpanTags.indexOf('span-tag-lone__more')),
    )
    expect(lone).toContain('class="span-tag-lone"')
    expect(lone).toContain('data-span-tag-item')
    expect(lone).toMatch(/<span v-if="tags\.length > 1" class="span-tag-lone__more">\{\{ calendarSpanCompactMore\(tags\.length\) \}\}/)
    expect(calendarSpanTags).toMatch(/v-else-if="\(fit\.level === 'chips' \|\| fit\.level === 'avatars'\) && hidden > 0"/)
    expect(ruleBody(spanTags, '.span-tag-lone__more')).toContain('position: absolute')
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
