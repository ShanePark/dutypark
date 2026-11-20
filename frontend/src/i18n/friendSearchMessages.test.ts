import { describe, expect, it } from 'vitest'
import en from './messages/en'
import ko from './messages/ko'

// The backend friend search (MemberRepository.searchPossibleFriends) matches member names only.
describe('friend search placeholder', () => {
  it('describes a name-only search', () => {
    expect(ko.friendSearchModal.searchPlaceholder).toBe('이름으로 검색')
    expect(en.friendSearchModal.searchPlaceholder).toBe('Search by name')
  })
})
