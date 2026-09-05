import { beforeEach, describe, expect, it, vi } from 'vitest'
import { h, nextTick } from 'vue'
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

vi.mock('lucide-vue-next', async () => {
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
vi.mock('@/components/duty/DayDetailModal.vue', () => emptyStub)
vi.mock('@/components/duty/TodoDetailModal.vue', () => emptyStub)
vi.mock('@/components/duty/SearchResultModal.vue', () => emptyStub)
vi.mock('@/components/duty/OtherDutiesModal.vue', () => emptyStub)
vi.mock('@/components/duty/DutyHeaderControls.vue', () => emptyStub)
vi.mock('@/components/duty/DutyTypesBar.vue', () => emptyStub)
vi.mock('@/components/duty/DutyCalendarContent.vue', () => emptyStub)
vi.mock('@/components/common/YearMonthPicker.vue', () => emptyStub)
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
  mocks.route.params.id = '1'
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
