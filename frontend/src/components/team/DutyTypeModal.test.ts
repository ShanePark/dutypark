import { beforeEach, describe, expect, it, vi } from 'vitest'
import { h, nextTick, reactive } from 'vue'
import dutyTypeModalSource from './DutyTypeModal.vue?raw'
import en from '@/i18n/messages/en'
import ko from '@/i18n/messages/ko'
import {
  createHostWrapper,
  findHostNode,
  findHostNodes,
  mountHost,
  triggerHost,
  type HostNode,
  hostText,
} from '@/test/hostRenderer'

const mocks = vi.hoisted(() => ({
  t: vi.fn((key: string) => key),
  locale: { value: 'ko' },
  filterStore: { isBlocked: vi.fn() },
  teamApi: {
    addDutyType: vi.fn(),
    updateDutyType: vi.fn(),
    updateDefaultDuty: vi.fn(),
  },
  showWarning: vi.fn(),
  showError: vi.fn(),
  toastSuccess: vi.fn(),
  pickrInstances: [] as Array<{ on: ReturnType<typeof vi.fn>; setColor: ReturnType<typeof vi.fn>; destroyAndRemove: ReturnType<typeof vi.fn> }>,
  pickrCreate: vi.fn((_options: { default: string; defaultRepresentation?: string }) => ({ on: vi.fn((event, callback) => { if (event === 'init') callback() }), setColor: vi.fn(), destroyAndRemove: vi.fn() })),

}))

vi.mock('@/i18n', () => ({
  translateGlobal: (key: string) => key,
  i18n: { global: { locale: { value: 'ko' }, t: (key: string) => key } },
}))

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: mocks.t, locale: mocks.locale }),
  createI18n: () => ({ global: { locale: { value: 'ko' }, t: mocks.t } }),
}))

vi.doMock('vue-i18n', () => ({
  useI18n: () => ({ t: mocks.t, locale: mocks.locale }),
  createI18n: () => ({ global: { locale: { value: 'ko' }, t: mocks.t } }),
}))

vi.mock('@simonwep/pickr', () => ({ default: { create: mocks.pickrCreate } }))
vi.mock('@simonwep/pickr/dist/themes/monolith.min.css', () => ({}))

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

vi.mock('@lucide/vue', async () => {
  const { defineComponent, h } = await import('vue')
  const icon = defineComponent({
    setup() {
      return () => h('span')
    },
  })
  return { X: icon, Check: icon }
})

const { default: DutyTypeModal } = await import('./DutyTypeModal.vue')

function flush() {
  return nextTick().then(() => Promise.resolve()).then(() => nextTick())
}

