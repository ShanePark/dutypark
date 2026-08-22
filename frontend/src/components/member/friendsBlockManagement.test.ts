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

  it('asks before removing a friend from favorites', () => {
    const unpin = functionBody(friendsView, 'unpinFriend')

    expect(unpin).toContain('friend?.pinOrder == null')
    expect(unpin).toMatch(/confirm\([\s\S]*?friends\.messages\.unpinConfirm/)
    expect(unpin).toMatch(/confirm\([\s\S]*?friendApi\.unpinFriend\(/)
  })

  it('treats a zero pin order as a pinned friend', () => {
    expect(friendsView).toContain('a.pinOrder == null ? 1 : 0')
    expect(friendCard).toContain('friend.pinOrder != null')
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

  it.each([
    ['ko', ko, {
      dashboardSection: '친구',
      friendsSection: '친구 목록',
      add: '즐겨찾기에 추가',
      remove: '즐겨찾기 해제',
      addFailed: '친구를 즐겨찾기에 추가하지 못했습니다.',
      removeFailed: '친구를 즐겨찾기에서 해제하지 못했습니다.',
      confirmTitle: '즐겨찾기 해제',
      confirm: '{name}님을 즐겨찾기에서 해제할까요?',
      helpOpenAriaLabel: '친구 즐겨찾기 및 순서 도움말',
      helpTitle: '즐겨찾는 친구 순서 변경하기',
      helpPinTitle: '자주 보는 친구를 즐겨찾기에 추가하세요',
      helpPinText: '별 아이콘을 누르면 즐겨찾는 친구로 추가되어 목록 맨 위에 표시됩니다. 즐겨찾는 친구는 원하는 순서로 바꿀 수 있어요.',
      helpReorderText: '즐겨찾는 친구가 두 명 이상이면 카드 오른쪽 아래에 손잡이가 나타납니다. 손잡이를 끌어 원하는 자리에 놓으세요.',
      helpNote: '즐겨찾기에 추가하지 않은 친구는 기본 순서대로 아래에 표시됩니다.',
    }],
    ['en', en, {
      dashboardSection: 'Friends',
      friendsSection: 'Friends list',
      add: 'Add to favorites',
      remove: 'Remove from favorites',
      addFailed: 'Failed to add the friend to your favorites.',
      removeFailed: 'Failed to remove the friend from your favorites.',
      confirmTitle: 'Remove from favorites',
      confirm: 'Remove {name} from your favorites?',
      helpOpenAriaLabel: 'How to favorite and reorder friends',
      helpTitle: 'Reorder favorite friends',
      helpPinTitle: 'Add friends you check often to your favorites',
      helpPinText: 'Tap the star to add a friend to your favorites. Favorite friends move to the top and can be reordered.',
      helpReorderText: 'Once two or more friends are in your favorites, a handle appears at the bottom right of each card. Drag it to the position you want.',
      helpNote: 'Friends not in your favorites stay below in the default order.',
    }],
  ] as const)('uses the favorite-friend terminology consistently in %s', (_locale, messages, expected) => {
    expect(messages.dashboard.labels.friends).toBe(expected.dashboardSection)
    expect(messages.dashboard.actions.pin).toBe(expected.add)
    expect(messages.dashboard.actions.unpin).toBe(expected.remove)
    expect(messages.dashboard.messages.pinFailed).toBe(expected.addFailed)
    expect(messages.dashboard.messages.unpinFailed).toBe(expected.removeFailed)
    expect(messages.dashboard.messages.unpinTitle).toBe(expected.confirmTitle)
    expect(messages.dashboard.messages.unpinConfirm).toBe(expected.confirm)

    expect(messages.friends.sections.list).toBe(expected.friendsSection)
    expect(messages.friends.actions.pin).toBe(expected.add)
    expect(messages.friends.actions.unpin).toBe(expected.remove)
    expect(messages.friends.messages.pinFailed).toBe(expected.addFailed)
    expect(messages.friends.messages.unpinFailed).toBe(expected.removeFailed)
    expect(messages.friends.messages.unpinTitle).toBe(expected.confirmTitle)
    expect(messages.friends.messages.unpinConfirm).toBe(expected.confirm)
    expect(messages.friends.help.openAriaLabel).toBe(expected.helpOpenAriaLabel)
    expect(messages.friends.help.title).toBe(expected.helpTitle)
    expect(messages.friends.help.pinTitle).toBe(expected.helpPinTitle)
    expect(messages.friends.help.pinText).toBe(expected.helpPinText)
    expect(messages.friends.help.reorderText).toBe(expected.helpReorderText)
    expect(messages.friends.help.note).toBe(expected.helpNote)
  })
})
