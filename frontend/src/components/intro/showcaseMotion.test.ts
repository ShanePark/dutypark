import { strict as assert } from 'node:assert'
import { describe, it } from 'vitest'
import { getShowcaseProgress, getTransitionProgress, getScreenOpacity } from './showcaseMotion'

describe('showcase scroll motion', () => {
  it('keeps the first screen fully visible while the section scrolls up from below', () => {
    for (const top of [900, 600, 300, 0]) {
      const state = getShowcaseProgress(top, 5400, 900, 6)
      assert.deepEqual(state, { activeIndex: 0, featureProgress: 0 })
      assert.equal(getScreenOpacity(0, state.activeIndex, state.featureProgress, 6), 1)
      assert.equal(getScreenOpacity(1, state.activeIndex, state.featureProgress, 6), 0)
    }
  })

  it('keeps an opaque screen underneath every crossfade, including reverse scrolling', () => {
    for (let active = 0; active < 5; active++) {
      for (const progress of [0, 0.4, 0.8, 0.9, 0.99, 1, 0.99, 0.9, 0.8, 0]) {
        assert.equal(getScreenOpacity(active, active, progress, 6), 1)
        const next = getScreenOpacity(active + 1, active, progress, 6)
        assert.ok(next >= 0 && next <= 1)
        assert.equal(getScreenOpacity((active + 2) % 6, active, progress, 6), 0)
      }
      assert.ok(Math.abs(getScreenOpacity(active + 1, active, 0.9, 6) - 0.5) < 1e-10)
      assert.equal(getScreenOpacity(active + 1, active + 1, 0, 6), 1)
    }
  })

  it('keeps the final feature visible while scrolling out toward the CTA', () => {
    assert.deepEqual(getShowcaseProgress(-4500, 5400, 900, 6), { activeIndex: 5, featureProgress: 1 })
    assert.deepEqual(getShowcaseProgress(-5000, 5400, 900, 6), { activeIndex: 5, featureProgress: 1 })
    assert.equal(getTransitionProgress(5, 1, 6), 0)
    assert.equal(getScreenOpacity(5, 5, 1, 6), 1)
  })

  it('guards empty and non-scrollable showcases against invalid progress', () => {
    for (const count of [0, 1, 6]) {
      assert.deepEqual(getShowcaseProgress(0, 900, 900, count), { activeIndex: 0, featureProgress: 0 })
      assert.deepEqual(getShowcaseProgress(-100, 800, 900, count), { activeIndex: 0, featureProgress: 0 })
    }
    assert.equal(getScreenOpacity(0, 0, 0, 0), 0)
  })

  it('recomputes the active feature from resized container geometry', () => {
    assert.deepEqual(getShowcaseProgress(-1500, 5400, 900, 6), { activeIndex: 2, featureProgress: 0 })
    assert.deepEqual(getShowcaseProgress(-1000, 3600, 600, 6), { activeIndex: 2, featureProgress: 0 })
  })
})
