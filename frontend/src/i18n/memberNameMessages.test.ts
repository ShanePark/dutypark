import { describe, expect, it } from 'vitest'
import en from './messages/en'
import ko from './messages/ko'

describe('member name messages', () => {
  it('uses the localized default signup name prefix', () => {
    expect(ko.auth.ssoSignup.username.defaultPrefix).toBe('사용자')
    expect(en.auth.ssoSignup.username.defaultPrefix).toBe('User')
  })

  it.each([ko, en])('defines the name change UI messages', (messages) => {
    const nameChange = messages.member.profile.nameChange
    for (const key of ['action', 'modalTitle', 'placeholder', 'hint', 'required', 'submit', 'submitting', 'success', 'failed'] as const) {
      expect(nameChange[key]).toBeTruthy()
    }
  })
})
