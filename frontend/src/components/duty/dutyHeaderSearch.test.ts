import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import header from './DutyHeaderControls.vue?raw'

const styles = readFileSync(resolve(process.cwd(), 'src/style.css'), 'utf8')

const template = header.slice(header.indexOf('<template>'))

describe('duty header search', () => {
  it('shows only a search icon on mobile, which opens the search modal', () => {
    const start = template.indexOf('duty-header-search-icon')
    expect(start).toBeGreaterThan(-1)
    const button = template.slice(template.lastIndexOf('<button', start), template.indexOf('</button>', start))
    expect(button).toContain('sm:hidden')
    expect(button).toContain(`@click="emit('open-search-modal')"`)
    expect(button).toContain('<Search')
    // The icon's own unlayered display rule outranks sm:hidden, so CSS must hide it too.
    expect(styles).toMatch(/@media \(min-width: 640px\) \{\s*\.duty-header-search-icon \{\s*display: none;/)
  })

  it('keeps the inline search field for the wider layout only', () => {
    // The field was too narrow beside the month capsule on phones.
    expect(template).toMatch(/v-if="canSearch"\s+class="hidden [^"]*sm:flex/)
  })
})
