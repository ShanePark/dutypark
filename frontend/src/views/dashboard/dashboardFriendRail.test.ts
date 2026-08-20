import { describe, expect, it } from 'vitest'
import dashboardView from './DashboardView.vue?raw'
import en from '@/i18n/messages/en'
import ko from '@/i18n/messages/ko'

/**
 * The home friend list is a portrait card rail (D1/D2/D6) with no reordering of its own (D3):
 * dragging lives only on the friends page. These markers pin the rail's shape so a card can
 * never grow a taller neighbour, and pin the fact that the sortable wiring stays removed.
 */

const templateAt = dashboardView.indexOf('<template>')
const styleAt = dashboardView.indexOf('<style')

const script = dashboardView.slice(0, templateAt)
const template = dashboardView.slice(templateAt, styleAt > -1 ? styleAt : dashboardView.length)
const style = styleAt > -1 ? dashboardView.slice(styleAt) : ''

/** Body of the first CSS rule declared for `selector`, so a media-query override never shadows it. */
function ruleFor(selector: string) {
  const start = style.indexOf(`${selector} {`)
  expect(start, `missing rule for ${selector}`).toBeGreaterThan(-1)
  const end = style.indexOf('}', start)
  return style.slice(start, end)
}

/** The opening tag that carries `marker`, so a slot can be checked for a conditional guard. */
function tagWith(marker: string) {
  const index = template.indexOf(marker)
  expect(index, `missing template marker ${marker}`).toBeGreaterThan(-1)
  const start = template.lastIndexOf('<', index)
  const end = template.indexOf('>', index)
  return template.slice(start, end + 1)
}

describe('home friend list drops reordering (D3)', () => {
  it('unwires sortablejs from the dashboard', () => {
    expect(script).not.toContain("from 'sortablejs'")
    expect(script).not.toContain('new Sortable(')
    expect(script).not.toContain('initFriendSortable')
    expect(script).not.toContain('destroyFriendSortable')
    expect(script).not.toContain('updateFriendsPin')
    expect(script).not.toContain('applyFriendOrder')
    expect(script).not.toContain('useDragClickGuard')
  })

  it('drops the drag handle and the markers the drag needed', () => {
    expect(template).not.toContain('GripVertical')
    expect(template).not.toContain('friend-drag-handle')
    expect(template).not.toContain('pinned-friend')
    expect(template).not.toContain('data-member-id')
    expect(template).not.toContain('friend-section-sorting')
    expect(script).not.toContain('friend-section-sorting')
  })

  it('retires the reorder-only copy from both locales', () => {
    for (const [name, messages] of Object.entries({ ko, en })) {
      expect(messages.dashboard.actions, name).not.toHaveProperty('dragToReorder')
      expect(messages.dashboard.messages, name).not.toHaveProperty('reorderFailed')
    }
  })
})

describe('home friend list keeps the pin toggle (D4)', () => {
  it('keeps the optimistic pin and unpin calls', () => {
    expect(script).toContain('async function pinFriend')
    expect(script).toContain('async function unpinFriend')
    expect(script).toContain('friendApi.pinFriend')
    expect(script).toContain('friendApi.unpinFriend')
    expect(script).toContain('dashboard.messages.pinFailed')
    expect(script).toContain('dashboard.messages.unpinFailed')
  })

  it('overlays the star on the portrait without navigating the card', () => {
    expect(template).toContain('@click.stop="pinFriend(friend.member)"')
    expect(template).toContain('@click.stop="unpinFriend(friend.member)"')
    expect(ruleFor('.dashboard-friend-card__pin')).toContain('position: absolute')
  })
})

describe('home friend rail shape (D1/D2)', () => {
  it('lays the friends out as a horizontally scrolling rail', () => {
    expect(template).toContain('class="dashboard-friend-rail"')
    const rail = ruleFor('.dashboard-friend-rail')
    expect(rail).toContain('overflow-x: auto')
    expect(rail).toContain('scroll-snap-type: x proximity')
    expect(rail).toContain('overscroll-behavior-x: contain')
  })

  it('keeps the three-and-a-peek card width of the tag selector rail', () => {
    const card = ruleFor('.dashboard-friend-card')
    expect(card).toContain('calc((100% - var(--friend-card-gap) * 3) / 3.2)')
    expect(card).toContain('scroll-snap-align: start')
  })

  it('shows the friend as a portrait photo', () => {
    expect(template).toContain('shape="portrait"')
  })

  it('always renders the team and duty slots, so no card is shorter than another', () => {
    expect(tagWith('dashboard-friend-card__team')).not.toContain('v-if')
    expect(tagWith('dashboard-friend-card__duty')).not.toContain('v-if')
    expect(ruleFor('.dashboard-friend-card__team')).toMatch(/min-height:\s*1\.2em/)
    expect(ruleFor('.dashboard-friend-card__duty')).toMatch(/min-height:/)
  })

  it('hangs every card from a common top edge', () => {
    expect(ruleFor('.dashboard-friend-rail')).toContain('align-items: flex-start')
  })

  it('falls back to a dash when a friend has no duty today', () => {
    expect(script).toContain("dashboard.labels.offDuty")
    expect(script).toMatch(/function dutyLabel[\s\S]*?'-'/)
  })

  it('drops the schedule preview from the card', () => {
    expect(template).not.toContain('friend.schedules')
    expect(template).not.toContain('moreSchedules')
    for (const [name, messages] of Object.entries({ ko, en })) {
      expect(messages.dashboard.labels, name).not.toHaveProperty('moreSchedules')
    }
  })

  it('still opens the friend calendar and the friends page', () => {
    expect(template).toContain('@click="moveTo(friend.member.id)"')
    expect(template).toContain("router.push('/friends')")
    expect(template).toContain('dashboard.labels.noFriends')
  })
})

describe('home friend rail arrows (D6)', () => {
  it('derives the arrows from the rail scroll position', () => {
    expect(script).toContain('canScrollPrev')
    expect(script).toContain('canScrollNext')
    expect(script).toContain('rail.scrollLeft')
    expect(template).toContain('@scroll.passive="updateRailHints"')
  })

  it('reserves the arrows for pointer devices', () => {
    expect(style).toContain('@media (hover: hover) and (pointer: fine)')
    const navRule = ruleFor('.dashboard-friend-rail-nav')
    expect(navRule).toContain('display: none')
  })

  it('labels both arrows from the dashboard namespace', () => {
    expect(template).toContain("t('dashboard.actions.scrollPrevAria')")
    expect(template).toContain("t('dashboard.actions.scrollNextAria')")
    expect(template).not.toContain('friendTagSelector.')
    for (const [name, messages] of Object.entries({ ko, en })) {
      expect(messages.dashboard.actions, name).toHaveProperty('scrollPrevAria')
      expect(messages.dashboard.actions, name).toHaveProperty('scrollNextAria')
    }
  })
})
