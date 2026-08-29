import { describe, expect, it } from 'vitest'
import en from './messages/en'
import ko from './messages/ko'

describe('account deletion translations', () => {
  it.each([['ko', ko], ['en', en]])(
    'defines the complete five-step and completion copy in %s',
    (_locale, messages) => {
      const deletion = messages.member.accountDeletion
      expect(deletion.progress).toContain('{current}')
      expect(deletion.progress).toContain('{total}')
      expect(deletion.scope.access).toBeTruthy()
      expect(deletion.scope.async).toBeTruthy()
      expect(deletion.team.transferRequired).toBeTruthy()
      expect(deletion.reauth.socialAction).toContain('{provider}')
      expect(deletion.reauth.appleOnlyMessage).toBeTruthy()
      expect(deletion.reauth.appleAlternativeMessage).toBeTruthy()
      expect(deletion.name.placeholder).toBeTruthy()
      expect(deletion.final.irreversible).toBeTruthy()
      expect(deletion.retentionNotice).toMatch(/문의|inquir/i)
      expect(deletion.retentionNotice).toMatch(/원문|original.*content/i)
      expect(deletion.retentionNotice).toMatch(/처리 기록|handling records/i)
      expect(deletion.retentionNotice).toMatch(/기록에 포함된 이름 및 콘텐츠|names or content snapshots included in those records/i)
      expect(deletion.retentionNotice).toMatch(/보관|retain/i)
      expect(deletion.retentionNotice).toMatch(/삭제|익명|delet|anonym/i)
      expect(deletion.retentionNotice).not.toMatch(/\d/)
      expect(deletion.retentionNotice).not.toMatch(/탈퇴 시점|captured at deletion/i)
      expect(messages.policy.privacy.title).toBeTruthy()
      expect(deletion.errors.oauthPopupBlocked).toBeTruthy()
      expect(deletion.errors.oauthAccountMismatch).toBeTruthy()
      expect(deletion.errors.appleRequiresIos).toBeTruthy()
      expect(deletion.oauth.callbackNoOpener).toBeTruthy()
      expect(deletion.completion.signedOut).toBeTruthy()
      expect(deletion.completion.asyncCleanup).toBeTruthy()
      expect(deletion.status.processingMessage).toContain('5')
      expect(deletion.status.completedMessage).toBeTruthy()
      expect(deletion.status.failedMessage).toBeTruthy()
      expect(deletion.status.unavailable).toBeTruthy()
      expect(deletion.status.support).toBeTruthy()
    },
  )

  it.each([['ko', ko], ['en', en]])(
    'defines Apple-specific disconnect semantics in %s',
    (_locale, messages) => {
      const unlink = messages.member.sso.unlink
      expect(messages.member.sso.providers.apple).toBeTruthy()
      expect(unlink.appleAuthorizationDescription).toBeTruthy()
      expect(unlink.appleConfirmMessage).toBeTruthy()
      expect(unlink.appleSuccess).toBeTruthy()
      expect(unlink.errors.appleProviderUnavailable).toBeTruthy()
    },
  )
})
