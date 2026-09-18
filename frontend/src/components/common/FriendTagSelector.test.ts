import { describe, expect, it } from 'vitest'
import friendTagSelector from './FriendTagSelector.vue?raw'

const script = friendTagSelector.slice(0, friendTagSelector.indexOf('<template>'))
const template = friendTagSelector.slice(
  friendTagSelector.indexOf('<template>'),
  friendTagSelector.indexOf('<style'),
)
const style = friendTagSelector.slice(friendTagSelector.indexOf('<style'))

/** Body of the first CSS rule declared for `selector`, so a media-query override never shadows it. */
function ruleFor(selector: string) {
  const start = style.indexOf(`${selector} {`)
  expect(start, `missing rule for ${selector}`).toBeGreaterThan(-1)
  const end = style.indexOf('}', start)
  return style.slice(start, end)
}

function templateIndex(marker: string) {
  const index = template.indexOf(marker)
  expect(index, `missing template marker ${marker}`).toBeGreaterThan(-1)
  return index
}

describe('FriendTagSelector card rail (D7)', () => {
  it('always renders the team line so a team-less friend keeps the same card layout', () => {
    expect(template).not.toContain('v-if="getSubtitle(friend)"')
    expect(template).toContain('class="friend-tag-selector__card-team"')
  })

  it('leaves the reserved team slot blank instead of filling it with a fallback label', () => {
    expect(script).toContain("return friend.team || ''")
    expect(template).not.toContain('noTeam')
  })

  it('holds the blank team line open so every card ends up the same height', () => {
    const teamRule = ruleFor('.friend-tag-selector__card-team')
    expect(teamRule).toContain('line-height: 1.2')
    expect(teamRule).toMatch(/min-height:\s*1\.2em/)
  })

  it('keeps the blank team line out of the card button\'s accessible name', () => {
    expect(template).toMatch(/:aria-hidden="getSubtitle\(friend\) \? [^"]+ : 'true'"/)
  })

  it('hangs every card from a common top edge', () => {
    expect(ruleFor('.friend-tag-selector__rail')).toContain('align-items: flex-start')
  })

  it('keeps the three-and-a-peek card width and the scroll snapping untouched', () => {
    const cardRule = ruleFor('.friend-tag-selector__card')
    expect(cardRule).toContain('calc((100% - var(--friend-card-gap) * 3) / 3.2)')
    expect(cardRule).toContain('scroll-snap-align: start')
    expect(ruleFor('.friend-tag-selector__rail')).toContain('scroll-snap-type: x proximity')
  })
})

describe('FriendTagSelector expanded layout (D8)', () => {
  it('orders the panel as search, then rail, then the selected friends', () => {
    const search = templateIndex('class="friend-tag-selector__search"')
    const rail = templateIndex('class="friend-tag-selector__rail-frame"')
    const emptyState = templateIndex("t('friendTagSelector.emptyTitle')")
    const selected = templateIndex('class="friend-tag-selector__selected"')

    expect(search).toBeLessThan(rail)
    expect(rail).toBeLessThan(emptyState)
    expect(emptyState).toBeLessThan(selected)
  })

  it('reserves the selected summary block as soon as the selector expands', () => {
    const selected = templateIndex('class="friend-tag-selector__selected"')
    expect(template.slice(selected - 120, selected)).not.toContain('v-if="selectedFriends.length"')
    expect(template).toContain("t('friendTagSelector.selectedCount', { count: selectedCount })")
    expect(ruleFor('.friend-tag-selector__selected-header')).toContain('min-height: 1.5rem')
    expect(ruleFor('.friend-tag-selector__chips')).toContain('min-height: 2rem')
  })

  it('keeps the page position stable when the inline selector opens', () => {
    expect(template).not.toContain('ref="selectedBlockRef"')
    expect(script).not.toContain('scrollIntoView')
    expect(script).not.toContain("window.matchMedia('(max-width: 639px)').matches")
  })

  it('keeps the expanded selector within its grid column', () => {
    const selectorRule = ruleFor('.friend-tag-selector')
    expect(selectorRule).toContain('width: 100%')
    expect(selectorRule).toContain('min-width: 0')
    expect(selectorRule).toContain('max-width: 100%')
  })

  it('uses a 16px search input on mobile to prevent browser auto-zoom', () => {
    const mobileStyles = style.slice(style.indexOf('@media (max-width: 639px)'))
    expect(mobileStyles).toMatch(/\.friend-tag-selector__search-input \{[\s\S]*?font-size:\s*1rem;/)
  })

  it('keeps the rail scroll hints wired to the rail itself, not to the block order', () => {
    expect(template).toContain('@scroll.passive="updateRailHints"')
    expect(script).toContain('watch([railFriends, isExpanded]')
    expect(script).toContain("window.addEventListener('resize', updateRailHints)")
  })
})

describe('FriendTagSelector presentation modes (D9)', () => {
  it('supports an always-expanded inline mode without changing the default schedule behavior', () => {
    expect(script).toContain('alwaysExpanded?: boolean')
    expect(script).toContain('alwaysExpanded: false')
    expect(script).toContain('appearance?: \'default\' | \'flat\'')
    expect(script).toContain("appearance: 'default'")
    expect(script).toContain('const isInternallyExpanded = ref(props.modelValue.length > 0)')
    expect(script).toContain('const isExpanded = computed(() => props.alwaysExpanded || isInternallyExpanded.value)')
    expect(script).toContain('count > 0 && previousCount === 0 && !props.alwaysExpanded')
    expect(template).toContain("'friend-tag-selector--flat': isExpanded && appearance === 'flat'")
  })

  it('flattens the Todo presentation while preserving the selected card cues', () => {
    expect(ruleFor('.friend-tag-selector--flat')).toMatch(/border:\s*0/)
    expect(ruleFor('.friend-tag-selector--flat .friend-tag-selector__rail-frame')).toMatch(/border:\s*0/)
    expect(ruleFor('.friend-tag-selector--flat .friend-tag-selector__selected')).toMatch(/background:\s*transparent/)
    expect(template).toContain("'friend-tag-selector__chips--empty': selectedFriends.length === 0")
    expect(ruleFor('.friend-tag-selector--flat .friend-tag-selector__chips--empty')).toMatch(/min-height:\s*0\s*!important/)
  })
})
