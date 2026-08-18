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

  it('asks before unblocking, since it undoes a protective action', () => {
    const unblock = functionBody(friendsView, 'unblockMember')

    expect(unblock).toMatch(/confirm\([\s\S]*?friends\.block\.unblockConfirmMessage/)
    expect(unblock).toMatch(/confirm\([\s\S]*?blockApi\.unblock\(/)
  })

  it('asks before sending a family request, the way a friend request already does', () => {
    const addFamily = functionBody(friendsView, 'addFamily')

    expect(addFamily).toMatch(/confirm\([\s\S]*?friends\.messages\.familyRequestConfirm/)
    expect(addFamily).toMatch(/confirm\([\s\S]*?friendApi\.sendFamilyRequest\(/)
  })

  it('closes the kebab menu before running its action, so a dialog it opens stays clickable', () => {
    // The menu keeps a full-screen click catcher above the confirmation dialog's layer. Left open,
    // the catcher swallows the dialog's buttons and the tap only dismisses the menu.
    for (const [wrapper, action] of [
      ['addFamilyFromMenu', 'addFamily('],
      ['demoteFromFamilyFromMenu', 'demoteFromFamily('],
      ['unfriendFromMenu', 'unfriend('],
      ['blockFromMenu', 'blockFriend('],
    ] as const) {
      const body = functionBody(friendsView, wrapper)
      const closedAt = body.indexOf('closeDropdown()')

      expect(closedAt, wrapper).toBeGreaterThan(-1)
      expect(closedAt, wrapper).toBeLessThan(body.indexOf(action))
    }

    for (const handler of ['addFamily', 'demoteFromFamily', 'unfriend', 'blockFriend']) {
      expect(functionBody(friendsView, handler), handler).not.toContain('closeDropdown()')
    }
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

describe('blocked list loading failures', () => {
  it('remembers that the blocked list failed to load and clears it on the next try', () => {
    const load = functionBody(friendsView, 'loadBlockedMembers')

    expect(load).toContain('blockedLoadFailed.value = false')
    expect(load).toContain('blockedLoadFailed.value = true')
    expect(friendsView).toContain(':load-failed="blockedLoadFailed"')
    expect(friendsView).toContain('@retry="loadBlockedMembers"')
  })

  it('shows a failure state with a retry instead of the empty state', () => {
    expect(blockedMemberList).toContain('loadFailed?: boolean')
    expect(blockedMemberList).toMatch(
      /v-else-if="loadFailed"[\s\S]*?friends\.messages\.loadFailed[\s\S]*?emit\('retry'\)[\s\S]*?common\.actions\.retry/
    )
    // A failed load must not fall through to "no blocked users", nor claim a count of zero.
    expect(blockedMemberList).toMatch(/v-else-if="loadFailed"[\s\S]*?v-else-if="members\.length === 0"/)
    expect(blockedMemberList).toMatch(/v-if="!loadFailed"[\s\S]*?\{\{ members\.length \}\}/)
  })

  it('disables the unblock button while its request is in flight', () => {
    const unblock = functionBody(friendsView, 'unblockMember')

    expect(unblock).toContain('if (unblockingId.value !== null) return')
    expect(unblock).toContain('unblockingId.value = member.id')
    expect(unblock).toContain('unblockingId.value = null')
    expect(friendsView).toContain(':unblocking-id="unblockingId"')
    expect(blockedMemberList).toContain('unblockingId?: number | null')
    expect(blockedMemberList).toContain(':disabled="unblockingId === member.id"')
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
    expect(block.unblockConfirmTitle).toBeTruthy()
    expect(block.unblockConfirmMessage).toContain('{name}')
  })

  it.each([
    ['ko', ko],
    ['en', en],
  ])('defines the family request confirmation copy in %s', (_locale, messages) => {
    expect(messages.friends.messages.familyRequestTitle).toBeTruthy()
    expect(messages.friends.messages.familyRequestConfirm).toContain('{name}')
  })
})
