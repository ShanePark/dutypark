import { beforeEach, describe, expect, it, vi } from 'vitest'
import { h, nextTick, reactive } from 'vue'
import ko from '@/i18n/messages/ko'
import {
  createHostWrapper,
  findHostNode,
  mountHost,
  triggerHost,
  type HostNode,
} from '@/test/hostRenderer'

const mocks = vi.hoisted(() => ({
  t: vi.fn((key: string) => key),
  filterStore: { isBlocked: vi.fn() },
  teamApi: {
    addDutyType: vi.fn(),
    updateDutyType: vi.fn(),
    updateDefaultDuty: vi.fn(),
  },
  showWarning: vi.fn(),
  showError: vi.fn(),
  toastSuccess: vi.fn(),
  pickr: {
    create: vi.fn(() => ({
      on: vi.fn(),
      destroyAndRemove: vi.fn(),
    })),
  },
}))

vi.mock('@/i18n', () => ({
  translateGlobal: (key: string) => key,
  i18n: { global: { locale: { value: 'ko' }, t: (key: string) => key } },
}))

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: mocks.t }),
  createI18n: () => ({ global: { locale: { value: 'ko' }, t: mocks.t } }),
}))

vi.doMock('vue-i18n', () => ({
  useI18n: () => ({ t: mocks.t }),
  createI18n: () => ({ global: { locale: { value: 'ko' }, t: mocks.t } }),
}))

vi.mock('@/api/team', () => ({ teamApi: mocks.teamApi }))
vi.mock('@/stores/contentFilter', () => ({
  useContentFilterStore: () => mocks.filterStore,
}))
vi.mock('@/composables/useSwal', () => ({
  useSwal: () => ({
    showWarning: mocks.showWarning,
    showError: mocks.showError,
    toastSuccess: mocks.toastSuccess,
  }),
}))
vi.mock('@simonwep/pickr', () => ({ default: mocks.pickr }))
vi.mock('@simonwep/pickr/dist/themes/monolith.min.css', () => ({}))

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
  return {
    default: defineComponent({
      setup() {
        return () => h('span')
      },
    }),
  }
})

vi.mock('lucide-vue-next', async () => {
  const { defineComponent, h } = await import('vue')
  const icon = defineComponent({
    setup() {
      return () => h('span')
    },
  })
  return { X: icon }
})

const { default: DutyTypeModal } = await import('./DutyTypeModal.vue')

function flush() {
  return nextTick().then(() => Promise.resolve()).then(() => nextTick())
}

function mountDutyType(options: {
  dutyType?: { id: number; name: string; color: string; position: number; hidden: boolean } | null
} = {}) {
  const state = reactive({
    isOpen: true,
    saving: false,
    dutyType: options.dutyType === undefined ? null : options.dutyType,
  })
  const savingEvents: boolean[] = []
  const savedEvents: unknown[] = []

  const wrapper = createHostWrapper(() => h(DutyTypeModal, {
    isOpen: state.isOpen,
    teamId: 42,
    dutyType: state.dutyType,
    dutyTypes: state.dutyType ? [state.dutyType] : [],
    saving: state.saving,
    onClose: () => { state.isOpen = false },
    onSaved: () => { savedEvents.push(true) },
    'onUpdate:saving': (value: boolean) => {
      savingEvents.push(value)
      state.saving = value
    },
  }))
  const mounted = mountHost(wrapper)
  return { ...mounted, state, savingEvents, savedEvents }
}

function nameInput(root: HostNode): HostNode {
  const input = findHostNode(root, (node) => node.type === 'input' && node.props.type === 'text')
  if (!input) throw new Error('Could not find duty type name input')
  return input
}

function saveButton(root: HostNode): HostNode {
  const button = findHostNode(root, (node) =>
    node.type === 'button' && String(node.props.class ?? '').includes('bg-dp-success')
  )
  if (!button) throw new Error('Could not find duty type save button')
  return button
}

