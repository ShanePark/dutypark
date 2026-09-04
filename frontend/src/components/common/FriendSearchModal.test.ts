import { describe, expect, it } from 'vitest'
import friendSearchModal from './FriendSearchModal.vue?raw'

const styleStart = friendSearchModal.indexOf('<style')
const template = friendSearchModal.slice(friendSearchModal.indexOf('<template>'), styleStart > -1 ? styleStart : friendSearchModal.length)
const style = styleStart > -1 ? friendSearchModal.slice(styleStart) : ''

function ruleFor(selector: string) {
  const start = style.indexOf(`${selector} {`)
  expect(start, `missing rule for ${selector}`).toBeGreaterThan(-1)
  const end = style.indexOf('}', start)
  return style.slice(start, end)
}

describe('FriendSearchModal search field', () => {
  it('keeps the placeholder clear of the leading search icon', () => {
    const inputStart = template.indexOf('<input')
    const inputEnd = template.indexOf('/>', inputStart)
    const input = template.slice(inputStart, inputEnd)

    expect(input).toContain('friend-search-modal__search-input')

    const inputRule = ruleFor('.friend-search-modal__search-input')
    expect(inputRule).toContain('padding: 0.75rem 1rem 0.75rem 2.75rem')
    expect(inputRule).toContain('border-radius: 0.75rem')
  })
})
