import { beforeEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h, nextTick, reactive } from 'vue'
import {
  findHostNode,
  mountHost,
  triggerHost,
  hostText,
  type HostNode,
} from '@/test/hostRenderer'

const mocks = vi.hoisted(() => ({
  t: vi.fn((key: string) => {
    if (key === 'contentFilter.blocked') return 'client-filtered-message'
    if (key === 'apiErrors.contentFilter.blocked') return 'server-filtered-message'
    return key
  }),
  route: { params: { id: '1' } },
  router: { push: vi.fn(), replace: vi.fn() },
  authStore: {
    user: { id: 1, name: 'Tester', teamId: null, isAdmin: false },
    isLoggedIn: true,
  },
  filterStore: { isBlocked: vi.fn() },
  showError: vi.fn(),
  confirm: vi.fn(),
  confirmDelete: vi.fn(),
  toastSuccess: vi.fn(),
  toastInfo: vi.fn(),
  ddayApi: {
    getMyDDays: vi.fn(),
    getDDaysByMemberId: vi.fn(),
    saveDDay: vi.fn(),
    deleteDDay: vi.fn(),
  },
  memberApi: {
    getMyInfo: vi.fn(),
    getMemberById: vi.fn(),
  },
  friendApi: { getFriends: vi.fn() },
  todoApi: { getBoard: vi.fn() },
  dutyApi: {
    getCalendar: vi.fn(),
    getDuties: vi.fn(),
    getHolidays: vi.fn(),
    getTeam: vi.fn(),
    canManage: vi.fn(),
    getOtherDuties: vi.fn(),
    updateDuty: vi.fn(),
    uploadDutyBatch: vi.fn(),
  },
  scheduleApi: {
    getSchedules: vi.fn(),
    searchSchedules: vi.fn(),
    saveSchedule: vi.fn(),
    deleteSchedule: vi.fn(),
    reorderSchedulePositions: vi.fn(),
    untagSelf: vi.fn(),
  },
  reportApi: { submitReport: vi.fn() },
  blockApi: { block: vi.fn(), unblock: vi.fn() },
  swal: { fire: vi.fn(), close: vi.fn(), mixin: vi.fn() },
}))

vi.mock('@/i18n', () => ({
  getCurrentLocale: () => 'ko',
  translateGlobal: (key: string) => key,
  i18n: { global: { locale: { value: 'ko' }, t: mocks.t } },
}))

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: mocks.t }),
  createI18n: () => ({ global: { locale: { value: 'ko' }, t: mocks.t } }),
}))

vi.mock('vue-router', () => ({
  useRoute: () => mocks.route,
  useRouter: () => mocks.router,
}))

vi.mock('@/stores/auth', () => ({
  useAuthStore: () => mocks.authStore,
}))

vi.mock('@/stores/contentFilter', () => ({
  useContentFilterStore: () => mocks.filterStore,
}))

vi.mock('@/composables/useNavigateBack', () => ({
  useNavigateBack: () => ({ goBack: vi.fn() }),
}))

vi.mock('@/composables/useSwal', () => ({
  useSwal: () => ({
    showError: mocks.showError,
    confirm: mocks.confirm,
    confirmDelete: mocks.confirmDelete,
    toastSuccess: mocks.toastSuccess,
    toastInfo: mocks.toastInfo,
  }),
}))

vi.mock('sweetalert2', () => ({ default: mocks.swal }))
vi.mock('@/api/member', () => ({
  ddayApi: mocks.ddayApi,
  memberApi: mocks.memberApi,
  friendApi: mocks.friendApi,
}))
vi.mock('@/api/todo', () => ({ todoApi: mocks.todoApi }))
vi.mock('@/api/duty', () => ({ dutyApi: mocks.dutyApi }))
vi.mock('@/api/schedule', () => ({ scheduleApi: mocks.scheduleApi }))
vi.mock('@/api/report', () => ({ reportApi: mocks.reportApi }))
vi.mock('@/api/block', () => ({ blockApi: mocks.blockApi }))

vi.mock('@lucide/vue', async () => {
  const { defineComponent, h } = await import('vue')
  const icon = defineComponent({ setup: () => () => h('span') })
  return {
    Loader2: icon,
    X: icon,
    Plus: icon,
    Minus: icon,
    RotateCcw: icon,
    Lock: icon,
    Unlock: icon,
  }
})

vi.mock('@/components/common/BaseModal.vue', async () => {
  const { defineComponent, h } = await import('vue')
  return {
    default: defineComponent({
      props: { isOpen: Boolean },
      setup(props, { slots }) {
        return () => props.isOpen ? h('div', { 'data-test': 'modal' }, slots.default?.()) : null
      },
    }),
  }
})

vi.mock('@/components/common/CharacterCounter.vue', async () => {
  const { defineComponent, h } = await import('vue')
  return { default: defineComponent({ setup: () => () => h('span') }) }
})

vi.mock('@/components/common/DatePickerField.vue', async () => {
  const { defineComponent, h } = await import('vue')
  return {
    default: defineComponent({
      props: { modelValue: String, disabled: Boolean },
      setup(props) {
        return () => h('button', {
          type: 'button',
          disabled: props.disabled,
          'data-test': 'date-picker',
        })
      },
    }),
  }
})

vi.mock('@/components/duty/DDayList.vue', async () => {
  const { defineComponent, h } = await import('vue')
  return {
    default: defineComponent({
      props: { dDays: { type: Array, default: () => [] } },
      emits: ['add', 'open-detail', 'toggle-pin'],
      setup(props, { emit }) {
        return () => h('div', { 'data-test': 'dday-list' }, [
          h('button', { 'data-test': 'dday-add', onClick: () => emit('add') }, 'add'),
          ...(props.dDays as Array<{ id: number; title: string }>).map(dday =>
            h('button', {
              'data-test': `dday-open-${dday.id}`,
              onClick: () => emit('open-detail', dday),
            }, dday.title),
          ),
        ])
      },
    }),
  }
})

