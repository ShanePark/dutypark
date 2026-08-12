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
      expect(deletion.name.placeholder).toBeTruthy()
      expect(deletion.final.irreversible).toBeTruthy()
      expect(deletion.errors.oauthPopupBlocked).toBeTruthy()
      expect(deletion.errors.oauthAccountMismatch).toBeTruthy()
      expect(deletion.oauth.callbackNoOpener).toBeTruthy()
      expect(deletion.completion.signedOut).toBeTruthy()
      expect(deletion.completion.asyncCleanup).toBeTruthy()
    },
  )
})
