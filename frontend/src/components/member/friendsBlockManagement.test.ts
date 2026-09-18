import { describe, expect, it, vi } from 'vitest'
import { h } from 'vue'
import { createHostWrapper, findHostNode, findHostNodes, mountHost, triggerHost } from '@/test/hostRenderer'
import friendsView from '@/views/member/FriendsView.vue?raw'
import FriendCard from './FriendCard.vue'
import friendRequestList from './FriendRequestList.vue?raw'
import friendCard from './FriendCard.vue?raw'
import friendActionMenu from './FriendActionMenu.vue?raw'
import blockedMemberList from './BlockedMemberList.vue?raw'
import en from '@/i18n/messages/en'
import ko from '@/i18n/messages/ko'

vi.mock('vue-i18n', async (importOriginal) => ({
  ...await importOriginal<typeof import('vue-i18n')>(),
  useI18n: () => ({ t: (key: string) => key }),
}))

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
    expect(friendCard).toContain('friend-card')
    expect(friendCard).toContain('friend-card-calendar')
    expect(friendCard).toContain('friend-card-action')
    expect(friendCard).toContain('SlidersHorizontal')
    expect(friendCard).toContain('h-11 w-11')
    expect(friendCard).toContain('!h-11 !w-11')
    expect(friendCard).toContain('border-b')
    expect(friendCard).not.toContain('MoreVertical')
    expect(friendCard).toContain("friends.actions.manageFriend")
    expect(friendCard).not.toContain('pinned-friend')
    expect(friendCard).not.toContain('friend-drag-handle')

    expect(friendsView).toContain("draggable: '.friend-card'")
    expect(friendsView).not.toContain("handle: '.handle'")
    expect(friendsView).not.toContain("filter: '.friend-card-action'")
    expect(friendsView).not.toContain('preventOnFilter')
    expect(friendsView).toContain('friend-list-surface')
    expect(friendsView).toContain('friend-card-add')
    expect(friendsView).not.toContain('grid-cols-1')
    expect(friendsView).not.toContain('gap-2 sm:gap-3')
    expect(friendsView).toContain("querySelectorAll('.friend-card')")
    expect(friendsView).toContain("getAttribute('data-member-id')")
  })

  it('starts a deliberate long-press before moving a card', () => {
    expect(friendsView).toContain('delay: 150')
    expect(friendsView).toContain('delayOnTouchOnly: true')
    expect(friendsView).toContain('touchStartThreshold: 4')
    expect(friendCard).toContain('touch-manipulation')
  })

  it('persists the complete order and guards an in-flight save', () => {
    expect(friendsView).toContain('const isSavingFriendOrder = ref(false)')
    expect(friendsView).toContain('if (isSavingFriendOrder.value) return')
    expect(friendsView).toContain('friendApi.updateFriendsOrder(friendIds)')
    expect(friendsView).toContain('displayOrder: index + 1')
    expect(friendsView).toContain('friendInfo.value.friends = previousFriends')
  })
})

