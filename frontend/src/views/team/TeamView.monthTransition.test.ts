import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h, nextTick } from 'vue'
import { findHostNode, hostText, mountHost, triggerHost, type HostNode } from '@/test/hostRenderer'

const mocks = vi.hoisted(() => ({
  teamApi: { getMyTeamSummary: vi.fn(), getTeamSchedules: vi.fn(), getShift: vi.fn() },
  dutyApi: { getCalendar: vi.fn(), getDuties: vi.fn(), getHolidays: vi.fn() },
}))
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }))
vi.mock('@/i18n', () => ({ getCurrentLocale: () => 'ko', translateGlobal: (key: string) => key }))
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: (key: string, args?: Record<string, number>) =>
  key === 'team.view.selectedDate' ? `${args?.year}-${args?.month}-${args?.day}` : key }) }))
vi.mock('@/stores/auth', () => ({ useAuthStore: () => ({ user: { id: 1 }, checkAuth: vi.fn(), setUser: vi.fn() }) }))
vi.mock('@/stores/contentFilter', () => ({ useContentFilterStore: () => ({ isBlocked: () => false }) }))
vi.mock('@/composables/useSwal', () => ({ useSwal: () => ({ showError: vi.fn(), confirmDelete: vi.fn(), toastSuccess: vi.fn() }) }))
vi.mock('@/api/team', () => ({ teamApi: mocks.teamApi }))
vi.mock('@/api/duty', () => ({ dutyApi: mocks.dutyApi }))
vi.mock('@lucide/vue', () => {
  const icon = defineComponent({ setup: () => () => h('span') })
  return {
    Settings: icon, CalendarPlus: icon, Pencil: icon, Trash2: icon, Building2: icon,
    X: icon, Plus: icon, Check: icon, AlertCircle: icon, LogOut: icon,
    Loader2: defineComponent({ setup: () => () => h('span', { 'data-test': 'spinner' }) }),
  }
})
vi.mock('@/components/common/BaseModal.vue', () => ({ default: defineComponent({ setup: () => () => null }) }))
vi.mock('@/components/common/YearMonthPicker.vue', () => ({ default: defineComponent({ setup: () => () => null }) }))
vi.mock('@/components/common/DatePickerField.vue', () => ({ default: defineComponent({ setup: () => () => null }) }))
vi.mock('@/components/common/CharacterCounter.vue', () => ({ default: defineComponent({ setup: () => () => null }) }))
vi.mock('@/components/common/ProfileAvatar.vue', () => ({ default: defineComponent({ setup: () => () => h('span') }) }))
vi.mock('@/components/common/CalendarMonthNavigator.vue', () => ({
  default: defineComponent({
    props: ['currentYear', 'currentMonth'], emits: ['next-month'],
    setup: (props, { emit }) => () => h('nav', { 'data-test': 'month-header' }, [
      `${props.currentYear}-${props.currentMonth}`,
      h('button', { 'data-test': 'next-month', onClick: () => emit('next-month') }, 'next'),
    ]),
  }),
}))
vi.mock('@/components/common/CalendarGrid.vue', () => ({
  default: defineComponent({
    props: ['days', 'currentYear', 'currentMonth'],
    emits: ['day-click'],
    setup: (props, { emit }) => () => h('section', {
      'data-test': 'calendar', 'data-month': props.currentMonth, 'data-day-count': props.days.length,
    }, [h('button', {
      'data-test': 'select-next-day',
      onClick: () => emit('day-click', { year: 2026, month: 9, day: 16 }, 15),
    })]),
  }),
}))

import TeamView from './TeamView.vue'

const apps: Array<ReturnType<typeof mountHost>['app']> = []
const team = { id: 7, name: 'Team', members: [], dutyTypes: [] }
function summary(month: number) { return { data: { team, isTeamManager: false, year: 2026, month } } }
function days(year: number, month: number) {
  return Array.from({ length: 35 }, (_, index) => {
    const date = new Date(year, month - 1, index + 1)
    return { year: date.getFullYear(), month: date.getMonth() + 1, day: date.getDate() }
  })
}
function schedules(month: number) {
  return { data: days(2026, month).map(date => [{
    id: `schedule-${month}-${date.day}`, content: `Schedule ${month}`, description: '', createMember: 'Author',
  }]) }
}
function shift(month: number, day: number) {
  return { data: [{ dutyType: { id: 1, name: 'Day', color: null }, members: [{ id: 2, name: `Member ${month}-${day}` }] }] }
}
function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>(yes => { resolve = yes })
  return { promise, resolve }
}
async function settle() {
  for (let i = 0; i < 20; i++) await Promise.resolve()
  await nextTick()
}
function node(root: HostNode, test: string) {
  return findHostNode(root, item => item.props['data-test'] === test)
}
async function mountTeam() {
  const mounted = mountHost(TeamView)
  apps.push(mounted.app)
  await settle()
  return mounted.root
}

