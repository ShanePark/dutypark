import { describe, expect, it } from 'vitest'
import friendSearchModal from './FriendSearchModal.vue?raw'

const template = friendSearchModal.slice(
  friendSearchModal.indexOf('<template>'),
  friendSearchModal.indexOf('<style') > -1 ? friendSearchModal.indexOf('<style') : friendSearchModal.length,
)

describe('FriendSearchModal search field', () => {
  it('keeps the placeholder clear of the leading search icon', () => {
    const inputStart = template.indexOf('<input')
    const inputEnd = template.indexOf('/>', inputStart)
    const input = template.slice(inputStart, inputEnd)

    // form-control-neutral sets padding-inline in an unlayered component rule, so the
    // important utility is needed for the icon-specific left padding to win the cascade.
    expect(input).toContain('!pl-11')
  })
})