vi.mock('@/components/duty/DDayDetailModal.vue', async () => {
  const { defineComponent, h } = await import('vue')
  return {
    default: defineComponent({
      props: { isOpen: Boolean, dday: Object },
      emits: ['close', 'edit', 'delete', 'toggle-pin'],
      setup(props, { emit }) {
        return () => props.isOpen && props.dday
          ? h('button', {
            'data-test': 'dday-edit',
            onClick: () => emit('edit', props.dday),
          }, 'edit')
          : null
      },
    }),
  }
})

const emptyStub = { default: { setup: () => () => null } }
const scheduleData = {
  content: 'Existing appointment', description: '',
  startDateTime: '2026-10-07T00:00', endDateTime: '2026-10-07T00:00',
  visibility: 'PUBLIC', tagFriendIds: [], aiTimeParsingRequested: false,
}
vi.mock('@/components/duty/DayDetailModal.vue', () => ({
  default: defineComponent({
    props: { isOpen: Boolean },
    emits: ['create-schedule', 'edit-schedule'],
    setup(props, { emit }) {
      return () => h('div', { 'data-test': 'day-detail', 'data-open': props.isOpen }, [
        h('button', { 'data-test': 'create-schedule', onClick: () => emit('create-schedule', scheduleData) }),
        h('button', { 'data-test': 'edit-schedule', onClick: () => emit('edit-schedule', { ...scheduleData, id: 'existing-id' }) }),
      ])
    },
  }),
}))
vi.mock('@/components/duty/TodoDetailModal.vue', () => emptyStub)
vi.mock('@/components/duty/SearchResultModal.vue', () => emptyStub)
vi.mock('@/components/duty/OtherDutiesModal.vue', () => ({
  default: defineComponent({
    emits: ['toggle', 'clear'],
    setup(_props, { emit }) {
      return () => h('div', [
        h('button', { 'data-test': 'toggle-comparison', onClick: () => emit('toggle', 2) }),
        h('button', { 'data-test': 'clear-comparison', onClick: () => emit('clear') }),
      ])
    },
  }),
}))
vi.mock('@/components/duty/DutyHeaderControls.vue', () => ({
  default: defineComponent({
    props: { currentYear: Number, currentMonth: Number, memberName: String },
    emits: ['open-year-month-picker', 'next-month', 'prev-month'],
    setup(props, { emit }) {
      return () => h('div', [
        h('span', { 'data-test': 'calendar-member-name' }, props.memberName),
        h('button', {
          'data-test': 'open-year-month-picker',
          onClick: () => emit('open-year-month-picker'),
        }, 'open picker'),
        h('button', {
          'data-test': 'next-month',
          onClick: () => emit('next-month'),
        }, 'next month'),
        h('button', { 'data-test': 'prev-month', onClick: () => emit('prev-month') }, 'previous month'),
      ])
    },
  }),
}))
vi.mock('@/components/duty/DutyTypesBar.vue', () => ({
  default: defineComponent({
    props: {
      batchEditMode: Boolean,
      currentYear: Number,
      currentMonth: Number,
      focusedDay: Number,
      isCalendarMonthLoaded: Boolean,
      isLoadingDuties: Boolean,
      dutyTypesWithCount: Array,
    },
    emits: ['toggle-batch-edit', 'update:focusedDay', 'quick-duty-change'],
    setup(props, { emit }) {
      return () => h('div', { 'data-test': 'duty-loading', 'data-loading': props.isLoadingDuties, 'data-counts': JSON.stringify(props.dutyTypesWithCount) }, [
        h('button', {
          'data-test': 'toggle-batch-edit',
          onClick: () => emit('toggle-batch-edit', !props.batchEditMode),
        }, 'toggle edit'),
        h('button', {
          'data-test': 'set-focused-day-31',
          onClick: () => emit('update:focusedDay', 31),
        }, 'focus 31'),
        h('button', {
          'data-test': 'quick-duty-change',
          onClick: () => emit('quick-duty-change', null),
        }, 'quick duty'),
        h('span', {
          'data-test': 'focused-day-state',
        }, `${props.currentYear}-${props.currentMonth}-${props.focusedDay ?? 'none'}`),
      ])
    },
  }),
}))
vi.mock('@/components/duty/DutyCalendarContent.vue', () => ({
  default: defineComponent({
    props: {
      days: Array,
      currentYear: Number,
      currentMonth: Number,
      calendarDataYear: Number,
      calendarDataMonth: Number,
      isCalendarMonthLoaded: Boolean,
      isMonthLoading: Boolean,
      schedulesByDays: Array,
      duties: Array,
      holidays: Array,
      otherDuties: Array,
    },
    emits: ['day-click', 'batch-duty-change'],
    setup(props, { slots, emit }) {
      return () => h('div', {
        'data-test': 'duty-calendar-content',
        'data-current-month': `${props.currentYear}-${props.currentMonth}`,
        'data-calendar-month': `${props.calendarDataYear}-${props.calendarDataMonth}`,
        'data-calendar-loaded': props.isCalendarMonthLoaded,
        'data-month-loading': props.isMonthLoading,
        'data-day-count': props.days?.length ?? 0,
        'data-schedules': JSON.stringify(props.schedulesByDays),
        'data-duties': JSON.stringify(props.duties),
        'data-holidays': JSON.stringify(props.holidays),
        'data-comparison': JSON.stringify(props.otherDuties),
      }, [
        h('button', { 'data-test': 'open-calendar-day', onClick: () => {
          const day = (props.days as Array<{ year: number; month: number; day: number }>)
            .find(day => day.year === props.calendarDataYear && day.month === props.calendarDataMonth)!
          emit('day-click', day, 0)
        } }),
        h('button', { 'data-test': 'change-calendar-duty', onClick: () => {
          emit('batch-duty-change', { year: props.calendarDataYear, month: props.calendarDataMonth, day: 1 }, null)
        } }),
        ...(slots.default?.() ?? []),
      ])
    },
  }),
}))
vi.mock('@/components/common/YearMonthPicker.vue', () => ({
  default: defineComponent({
    props: { isOpen: Boolean, currentYear: Number },
    emits: ['select'],
    setup(props, { emit }) {
      return () => props.isOpen
        ? h('button', {
          'data-test': 'select-january',
          onClick: () => emit('select', props.currentYear, 1),
        }, 'January')
        : null
    },
  }),
}))
vi.mock('@/components/common/ReportModal.vue', () => emptyStub)