beforeEach(() => {
  vi.useFakeTimers()
  vi.setSystemTime(new Date(2026, 8, 15))
  vi.resetAllMocks()
  mocks.teamApi.getMyTeamSummary.mockImplementation((_year: number, month: number) => Promise.resolve(summary(month)))
  mocks.teamApi.getTeamSchedules.mockImplementation((_id: number, _year: number, month: number) => Promise.resolve(schedules(month)))
  mocks.teamApi.getShift.mockImplementation((_year: number, month: number, day: number) => Promise.resolve(shift(month, day)))
  mocks.dutyApi.getCalendar.mockImplementation((year: number, month: number) => Promise.resolve(days(year, month)))
  mocks.dutyApi.getDuties.mockResolvedValue([])
  mocks.dutyApi.getHolidays.mockResolvedValue([])
})
afterEach(() => {
  apps.splice(0).forEach(app => app.unmount())
  vi.useRealTimers()
  vi.restoreAllMocks()
})

describe('team calendar month transition', () => {
  it.each(['duties', 'holidays', 'schedules', 'shift', 'calendar'])('does not report an existing team missing when initial %s loading fails', async api => {
    vi.spyOn(console, 'error').mockImplementation(() => {})
    const requests = {
      duties: mocks.dutyApi.getDuties, holidays: mocks.dutyApi.getHolidays,
      schedules: mocks.teamApi.getTeamSchedules, shift: mocks.teamApi.getShift,
      calendar: mocks.dutyApi.getCalendar,
    }
    requests[api as keyof typeof requests].mockRejectedValueOnce(new Error('unavailable'))
    const root = await mountTeam()
    expect(node(root, 'month-header')).not.toBeNull()
    expect(hostText(root)).not.toContain('team.view.emptyTitle')
  })

  it('keeps the loaded calendar, selected-day details and shift until the complete next month is ready', async () => {
    const root = await mountTeam()
    const header = node(root, 'month-header')
    const calendar = node(root, 'calendar')!
    const pendingSummary = deferred<ReturnType<typeof summary>>()
    const pendingSchedules = deferred<ReturnType<typeof schedules>>()
    mocks.teamApi.getMyTeamSummary.mockReturnValueOnce(pendingSummary.promise)
    mocks.teamApi.getTeamSchedules.mockReturnValueOnce(pendingSchedules.promise)

    triggerHost(node(root, 'next-month')!, 'onClick')
    await settle()
    expect(node(root, 'month-header')).toBe(header)
    expect(node(root, 'calendar')).toBe(calendar)
    expect(calendar.props['data-month']).toBe(9)
    expect(hostText(root)).toContain('Schedule 9')
    expect(hostText(root)).toContain('Member 9-15')
    expect(node(root, 'spinner')).toBeNull()

    pendingSummary.resolve(summary(10))
    await settle()
    expect(calendar.props['data-month']).toBe(9)
    expect(hostText(root)).toContain('Member 9-15')

    pendingSchedules.resolve(schedules(10))
    await settle()
    expect(node(root, 'calendar')).toBe(calendar)
    expect(calendar.props['data-month']).toBe(10)
    expect(hostText(root)).toContain('Schedule 10')
    expect(hostText(root)).toContain('Member 10-1')
    expect(node(root, 'spinner')).toBeNull()
  })

  it('ignores an earlier month that finishes after a newer month', async () => {
    const root = await mountTeam()
    const next = node(root, 'next-month')!
    const october = deferred<ReturnType<typeof summary>>()
    mocks.teamApi.getMyTeamSummary.mockImplementation((_year: number, month: number) =>
      month === 10 ? october.promise : Promise.resolve(summary(month)))
    triggerHost(next, 'onClick')
    await settle()
    triggerHost(next, 'onClick')
    await settle()
    october.resolve(summary(10))
    await settle()
    expect(node(root, 'calendar')?.props['data-month']).toBe(11)
    expect(hostText(root)).toContain('Schedule 11')
    expect(hostText(root)).toContain('Member 11-1')
  })

  it('keeps the loaded month when a month request fails', async () => {
    const root = await mountTeam()
    const calendar = node(root, 'calendar')
    vi.spyOn(console, 'error').mockImplementation(() => {})
    mocks.teamApi.getMyTeamSummary.mockRejectedValueOnce(new Error('unavailable'))
    triggerHost(node(root, 'next-month')!, 'onClick')
    await settle()
    expect(node(root, 'calendar')).toBe(calendar)
    expect(hostText(node(root, 'month-header')!)).toContain('2026-9')
    expect(hostText(root)).toContain('Schedule 9')
    expect(hostText(root)).toContain('Member 9-15')
  })

  it('allows the selected-day shift to finish if a later month request fails', async () => {
    const root = await mountTeam()
    const selectedShift = deferred<ReturnType<typeof shift>>()
    mocks.teamApi.getShift.mockReturnValueOnce(selectedShift.promise)
    triggerHost(node(root, 'select-next-day')!, 'onClick')
    await settle()
    vi.spyOn(console, 'error').mockImplementation(() => {})
    mocks.teamApi.getMyTeamSummary.mockRejectedValueOnce(new Error('unavailable'))
    triggerHost(node(root, 'next-month')!, 'onClick')
    await settle()
    selectedShift.resolve(shift(9, 16))
    await settle()
    expect(hostText(root)).toContain('2026-9-16')
    expect(hostText(root)).toContain('Member 9-16')
    expect(hostText(root)).not.toContain('Member 9-15')
  })
})
