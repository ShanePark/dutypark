import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createHash } from 'node:crypto'
import { defineComponent, h, nextTick, reactive } from 'vue'
import { createHostWrapper, findHostNode, findHostNodes, hostText, mountHost, triggerHost, type HostNode } from '@/test/hostRenderer'
import type { CalendarDay, LocalDDay, Schedule } from '@/views/duty/dutyViewTypes'

vi.mock('@/i18n', () => ({ getCurrentLocale: () => 'ko' }))
vi.mock('vue-i18n', () => ({ useI18n: () => ({ locale: { value: 'ko' } }) }))
vi.mock('@lucide/vue', () => {
  const icon = defineComponent({ setup: () => () => h('span') })
  return { CalendarCheck: icon, MessageSquareText: icon, CheckSquare: icon }
})
vi.mock('@/components/common/ProfileAvatar.vue', () => ({
  default: defineComponent({
    props: ['memberId', 'name', 'hasProfilePhoto', 'profilePhotoVersion'],
    setup: props => () => h('span', {
      'data-avatar-id': props.memberId,
      'data-avatar-name': props.name,
      'data-photo-version': props.profilePhotoVersion,
    }),
  }),
}))
vi.mock('@/components/common/VisibilityHintIcon.vue', () => ({
  default: defineComponent({ setup: () => () => h('span') }),
}))

import DutyCalendarContent from './DutyCalendarContent.vue'
import { parseDateOnly } from '@/utils/date'
import { buildDisplayTagMembers } from '@/utils/tagMembers'
import * as dateUtils from '@/utils/date'
import * as tagMembers from '@/utils/tagMembers'

type CalendarProps = {
  -readonly [Key in keyof InstanceType<typeof DutyCalendarContent>['$props']]:
    InstanceType<typeof DutyCalendarContent>['$props'][Key]
}
const apps: Array<ReturnType<typeof mountHost>['app']> = []

function makeSchedule(id: string, daysFromStart = 1): Schedule {
  return {
    id, content: `Schedule ${id}`, startDateTime: '2026-09-01T09:30', endDateTime: '2026-09-03T17:45',
    visibility: 'FRIENDS', isMine: false, isTagged: true, owner: 'Owner',
    taggedByMember: { id: 8, name: 'Owner', hasProfilePhoto: true, profilePhotoVersion: 1 },
    tags: [
      { id: 1, name: 'Viewer' }, { id: 2, name: 'Alpha' },
      { id: 3, name: 'Bravo' }, { id: 4, name: 'Charlie' },
    ],
    daysFromStart, totalDays: 3,
  }
}

function makeProps(ddayCount = 100): CalendarProps {
  const days: CalendarDay[] = Array.from({ length: 42 }, (_, index) => {
    const date = new Date(2026, 7, 30 + index)
    return { year: date.getFullYear(), month: date.getMonth() + 1, day: date.getDate(), isToday: false }
  })
  const dDays: LocalDDay[] = Array.from({ length: ddayCount }, (_, index) => {
    const day = days[index % days.length]!
    return {
      id: index, title: `D-Day ${index}`, isPrivate: false, calc: index, dDayText: `D-${index}`,
      date: `${day.year}-${String(day.month).padStart(2, '0')}-${String(day.day).padStart(2, '0')}`,
    }
  })
  return {
    days, currentYear: 2026, currentMonth: 9, holidays: [], getDutyColorForDay: () => null,
    highlightDay: null, batchEditMode: false, focusedDay: null, canEdit: true,
    duties: [], dutyTypes: [], otherDuties: [], dDays, pinnedDDay: null, todosDueByDays: [],
    isMyCalendar: true, memberId: 1,
    schedulesByDays: days.map((_, index) => Array.from({ length: 4 }, (_, slot) => makeSchedule(`${index}-${slot}`))),
  }
}

function mountCalendar(props: CalendarProps) {
  const mounted = mountHost(createHostWrapper(() => h(DutyCalendarContent, props)))
  apps.push(mounted.app)
  return mounted.root
}

function ddayButtons(root: HostNode) {
  return findHostNodes(root, node => node.type === 'button' && String(node.props.class).includes('calendar-action-bubble--dday'))
}

function tagNames(root: HostNode) {
  return findHostNodes(root, node => 'data-avatar-name' in node.props).map(node => node.props['data-avatar-name'])
}

beforeEach(() => {
  vi.spyOn(dateUtils, 'parseDateOnly')
  vi.spyOn(tagMembers, 'buildDisplayTagMembers')
})
afterEach(() => {
  apps.splice(0).forEach(app => app.unmount())
  vi.restoreAllMocks()
})

