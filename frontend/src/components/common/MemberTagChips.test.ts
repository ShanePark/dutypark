import { describe, expect, it, vi } from 'vitest'
import { defineComponent, h } from 'vue'
import { createHostWrapper, findHostNodes, hostText, mountHost } from '@/test/hostRenderer'
import MemberTagChips from './MemberTagChips.vue'

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: () => '작성자' }) }))
vi.mock('@/components/common/ProfileAvatar.vue', () => ({ default: defineComponent({ setup: () => () => h('span') }) }))

describe('member tag owner treatment', () => {
  it.each([
    { tone: undefined, expected: 'accent' },
    { tone: 'neutral' as const, expected: 'neutral' },
  ])('uses $expected tags without changing names or the owner role', ({ tone, expected }) => {
    const mounted = mountHost(createHostWrapper(() => h(MemberTagChips, { tone, members: [
      { key: 'owner', id: 8, name: 'Owner', isOwner: true },
      { key: 'friend', id: 2, name: 'Friend' },
    ] })))
    const chips = findHostNodes(mounted.root, node => String(node.props.class).includes('member-tag-chip--compact'))
    expect(chips).toHaveLength(2)
    expect(chips.every(chip => String(chip.props.class).includes(`member-tag-chip--${expected}`))).toBe(true)
    expect(chips[0]?.props['aria-label']).toBe('Owner, 작성자')
    expect(hostText(mounted.root)).toBe('OwnerFriend')
    mounted.app.unmount()
  })

  it('identifies only the owner without adding a star or visible label text', () => {
    const mounted = mountHost(createHostWrapper(() => h(MemberTagChips, { members: [
      { key: 'owner', id: 8, name: 'Owner', isOwner: true },
      { key: 'friend', id: 2, name: 'Friend' },
    ] })))
    const markers = findHostNodes(mounted.root, node => String(node.props.class).includes('schedule-owner-icon'))
    expect(markers).toHaveLength(0)
    const owners = findHostNodes(mounted.root, node => String(node.props.class).includes('member-tag-chip--owner'))
    expect(owners).toHaveLength(1)
    expect(owners[0]?.props['aria-label']).toBe('Owner, 작성자')
    expect(findHostNodes(mounted.root, node => node.props['aria-label'] === 'Friend, 작성자')).toHaveLength(0)
    expect(hostText(mounted.root)).toBe('OwnerFriend')
    mounted.app.unmount()
  })
})
