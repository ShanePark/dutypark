import { describe, expect, it } from 'vitest'
import { createStaticNotificationTranslate } from './staticTranslate'
import { scheduleChangeMessage } from './scheduleChangeMessage'

const t = createStaticNotificationTranslate('ko')
const time = (startDateTime: string, endDateTime: string) => ({ startDateTime, endDateTime })
function changes(beforeStart: string, beforeEnd: string, afterStart: string, afterEnd: string) {
  return { scheduleId: 's', scheduleVersion: 3, time: { before: time(beforeStart, beforeEnd), after: time(afterStart, afterEnd) } }
}
describe('compact schedule change rows', () => {
  it('omits dates for same-day time changes', () => {
    expect(scheduleChangeMessage(changes('2026-11-24T14:00:00', '2026-11-24T14:30:00', '2026-11-24T15:00:00', '2026-11-24T15:30:00'), t)).toBe('14:00–14:30 → 15:00–15:30')
  })
  it('shows month and day only once per same-day range when moved', () => {
    expect(scheduleChangeMessage(changes('2026-11-24T14:00:00', '2026-11-24T14:30:00', '2026-11-25T15:00:00', '2026-11-25T15:30:00'), t)).toBe('11/24 14:00–14:30 → 11/25 15:00–15:30')
  })
  it('includes both endpoint dates for cross-midnight ranges and years when needed', () => {
    expect(scheduleChangeMessage(changes('2026-12-31T23:00:00', '2027-01-01T00:30:00', '2027-01-01T23:00:00', '2027-01-02T00:30:00'), t)).toBe('2026/12/31 23:00–2027/1/1 00:30 → 2027/1/1 23:00–2027/1/2 00:30')
  })
  it('keeps meaningful words together and separates field rows', () => {
    expect(scheduleChangeMessage({ scheduleId: 's', scheduleVersion: 2, title: { before: 'old', after: 'new' }, description: { before: '회의실 A', after: '화상 통화' } }, t)).toBe('‘회의실 A’ → ‘화상 통화’')
  })
})
