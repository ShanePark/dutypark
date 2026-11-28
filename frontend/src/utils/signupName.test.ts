import { describe, expect, it } from 'vitest'
import {
  buildSsoSignupNameState,
  formatAppleDisplayName,
  generateDefaultSignupName,
  readSsoSignupNameState,
} from './signupName'

describe('generateDefaultSignupName', () => {
  it('appends four zero-padded random digits to the localized prefix', () => {
    expect(generateDefaultSignupName('사용자', () => 0.4821)).toBe('사용자4821')
    expect(generateDefaultSignupName('User', () => 0)).toBe('User0000')
    expect(generateDefaultSignupName('User', () => 0.0042)).toBe('User0042')
    expect(generateDefaultSignupName('User', () => 0.99999999)).toBe('User9999')
  })

  it('uses Math.random by default', () => {
    expect(generateDefaultSignupName('사용자')).toMatch(/^사용자\d{4}$/)
  })
})

describe('formatAppleDisplayName', () => {
  it('joins Latin names as "firstName lastName"', () => {
    expect(formatAppleDisplayName({ firstName: 'John', lastName: 'Kim' })).toBe('John Kim')
  })

  it('joins Hangul or CJK names as lastName + firstName without a space', () => {
    expect(formatAppleDisplayName({ firstName: '길동', lastName: '홍' })).toBe('홍길동')
    expect(formatAppleDisplayName({ firstName: 'Gildong', lastName: '홍' })).toBe('홍Gildong')
    expect(formatAppleDisplayName({ firstName: '太郎', lastName: '山田' })).toBe('山田太郎')
  })

  it('trims parts and tolerates a missing part', () => {
    expect(formatAppleDisplayName({ firstName: '  Jane ', lastName: null })).toBe('Jane')
    expect(formatAppleDisplayName({ lastName: ' Doe ' })).toBe('Doe')
    expect(formatAppleDisplayName({ firstName: ' 길동 ' })).toBe('길동')
  })

  it('falls back to the first name when the full name exceeds 10 characters', () => {
    expect(formatAppleDisplayName({ firstName: 'Johnathan', lastName: 'Smith' })).toBe('Johnathan')
  })

  it('truncates to 10 characters when the first name alone is still too long', () => {
    expect(formatAppleDisplayName({ firstName: 'Maximiliano', lastName: 'Rodriguez' })).toBe('Maximilian')
    expect(formatAppleDisplayName({ lastName: 'Wolfeschlegelstein' })).toBe('Wolfeschle')
  })

  it('does not leave trailing whitespace after truncation', () => {
    expect(formatAppleDisplayName({ firstName: 'Ann Marie Lee', lastName: 'X' })).toBe('Ann Marie')
  })

  it('returns an empty string when Apple shared no usable name', () => {
    expect(formatAppleDisplayName(null)).toBe('')
    expect(formatAppleDisplayName(undefined)).toBe('')
    expect(formatAppleDisplayName({})).toBe('')
    expect(formatAppleDisplayName({ firstName: '   ', lastName: '' })).toBe('')
  })
})

describe('SSO signup name navigation state', () => {
  it('round-trips a non-empty name and omits state for an empty one', () => {
    expect(readSsoSignupNameState(buildSsoSignupNameState(' 홍길동 '))).toBe('홍길동')
    expect(buildSsoSignupNameState('   ')).toBeUndefined()
  })

  it('reads only a string name and keeps it within the member name limit', () => {
    expect(readSsoSignupNameState(null)).toBe('')
    expect(readSsoSignupNameState({ back: '/auth/login' })).toBe('')
    expect(readSsoSignupNameState({ ssoSignupName: 42 })).toBe('')
    expect(readSsoSignupNameState({ ssoSignupName: 'Wolfeschlegelstein' })).toBe('Wolfeschle')
  })
})
