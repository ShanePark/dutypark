import { describe, expect, it } from 'vitest'
import navigator from './CalendarMonthNavigator.vue?raw'

const template = navigator.slice(navigator.indexOf('<template>'))

function buttonWithLabel(label: string): string {
  const start = template.indexOf(`t('common.calendar.${label}')`)
  expect(start).toBeGreaterThan(-1)
  const open = template.lastIndexOf('<button', start)
  return template.slice(open, template.indexOf('</button>', start))
}

const arrowLabels = ['previousMonth', 'nextMonth']

describe('CalendarMonthNavigator arrows', () => {
  it.each(arrowLabels)('draws %s as a tinted circle so the tap area is visible', (label) => {
    const button = buttonWithLabel(label)
    expect(button).toContain('calendar-nav-arrow')
    // The bare hover-only style left touch devices with no sign of where the button was.
    expect(button).not.toContain('calendar-nav-btn')
  })

  it.each(arrowLabels)('gives the %s chevron a larger glyph', (label) => {
    const button = buttonWithLabel(label)
    expect(button).toMatch(/class="h-6 w-6 sm:h-7 sm:w-7"/)
  })

  it('keeps the arrows clear of the year-month button', () => {
    expect(template).toContain('flex items-center justify-center gap-1 sm:gap-2')
  })
})