const { default: DutyView } = await import('./DutyView.vue')

type DDay = {
  id: number
  title: string
  date: string
  isPrivate: boolean
  calc: number
}

function makeDDay(overrides: Partial<DDay> = {}): DDay {
  return {
    id: 1,
    title: '기존 제목',
    date: '2030-01-01',
    isPrivate: false,
    calc: 10,
    ...overrides,
  }
}

function makeCalendarDays(year: number, month: number) {
  const firstDay = new Date(year, month - 1, 1)
  const firstVisibleDay = new Date(year, month - 1, 1 - firstDay.getDay())
  return Array.from({ length: 42 }, (_, index) => {
    const date = new Date(firstVisibleDay.getFullYear(), firstVisibleDay.getMonth(), firstVisibleDay.getDate() + index)
    return { year: date.getFullYear(), month: date.getMonth() + 1, day: date.getDate() }
  })
}

function installBrowserGlobals() {
  const values = new Map<string, string>()
  const storage = {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => values.set(key, value),
    removeItem: (key: string) => values.delete(key),
    clear: () => values.clear(),
  }
  const windowValue = {
    localStorage: storage,
    sessionStorage: storage,
    history: { state: {} },
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    innerWidth: 390,
  }
  Object.defineProperty(globalThis, 'localStorage', { configurable: true, value: storage })
  Object.defineProperty(globalThis, 'sessionStorage', { configurable: true, value: storage })
  Object.defineProperty(globalThis, 'window', { configurable: true, value: windowValue })
}

async function flush() {
  for (let index = 0; index < 6; index += 1) {
    await Promise.resolve()
    await nextTick()
  }
}

async function mountDutyView() {
  installBrowserGlobals()
  const mounted = mountHost(DutyView)
  await flush()
  return mounted
}

function nodeByDataTest(root: HostNode, value: string): HostNode {
  const node = findHostNode(root, candidate => candidate.props['data-test'] === value)
  if (!node) throw new Error(`Could not find ${value}`)
  return node
}

function titleInput(root: HostNode): HostNode {
  const node = findHostNode(root, candidate => candidate.type === 'input' && candidate.props.type === 'text')
  if (!node) throw new Error('Could not find D-Day title input')
  return node
}

function saveButton(root: HostNode): HostNode {
  const node = findHostNode(root, candidate =>
    candidate.type === 'button' && String(candidate.props.class ?? '').includes('text-dp-text-on-dark'))
  if (!node) throw new Error('Could not find D-Day save button')
  return node
}

function enterTitle(root: HostNode, title: string) {
  triggerHost(titleInput(root), 'onInput', { target: { value: title } })
}

function openAddModal(root: HostNode) {
  triggerHost(nodeByDataTest(root, 'dday-add'), 'onClick')
}

function closeMounted(mounted: { app: { unmount: () => void } }) {
  mounted.app.unmount()
}

beforeEach(() => {
  vi.clearAllMocks()
  mocks.route.params = reactive({ id: '1' })
  mocks.authStore.user = { id: 1, name: 'Tester', teamId: null, isAdmin: false }
  mocks.authStore.isLoggedIn = true
  mocks.filterStore.isBlocked.mockReturnValue(false)
  mocks.memberApi.getMyInfo.mockResolvedValue({
    data: {
      id: 1,
      name: 'Tester',
      teamId: null,
      hasProfilePhoto: false,
      profilePhotoVersion: 0,
    },
  })
  mocks.friendApi.getFriends.mockResolvedValue({ data: [] })
  mocks.memberApi.getMemberById.mockImplementation((id: number) => Promise.resolve({ data: { id, name: `Member ${id}`, teamId: null } }))
  mocks.ddayApi.getDDaysByMemberId.mockResolvedValue({ data: [] })
  mocks.todoApi.getBoard.mockResolvedValue({ todo: [], inProgress: [] })
  mocks.dutyApi.getCalendar.mockResolvedValue([])
  mocks.dutyApi.getDuties.mockResolvedValue([])
  mocks.dutyApi.getHolidays.mockResolvedValue([])
  mocks.dutyApi.canManage.mockResolvedValue(false)
  mocks.dutyApi.getOtherDuties.mockResolvedValue([])
  mocks.scheduleApi.getSchedules.mockResolvedValue([])
  mocks.ddayApi.getMyDDays.mockResolvedValue({ data: [] })
  mocks.ddayApi.saveDDay.mockResolvedValue({ data: makeDDay({ id: 10, title: '새 제목' }) })
})