function enterName(root: HostNode, name: string) {
  triggerHost(nameInput(root), 'onInput', { target: { value: name } })
}

const variants = [
  {
    name: 'new',
    dutyType: null,
    method: 'addDutyType' as const,
    args: [42, { teamId: 42, name: '주간', color: '#ffb3ba' }],
  },
  {
    name: 'existing',
    dutyType: { id: 7, name: '기존', color: '#123456', position: 0, hidden: false },
    method: 'updateDutyType' as const,
    args: [42, { id: 7, name: '주간', color: '#123456' }],
  },
  {
    name: 'default',
    dutyType: { id: 1, name: '휴무', color: '#654321', position: -1, hidden: false },
    method: 'updateDefaultDuty' as const,
    args: [42, '주간', '#654321'],
  },
]

describe('DutyTypeModal save behavior', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mocks.t.mockImplementation((key: string) => {
      if (key === 'contentFilter.blocked') return ko.contentFilter.blocked
      if (key === 'apiErrors.contentFilter.blocked') return ko.apiErrors.contentFilter.blocked
      return key
    })
    mocks.filterStore.isBlocked.mockReturnValue(false)
    mocks.teamApi.addDutyType.mockResolvedValue(undefined)
    mocks.teamApi.updateDutyType.mockResolvedValue(undefined)
    mocks.teamApi.updateDefaultDuty.mockResolvedValue(undefined)
  })

  it.each(variants)('does not call the $name API when the name is blocked', async (variant) => {
    mocks.filterStore.isBlocked.mockReturnValue(true)
    const mounted = mountDutyType({ dutyType: variant.dutyType })
    await flush()
    enterName(mounted.root, '금지')

    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()

    expect(mocks.filterStore.isBlocked).toHaveBeenCalledWith('금지')
    expect(mocks.teamApi[variant.method]).not.toHaveBeenCalled()
    expect(mocks.showError).toHaveBeenCalledWith(ko.contentFilter.blocked)
    expect(mounted.savingEvents).toEqual([])
  })

  it.each(variants)('saves the $name duty type through its API branch', async (variant) => {
    const mounted = mountDutyType({ dutyType: variant.dutyType })
    await flush()
    enterName(mounted.root, '주간')

    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()

    expect(mocks.teamApi[variant.method]).toHaveBeenCalledWith(...variant.args)
    expect(mounted.savingEvents).toEqual([true, false])
    expect(mounted.state.isOpen).toBe(false)
  })

  it('maps a server content-filter error to the shared message and restores saving state', async () => {
    mocks.teamApi.addDutyType.mockRejectedValue({ status: 400, code: 'contentFilter.blocked' })
    const mounted = mountDutyType()
    await flush()
    enterName(mounted.root, '금지')

    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()

    expect(mocks.showError).toHaveBeenCalledWith(ko.apiErrors.contentFilter.blocked)
    expect(mounted.savingEvents).toEqual([true, false])
    expect(mounted.state.saving).toBe(false)
    expect(mounted.state.isOpen).toBe(true)
    expect(mounted.savedEvents).toEqual([])
    expect(nameInput(mounted.root).value).toBe('금지')
  })

  it('ignores a second click while the first request is pending', async () => {
    let resolveRequest!: () => void
    mocks.teamApi.addDutyType.mockReturnValue(new Promise<void>((resolve) => {
      resolveRequest = resolve
    }))
    const mounted = mountDutyType()
    await flush()
    enterName(mounted.root, '주간')

    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()
    expect(saveButton(mounted.root).props.disabled).toBe(true)
    triggerHost(saveButton(mounted.root), 'onClick')
    expect(mocks.teamApi.addDutyType).toHaveBeenCalledTimes(1)

    resolveRequest()
    await flush()
    expect(mounted.savingEvents).toEqual([true, false])
    expect(mounted.state.saving).toBe(false)
  })
})
