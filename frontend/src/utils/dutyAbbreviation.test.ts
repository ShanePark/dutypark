import { describe, expect, it } from 'vitest'
import { dutyAbbreviation, dutyLabel, dutyTypeLabel } from './dutyAbbreviation'

describe('duty abbreviations', () => {
  it.each([
    ['야간근무', undefined, '야'],
    ['야간근무', null, '야'],
    ['야간근무', '', '야'],
    ['야간근무', '  ', '야'],
    ['야간근무', ' N ', 'N'],
    ['주간근무', null, '주'],
    ['🌙야간', null, '🌙'],
    ['👩‍⚕️근무', null, '👩‍⚕️'],
    ['e\u0301vening', null, 'e\u0301'],
    ['', null, ''],
  ])('resolves %s with override %s', (name, override, expected) => {
    expect(dutyAbbreviation(name, override)).toBe(expected)
  })

  it('uses compact labels only for the owner, not for managers viewing others', () => {
    const type = { name: '야간근무', abbreviation: 'N', shortName: 'N' }
    expect(dutyTypeLabel(type, true)).toBe('N')
    expect(dutyTypeLabel(type, false)).toBe('야간근무')
    expect(type.name).toBe('야간근무')
  })

  it('supports older payloads, hidden duties and widget-sized daily labels', () => {
    expect(dutyTypeLabel({ name: '야간근무' }, true)).toBe('야')
    const duty = { dutyType: '야간근무', dutyAbbreviation: 'N' }
    expect(dutyLabel(duty, true)).toBe('N')
    expect(dutyLabel(duty, false)).toBe('야간근무')
    expect(dutyLabel({ dutyType: '휴무' }, true)).toBe('휴')
    expect(dutyLabel({ dutyType: null }, true)).toBe('')
  })
})