describe('DutyView D-Day saves', () => {
  it('creates a D-Day and sends the edited title to the API', async () => {
    const mounted = await mountDutyView()
    openAddModal(mounted.root)
    await flush()
    enterTitle(mounted.root, '여행')
    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()

    expect(mocks.ddayApi.saveDDay).toHaveBeenCalledOnce()
    expect(mocks.ddayApi.saveDDay).toHaveBeenCalledWith({
      id: undefined,
      title: '여행',
      date: expect.any(String),
      isPrivate: false,
    })
    expect(findHostNode(mounted.root, node => node.type === 'input' && node.props.type === 'text')).toBeNull()
    closeMounted(mounted)
  })

  it('updates an existing D-Day through the same save path', async () => {
    const existing = makeDDay({ id: 7, title: '이전 제목' })
    mocks.ddayApi.getMyDDays.mockResolvedValue({ data: [existing] })
    mocks.ddayApi.saveDDay.mockResolvedValue({ data: makeDDay({ id: 7, title: '새 제목' }) })
    const mounted = await mountDutyView()
    triggerHost(nodeByDataTest(mounted.root, 'dday-open-7'), 'onClick')
    await flush()
    triggerHost(nodeByDataTest(mounted.root, 'dday-edit'), 'onClick')
    await flush()
    enterTitle(mounted.root, '새 제목')
    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()

    expect(mocks.ddayApi.saveDDay).toHaveBeenCalledWith({
      id: 7,
      title: '새 제목',
      date: '2030-01-01',
      isPrivate: false,
    })
    closeMounted(mounted)
  })

  it('blocks public titles before the API call and keeps the modal input', async () => {
    mocks.filterStore.isBlocked.mockReturnValue(true)
    const mounted = await mountDutyView()
    openAddModal(mounted.root)
    await flush()
    enterTitle(mounted.root, '금지')
    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()

    expect(mocks.filterStore.isBlocked).toHaveBeenCalledWith('금지')
    expect(mocks.ddayApi.saveDDay).not.toHaveBeenCalled()
    expect(mocks.showError).toHaveBeenCalledWith('client-filtered-message')
    expect(titleInput(mounted.root).value).toBe('금지')
    closeMounted(mounted)
  })

  it('allows private D-Days without applying the public UGC filter', async () => {
    mocks.filterStore.isBlocked.mockReturnValue(true)
    const mounted = await mountDutyView()
    openAddModal(mounted.root)
    await flush()
    enterTitle(mounted.root, '금지')
    const privateToggle = findHostNode(mounted.root, node =>
      node.type === 'button' && String(node.props.class ?? '').includes('relative inline-flex'))
    if (!privateToggle) throw new Error('Could not find private D-Day toggle')
    triggerHost(privateToggle, 'onClick')
    await flush()
    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()

    expect(mocks.filterStore.isBlocked).not.toHaveBeenCalled()
    expect(mocks.ddayApi.saveDDay).toHaveBeenCalledWith({
      id: undefined,
      title: '금지',
      date: expect.any(String),
      isPrivate: true,
    })
    closeMounted(mounted)
  })

  it('maps a server content-filter error and keeps the entered input after failure', async () => {
    mocks.ddayApi.saveDDay.mockRejectedValue({ status: 400, code: 'contentFilter.blocked' })
    const mounted = await mountDutyView()
    openAddModal(mounted.root)
    await flush()
    enterTitle(mounted.root, '서버 차단')
    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()

    expect(mocks.showError).toHaveBeenCalledWith('server-filtered-message')
    expect(titleInput(mounted.root).value).toBe('서버 차단')
    expect(saveButton(mounted.root).props.disabled).toBe(false)
    closeMounted(mounted)
  })

  it('prevents a second click while the D-Day request is in flight and restores the button', async () => {
    let resolveRequest!: (value: { data: DDay }) => void
    mocks.ddayApi.saveDDay.mockReturnValue(new Promise(resolve => {
      resolveRequest = resolve
    }))
    const mounted = await mountDutyView()
    openAddModal(mounted.root)
    await flush()
    enterTitle(mounted.root, '중복 방지')
    const button = saveButton(mounted.root)
    triggerHost(button, 'onClick')
    await flush()
    expect(mocks.ddayApi.saveDDay).toHaveBeenCalledOnce()
    expect(button.props.disabled).toBe(true)
    triggerHost(button, 'onClick')
    expect(mocks.ddayApi.saveDDay).toHaveBeenCalledOnce()

    resolveRequest({ data: makeDDay({ id: 11, title: '중복 방지' }) })
    await flush()
    expect(findHostNode(mounted.root, node => node.type === 'input' && node.props.type === 'text')).toBeNull()
    closeMounted(mounted)
  })
})

describe('DutyView teamless duty guidance', () => {
  it('explains that duty input requires a team and links to the team menu', async () => {
    const mounted = await mountDutyView()

    const banner = nodeByDataTest(mounted.root, 'teamless-duty-guidance')
    expect(hostText(banner)).toContain('duty.view.teamRequired')

    triggerHost(nodeByDataTest(mounted.root, 'teamless-duty-guidance-action'), 'onClick')
    expect(mocks.router.push).toHaveBeenCalledWith('/team')

    closeMounted(mounted)
  })
})

function deferred<T>() {
  let resolve!: (value: T) => void
  let reject!: (reason: unknown) => void
  const promise = new Promise<T>((yes, no) => { resolve = yes; reject = no })
  return { promise, resolve, reject }
}

