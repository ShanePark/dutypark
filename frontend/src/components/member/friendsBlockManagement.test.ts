import { describe, expect, it } from 'vitest'
import friendsView from '@/views/member/FriendsView.vue?raw'
import friendRequestList from './FriendRequestList.vue?raw'
import friendCard from './FriendCard.vue?raw'
import friendActionMenu from './FriendActionMenu.vue?raw'
import blockedMemberList from './BlockedMemberList.vue?raw'
import en from '@/i18n/messages/en'
import ko from '@/i18n/messages/ko'

/**
 * The friends page was split into request list / friend card / action menu / blocked list.
 * These markers pin each piece to its own component so the page stays an assembly point,
 * and cover the blocking flow the split was made for.
 */

function functionBody(source: string, name: string): string {
  const start = source.indexOf(`function ${name}(`)
  expect(start, `missing function ${name}`).toBeGreaterThan(-1)
  const next = source.indexOf('\nasync function ', start + 1)
  const plain = source.indexOf('\nfunction ', start + 1)
  const end = [next, plain].filter((index) => index > -1).sort((a, b) => a - b)[0] ?? source.length
  return source.slice(start, end)
}

describe('friends page composition', () => {
  it('assembles the page from the extracted components', () => {
    for (const component of ['FriendRequestList', 'FriendCard', 'FriendActionMenu', 'BlockedMemberList']) {
      expect(friendsView, component).toContain(`<${component}`)
    }
  })

  it('moves each extracted block out of the page', () => {
    expect(friendRequestList).toContain('friend-request-received')
    expect(friendsView).not.toContain('friend-request-received')

    expect(friendActionMenu).toContain('<Teleport to="body">')
    expect(friendsView).not.toContain('<Teleport')
    expect(friendsView).not.toContain('friend-menu-header')
  })

  it('keeps the drag-and-drop contract between the page and the friend card', () => {
    expect(friendCard).toContain(':data-member-id="friend.member.id"')
    expect(friendCard).toContain('pinned-friend')
    expect(friendCard).toContain('handle friend-drag-handle')

    expect(friendsView).toContain("querySelectorAll('.pinned-friend')")
    expect(friendsView).toContain("getAttribute('data-member-id')")
  })
})

describe('friend blocking', () => {
  it('offers block under unfriend in the kebab menu', () => {
    const unfriendAt = friendActionMenu.indexOf("friends.actions.removeFriend")
    const blockAt = friendActionMenu.indexOf("friends.block.action")

    expect(unfriendAt).toBeGreaterThan(-1)
    expect(blockAt).toBeGreaterThan(unfriendAt)
    expect(friendActionMenu).toContain("emit('block')")
  })

  it('confirms before blocking, then refreshes both lists', () => {
    const block = functionBody(friendsView, 'blockFriend')

    expect(block).toMatch(/confirmDelete\([\s\S]*?friends\.block\.confirmMessage/)
    expect(block).toMatch(/confirmDelete\([\s\S]*?blockApi\.block\(/)
    expect(block).toContain('loadFriendInfo()')
    expect(block).toContain('loadBlockedMembers()')
  })

  it('unblocks immediately without a confirmation', () => {
    const unblock = functionBody(friendsView, 'unblockMember')

    expect(unblock).toContain('blockApi.unblock(')
    expect(unblock).not.toContain('confirm')
  })

  it('always renders the blocked section with an empty state', () => {
    expect(blockedMemberList).toMatch(/<template>\s*<div class="rounded-2xl/)
    expect(blockedMemberList).toContain('friends.block.sectionTitle')
    expect(blockedMemberList).toContain('{{ members.length }}')
    expect(blockedMemberList).toContain('v-else-if="members.length === 0"')
    expect(blockedMemberList).toContain('friends.block.empty')
    expect(blockedMemberList).toContain('friends.block.unblockAction')
    expect(blockedMemberList).toContain("emit('unblock', member)")
  })
})

describe('block translations', () => {
  it.each([
    ['ko', ko],
    ['en', en],
  ])('defines the complete block copy in %s', (_locale, messages) => {
    const block = messages.friends.block

    expect(block.action).toBeTruthy()
    expect(block.sectionTitle).toBeTruthy()
    expect(block.empty).toBeTruthy()
    expect(block.blockedAt).toContain('{date}')
    expect(block.unblockAction).toBeTruthy()
    expect(block.confirmTitle).toBeTruthy()
    expect(block.confirmMessage).toContain('{name}')
    expect(block.confirmAction).toBeTruthy()
    expect(block.blockSuccess).toContain('{name}')
    expect(block.blockFailed).toBeTruthy()
    expect(block.unblockSuccess).toContain('{name}')
    expect(block.unblockFailed).toBeTruthy()
  })
})
