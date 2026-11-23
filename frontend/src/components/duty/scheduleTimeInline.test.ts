import { describe, expect, it } from 'vitest'
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
    // One space separates the title from the chip and hangs at the line end when
    // the chip wraps, so a wrapped chip starts flush. Month cells draw no day counter.
    expect(line).toMatch(
      /class="calendar-schedule-detail-icon"\s*\/><\/span> <span v-if="formatScheduleTime\(schedule\)" class="calendar-item__time">/
    )
    expect(dutyCalendarContent).not.toContain('calendar-item__part')
    expect(line).toMatch(/<wbr v-if="partIndex > 0"><span class="calendar-item__time-part">\{\{ part \}\}<\/span>/)
    expect(dutyCalendarContent).not.toContain('<div v-if="formatScheduleTime(schedule)" class="calendar-item__time"')
    expect(dutyCalendarContent).not.toContain('calendar-item__line--split')
  })

  it('styles the time chip as a tone-on-tone pill that never sits inside the title clamp', () => {
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
    expect(chip[0]).toContain('padding: 1px 3px')
    expect(chip[0]).toContain('border-radius: 4px')
    expect(chip[0]).toContain('margin-top: 1px')
    expect(chip[0]).toContain('font-size: 0.84em')
    expect(chip[0]).toContain('line-height: 1.4')
    expect(chip[0]).toContain('font-weight: 700')
    expect(chip[0]).toContain('font-variant-numeric: tabular-nums')
    // A side margin would indent a chip that wraps to a new line; the leading space hangs instead.
    expect(chip[0]).not.toMatch(/margin(-left|-right)?:/)
    expect(chip[1]).toContain('margin-top: 0')
    expect(chip[1]).toContain('padding: 1px 5px')
    expect(chip[1]).toContain('border-radius: 5px')

    // Each side of the range stays whole; the only break opportunity is the <wbr> after "~".
    const part = bodies(':slotted(.calendar-item__time-part)')
    expect(part).toHaveLength(1)
    expect(part[0]).toContain('white-space: nowrap')
    expect(part[0]).toContain('overflow-wrap: normal')

    const line = bodies(':slotted(.calendar-item__line--chip)')
    expect(line).toHaveLength(1)
    expect(line[0]).toContain('display: block')
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