describe('DutyView calendar response ordering', () => {
  it.each([21, 0])('keeps the previous duty counts until the new month returns %i working days', async workingDays => {
    const today = new Date()
    const year = today.getFullYear()
    const month = today.getMonth() + 1
    const next = new Date(year, month, 1)
    const nextYear = next.getFullYear()
    const nextMonth = next.getMonth() + 1
    const makeDuties = (y: number, m: number, count: number) => Array.from({ length: count }, (_, index) => ({
      year: y, month: m, day: index + 1, dutyTypeId: 1, dutyType: 'Day', dutyColor: '#123456', isOff: false,
    }))
    mocks.memberApi.getMyInfo.mockResolvedValue({ data: { id: 1, name: 'Tester', teamId: 5 } })
    mocks.dutyApi.getTeam.mockResolvedValue({ dutyTypes: [
      { id: 1, name: 'Day', color: '#123456' },
      { id: null, name: 'Off', color: null },
    ] })
    mocks.dutyApi.getCalendar.mockImplementation((y: number, m: number) => Promise.resolve(makeCalendarDays(y, m)))
    mocks.dutyApi.getDuties.mockResolvedValue(makeDuties(year, month, 20))
    const mounted = await mountDutyView()
    const counts = () => JSON.parse(String(nodeByDataTest(mounted.root, 'duty-loading').props['data-counts']))
      .map((type: { cnt: number }) => type.cnt)
    const oldCounts = [20, new Date(year, month, 0).getDate() - 20]
    expect(counts()).toEqual(oldCounts)

    const calendar = deferred<ReturnType<typeof makeCalendarDays>>()
    const duties = deferred<ReturnType<typeof makeDuties>>()
    mocks.dutyApi.getCalendar.mockReturnValueOnce(calendar.promise)
    mocks.dutyApi.getDuties.mockReturnValueOnce(duties.promise)
    triggerHost(nodeByDataTest(mounted.root, 'next-month'), 'onClick')
    await flush()
    expect(counts()).toEqual(oldCounts)
    calendar.resolve(makeCalendarDays(nextYear, nextMonth))
    await flush()
    expect(counts()).toEqual(oldCounts)
    duties.resolve(makeDuties(nextYear, nextMonth, workingDays))
    await flush()
    expect(counts()).toEqual([workingDays, new Date(nextYear, nextMonth, 0).getDate() - workingDays])
    if (workingDays > 0) {
      const update = deferred<void>()
      const refreshedDuties = deferred<ReturnType<typeof makeDuties>>()
      mocks.dutyApi.updateDuty.mockReturnValueOnce(update.promise)
      mocks.dutyApi.getDuties.mockReturnValueOnce(refreshedDuties.promise)
      triggerHost(nodeByDataTest(mounted.root, 'toggle-batch-edit'), 'onClick')
      await flush()
      triggerHost(nodeByDataTest(mounted.root, 'quick-duty-change'), 'onClick')
      await flush()
      expect(counts()).toEqual([workingDays - 1, new Date(nextYear, nextMonth, 0).getDate() - workingDays + 1])
      const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {})
      update.reject(new Error('update failed'))
      await flush()
      expect(counts()).toEqual([workingDays, new Date(nextYear, nextMonth, 0).getDate() - workingDays])
      refreshedDuties.resolve(makeDuties(nextYear, nextMonth, workingDays))
      await flush()
      consoleError.mockRestore()
    }
    closeMounted(mounted)
  })

  it.each(['display', 'actions'] as const)('waits for current monthly payloads at the %s boundary', async boundary => {
    const today = new Date()
    const year = today.getFullYear()
    const month = today.getMonth() + 1
    function schedule(label: string, y: number, m: number) {
      return [[{ id: label, content: label, year: y, month: m, dayOfMonth: 1,
        startDateTime: `${y}-${String(m).padStart(2, '0')}-01T00:00`, endDateTime: `${y}-${String(m).padStart(2, '0')}-01T00:00`,
        totalDays: 1, daysFromStart: 1, tags: [], attachments: [] }]]
    }
    mocks.dutyApi.getCalendar.mockImplementation((y: number, m: number) => Promise.resolve(makeCalendarDays(y, m)))
    mocks.memberApi.getMyInfo.mockResolvedValue({ data: { id: 1, name: 'Tester', teamId: 5 } })
    mocks.dutyApi.getTeam.mockResolvedValue({ dutyTypes: [] })
    mocks.scheduleApi.getSchedules.mockResolvedValue(schedule('old schedule', year, month))
    mocks.dutyApi.getDuties.mockResolvedValue([{ year, month, day: 1, dutyType: 'old duty', dutyColor: '#123456' }])
    mocks.dutyApi.getHolidays.mockResolvedValue([[{ dateName: 'old holiday' }]])
    const mounted = await mountDutyView()
    mocks.dutyApi.getOtherDuties.mockResolvedValue([{ memberId: 2, name: 'old comparison', duties: [] }])
    triggerHost(nodeByDataTest(mounted.root, 'toggle-comparison'), 'onClick')
    await flush()
    const pending = {
      schedules: deferred<unknown[]>(), duties: deferred<unknown[]>(),
      holidays: deferred<unknown[]>(), comparison: deferred<unknown[]>(),
    }
    mocks.scheduleApi.getSchedules.mockReturnValueOnce(pending.schedules.promise)
    mocks.dutyApi.getDuties.mockReturnValueOnce(pending.duties.promise)
    mocks.dutyApi.getHolidays.mockReturnValueOnce(pending.holidays.promise)
    mocks.dutyApi.getOtherDuties.mockReturnValueOnce(pending.comparison.promise)
    triggerHost(nodeByDataTest(mounted.root, 'next-month'), 'onClick')
    await flush()
    const calendar = () => nodeByDataTest(mounted.root, 'duty-calendar-content')
    const [nextYear, nextMonth] = String(calendar().props['data-current-month']).split('-').map(Number)
    expect(calendar().props['data-calendar-month']).toBe(`${nextYear}-${nextMonth}`)
    expect(calendar().props['data-month-loading']).toBe(true)
    if (boundary === 'display') {
      for (const field of ['schedules', 'duties', 'holidays', 'comparison']) {
        expect(String(calendar().props[`data-${field}`])).not.toContain('old ')
      }
    } else {
      expect(calendar().props['data-calendar-loaded']).toBe(false)
      triggerHost(nodeByDataTest(mounted.root, 'open-calendar-day'), 'onClick')
      expect(nodeByDataTest(mounted.root, 'day-detail').props['data-open']).toBe(false)
      triggerHost(nodeByDataTest(mounted.root, 'toggle-batch-edit'), 'onClick')
      await flush()
      triggerHost(nodeByDataTest(mounted.root, 'change-calendar-duty'), 'onClick')
      triggerHost(nodeByDataTest(mounted.root, 'quick-duty-change'), 'onClick')
      expect(mocks.dutyApi.updateDuty).not.toHaveBeenCalled()
      triggerHost(nodeByDataTest(mounted.root, 'toggle-batch-edit'), 'onClick')
      await flush()
    }
    pending.schedules.resolve(schedule('new schedule', nextYear!, nextMonth!))
    pending.duties.resolve([])
    pending.holidays.resolve([])
    pending.comparison.resolve([])
    await flush()
    expect(calendar().props['data-month-loading']).toBe(false)
    expect(calendar().props['data-calendar-loaded']).toBe(true)
    expect(String(calendar().props['data-schedules'])).toContain('new schedule')
    triggerHost(nodeByDataTest(mounted.root, 'open-calendar-day'), 'onClick')
    await flush()
    expect(nodeByDataTest(mounted.root, 'day-detail').props['data-open']).toBe(true)
    closeMounted(mounted)
  })

  it('clears obsolete duty loading when the replacement calendar fails', async () => {
    mocks.dutyApi.getCalendar.mockImplementation((year: number, month: number) => Promise.resolve(makeCalendarDays(year, month)))
    const mounted = await mountDutyView()
    const pending = deferred<unknown[]>()
    mocks.dutyApi.getDuties.mockReturnValueOnce(pending.promise)
    triggerHost(nodeByDataTest(mounted.root, 'next-month'), 'onClick')
    await flush()
    expect(nodeByDataTest(mounted.root, 'duty-loading').props['data-loading']).toBe(true)
    mocks.dutyApi.getCalendar.mockRejectedValueOnce(new Error('current calendar unavailable'))
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {})
    triggerHost(nodeByDataTest(mounted.root, 'prev-month'), 'onClick')
    await flush()
    expect(nodeByDataTest(mounted.root, 'duty-loading').props['data-loading']).toBe(false)
    pending.resolve([])
    await flush()
    consoleError.mockRestore()
    closeMounted(mounted)
  })

  it('keeps the current member when an earlier member profile finishes late', async () => {
    mocks.dutyApi.getCalendar.mockImplementation((year: number, month: number) => Promise.resolve(makeCalendarDays(year, month)))
    const mounted = await mountDutyView()
    const pending = deferred<{ data: { id: number; name: string; teamId: null } }>()
    mocks.memberApi.getMemberById.mockReturnValueOnce(pending.promise)
    mocks.route.params.id = '2'
    await flush()
    mocks.route.params.id = '3'
    await flush()
    expect(hostText(nodeByDataTest(mounted.root, 'calendar-member-name'))).toBe('Member 3')
    pending.resolve({ data: { id: 2, name: 'Stale member 2', teamId: null } })
    await flush()
    expect(hostText(nodeByDataTest(mounted.root, 'calendar-member-name'))).toBe('Member 3')
    closeMounted(mounted)
  })

  it('ignores the old member schedules and D-Days after the route changes', async () => {
    mocks.dutyApi.getCalendar.mockImplementation((year: number, month: number) => Promise.resolve(makeCalendarDays(year, month)))
    const schedules = deferred<unknown[]>()
    const ddays = deferred<{ data: DDay[] }>()
    mocks.scheduleApi.getSchedules.mockReturnValueOnce(schedules.promise)
    mocks.ddayApi.getMyDDays.mockReturnValueOnce(ddays.promise)
    const mounted = await mountDutyView()
    mocks.route.params.id = '2'
    await flush()
    const before = nodeByDataTest(mounted.root, 'duty-calendar-content').props['data-schedules']
    const today = new Date()
    schedules.resolve([[{ id: 'stale', content: 'Stale schedule', year: today.getFullYear(), month: today.getMonth() + 1,
      dayOfMonth: 1, startDateTime: today.toISOString(), endDateTime: today.toISOString(), totalDays: 1, daysFromStart: 1,
      tags: [], attachments: [] }]])
    ddays.resolve({ data: [makeDDay({ id: 99, title: 'Stale D-Day' })] })
    await flush()
    expect(nodeByDataTest(mounted.root, 'duty-calendar-content').props['data-schedules']).toBe(before)
    expect(hostText(mounted.root)).not.toContain('Stale D-Day')
    closeMounted(mounted)
  })

  it.each(['schedules', 'duties', 'holidays'] as const)('ignores late %s after returning to the original month', async loader => {
    mocks.dutyApi.getCalendar.mockImplementation((year: number, month: number) => Promise.resolve(makeCalendarDays(year, month)))
    mocks.memberApi.getMyInfo.mockResolvedValue({ data: { id: 1, name: 'Tester', teamId: 5 } })
    mocks.dutyApi.getTeam.mockResolvedValue({ dutyTypes: [{ id: 1, name: 'Day', color: '#123456' }] })
    const mounted = await mountDutyView()
    const calendar = () => nodeByDataTest(mounted.root, 'duty-calendar-content')
    const originalMonth = calendar().props['data-current-month']
    const pending = deferred<unknown[]>()
    const request = { schedules: mocks.scheduleApi.getSchedules, duties: mocks.dutyApi.getDuties, holidays: mocks.dutyApi.getHolidays }[loader]
    request.mockReturnValueOnce(pending.promise)
    triggerHost(nodeByDataTest(mounted.root, 'next-month'), 'onClick')
    await flush()
    const [year, month] = String(calendar().props['data-current-month']).split('-').map(Number)
    triggerHost(nodeByDataTest(mounted.root, 'prev-month'), 'onClick')
    await flush()
    expect(calendar().props['data-current-month']).toBe(originalMonth)
    const before = calendar().props[`data-${loader}`]
    const countsBefore = nodeByDataTest(mounted.root, 'duty-loading').props['data-counts']
    const late = {
      schedules: [[{ id: 'stale', content: 'stale', year, month, dayOfMonth: 1,
        startDateTime: `${year}-${String(month).padStart(2, '0')}-01T00:00`, endDateTime: `${year}-${String(month).padStart(2, '0')}-01T00:00`,
        daysFromStart: 1, totalDays: 1, visibility: 'PUBLIC', tags: [], attachments: [] }]],
      duties: [{ year, month, day: 1, dutyTypeId: 1, dutyType: 'stale', dutyColor: '#123456' }],
      holidays: [[{ localDate: `${year}${String(month).padStart(2, '0')}01`, dateName: 'stale', isHoliday: true }]],
    }[loader]
    pending.resolve(late)
    await flush()
    expect(calendar().props[`data-${loader}`]).toBe(before)
    expect(nodeByDataTest(mounted.root, 'duty-loading').props['data-counts']).toBe(countsBefore)
    expect(calendar().props['data-month-loading']).toBe(false)
    closeMounted(mounted)
  })

  it('does not accept an earlier calendar response when the same month is requested again', async () => {
    mocks.dutyApi.getCalendar.mockImplementation((year: number, month: number) => Promise.resolve(makeCalendarDays(year, month)))
    const mounted = await mountDutyView()
    const oldCalendar = deferred<ReturnType<typeof makeCalendarDays>>()
    mocks.dutyApi.getCalendar.mockReturnValueOnce(oldCalendar.promise)
    triggerHost(nodeByDataTest(mounted.root, 'next-month'), 'onClick')
    await flush()
    const requestedMonth = nodeByDataTest(mounted.root, 'duty-calendar-content').props['data-current-month']
    triggerHost(nodeByDataTest(mounted.root, 'next-month'), 'onClick')
    await flush()
    const loadedMonth = nodeByDataTest(mounted.root, 'duty-calendar-content').props['data-calendar-month']
    const newestCalendar = deferred<ReturnType<typeof makeCalendarDays>>()
    mocks.dutyApi.getCalendar.mockReturnValueOnce(newestCalendar.promise)
    triggerHost(nodeByDataTest(mounted.root, 'prev-month'), 'onClick')
    await flush()
    const [year, month] = String(requestedMonth).split('-').map(Number)
    oldCalendar.resolve(makeCalendarDays(year!, month!))
    await flush()
    expect(nodeByDataTest(mounted.root, 'duty-calendar-content').props['data-calendar-month']).toBe(loadedMonth)
    newestCalendar.resolve(makeCalendarDays(year!, month!))
    await flush()
    expect(nodeByDataTest(mounted.root, 'duty-calendar-content').props['data-calendar-month']).toBe(requestedMonth)
    closeMounted(mounted)
  })

  it.each(['resolve', 'reject'] as const)('ignores a comparison %s after the comparison is cleared', async outcome => {
    const mounted = await mountDutyView()
    const pending = deferred<unknown[]>()
    mocks.dutyApi.getOtherDuties.mockReturnValueOnce(pending.promise)
    triggerHost(nodeByDataTest(mounted.root, 'toggle-comparison'), 'onClick')
    await flush()
    triggerHost(nodeByDataTest(mounted.root, 'clear-comparison'), 'onClick')
    await flush()
    if (outcome === 'resolve') pending.resolve([{ memberId: 2, name: 'stale', duties: [] }])
    else pending.reject(new Error('stale failure'))
    await flush()
    expect(nodeByDataTest(mounted.root, 'duty-calendar-content').props['data-comparison']).toBe('[]')
    expect(mocks.showError).not.toHaveBeenCalled()
    closeMounted(mounted)
  })
})