describe('calendar derived display data', () => {
  it('parses each D-Day once and builds tags only for visible schedules', () => {
    const props = makeProps()
    const root = mountCalendar(props)

    expect(ddayButtons(root)).toHaveLength(props.dDays.length)
    expect(parseDateOnly).toHaveBeenCalledTimes(props.dDays.length)
    expect(buildDisplayTagMembers).toHaveBeenCalledTimes(42 * 3)
    expect(hostText(root)).not.toContain('Schedule 0-3')
    expect(hostText(root)).toContain('+1')
  })

  it('keeps derived data cached when highlighting another day', async () => {
    const props = reactive(makeProps())
    const root = mountCalendar(props)
    const before = hostText(root)
    vi.clearAllMocks()

    props.highlightDay = { year: 2026, month: 9, day: 12 }
    await nextTick()

    expect(hostText(root)).toBe(before)
    expect(vi.mocked(parseDateOnly).mock.calls.length).toBe(0)
    expect(vi.mocked(buildDisplayTagMembers).mock.calls.length).toBe(0)
  })

  it('preserves date normalization, input order, clicks, and nested D-Day updates', async () => {
    const props = reactive(makeProps(0))
    props.schedulesByDays = []
    props.days = [
      { year: 2026, month: 12, day: 31 }, { year: 2027, month: 1, day: 1 },
      { year: 2027, month: 3, day: 3 },
    ]
    props.dDays = [
      { id: 1, title: 'First', date: '2027-01-01', isPrivate: false, calc: 0, dDayText: 'D-Day' },
      { id: 2, title: 'Second', date: '2027-01-01', isPrivate: false, calc: 0, dDayText: 'D-Day' },
      { id: 3, title: 'Normalized', date: '2027-02-31', isPrivate: false, calc: 0, dDayText: 'D-Day' },
      { id: 4, title: 'Invalid', date: 'invalid', isPrivate: false, calc: 0, dDayText: 'D-Day' },
    ]
    const clicked = vi.fn()
    props['onDday-click'] = clicked
    const root = mountCalendar(props)
    expect(ddayButtons(root).map(node => node.props.title)).toEqual(['First', 'Second', 'Normalized'])
    triggerHost(ddayButtons(root)[0]!, 'onClick', { stopPropagation: vi.fn() })
    expect(clicked).toHaveBeenCalledWith(props.dDays[0])

    props.dDays[1]!.date = '2026-12-31'
    props.dDays[0]!.title = 'Renamed'
    await nextTick()
    expect(ddayButtons(root).map(node => node.props.title)).toEqual(['Second', 'Renamed', 'Normalized'])

    props.dDays.splice(0, 1)
    await nextTick()
    expect(ddayButtons(root).map(node => node.props.title)).toEqual(['Second', 'Normalized'])
  })

  it('refreshes nested tag data and the viewed member without mixing same-id schedule occurrences', async () => {
    const props = reactive(makeProps(0))
    const shared = makeSchedule('shared')
    const secondOccurrence = makeSchedule('shared', 2)
    secondOccurrence.tags![1]!.name = 'Different'
    props.schedulesByDays = [[shared], [shared], [secondOccurrence]]
    const root = mountCalendar(props)
    expect(buildDisplayTagMembers).toHaveBeenCalledTimes(2)
    expect(tagNames(root)).toContain('Different')
    expect(tagNames(root)).not.toContain('Viewer')
    expect(hostText(root)).toContain('(2/3)')

    props.schedulesByDays[0]![0]!.tags![1]!.name = 'Renamed'
    props.schedulesByDays[0]![0]!.taggedByMember!.profilePhotoVersion = 2
    await nextTick()
    expect(tagNames(root)).toContain('Renamed')
    expect(tagNames(root)).not.toContain('Alpha')
    expect(findHostNode(root, node => node.props['data-avatar-id'] === 8 && node.props['data-photo-version'] === 2)).not.toBeNull()

    props.memberId = 2
    await nextTick()
    expect(tagNames(root)).toContain('Viewer')
    expect(tagNames(root)).not.toContain('Renamed')
    expect(tagNames(root)).not.toContain('Different')

    props.schedulesByDays[0]![0]!.tags!.push({ id: 5, name: 'Added' })
    await nextTick()
    expect(tagNames(root)).toContain('Added')
    expect(hostText(root)).toContain('+2')
  })
})

it.skipIf(!process.env.DUTYPARK_PERFORMANCE_BENCHMARK)('measures calendar mount and highlight renders', async () => {
  const props = reactive(makeProps())
  const root = mountCalendar(props)
  const expectedText = hostText(root)
  const mountDateParses = vi.mocked(parseDateOnly).mock.calls.length
  const mountTagBuilds = vi.mocked(buildDisplayTagMembers).mock.calls.length
  vi.clearAllMocks()
  props.highlightDay = { year: 2026, month: 9, day: 1 }
  await nextTick()
  expect(hostText(root)).toBe(expectedText)
  const highlightDateParses = vi.mocked(parseDateOnly).mock.calls.length
  const highlightTagBuilds = vi.mocked(buildDisplayTagMembers).mock.calls.length
  vi.restoreAllMocks()

  const mountSamples: number[] = []
  const highlightSamples: number[] = []
  for (let sample = 0; sample < 12; sample++) {
    const sampleProps = reactive(makeProps())
    const start = performance.now()
    const sampleRoot = mountCalendar(sampleProps)
    const mountElapsed = performance.now() - start
    const highlightStart = performance.now()
    sampleProps.highlightDay = { year: 2026, month: 9, day: 12 }
    await nextTick()
    const highlightElapsed = performance.now() - highlightStart
    expect(hostText(sampleRoot)).toBe(expectedText)
    apps.pop()!.unmount()
    if (sample >= 3) {
      mountSamples.push(mountElapsed)
      highlightSamples.push(highlightElapsed)
    }
  }
  mountSamples.sort((a, b) => a - b)
  highlightSamples.sort((a, b) => a - b)
  console.log(JSON.stringify({
    benchmark: 'calendar-rendering', days: 42, dDays: props.dDays.length,
    outputSha256: createHash('sha256').update(expectedText).digest('hex'),
    schedulesPerDay: 4, visibleSchedulesPerDay: 3,
    mountDateParses, mountTagBuilds, highlightDateParses, highlightTagBuilds,
    mountSamplesMs: mountSamples, mountMedianMs: mountSamples[4],
    highlightSamplesMs: highlightSamples, highlightMedianMs: highlightSamples[4],
  }))
}, 30_000)
