import { describe, expect, it } from 'vitest'
import en from './messages/en'
import ko from './messages/ko'

describe('login failure messages', () => {
  it.each([ko, en])('separates connection, server and unclassified failures', (messages) => {
    const error = messages.auth.login.error

    expect(error.generic).toBeTruthy()
    expect(error.network).toBeTruthy()
    expect(error).not.toHaveProperty('invalidCredentials')
    expect(error.server).toContain('{status}')
    expect(error.unknown).toContain('{status}')
    expect(error.network).not.toBe(error.generic)
    expect(error.server).not.toBe(error.unknown)
  })
})
