import { describe, expect, it } from 'vitest'
import en from './messages/en'
import ko from './messages/ko'

describe('Apple web sign-in messages', () => {
  it.each([ko, en])('defines the login UI and backend error messages', (messages) => {
    expect(messages.auth.login.social.apple).toBeTruthy()
    expect(messages.auth.login.apple).not.toHaveProperty('configurationUnavailable')
    expect(messages.auth.login.apple).not.toHaveProperty('localDevelopmentUnsupported')
    expect(messages.auth.login.apple.cancelled).toBeTruthy()
    expect(messages.auth.login.apple.providerUnavailable).toBeTruthy()
    expect(messages.auth.login.apple.invalidCredential).toBeTruthy()
    expect(messages.auth.login.apple.generic).toBeTruthy()
    expect(messages.auth.login.apple.retry).toBeTruthy()
    expect(messages.auth.login.apple.retrying).toBeTruthy()
    expect(messages.member.sso.prompts.appleTitle).toBeTruthy()
    expect(messages.member.sso.prompts.appleMessage).toBeTruthy()
    expect(messages.member.sso.apple).not.toHaveProperty('localDevelopmentUnsupported')
    expect(messages.member.sso.apple).not.toHaveProperty('configurationUnavailable')
    expect(messages.member.sso.apple.providerUnavailable).toBeTruthy()
    expect(messages.member.sso.apple.invalidCredential).toBeTruthy()
    expect(messages.member.sso.apple.linkFailed).toBeTruthy()
    expect(messages.member.sso.apple.refreshFailedTitle).toBeTruthy()
    expect(messages.member.sso.apple.refreshFailed).toBeTruthy()
    expect(messages.member.sso.apple.retry).toBeTruthy()
    expect(messages.apiErrors.auth.apple.configurationUnavailable).toBeTruthy()
    expect(messages.apiErrors.auth.apple.credential.invalid).toBeTruthy()
    expect(messages.apiErrors.auth.apple.provider.unavailable).toBeTruthy()
  })
})
