import { describe, expect, it } from 'vitest'
import { compileStyle, parse } from 'vue/compiler-sfc'
import scheduleList from './ScheduleList.vue?raw'
import dutyCalendarContent from './DutyCalendarContent.vue?raw'
import calendarGrid from '../common/CalendarGrid.vue?raw'

describe('schedule time inline display', () => {
  it('keeps the day-detail time beside the schedule title', () => {
    expect(scheduleList).toMatch(
      /<span class="schedule-primary-title[^"]*">[\s\S]*?<span v-if="formatScheduleTime\(schedule\)" class="schedule-primary-time[^"]*">[\s\S]*?\{\{ formatScheduleTime\(schedule\) \}\}[\s\S]*?<\/span>[\s\S]*?<\/span>/
    )
    expect(scheduleList).not.toMatch(
      /class="schedule-primary-extra[^"]*"[\s\S]*?class="schedule-primary-time"/
    )
  })

  it('follows the monthly cell title and details mark with a time chip', () => {
    const lineStart = dutyCalendarContent.indexOf('<div class="calendar-item__line calendar-item__line--chip">')
    expect(lineStart).toBeGreaterThan(-1)
    const line = dutyCalendarContent.slice(lineStart, dutyCalendarContent.indexOf('</div>', lineStart))
    expect(line).toMatch(
      /\{\{ schedule\.contentWithoutTime \|\| schedule\.content \}\}<MessageSquareText\s+v-if="hasScheduleDetails\(schedule\)"/
    )
    // The chip's own left margin separates it from the title, so no text node sits
    // between them. Month cells draw no day counter.
    expect(line).toMatch(
      /class="calendar-schedule-detail-icon"\s*\/><\/span><span\s+v-if="formatScheduleTime\(schedule\)"\s+class="calendar-item__time"\s+:class="\{ 'calendar-item__time--single': getScheduleTimeParts\(schedule\)\.length === 1 \}"\s*>/
    )
    expect(dutyCalendarContent).not.toContain('calendar-item__part')
    expect(line).toMatch(/<wbr v-if="partIndex > 0"><span class="calendar-item__time-part">\{\{ part \}\}<\/span>/)
    expect(dutyCalendarContent).not.toContain('<div v-if="formatScheduleTime(schedule)" class="calendar-item__time"')
    expect(dutyCalendarContent).not.toContain('calendar-item__line--split')
  })

  it('styles the time chip as a tone-on-tone pill held at the right edge of the row', () => {
    const style = calendarGrid.slice(calendarGrid.indexOf('<style scoped>'))
    const bodies = (selector: string) => [...style.matchAll(new RegExp(`${selector.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')} \\{([^}]*)\\}`, 'g'))]
      .map((match) => match[1]!)

    // Mobile base first, then the 640px+ override.
    const chip = bodies(':slotted(.calendar-item__time)')
    expect(chip).toHaveLength(2)
    expect(chip[0]).toContain('display: inline-block')
    expect(chip[0]).toContain('max-width: 100%')
    // The tile sets a tone-on-tone pair from its duty fill; otherwise the neutral ink chip shows.
    expect(chip[0]).toContain('background: var(--calendar-time-bg, color-mix(in srgb, var(--calendar-ink) 8.5%, transparent))')
    expect(chip[0]).toContain('color: var(--calendar-time-ink, color-mix(in srgb, var(--calendar-ink) 82%, transparent))')
    // On phones the chip is a short box with a hairline of side room and the iOS
    // tracking, so most ranges fit one narrow row without the glyphs touching its edges.
    expect(chip[0]).toContain('padding: 0 1px')
    expect(chip[0]).toContain('letter-spacing: -0.36px')
    // A large corner would bite into the edge glyphs of a box this tight.
    expect(chip[0]).toContain('border-radius: 2.5px')
    expect(chip[0]).toContain('margin-top: 1px')
    // A phone-sized chip at 77% of the cell text keeps "10:00~11:00" on one row, as on iOS.
    expect(chip[0]).toContain('font-size: 0.77em')
    expect(chip[0]).toContain('line-height: 1.2')
    expect(chip[0]).toContain('font-weight: 700')
    expect(chip[0]).toContain('font-variant-numeric: tabular-nums')
    // A right float after the title lands at the right edge of the title's last line
    // when it fits there, otherwise at the right edge of the next line.
    expect(chip[0]).toContain('float: right')
    // The gap before the chip is the title's hanging trailing space, so a chip on its
    // own line can use the whole row.
    expect(chip[0]).toContain('margin-left: 0')
    expect(chip[0]).not.toContain('margin-left: 0.25em')
    // A range wider than the row breaks after "~" and keeps both lines flush right.
    expect(chip[0]).toContain('text-align: right')
    expect(chip[0]).not.toMatch(/margin(-right)?:/)
    expect(chip[1]).toContain('margin-top: 0')
    expect(chip[1]).toContain('padding: 1px 5px')
    expect(chip[1]).toContain('border-radius: 5px')
    expect(chip[1]).toContain('font-size: 0.84em')
    expect(chip[1]).toContain('letter-spacing: normal')
    expect(chip[1]).toContain('line-height: 1.4')
    expect(chip[1]).toContain('margin-left: 0.25em')

    // A preserved space hangs at a line end, so it never wraps the title, but it
    // takes room when the chip shares the title's last line. Desktop keeps the chip margin.
    const gap = bodies(':slotted(.calendar-item__line--chip > .calendar-item__text--flow)::after')
    expect(gap).toHaveLength(2)
    expect(gap[0]).toContain("content: ' '")
    expect(gap[0]).toContain('white-space: pre-wrap')
    expect(gap[1]).toContain('content: none')
    const { descriptor } = parse(calendarGrid)
    const compiled = compileStyle({ source: descriptor.styles[0]!.content, filename: 'CalendarGrid.vue', id: 'data-v-test', scoped: true })
    expect(compiled.errors).toEqual([])
    expect(compiled.code).toContain('.calendar-item__line--chip > .calendar-item__text--flow[data-v-test-s]::after')

    // Each side of the range stays whole; the only break opportunity is the <wbr> after "~".
    const part = bodies(':slotted(.calendar-item__time-part)')
    expect(part).toHaveLength(1)
    expect(part[0]).toContain('white-space: nowrap')
    expect(part[0]).toContain('overflow-wrap: normal')

    // The line contains the floated chip, so a wrapped chip still adds to the row height.
    const line = bodies(':slotted(.calendar-item__line--chip)')
    expect(line).toHaveLength(1)
    expect(line[0]).toContain('display: flow-root')

    // A lone time has room to spare, so on phones it stops 2px short of the row edge;
    // a range keeps the whole row. Desktop keeps every chip flush.
    const single = bodies(':slotted(.calendar-item__time--single)')
    expect(single).toHaveLength(2)
    expect(single[0]).toContain('margin-right: 2px')
    expect(single[1]).toContain('margin-right: 0')
    expect(style.indexOf(':slotted(.calendar-item__time--single)')).toBeGreaterThan(style.indexOf(':slotted(.calendar-item__time) {'))
    expect(style.lastIndexOf(':slotted(.calendar-item__time--single)')).toBeGreaterThan(style.indexOf('@media (min-width: 640px)'))
    expect(line[0]).toContain('overflow: visible')
    expect(line[0]).toContain('-webkit-line-clamp: none')

    const title = bodies(':slotted(.calendar-item__line--chip > .calendar-item__text)')
    expect(title).toHaveLength(1)
    expect(title[0]).toContain('display: -webkit-inline-box')
    expect(title[0]).toContain('-webkit-line-clamp: 2')
    expect(title[0]).toContain('overflow: hidden')
    expect(title[0]).toContain('max-width: 100%')

    const flowingTitle = bodies(':slotted(.calendar-item__line--chip > .calendar-item__text--flow)')
    expect(flowingTitle).toHaveLength(1)
    expect(flowingTitle[0]).toContain('display: inline')
    expect(flowingTitle[0]).toContain('overflow: visible')
  })
})
