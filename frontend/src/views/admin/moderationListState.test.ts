import { describe, expect, it } from 'vitest'
import {
  createLatestRequestTracker,
  lastValidPage,
} from './moderationListState'

describe('moderation list request state', () => {
  it('accepts only the most recently started request', () => {
    const tracker = createLatestRequestTracker()
    const first = tracker.start()
    const second = tracker.start()

    expect(tracker.isLatest(first)).toBe(false)
    expect(tracker.isLatest(second)).toBe(true)
  })

  it('moves a removed last page back to the final page that still exists', () => {
    expect(lastValidPage(1, 1)).toBe(0)
    expect(lastValidPage(3, 2)).toBe(1)
    expect(lastValidPage(1, 0)).toBe(0)
    expect(lastValidPage(1, 3)).toBe(1)
  })
})
