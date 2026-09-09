import { describe, expect, it } from 'vitest'
import {
  dutyAbbreviation,
  dutyLabel,
  dutyTypeLabel,
  isValidDutyAbbreviation,
  normalizeDutyAbbreviation,
} from './dutyAbbreviation'

describe('duty abbreviations', () => {
  it.each([
    ['야간근무', undefined, '야'],
    ['야간근무', null, '야'],
    ['야간근무', '', '야'],
    ['야간근무', '  ', '야'],
    ['야간근무', ' N ', 'N'],
    ['야간근무', 'n', 'n'],
    ['야간근무', 'Ab', 'Ab'],
    ['야간근무', '가', '가'],
    ['야간근무', 'NN', 'NN'],
    ['야간근무', '가나다', '가나다'],
    ['야간근무', 'ABCD', '야'],
    ['야간근무', '1', '야'],
    ['야간근무', 'ㄱ', '야'],
    ['주간근무', null, '주'],
    ['', null, ''],
  ])('resolves %s with override %s', (name, override, expected) => {
    expect(dutyAbbreviation(name, override)).toBe(expected)
  })

  it.each([
    ['', true],
    ['A', true],
    ['Z', true],
    ['가', true],
    ['힣', true],
    ['a', true],
    ['Ab', true],
    ['ABC', true],
    ['가나다', true],
    ['ABCD', false],
    ['가나다라', false],
    ['1', false],
    ['ㄱ', false],
    ['🌙', false],
    ['e\u0301', false],
  ])('checks whether %s is a valid override', (value, expected) => {
    expect(isValidDutyAbbreviation(value)).toBe(expected)
  })

  it('trims overrides without changing ASCII letter case or other input', () => {
    expect(normalizeDutyAbbreviation(' n ')).toBe('n')
    expect(normalizeDutyAbbreviation('Ab')).toBe('Ab')
    expect(normalizeDutyAbbreviation('가')).toBe('가')
    expect(normalizeDutyAbbreviation('1/10')).toBe('1/10')
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