function mountDutyType(options: {
  dutyType?: { id: number; name: string; color: string; position: number; hidden: boolean; abbreviation?: string | null } | null
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

function abbreviationInput(root: HostNode): HostNode {
  const input = findHostNode(root, (node) => node.type === 'input' && node.props.id === 'duty-type-abbreviation')
  if (!input) throw new Error('Could not find duty abbreviation input')
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
    args: [42, { teamId: 42, name: '주간', color: '#F6D365', abbreviation: null }],
  },
  {
    name: 'existing',
    dutyType: { id: 7, name: '기존', color: '#123456', position: 0, hidden: false },
    method: 'updateDutyType' as const,
    args: [42, { id: 7, name: '주간', color: '#123456', abbreviation: null }],
  },
  {
    name: 'default',
    dutyType: { id: 1, name: '휴무', color: '#654321', position: -1, hidden: false },
    method: 'updateDefaultDuty' as const,
    args: [42, '주간', '#654321', ''],
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

  it('shows an automatic placeholder without persisting the inferred character', async () => {
    const mounted = mountDutyType()
    enterName(mounted.root, '야간근무')
    await flush()
    expect(abbreviationInput(mounted.root).props.placeholder).toBe('야')
    expect(abbreviationInput(mounted.root).value).toBe('')
    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()
    expect(mocks.teamApi.addDutyType).toHaveBeenCalledWith(42, {
      teamId: 42, name: '야간근무', color: '#F6D365', abbreviation: null,
    })
  })

  it('saves a trimmed custom abbreviation without changing the full name', async () => {
    const mounted = mountDutyType()
    enterName(mounted.root, '야간근무')
    triggerHost(abbreviationInput(mounted.root), 'onInput', { target: { value: ' N ' } })
    await flush()
    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()
    expect(mocks.teamApi.addDutyType).toHaveBeenCalledWith(42, {
      teamId: 42, name: '야간근무', color: '#F6D365', abbreviation: 'N',
    })
  })

  it('preserves ASCII letter case and limits the field to three characters', async () => {
    const mounted = mountDutyType()
    enterName(mounted.root, '야간근무')
    const input = abbreviationInput(mounted.root)
    expect(input.props.maxlength).toBe('3')
    expect(input.props.pattern).toBe('[A-Za-z가-힣]{1,3}')

    triggerHost(input, 'onInput', { target: { value: 'nAb' } })
    await flush()

    expect(input.value).toBe('nAb')
    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()
    expect(mocks.teamApi.addDutyType).toHaveBeenCalledWith(42, {
      teamId: 42, name: '야간근무', color: '#F6D365', abbreviation: 'nAb',
    })
  })

  it('keeps up to three Hangul syllables valid and rejects digits, jamo, and overlong values', async () => {
    const mounted = mountDutyType()
    enterName(mounted.root, '야간근무')
    const input = abbreviationInput(mounted.root)

    for (const value of ['가', '가나다', '1', 'ㄱ', 'ABCD']) {
      triggerHost(input, 'onInput', { target: { value } })
      await flush()
      if (value === '가' || value === '가나다') {
        expect(saveButton(mounted.root).props.disabled).toBe(false)
      } else {
        expect(saveButton(mounted.root).props.disabled).toBe(true)
      }
    }
  })

  it('does not transform an in-progress Hangul composition until it is committed', async () => {
    const mounted = mountDutyType()
    enterName(mounted.root, '야간근무')
    const input = abbreviationInput(mounted.root)

    triggerHost(input, 'onCompositionstart')
    triggerHost(input, 'onInput', { target: { value: 'ㄱ' }, isComposing: true })
    expect(input.value).toBe('ㄱ')

    triggerHost(input, 'onCompositionend', { target: { value: '가' } })
    await flush()
    expect(input.value).toBe('가')
    expect(saveButton(mounted.root).props.disabled).toBe(false)
  })

  it('clears an existing override with explicit null', async () => {
    const mounted = mountDutyType({ dutyType: {
      id: 7, name: '야간근무', color: '#123456', position: 0, hidden: false, abbreviation: 'N',
    } })
    await flush()
    expect(abbreviationInput(mounted.root).value).toBe('N')
    triggerHost(abbreviationInput(mounted.root), 'onInput', { target: { value: '' } })
    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()
    expect(mocks.teamApi.updateDutyType).toHaveBeenCalledWith(42, {
      id: 7, name: '야간근무', color: '#123456', abbreviation: null,
    })
  })

  it('also configures the synthetic default duty abbreviation', async () => {
    const mounted = mountDutyType({ dutyType: {
      id: 1, name: '휴무', color: '#654321', position: -1, hidden: false,
    } })
    triggerHost(abbreviationInput(mounted.root), 'onInput', { target: { value: 'O' } })
    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()
    expect(mocks.teamApi.updateDefaultDuty).toHaveBeenCalledWith(42, '휴무', '#654321', 'O')
  })

  it('rejects blocked abbreviations before starting a save', async () => {
    mocks.filterStore.isBlocked.mockImplementation((value: string) => value === 'B')
    const mounted = mountDutyType()
    enterName(mounted.root, '야간근무')
    triggerHost(abbreviationInput(mounted.root), 'onInput', { target: { value: 'B' } })
    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()
    expect(mocks.teamApi.addDutyType).not.toHaveBeenCalled()
    expect(mocks.showError).toHaveBeenCalledWith(ko.contentFilter.blocked)
    expect(mounted.savingEvents).toEqual([])
  })

  it('rejects overlong abbreviations even when input events bypass maxlength', async () => {
    const mounted = mountDutyType()
    enterName(mounted.root, '야간근무')
    triggerHost(abbreviationInput(mounted.root), 'onInput', { target: { value: 'ABCD' } })
    await flush()
    expect(saveButton(mounted.root).props.disabled).toBe(true)
    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()
    expect(mocks.teamApi.addDutyType).not.toHaveBeenCalled()
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

describe('DutyTypeModal previews', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mocks.t.mockImplementation((key: string) => key)
    mocks.filterStore.isBlocked.mockReturnValue(false)
  })

  it('renders one readable full-name badge using the configured color', async () => {
    const mounted = mountDutyType()
    enterName(mounted.root, '야간근무')
    await flush()

    const previews = findHostNodes(
      mounted.root,
      (node) => node.type === 'span' && String(node.props.class ?? '').includes('duty-type-preview'),
    )

    expect(previews).toHaveLength(1)
    expect(previews.map(hostText)).toEqual(['야간근무'])
    for (const preview of previews) {
      expect(String(preview.props.class)).toContain('px-2.5')
      expect(String(preview.props.class)).toContain('py-0.5')
      expect(String(preview.props.class)).toContain('rounded-md')
      expect(String(preview.props.class)).toContain('font-semibold')
      expect(String(preview.props.class)).toContain('text-sm')
      expect(preview.props.style).toMatchObject({
        backgroundColor: '#F6D365',
        color: 'var(--dp-text-on-light)',
      })
    }
  })

  it('uses the dark text token when the selected color needs it', async () => {
    const mounted = mountDutyType({
      dutyType: { id: 7, name: '야간근무', color: '#123456', position: 0, hidden: false, abbreviation: 'N' },
    })
    await flush()

    const previews = findHostNodes(
      mounted.root,
      (node) => node.type === 'span' && String(node.props.class ?? '').includes('duty-type-preview'),
    )

    expect(previews).toHaveLength(1)
    expect(previews.every((preview) => {
      const style = preview.props.style as { color?: string } | undefined
      return style?.color === 'var(--dp-text-on-dark)'
    })).toBe(true)
  })

  it('keeps the edit form compact and removes redundant explanatory copy', () => {
    expect(dutyTypeModalSource).toContain('grid grid-cols-[minmax(0,1fr)_minmax(0,0.8fr)]')
    expect(dutyTypeModalSource).not.toContain("t('dutyAbbreviation.hint')")
    expect(dutyTypeModalSource).not.toContain("t('dutyAbbreviation.preview')")
    expect(dutyTypeModalSource).not.toContain('team.dutyType.defaultNotice')
    expect(dutyTypeModalSource).not.toContain("t('team.dutyType.description')")
  })

  it('marks only the duty name as required and keeps both field labels on one aligned row', async () => {
    const mounted = mountDutyType()
    await flush()

    expect(ko.dutyAbbreviation.label).toBe('단축어')
    expect(en.dutyAbbreviation.label).toBe('Abbreviation')
    expect(nameInput(mounted.root).props.required).toBe('')
    expect(nameInput(mounted.root).props['aria-required']).toBe('true')
    expect(abbreviationInput(mounted.root).props.required).toBeUndefined()
    expect(abbreviationInput(mounted.root).props['aria-required']).toBeUndefined()

    const labels = findHostNodes(mounted.root, (node) => node.type === 'label')
    const nameLabel = labels.find((node) => node.props.for === 'duty-type-name')
    const abbreviationLabel = labels.find((node) => node.props.for === 'duty-type-abbreviation')
    const requiredIndicator = findHostNode(
      mounted.root,
      (node) => node.type === 'span' && String(node.props.class ?? '').includes('duty-type-required-indicator'),
    )
    expect(String(nameLabel?.props.class)).toContain('whitespace-nowrap')
    expect(String(abbreviationLabel?.props.class)).toContain('whitespace-nowrap')
    expect(requiredIndicator?.props['aria-hidden']).toBe('true')
    expect(dutyTypeModalSource).toContain('min-h-5')
    expect(dutyTypeModalSource).toContain('duty-type-required-indicator')
  })
})

describe('DutyTypeModal representative palette', () => {
  beforeEach(() => { vi.clearAllMocks(); mocks.t.mockImplementation((key: string) => key); mocks.filterStore.isBlocked.mockReturnValue(false) })
  it('offers eleven representative options and one custom option and defaults new duties to yellow', async () => {
    const mounted = mountDutyType(); await flush()
    const options = findHostNodes(mounted.root, node => node.type === 'input' && node.props.type === 'radio' && node.props.value !== 'custom')
    expect(options).toHaveLength(11)
    expect(options.map(node => node.props.value)).toEqual(['#ECC2C9', '#F6BC7A', '#F6D365', '#D8BF9B', '#C8DD70', '#A6D99B', '#8FDCBD', '#9DDBDE', '#D1B8EC', '#E9AEE9', '#CCC8BD'])
    expect(options.find(node => node.props.value === '#F6D365')?.props.checked).toBe(true)
    expect(findHostNodes(mounted.root, node => node.type === 'input' && node.props.type === 'radio')).toHaveLength(12)
    expect(dutyTypeModalSource).toContain('grid grid-cols-2 gap-2')
  })
  it('preserves a legacy color until a palette option is selected', async () => {
    const mounted = mountDutyType({ dutyType: { id: 7, name: '기존', color: '#123456', position: 0, hidden: false } }); await flush()
    const options = findHostNodes(mounted.root, node => node.type === 'input' && node.props.type === 'radio' && node.props.value !== 'custom')
    expect(options.every(node => !node.props.checked)).toBe(true)
    expect(hostText(mounted.root)).toContain('team.dutyType.palette.currentColor')
    enterName(mounted.root, '주간'); triggerHost(saveButton(mounted.root), 'onClick'); await flush()
    expect(mocks.teamApi.updateDutyType).toHaveBeenCalledWith(42, { id: 7, name: '주간', color: '#123456', abbreviation: null })
  })
  it('updates preview and saves only the selected representative color', async () => {
    const mounted = mountDutyType(); await flush(); enterName(mounted.root, '주간')
    const option = findHostNode(mounted.root, node => node.type === 'input' && node.props.value === '#A6D99B')
    expect(option).not.toBeNull(); triggerHost(option!, 'onChange', { target: { checked: true } }); await flush()
    const preview = findHostNode(mounted.root, node => node.type === 'span' && String(node.props.class ?? '').includes('duty-type-preview'))
    expect(preview?.props.style).toMatchObject({ backgroundColor: '#A6D99B' })
    triggerHost(saveButton(mounted.root), 'onClick'); await flush()
    expect(mocks.teamApi.addDutyType).toHaveBeenCalledWith(42, { teamId: 42, name: '주간', color: '#A6D99B', abbreviation: null })
  })
  it('leaves the exact stored palette value unchanged on a no-op selection', async () => {
    const mounted = mountDutyType({ dutyType: { id: 7, name: '기존', color: '#f6d365', position: 0, hidden: false } })
    await flush()
    const option = findHostNode(mounted.root, node => node.type === 'input' && node.props.value === '#F6D365')
    expect(option?.props.checked).toBe(true)
    triggerHost(option!, 'onChange', { target: { checked: true } })
    enterName(mounted.root, '주간'); triggerHost(saveButton(mounted.root), 'onClick'); await flush()
    expect(mocks.teamApi.updateDutyType).toHaveBeenCalledWith(42, { id: 7, name: '주간', color: '#f6d365', abbreviation: null })
  })
  it('disables palette selection while saving and ignores a forced change event', async () => {
    const mounted = mountDutyType(); mounted.state.saving = true; await flush()
    const options = findHostNodes(mounted.root, node => node.type === 'input' && node.props.type === 'radio')
    expect(options.every(node => node.props.disabled)).toBe(true)
    triggerHost(options[4]!, 'onChange', { target: { checked: true } }); await flush()
    expect(options.find(node => node.props.value === '#F6D365')?.props.checked).toBe(true)
  })
  it('discards palette selection when closed and reopened', async () => {
    const mounted = mountDutyType(); await flush()
    const option = findHostNode(mounted.root, node => node.type === 'input' && node.props.value === '#A6D99B')
    expect(option).not.toBeNull(); triggerHost(option!, 'onChange', { target: { checked: true } }); await flush()
    mounted.state.isOpen = false; await flush(); mounted.state.isOpen = true; await flush()
    const selected = findHostNodes(mounted.root, node => node.type === 'input' && node.props.type === 'radio' && Boolean(node.props.checked))
    expect(selected.map(node => node.props.value)).toEqual(['#F6D365'])
    expect(mocks.teamApi.addDutyType).not.toHaveBeenCalled()
  })
})


describe('DutyTypeModal custom spectrum', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mocks.t.mockImplementation((key: string) => key)
    mocks.filterStore.isBlocked.mockReturnValue(false)
    mocks.pickrInstances.length = 0
    mocks.pickrCreate.mockImplementation(() => {
      const instance = { on: vi.fn((event, callback) => { if (event === 'init') callback() }), setColor: vi.fn(), destroyAndRemove: vi.fn() }
      mocks.pickrInstances.push(instance)
      return instance
    })
  })

  function customOption(root: HostNode): HostNode {
    const option = findHostNode(root, node => node.type === 'input' && node.props.value === 'custom')
    if (!option) throw new Error('Could not find custom color option')
    return option
  }

  it('opens the spectrum without changing the current color and ignores repeated selection', async () => {
    const mounted = mountDutyType()
    await flush()
    expect(mocks.pickrCreate).not.toHaveBeenCalled()
    triggerHost(customOption(mounted.root), 'onChange')
    await flush()
    expect(mocks.pickrCreate).toHaveBeenCalledTimes(1)
    const preview = findHostNode(mounted.root, node => String(node.props.class ?? '').includes('duty-type-preview'))
    expect(preview?.props.style).toMatchObject({ backgroundColor: '#F6D365' })
    triggerHost(customOption(mounted.root), 'onChange')
    await flush()
    expect(mocks.pickrCreate).toHaveBeenCalledTimes(1)
  })

  it('saves an arbitrary custom color from the spectrum', async () => {
    const mounted = mountDutyType()
    enterName(mounted.root, '주간')
    triggerHost(customOption(mounted.root), 'onChange')
    await flush()
    const change = mocks.pickrInstances[0]?.on.mock.calls.find(([event]) => event === 'change')?.[1]
    expect(change).toBeTypeOf('function')
    change({ toHEXA: () => ({ toString: () => '#1234AB' }) })
    await flush()
    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()
    expect(mocks.teamApi.addDutyType).toHaveBeenCalledWith(42, { teamId: 42, name: '주간', color: '#1234AB', abbreviation: null })
  })

  it('starts stored arbitrary colors in custom mode without changing their exact value', async () => {
    const mounted = mountDutyType({ dutyType: { id: 7, name: '기존', color: '#aBcDeF', position: 0, hidden: false } })
    await flush()
    expect(customOption(mounted.root).props.checked).toBe(true)
    expect(mocks.pickrCreate.mock.calls[0]?.[0].default).toBe('#aBcDeF')
    expect(mocks.pickrCreate.mock.calls[0]?.[0].defaultRepresentation).toBe('HEXA')
    expect(mocks.pickrInstances[0]?.setColor).toHaveBeenCalledWith('#aBcDeF', true)
    const change = mocks.pickrInstances[0]?.on.mock.calls.find(([event]) => event === 'change')?.[1]
    change({ toHEXA: () => ({ toString: () => '#ABCDEF' }) })
    enterName(mounted.root, '주간')
    triggerHost(saveButton(mounted.root), 'onClick')
    await flush()
    expect(mocks.teamApi.updateDutyType).toHaveBeenCalledWith(42, { id: 7, name: '주간', color: '#aBcDeF', abbreviation: null })
  })

  it('ignores initialization color events until Pickr is ready', async () => {
    mocks.pickrCreate.mockImplementation(() => {
      const instance = { on: vi.fn(), setColor: vi.fn(), destroyAndRemove: vi.fn() }
      mocks.pickrInstances.push(instance)
      return instance
    })
    const mounted = mountDutyType()
    triggerHost(customOption(mounted.root), 'onChange')
    await flush()
    const handlers = mocks.pickrInstances[0]!.on.mock.calls
    const change = handlers.find(([event]) => event === 'change')![1]
    const initialize = handlers.find(([event]) => event === 'init')![1]
    change({ toHEXA: () => ({ toString: () => '#000000' }) })
    await flush()
    const preview = () => findHostNode(mounted.root, node => String(node.props.class ?? '').includes('duty-type-preview'))
    expect(preview()?.props.style).toMatchObject({ backgroundColor: '#F6D365' })
    initialize()
    change({ toHEXA: () => ({ toString: () => '#1234AB' }) })
    await flush()
    expect(preview()?.props.style).toMatchObject({ backgroundColor: '#1234AB' })
  })

  it('ignores custom change events while saving and after the picker was destroyed', async () => {
    const mounted = mountDutyType()
    triggerHost(customOption(mounted.root), 'onChange')
    await flush()
    const change = mocks.pickrInstances[0]?.on.mock.calls.find(([event]) => event === 'change')?.[1]
    mounted.state.saving = true
    await flush()
    change({ toHEXA: () => ({ toString: () => '#1234AB' }) })
    await flush()
    const preview = () => findHostNode(mounted.root, node => String(node.props.class ?? '').includes('duty-type-preview'))
    expect(preview()?.props.style).toMatchObject({ backgroundColor: '#F6D365' })
    mounted.state.saving = false
    await flush()
    const representative = findHostNode(mounted.root, node => node.type === 'input' && node.props.value === '#A6D99B')!
    triggerHost(representative, 'onChange')
    await flush()
    triggerHost(customOption(mounted.root), 'onChange')
    await flush()
    change({ toHEXA: () => ({ toString: () => '#1234AB' }) })
    await flush()
    expect(preview()?.props.style).toMatchObject({ backgroundColor: '#A6D99B' })
  })

  it('does not create a picker when the modal closes before initialization finishes', async () => {
    const mounted = mountDutyType()
    triggerHost(customOption(mounted.root), 'onChange')
    mounted.state.isOpen = false
    await flush()
    expect(mocks.pickrCreate).not.toHaveBeenCalled()
  })

  it('destroys the spectrum on palette selection, closing, and unmounting', async () => {
    const mounted = mountDutyType()
    triggerHost(customOption(mounted.root), 'onChange')
    await flush()
    const representative = findHostNode(mounted.root, node => node.type === 'input' && node.props.value === '#A6D99B')!
    triggerHost(representative, 'onChange')
    await flush()
    expect(mocks.pickrInstances[0]?.destroyAndRemove).toHaveBeenCalledTimes(1)
    triggerHost(customOption(mounted.root), 'onChange')
    await flush()
    mounted.state.isOpen = false
    await flush()
    expect(mocks.pickrInstances[1]?.destroyAndRemove).toHaveBeenCalledTimes(1)
    mounted.state.isOpen = true
    await flush()
    triggerHost(customOption(mounted.root), 'onChange')
    await flush()
    mounted.app.unmount()
    expect(mocks.pickrInstances[2]?.destroyAndRemove).toHaveBeenCalledTimes(1)
  })
})


