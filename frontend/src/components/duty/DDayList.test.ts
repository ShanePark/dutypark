import { describe, expect, it, vi } from 'vitest'
import { h, nextTick, ref } from 'vue'
import {
  createHostWrapper,
  findHostNode,
  findHostNodes,
  hostText,
  mountHost,
  triggerHost,
  type HostNode,
} from '@/test/hostRenderer'
import type { LocalDDay } from '@/views/duty/dutyViewTypes'

const mocks = vi.hoisted(() => ({
  t: vi.fn((key: string) => key),
}))

vi.mock('@/i18n', () => ({
  getCurrentLocale: () => 'ko',
}))

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: mocks.t, locale: ref('ko') }),
}))

vi.mock('@lucide/vue', async () => {
  const { defineComponent, h } = await import('vue')
  const icon = (name: string) => defineComponent({
    setup() {
      return () => h('svg', { 'data-icon': name })
    },
  })
  return { Lock: icon('lock'), Plus: icon('plus'), Star: icon('star') }
})

const { default: DDayList } = await import('./DDayList.vue')

const dDays: LocalDDay[] = [
  { id: 1, title: '제주 여행', date: '2026-11-14', isPrivate: false, calc: 13, dDayText: 'D-13' },
  { id: 2, title: '전세 만기', date: '2027-03-31', isPrivate: true, calc: 150, dDayText: 'D-150' },
  {
    id: 3,
    title: '정수기 필터 교체 (다음 교체는 8월, 2027년 4월까지) 아주 긴 제목이 계속 이어집니다',
    date: '2026-04-15',
    isPrivate: false,
    calc: -201,
    dDayText: 'D+201',
  },
  { id: 4, title: '오늘', date: '2026-11-01', isPrivate: false, calc: 0, dDayText: 'D-Day' },
]

type Emitted = { openDetail: LocalDDay[]; togglePin: LocalDDay[]; add: number }

function mountList(props: { pinnedDDayId: number | null; isMyCalendar: boolean }) {
  const emitted: Emitted = { openDetail: [], togglePin: [], add: 0 }
  const { root } = mountHost(createHostWrapper(() => h(DDayList, {
    dDays,
    ...props,
    onOpenDetail: (dday: LocalDDay) => emitted.openDetail.push(dday),
    onTogglePin: (dday: LocalDDay) => emitted.togglePin.push(dday),
    onAdd: () => { emitted.add += 1 },
  })))
  return { root, emitted }
}

function rows(root: HostNode): HostNode[] {
  return findHostNodes(root, node => node.props['data-testid'] === 'dday-row')
}

function byTestId(root: HostNode, id: string): HostNode {
  const node = findHostNode(root, n => n.props['data-testid'] === id)
  if (!node) throw new Error(`Missing ${id}`)
  return node
}

// Classes that may legitimately differ between items: state colour and pin marker.
const VARIANT_CLASS = /^(dday-row--(past|urgent|soon|future)|is-pinned)$/

function shape(node: HostNode): unknown {
  if (node.type === '#text' || node.type === '#comment') return null
  const classes = String(node.props.class ?? '')
    .split(/\s+/)
    .filter(token => token && !VARIANT_CLASS.test(token))
    .sort()
    .join(' ')
  // The lock slot is always present; only its icon content varies.
  const children = node.props['data-testid'] === 'dday-lock-slot'
    ? []
    : node.children.map(shape).filter(child => child !== null)
  return { type: node.type, classes, testid: node.props['data-testid'] ?? null, children }
}

describe('DDayList', () => {
  it('renders every item with an identical row structure regardless of pin, privacy, title length or state', async () => {
    const { root } = mountList({ pinnedDDayId: 1, isMyCalendar: true })
    await nextTick()

    const items = rows(root)
    expect(items).toHaveLength(4)
    const reference = JSON.stringify(shape(items[0]!))
    for (const item of items) {
      expect(JSON.stringify(shape(item))).toBe(reference)
    }

    // Markers only: pinned row gets is-pinned, private row gets a lock icon.
    expect(String(items[0]!.props.class)).toContain('is-pinned')
    expect(items.slice(1).every(item => !String(item.props.class).includes('is-pinned'))).toBe(true)
    const lockSlots = items.map(item => byTestId(item, 'dday-lock-slot'))
    expect(lockSlots.map(slot => findHostNode(slot, n => n.props['data-icon'] === 'lock') !== null))
      .toEqual([false, true, false, false])

    // State only changes colour classes.
    expect(items.map(item => String(item.props.class).match(/dday-row--(\w+)/)?.[1]))
      .toEqual(['soon', 'future', 'past', 'urgent'])
  })

  it('shows D-N, a single-line title with full-text tooltip, and a consistent date format', async () => {
    const { root } = mountList({ pinnedDDayId: null, isMyCalendar: true })
    await nextTick()
    const [first, , long] = rows(root)

    expect(hostText(byTestId(first!, 'dday-value'))).toBe('D-13')
    expect(hostText(byTestId(first!, 'dday-date'))).toBe('2026.11.14 (토)')
    expect(hostText(byTestId(long!, 'dday-date'))).toBe('2026.04.15 (수)')
    const title = byTestId(long!, 'dday-title')
    expect(String(title.props.class)).toContain('dday-row__title')
    expect(title.props.title).toBe(dDays[2]!.title)
  })

  it('emits open-detail from the row, toggle-pin from the star without bubbling, and add from the header', async () => {
    const { root, emitted } = mountList({ pinnedDDayId: 2, isMyCalendar: true })
    await nextTick()
    const [first, second] = rows(root)

    triggerHost(byTestId(first!, 'dday-open'), 'onClick')
    expect(emitted.openDetail.map(d => d.id)).toEqual([1])

    const stopPropagation = vi.fn()
    const star = byTestId(second!, 'dday-pin')
    expect(star.type).toBe('button')
    expect(star.props['aria-pressed']).toBe(true)
    expect(star.props['aria-label']).toBe('duty.ddayList.unpin')
    triggerHost(star, 'onClick', { stopPropagation })
    expect(emitted.togglePin.map(d => d.id)).toEqual([2])
    expect(stopPropagation).toHaveBeenCalled()
    expect(emitted.openDetail).toHaveLength(1)

    triggerHost(byTestId(root, 'dday-add'), 'onClick')
    expect(emitted.add).toBe(1)
  })

  it('shows the count and hides the add button on other calendars', async () => {
    const { root } = mountList({ pinnedDDayId: null, isMyCalendar: false })
    await nextTick()

    expect(hostText(byTestId(root, 'dday-count'))).toBe('4')
    expect(findHostNode(root, n => n.props['data-testid'] === 'dday-add')).toBeNull()
  })
})
