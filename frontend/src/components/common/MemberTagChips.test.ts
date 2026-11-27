import { describe, expect, it, vi } from 'vitest'
import { defineComponent, h } from 'vue'
import { createHostWrapper, findHostNodes, hostText, mountHost } from '@/test/hostRenderer'
import MemberTagChips from './MemberTagChips.vue'
import memberTagChipsSource from './MemberTagChips.vue?raw'

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

describe('member tag chip gloss', () => {
  const style = memberTagChipsSource.slice(memberTagChipsSource.indexOf('<style scoped>'))

  function ruleFor(selector: string) {
    const start = style.indexOf(`${selector} {`)
    expect(start, `${selector} rule`).toBeGreaterThan(-1)
    return style.slice(style.indexOf('{', start) + 1, style.indexOf('}', start))
  }

  it('gives every chip the sheen, an inner top highlight and a faint shadow', () => {
    const chip = ruleFor('.member-tag-chip')
    expect(chip).toContain('background-image: var(--dp-tag-chip-sheen);')
    expect(chip).toContain('box-shadow: inset 0 1px 0 var(--dp-tag-chip-highlight), var(--dp-tag-chip-drop);')
    expect(style).not.toContain('backdrop-filter')
  })

  it('fills accent chips with the defined accent background', () => {
    expect(style).not.toContain('--dp-accent-soft')
    expect(ruleFor('.member-tag-chip--accent')).toContain('background-color: var(--dp-accent-bg);')
  })

  it('keeps hover visible under the sheen by changing only the background colour', () => {
    expect(ruleFor('.member-tag-chip--interactive:hover')).toContain('background-color: var(--dp-accent-bg-hover);')
    expect(ruleFor('.member-tag-chip--neutral.member-tag-chip--interactive:hover')).toContain('background-color: var(--dp-bg-hover);')
    expect(style).not.toMatch(/background:\s/)
    expect(style).not.toContain('background-image: none')
  })

  it('keeps the inner highlight under the focus ring', () => {
    expect(ruleFor('.member-tag-chip--interactive:focus-visible')).toContain(
      'box-shadow: inset 0 1px 0 var(--dp-tag-chip-highlight), 0 0 0 3px var(--dp-accent-ring);',
    )
  })
})