describe('DutyView quick duty month changes', () => {
  it('keeps the month height reserved until the aligned schedule response finishes', async () => {
    mocks.dutyApi.getCalendar.mockImplementation((year: number, month: number) => Promise.resolve(makeCalendarDays(year, month)))
    const mounted = await mountDutyView()
    let resolveSchedules!: (value: never[]) => void
    mocks.scheduleApi.getSchedules.mockReturnValueOnce(new Promise<never[]>(resolve => { resolveSchedules = resolve }))
    const calendar = () => nodeByDataTest(mounted.root, 'duty-calendar-content')

    triggerHost(nodeByDataTest(mounted.root, 'next-month'), 'onClick')
    await flush()
    expect(calendar().props['data-calendar-loaded']).toBe(false)
    expect(calendar().props['data-month-loading']).toBe(true)

    resolveSchedules([])
    await flush()
    expect(calendar().props['data-month-loading']).toBe(false)
    expect(calendar().props['data-calendar-loaded']).toBe(true)
    closeMounted(mounted)
  })

  it('keeps the old calendar and skips aligned data requests when the new calendar fails', async () => {
    const today = new Date()
    const initialYear = today.getFullYear()
    const initialMonth = today.getMonth() + 1
    const nextMonthDate = new Date(initialYear, initialMonth, 1)
    const nextYear = nextMonthDate.getFullYear()
    const nextMonth = nextMonthDate.getMonth() + 1
    mocks.dutyApi.getCalendar.mockImplementation((year: number, month: number) => {
      if (year === nextYear && month === nextMonth) return Promise.reject(new Error('calendar unavailable'))
      return Promise.resolve(makeCalendarDays(year, month))
    })
    const mounted = await mountDutyView()
    const calendar = () => nodeByDataTest(mounted.root, 'duty-calendar-content')
    const requestCounts = {
      duties: mocks.dutyApi.getDuties.mock.calls.length,
      schedules: mocks.scheduleApi.getSchedules.mock.calls.length,
      holidays: mocks.dutyApi.getHolidays.mock.calls.length,
      otherDuties: mocks.dutyApi.getOtherDuties.mock.calls.length,
    }
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {})

    triggerHost(nodeByDataTest(mounted.root, 'next-month'), 'onClick')
    await flush()

    expect(calendar().props['data-current-month']).toBe(`${nextYear}-${nextMonth}`)
    expect(calendar().props['data-calendar-month']).toBe(`${initialYear}-${initialMonth}`)
    expect(calendar().props['data-calendar-loaded']).toBe(false)
    expect(mocks.dutyApi.getDuties).toHaveBeenCalledTimes(requestCounts.duties)
    expect(mocks.scheduleApi.getSchedules).toHaveBeenCalledTimes(requestCounts.schedules)
    expect(mocks.dutyApi.getHolidays).toHaveBeenCalledTimes(requestCounts.holidays)
    expect(mocks.dutyApi.getOtherDuties).toHaveBeenCalledTimes(requestCounts.otherDuties)

    consoleError.mockRestore()
    closeMounted(mounted)
  })

  it('keeps the loaded month until its newest calendar response arrives', async () => {
    let resolveFirstTarget!: (days: ReturnType<typeof makeCalendarDays>) => void
    let resolveLatestTarget!: (days: ReturnType<typeof makeCalendarDays>) => void
    const firstTargetCalendar = new Promise<ReturnType<typeof makeCalendarDays>>(resolve => { resolveFirstTarget = resolve })
    const latestTargetCalendar = new Promise<ReturnType<typeof makeCalendarDays>>(resolve => { resolveLatestTarget = resolve })
    const today = new Date()
    const initialYear = today.getFullYear()
    const initialMonth = today.getMonth() + 1
    const nextMonthDate = new Date(initialYear, initialMonth, 1)
    const followingMonthDate = new Date(initialYear, initialMonth + 1, 1)
    const nextYear = nextMonthDate.getFullYear()
    const nextMonth = nextMonthDate.getMonth() + 1
    const followingYear = followingMonthDate.getFullYear()
    const followingMonth = followingMonthDate.getMonth() + 1

    mocks.memberApi.getMyInfo.mockResolvedValue({
      data: { id: 1, name: 'Tester', teamId: 5, hasProfilePhoto: false, profilePhotoVersion: 0 },
    })
    mocks.dutyApi.getTeam.mockResolvedValue({ dutyTypes: [] })
    mocks.dutyApi.updateDuty.mockResolvedValue(undefined)

    mocks.dutyApi.getCalendar.mockImplementation((year: number, month: number) => {
      if (year === nextYear && month === nextMonth) return firstTargetCalendar
      if (year === followingYear && month === followingMonth) return latestTargetCalendar
      return Promise.resolve(makeCalendarDays(year, month))
    })

    const mounted = await mountDutyView()
    const calendar = () => nodeByDataTest(mounted.root, 'duty-calendar-content')
    expect(calendar().props['data-calendar-month']).toBe(`${initialYear}-${initialMonth}`)
    triggerHost(nodeByDataTest(mounted.root, 'toggle-batch-edit'), 'onClick')
    await flush()

    triggerHost(nodeByDataTest(mounted.root, 'next-month'), 'onClick')
    await flush()
    expect(calendar().props['data-current-month']).toBe(`${nextYear}-${nextMonth}`)
    expect(calendar().props['data-calendar-month']).toBe(`${initialYear}-${initialMonth}`)
    expect(calendar().props['data-calendar-loaded']).toBe(false)
    triggerHost(nodeByDataTest(mounted.root, 'quick-duty-change'), 'onClick')
    expect(mocks.dutyApi.updateDuty).not.toHaveBeenCalled()

    triggerHost(nodeByDataTest(mounted.root, 'next-month'), 'onClick')
    await flush()
    expect(calendar().props['data-current-month']).toBe(`${followingYear}-${followingMonth}`)
    expect(calendar().props['data-calendar-month']).toBe(`${initialYear}-${initialMonth}`)

    resolveFirstTarget(makeCalendarDays(nextYear, nextMonth))
    await flush()
    expect(calendar().props['data-calendar-month']).toBe(`${initialYear}-${initialMonth}`)
    expect(calendar().props['data-month-loading']).toBe(true)

    resolveLatestTarget(makeCalendarDays(followingYear, followingMonth))
    await flush()
    expect(calendar().props['data-calendar-month']).toBe(`${followingYear}-${followingMonth}`)
    expect(calendar().props['data-calendar-loaded']).toBe(true)
    expect(calendar().props['data-month-loading']).toBe(false)
    triggerHost(nodeByDataTest(mounted.root, 'quick-duty-change'), 'onClick')
    await flush()
    expect(mocks.dutyApi.updateDuty).toHaveBeenCalledWith(1, followingYear, followingMonth, 1, null)
    closeMounted(mounted)
  })

  it('clamps a focused day when moving from a long month to February', async () => {
    const mounted = await mountDutyView()

    triggerHost(nodeByDataTest(mounted.root, 'open-year-month-picker'), 'onClick')
    await flush()
    triggerHost(nodeByDataTest(mounted.root, 'select-january'), 'onClick')
    await flush()

    triggerHost(nodeByDataTest(mounted.root, 'toggle-batch-edit'), 'onClick')
    await flush()
    triggerHost(nodeByDataTest(mounted.root, 'set-focused-day-31'), 'onClick')
    await flush()
    expect(nodeByDataTest(mounted.root, 'focused-day-state').children[0]?.text).toMatch(/-1-31$/)

    triggerHost(nodeByDataTest(mounted.root, 'next-month'), 'onClick')
    await flush()

    expect(nodeByDataTest(mounted.root, 'focused-day-state').children[0]?.text).toMatch(/-2-28$/)
    closeMounted(mounted)
  })
})


