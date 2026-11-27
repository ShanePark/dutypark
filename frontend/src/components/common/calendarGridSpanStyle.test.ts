import { describe, expect, it } from 'vitest'
import { compileStyle, parse } from 'vue/compiler-sfc'
import calendarGrid from './CalendarGrid.vue?raw'
import calendarSpanTags from '../duty/CalendarSpanTags.vue?raw'
import dutyCalendarContent from '../duty/DutyCalendarContent.vue?raw'

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
  it('wraps full D-Day titles while preserving the schedule title clamp', () => {
    expect(dutyCalendarContent).toContain('class="calendar-item__line calendar-item__line--dday"')
    const ddayLine = ruleBody(baseBlock, ':slotted(.calendar-item__line--dday)')
    expect(ddayLine).toContain('display: block')
    expect(ddayLine).toContain('overflow: visible')
    expect(ddayLine).toContain('-webkit-line-clamp: none')
    expect(ddayLine).toContain('line-clamp: none')
    expect(ddayLine).toContain('overflow-wrap: anywhere')
    const scheduleTitle = ruleBody(baseBlock, ':slotted(.calendar-item__line--chip > .calendar-item__text)')
    expect(scheduleTitle).toContain('-webkit-line-clamp: 2')
    expect(scheduleTitle).toContain('overflow: hidden')
  })

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
  // (see CalendarGrid.test.ts), rimmed in each covered day's ink and lifted
  // by a faint drop shadow. The title follows the tile the band starts in; the
  // end time, chevron and tags follow the tile it ends in.
  it('paints the band as soft glass in the tile ink', () => {
    const band = ruleBody(baseBlock, '.calendar-span')
    expect(band).toContain('background: var(--calendar-span-fill)')
    expect(band).toContain('box-shadow: var(--calendar-span-shadow)')
    expect(band).not.toContain('box-shadow: inset')
    expect(band).toContain('color: var(--calendar-ink)')
    expect(band).not.toContain('rgba(31, 41, 55')
    expect(band).not.toContain('#1f2937')
    expect(ruleBody(baseBlock, ':slotted(.calendar-span__time)'))
      .toContain('color: color-mix(in srgb, var(--calendar-ink) 62%, transparent)')
    expect(baseBlock).toMatch(/\n:slotted\(\.calendar-span__time--end\) \{[^}]*color: color-mix\(in srgb, var\(--calendar-span-end-ink\) 62%, transparent\)/)
    expect(baseBlock).toMatch(/\n\.calendar-span__more \{[^}]*color: color-mix\(in srgb, var\(--calendar-span-end-ink\) 45%, transparent\)/)
    expect(ruleBody(spanTags, '.calendar-span__tags')).toContain('--calendar-ink: var(--calendar-span-end-ink)')
  })

  // A white hairline vanished on light tiles, so the rim is an ink tint that
  // follows the rounded ends: a transparent 1px border shows the outline layer
  // while the padding box repaints the fill. It sits under the text.
  it('rims the band in an ink tint that follows its rounded ends', () => {
    const band = ruleBody(baseBlock, '.calendar-span')
    expect(band).toContain('--calendar-span-outline-strength: 34%')
    expect(band).toContain('--calendar-span-shadow: 0 1px 2px rgb(15 23 42 / 16%)')
    const rim = ruleBody(baseBlock, '.calendar-span::before')
    expect(rim).toContain('position: absolute')
    expect(rim).toContain('inset: 0')
    expect(rim).toContain('z-index: -1')
    expect(rim).toContain('border: 1px solid transparent')
    expect(rim).toContain('border-radius: inherit')
    expect(rim).toContain('background: var(--calendar-span-fill) padding-box, var(--calendar-span-outline) border-box')
    expect(rim).toContain('background-origin: border-box')
    expect(ruleBody(baseBlock, ':global(.dark) .calendar-span'))
      .toContain('--calendar-span-shadow: 0 1px 2px rgb(0 0 0 / 40%)')
    expect(style).not.toContain('--calendar-span-edge')
    expect(style).not.toContain('--calendar-span-empty-edge')
  })

  // The gutters stay faintly visible through the band: an opaque divider over
  // each gutter, split at the seam, inside the rim so the outline stays
  // unbroken. In light theme it is the gutter seen through each side's glass,
  // so the line keeps the light gutter's colour and polarity above, inside
  // and below the band.
  it('draws each gutter through the band as the gutter under its glass in light theme', () => {
    const divider = ruleBody(baseBlock, '.calendar-span__divider')
    expect(divider).toContain('position: absolute')
    expect(divider).toContain('z-index: -1')
    expect(divider).toContain('top: 1px')
    expect(divider).toContain('bottom: 1px')
    expect(divider).toContain('width: var(--calendar-gap)')
    expect(divider).toContain('background: linear-gradient(to right, var(--calendar-span-before-gutter) 50%, var(--calendar-span-after-gutter) 50%)')
    expect(divider).not.toContain('ink')
    // The rim is drawn first, so the dividers paint over the fill it repaints.
    expect(template.indexOf('class="calendar-span__divider"')).toBeLessThan(template.indexOf('<slot name="span"'))
  })

  // Dark theme keeps exactly the faint ink line per side over that side's glass,
  // which reads as the dark gutter continuing.
  it('keeps the dark-theme divider as a faint ink line over each side\'s glass', () => {
    const dark = ruleBody(baseBlock, ':global(.dark .calendar-span__divider)')
    expect(dark).toContain('--calendar-span-divider-strength: 18%')
    expect(dark).toMatch(/background:\s*linear-gradient\(\s*to right,\s*color-mix\(in srgb, var\(--calendar-span-before-ink\) var\(--calendar-span-divider-strength\), transparent\) 50%,\s*color-mix\(in srgb, var\(--calendar-span-after-ink\) var\(--calendar-span-divider-strength\), transparent\) 50%\s*\),\s*linear-gradient\(to right, var\(--calendar-span-before-glass\) 50%, var\(--calendar-span-after-glass\) 50%\);/)
  })

  it('compiles the dark divider override to target the divider inside the dark theme', () => {
    const { descriptor } = parse(calendarGrid)
    const compiled = compileStyle({ source: descriptor.styles[0]!.content, filename: 'CalendarGrid.vue', id: 'data-v-test', scoped: true })
    expect(compiled.errors).toEqual([])
    expect(ruleBody(compiled.code, '.dark .calendar-span__divider')).toContain('--calendar-span-divider-strength: 18%')
  })

  it('keeps the light-theme empty tile glass as a faint ink tint', () => {
    // White glass would vanish on a light empty tile, so light-theme empty
    // tiles take a faint ink tint instead.
    const grid = ruleBody(baseBlock, '.calendar-grid')
    expect(grid).toContain('--calendar-span-empty-tint: var(--dp-text-primary)')
    expect(grid).toContain('--calendar-span-empty-glass: 6%')
    const dark = ruleBody(baseBlock, ':global(.dark .calendar-grid)')
    expect(dark).toContain('--calendar-span-empty-tint: #fff')
    expect(dark).toContain('--calendar-span-empty-glass: 10%')
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

describe('calendar item dividers', () => {
  it('keeps a rule between day items on every breakpoint', () => {
    expect(ruleBody(baseBlock, ':slotted(.calendar-item + .calendar-item)')).toContain('border-top: 1px solid var(--calendar-rule)')
    const desktop = ruleBody(desktopBlock, ':slotted(.calendar-item + .calendar-item)')
    expect(desktop).not.toContain('border-top: 0')
    // The rule sits in the middle of the 4px desktop gap.
    expect(desktop).toContain('margin-top: -2px')
    expect(desktop).toContain('padding-top: 2px')
  })

  it('keeps the rule above D-Day markers on desktop', () => {
    const dutyStyle = dutyCalendarContent.slice(dutyCalendarContent.indexOf('<style scoped>'))
    const desktop = dutyStyle.slice(dutyStyle.indexOf('@media (min-width: 640px)'))
    expect(desktop).not.toMatch(/\.calendar-item \+ \.calendar-item\.calendar-dday-marker \{\s*border-top: 0/)
  })
})

describe('responsive calendar day headers', () => {
  it('aligns desktop calendar items without a leading dot or reserved dot space', () => {
    expect(ruleBody(desktopBlock, ':slotted(.calendar-item)')).toContain('padding: 0;')
    expect(style).not.toContain(':slotted(.calendar-item)::before')
  })

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

// The phone month grid matches the iOS geometry: day columns are
// (viewport - 2 * 8 inset - 6 * 2 gutters) / 7 and each cell is padded by 1.5px.
describe('mobile month grid geometry', () => {
  it('pads phone cells by 1.5px and keeps the desktop padding', () => {
    expect(ruleBody(baseBlock, '.calendar-grid')).toContain('--calendar-pad-x: 1.5px')
    // Phones use the 1pt iOS gutter; desktop keeps its 2px gutter.
    expect(ruleBody(baseBlock, '.calendar-grid')).toContain('--calendar-gap: 1px')
    expect(ruleBody(desktopBlock, '.calendar-grid')).toContain('--calendar-gap: 2px')
    expect(ruleBody(desktopBlock, '.calendar-grid')).toContain('--calendar-pad-x: 8px')
    expect(ruleBody(baseBlock, '.calendar-day')).toContain('padding: 4px var(--calendar-pad-x) 5px')
  })

  it('lets the phone grid border reach into the page inset so columns match iOS', () => {
    const dutyStyle = dutyCalendarContent.slice(dutyCalendarContent.indexOf('<style scoped>'))
    const phone = dutyStyle.slice(dutyStyle.indexOf('@media (max-width: 639.98px)'))
    expect(dutyStyle).toContain('@media (max-width: 639.98px)')
    expect(ruleBody(phone, '.calendar-month-swipe__grid')).toContain('margin-inline: -1px')
    expect(ruleBody(dutyStyle, '.calendar-month-swipe')).toContain('padding-inline: 8px')
  })

  it('draws today\'s ring exactly over the gutter without reaching into neighbouring days', () => {
    const ring = ruleBody(baseBlock, '.calendar-day-today-border')
    expect(ring).toContain('inset: calc(-1 * var(--calendar-gap))')
    expect(ring).toContain('border: 1.5px solid var(--calendar-today)')
    // An outer halo would spill past a 1px gutter onto the neighbours.
    expect(ring).toContain('box-shadow: inset 0 0 0 1.5px #fff')
    expect(ring).not.toMatch(/box-shadow: 0 0 0/)
    const desktopRing = ruleBody(desktopBlock, '.calendar-day-today-border')
    expect(desktopRing).toContain('border-width: 3px')
    expect(desktopRing).toContain('box-shadow: 0 0 0 2px var(--calendar-gutter), inset 0 0 0 2px #fff')
  })
})
