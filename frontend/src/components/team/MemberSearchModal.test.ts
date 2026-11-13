import { describe, expect, it } from 'vitest'
import memberSearchModal from './MemberSearchModal.vue?raw'

describe('team member search modal', () => {
  it('does not render candidate email addresses', () => {
    expect(memberSearchModal).not.toContain('member.email')
    expect(memberSearchModal).not.toContain('team.memberSearch.columns.email')
  })

  it('shows the translated server reason when adding a member fails', () => {
    expect(memberSearchModal).toContain(
      "showError(resolveApiErrorMessage(error, { fallbackKey: 'team.memberSearch.addFailed' }, t))",
    )
  })
})