describe('DutyView schedule save outcomes', () => {
  it('informs the user when an identical schedule exists without claiming creation', async () => {
    mocks.scheduleApi.saveSchedule.mockResolvedValue({ id: 'existing-id', created: false })
    const mounted = await mountDutyView()
    const initialLoads = mocks.scheduleApi.getSchedules.mock.calls.length
    triggerHost(nodeByDataTest(mounted.root, 'create-schedule'), 'onClick')
    await flush()
    expect(mocks.scheduleApi.saveSchedule).toHaveBeenCalledWith(expect.objectContaining({ content: scheduleData.content }))
    expect(mocks.scheduleApi.getSchedules).toHaveBeenCalledTimes(initialLoads + 1)
    expect(mocks.toastInfo).toHaveBeenCalledWith('duty.schedule.messages.duplicate')
    expect(mocks.toastSuccess).not.toHaveBeenCalled()
    expect(mocks.showError).not.toHaveBeenCalled()
    closeMounted(mounted)
  })

  it.each([{ id: 'new-id', created: true }, { id: 'legacy-id' }])(
    'keeps success feedback for a new schedule or a legacy response %j', async result => {
      mocks.scheduleApi.saveSchedule.mockResolvedValue(result)
      const mounted = await mountDutyView()
      triggerHost(nodeByDataTest(mounted.root, 'create-schedule'), 'onClick')
      await flush()
      expect(mocks.toastSuccess).toHaveBeenCalledWith('duty.schedule.messages.created')
      expect(mocks.toastInfo).not.toHaveBeenCalled()
      closeMounted(mounted)
    },
  )

  it('does not interpret an update response as a duplicate creation', async () => {
    mocks.scheduleApi.saveSchedule.mockResolvedValue({ id: 'existing-id', created: false })
    const mounted = await mountDutyView()
    triggerHost(nodeByDataTest(mounted.root, 'edit-schedule'), 'onClick')
    await flush()
    expect(mocks.scheduleApi.saveSchedule).toHaveBeenCalledWith(expect.objectContaining({ id: 'existing-id' }))
    expect(mocks.toastInfo).not.toHaveBeenCalled()
    expect(mocks.showError).not.toHaveBeenCalled()
    closeMounted(mounted)
  })

  it('still reports an API failure instead of a duplicate message', async () => {
    mocks.scheduleApi.saveSchedule.mockRejectedValue(new Error('network unavailable'))
    const mounted = await mountDutyView()
    triggerHost(nodeByDataTest(mounted.root, 'create-schedule'), 'onClick')
    await flush()
    expect(mocks.showError).toHaveBeenCalledWith('duty.schedule.messages.createFailed')
    expect(mocks.toastInfo).not.toHaveBeenCalled()
    expect(mocks.toastSuccess).not.toHaveBeenCalled()
    closeMounted(mounted)
  })
})
