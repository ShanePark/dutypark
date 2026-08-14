import { describe, expect, it } from 'vitest'
import en from './messages/en'
import ko from './messages/ko'

describe('social account unlink translations', () => {
  it.each([
    ['ko', ko],
    ['en', en],
  ])('defines the complete unlink copy in %s', (_locale, messages) => {
    const unlink = messages.member.sso.unlink

    expect(unlink.action).toBeTruthy()
    expect(unlink.unlinking).toBeTruthy()
    expect(unlink.manageAction).toContain('{provider}')
    expect(unlink.manageHint).toBeTruthy()
    expect(unlink.modalTitle).toContain('{provider}')
    expect(unlink.localMappingTitle).toBeTruthy()
    expect(unlink.localMappingDescription).toContain('{provider}')
    expect(unlink.confirmTitle).toContain('{provider}')
    expect(unlink.confirmMessage).toContain('{provider}')
    expect(unlink.success).toContain('{provider}')
    expect(unlink.lastSocialReason).toBeTruthy()
    expect(unlink.lastSocialReason).not.toContain('{count}')
    expect(unlink).not.toHaveProperty('policyTitle')
    expect(unlink).not.toHaveProperty('availableReason')
    expect(unlink.errors.lastAuthenticationMethod).toBeTruthy()
    expect(unlink.errors.impersonationForbidden).toBeTruthy()
    expect(unlink.errors.generic).toBeTruthy()
  })
})
