import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'
import navigator from './CalendarMonthNavigator.vue?raw'

const styles = readFileSync(resolve(process.cwd(), 'src/style.css'), 'utf8')

const template = navigator.slice(navigator.indexOf('<template>'))

function buttonWithLabel(label: string): string {
  const start = template.indexOf(`t('common.calendar.${label}')`)
  expect(start).toBeGreaterThan(-1)
  const open = template.lastIndexOf('<button', start)
  return template.slice(open, template.indexOf('</button>', start))
}

const arrowLabels = ['previousMonth', 'nextMonth']

describe('CalendarMonthNavigator capsule', () => {
  it('joins both arrows and the year-month button into one capsule', () => {
    expect(template).toMatch(/<div\s+class="calendar-nav-group"/)
    const group = styles.match(/\.calendar-nav-group \{([^}]*)\}/)?.[1] ?? ''
    expect(group).toMatch(/border-radius: 9999px/)
    expect(group).toMatch(/background-color: var\(--dp-bg-card\)/)
  })

  it.each(arrowLabels)('keeps %s a full-height segment of the capsule', (label) => {
    const button = buttonWithLabel(label)
    expect(button).toContain('calendar-nav-arrow')
    expect(button).not.toContain('calendar-nav-btn')
    const arrow = styles.match(/\.calendar-nav-arrow \{([^}]*)\}/)?.[1] ?? ''
    expect(arrow).toMatch(/align-self: stretch/)
    expect(arrow).toMatch(/background-color: transparent/)
  })

  it('marks each arrow with a soft circle at rest instead of divider lines', () => {
    // Touch screens never hover, so the arrows must read as buttons without it.
    const circle = styles.match(/\.calendar-nav-arrow::before \{([^}]*)\}/)?.[1] ?? ''
    expect(circle).toMatch(/border-radius: 9999px/)
    expect(circle).toMatch(/background-color: var\(--dp-accent-bg\)/)
    expect(styles).not.toMatch(/\.calendar-nav-arrow::after/)
  })

  it('keeps every arrow segment square so its circle sits concentric with the capsule end', () => {
    const group = styles.match(/\.calendar-nav-group \{([^}]*)\}/)?.[1] ?? ''
    const arrow = styles.match(/\.calendar-nav-arrow \{([^}]*)\}/)?.[1] ?? ''
    expect(group).toMatch(/height: 2\.75rem/)
    expect(arrow).toMatch(/width: 2\.75rem/)
    // A narrower compact segment pushed the circle against the capsule's side edge.
    expect(styles).not.toMatch(/\.calendar-nav-group-compact \.calendar-nav-arrow/)
  })

  it('tints the whole capsule for the year-month button but only the circle for an arrow', () => {
    const capsule = styles.slice(styles.indexOf('/* Calendar month capsule'))
    expect(capsule).toMatch(/\.calendar-nav-group:has\(\.calendar-nav-month:hover\) \{[^}]*background-color: var\(--dp-accent-bg\)/)
    expect(capsule).toMatch(/\.calendar-nav-arrow:hover::before \{[^}]*background-color: var\(--dp-accent-bg-hover\)/)
    expect(capsule).toMatch(/\.calendar-nav-arrow:active::before \{[^}]*background-color: var\(--dp-accent-bg-hover\)/)
  })
})

describe('CalendarMonthNavigator year-month button', () => {
  const button = template.slice(
    template.indexOf('@click="handleMonthButtonClick"'),
    template.indexOf('</button>', template.indexOf('@click="handleMonthButtonClick"'))
  )

  it('shows a picker chevron so it reads as a button', () => {
    expect(button).toContain('calendar-nav-month')
    // The shared hover-only surface flashed a grey scaled block and showed nothing at rest.
    expect(button).not.toContain('calendar-nav-btn')
    expect(button).toContain('<ChevronDown')
  })
})
