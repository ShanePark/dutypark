import { describe, expect, it } from 'vitest'
import { useLoginAttemptGate } from './useLoginAttemptGate'

describe('useLoginAttemptGate', () => {
  it('allows only one login method until the active attempt finishes', () => {
    const gate = useLoginAttemptGate()

    expect(gate.startAttempt('PASSWORD')).toBe(true)
    expect(gate.isAttemptPending.value).toBe(true)
    expect(gate.activeAttempt.value).toBe('PASSWORD')
    expect(gate.startAttempt('KAKAO')).toBe(false)
    expect(gate.startAttempt('NAVER')).toBe(false)

    gate.finishAttempt('KAKAO')
    expect(gate.activeAttempt.value).toBe('PASSWORD')

    gate.finishAttempt('PASSWORD')
    expect(gate.isAttemptPending.value).toBe(false)
    expect(gate.startAttempt('NAVER')).toBe(true)
  })
})
