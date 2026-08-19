import { describe, expect, it } from 'vitest'
import en from './messages/en'
import ko from './messages/ko'

const locales = { ko, en }

// The pin row already shows its state through the star icon and the toggle, so the label
// stays static instead of spelling out "pinned"/"not pinned".
describe('D-Day pin label', () => {
  it.each(Object.entries(locales))('%s exposes a single state-independent label', (_locale, messages) => {
    const ddayDetail = messages.duty.ddayDetail as Record<string, unknown>
    expect(Object.keys(ddayDetail)).not.toContain('pinEnabled')
    expect(Object.keys(ddayDetail)).not.toContain('pinDisabled')
    expect(ddayDetail.pin).toBeTruthy()
  })

  it('reads as a plain calendar-visibility label', () => {
    expect(ko.duty.ddayDetail.pin).toBe('달력에 표시')
    expect(en.duty.ddayDetail.pin).toBe('Show on calendar')
  })
})