describe('friend card actions', () => {
  const friend = {
    member: { id: 31, name: 'Alex', hasProfilePhoto: false, profilePhotoVersion: 0 },
    duty: null,
    schedules: [],
    isFamily: false,
    displayOrder: null,
  }

  function mountFriend(displayOrder: number | null = null) {
    const events = {
      select: vi.fn(),
      openMenu: vi.fn(),
    }
    const mounted = mountHost(createHostWrapper(() => h(FriendCard, {
      friend: { ...friend, displayOrder },
      onSelect: events.select,
      onOpenMenu: events.openMenu,
    })))
    return { ...mounted, events }
  }

  it('separates calendar and friend-management actions into two touch regions', () => {
    const mounted = mountFriend()
    const buttons = findHostNodes(mounted.root, (node) => node.type === 'button')
    const calendar = findHostNode(mounted.root, (node) =>
      node.type === 'button' && String(node.props.class ?? '').includes('friend-card-calendar'))
    const management = findHostNode(mounted.root, (node) =>
      node.type === 'button' && String(node.props.class ?? '').includes('friend-card-action'))

    expect(calendar).toBeTruthy()
    expect(management).toBeTruthy()
    expect(String(management?.props.class)).toContain('friend-card-action')
    expect(String(management?.props.class)).toContain('h-11')
    expect(String(management?.props.class)).toContain('w-11')
    expect(buttons).toHaveLength(2)

    triggerHost(calendar!, 'onClick', { stopPropagation: vi.fn() })
    expect(mounted.events.select).toHaveBeenCalledOnce()
    triggerHost(management!, 'onClick', { stopPropagation: vi.fn(), currentTarget: management })

    expect(mounted.events.openMenu).toHaveBeenCalledOnce()
    expect(mounted.events.select).toHaveBeenCalledOnce()
    mounted.app.unmount()
  })

  it('does not make an unlabelled card surface navigate', () => {
    const mounted = mountFriend(3)
    const card = findHostNode(mounted.root, (node) =>
      node.type === 'div' && String(node.props.class ?? '').includes('friend-card'))

    expect(card).toBeTruthy()
    expect(card?.props.onClick).toBeUndefined()
    expect(mounted.events.select).not.toHaveBeenCalled()
    mounted.app.unmount()
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

  it('uses displayOrder only as the complete internal order', () => {
    expect(friendsView).toContain('a.displayOrder ?? Number.MAX_SAFE_INTEGER')
    expect(friendCard).not.toContain('friend.displayOrder')
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
      manageFriend: '{name}님 친구 관리',
      openCalendar: '{name}님의 시간표 보기',
      helpOpenAriaLabel: '친구 순서 변경 도움말',
      helpTitle: '친구 순서 바꾸기',
      reorderTitle: '친구 카드를 꾹 눌러 옮기세요',
      reorderText: '친구 카드를 꾹 누른 채 원하는 위치로 끌어 옮기세요.',
      saveTitle: '순서는 자동으로 저장됩니다',
      saveText: '카드를 놓는 순간 바뀐 순서가 저장되어 다른 기기에서도 똑같이 보입니다.',
      helpNote: '친구 카드를 꾹 눌러 원하는 위치로 옮길 수 있어요.',
    }],
    ['en', en, {
      dashboardSection: 'Friends',
      friendsSection: 'Friends list',
      manageFriend: 'Manage {name}',
      openCalendar: "View {name}'s calendar",
      helpOpenAriaLabel: 'How to reorder friends',
      helpTitle: 'Reorder friends',
      reorderTitle: 'Press and hold a friend to move it',
      reorderText: 'Press and hold a friend card, then drag it to the position you want.',
      saveTitle: 'The order saves itself',
      saveText: 'Dropping a card saves the new order right away, so it looks the same on your other devices.',
      helpNote: 'Press and hold a friend card to move it to the position you want.',
    }],
  ] as const)('uses the whole-friend reorder terminology consistently in %s', (_locale, messages, expected) => {
    expect(messages.dashboard.labels.friends).toBe(expected.dashboardSection)
    expect(messages.dashboard.actions).not.toHaveProperty('pin')
    expect(messages.dashboard.actions).not.toHaveProperty('unpin')
    expect(messages.dashboard.messages).not.toHaveProperty('pinFailed')
    expect(messages.dashboard.messages).not.toHaveProperty('unpinFailed')
    expect(messages.dashboard.messages).not.toHaveProperty('unpinTitle')
    expect(messages.dashboard.messages).not.toHaveProperty('unpinConfirm')

    expect(messages.friends.sections.list).toBe(expected.friendsSection)
    expect(messages.friends.actions.manageFriend).toBe(expected.manageFriend)
    expect(messages.friends.actions.openCalendar).toBe(expected.openCalendar)
    expect(messages.friends.actions).not.toHaveProperty('pin')
    expect(messages.friends.actions).not.toHaveProperty('unpin')
    expect(messages.friends.actions).not.toHaveProperty('dragToReorder')
    expect(messages.friends.messages).not.toHaveProperty('pinFailed')
    expect(messages.friends.messages).not.toHaveProperty('unpinFailed')
    expect(messages.friends.messages).not.toHaveProperty('unpinTitle')
    expect(messages.friends.messages).not.toHaveProperty('unpinConfirm')
    expect(messages.friends.help.openAriaLabel).toBe(expected.helpOpenAriaLabel)
    expect(messages.friends.help.title).toBe(expected.helpTitle)
    expect(messages.friends.help.reorderTitle).toBe(expected.reorderTitle)
    expect(messages.friends.help.reorderText).toBe(expected.reorderText)
    expect(messages.friends.help.saveTitle).toBe(expected.saveTitle)
    expect(messages.friends.help.saveText).toBe(expected.saveText)
    expect(messages.friends.help.note).toBe(expected.helpNote)
  })
})
