import { describe, expect, it } from 'vitest'
import { calendarTagLabel, memberInitials } from './memberName'

// Shared with iOS MemberNameInitials (docs/design/member-name-length.md).
describe('memberInitials', () => {
  it.each([
    ['Shane Park', 'S.P'],
    ['Mary Jane Lee', 'M.J.L'],
    ['shane park', 'S.P'],
    ['  Shane   Park  ', 'S.P'],
    ['Jean-Luc Picard', 'J.P'],
    ['Élodie Durand', 'É.D'],
    ['Christopher', null],
    ['박세현', null],
    ['박 세현', null],
    ['Shane 박', null],
    ['', null],
  ])('%j -> %j', (name, expected) => {
    expect(memberInitials(name)).toBe(expected)
  })
})

describe('calendarTagLabel', () => {
  it('keeps names of up to three characters whole', () => {
    expect(calendarTagLabel('박세현')).toBe('박세현')
    expect(calendarTagLabel('Amy')).toBe('Amy')
    expect(calendarTagLabel('A B')).toBe('A B')
  })

  it('uses initials for a longer name that has them', () => {
    expect(calendarTagLabel('Shane Park')).toBe('S.P')
    expect(calendarTagLabel('Mary Jane Lee')).toBe('M.J.L')
  })

  it('keeps the first two characters and an ellipsis for a longer name without initials', () => {
    expect(calendarTagLabel('남궁민수')).toBe('남궁…')
    expect(calendarTagLabel('Christopher')).toBe('Ch…')
    expect(calendarTagLabel('Shane 박')).toBe('Sh…')
  })
})