describe('DutyTypeModal weekend preview', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mocks.locale.value = 'ko'
    mocks.t.mockImplementation((key: string) => key)
    mocks.filterStore.isBlocked.mockReturnValue(false)
  })

  it.each([
    { color: '#F6D365', saturday: '#1E40AF', sunday: '#991B1B' },
    { color: '#123456', saturday: 'var(--dp-saturday)', sunday: 'var(--dp-sunday)' },
  ])('previews the actual Saturday and Sunday foreground for $color', async ({ color, saturday, sunday }) => {
    const mounted = mountDutyType({ dutyType: { id: 7, name: '야간근무', color, position: 0, hidden: false } })
    await flush()
    const previews = findHostNodes(mounted.root, node => node.type === 'span' && String(node.props.class ?? '').includes('duty-weekend-preview'))
    expect(previews.map(hostText)).toEqual(['토', '일'])
    expect(previews[0]?.props.style).toMatchObject({ backgroundColor: color, color: saturday })
    expect(previews[1]?.props.style).toMatchObject({ backgroundColor: color, color: sunday })
  })

  it('localizes the weekend labels for English', async () => {
    mocks.locale.value = 'en'
    const mounted = mountDutyType()
    await flush()
    const previews = findHostNodes(mounted.root, node => node.type === 'span' && String(node.props.class ?? '').includes('duty-weekend-preview'))
    expect(previews.map(hostText)).toEqual(['Sat', 'Sun'])
  })
})
