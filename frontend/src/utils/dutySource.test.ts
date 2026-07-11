import { describe, expect, it } from 'vitest'
import { dutySourcePatternLabelKey, isInheritedDutySource } from './dutySource'

describe('duty source presentation', () => {
  it('distinguishes current, preserved, unset and manual sources', () => {
    expect(dutySourcePatternLabelKey('PATTERN')).toBe('duty.common.currentPattern')
    expect(dutySourcePatternLabelKey('PATTERN_PAUSED')).toBe('duty.common.pausedPattern')
    expect(dutySourcePatternLabelKey('DEFAULT_OFF')).toBe('duty.common.patternNotSet')
    expect(dutySourcePatternLabelKey('OVERRIDE')).toBe('duty.common.usePattern')
    expect(dutySourcePatternLabelKey(null)).toBe('duty.common.usePattern')
  })

  it('treats every non-manual default result as inherited', () => {
    expect(isInheritedDutySource('PATTERN')).toBe(true)
    expect(isInheritedDutySource('PATTERN_PAUSED')).toBe(true)
    expect(isInheritedDutySource('DEFAULT_OFF')).toBe(true)
    expect(isInheritedDutySource('OVERRIDE')).toBe(false)
    expect(isInheritedDutySource(null)).toBe(false)
    expect(isInheritedDutySource(undefined)).toBe(false)
  })
})
