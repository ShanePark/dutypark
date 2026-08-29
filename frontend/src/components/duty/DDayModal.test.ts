import { beforeEach, describe, expect, it, vi } from 'vitest'
import { h, nextTick, reactive } from 'vue'
import {
  createHostWrapper,
  findHostNode,
  hostText,
  mountHost,
  triggerHost,
  type HostNode,
} from '@/test/hostRenderer'


const mocks = vi.hoisted(() => ({
  icon: null as unknown,
  t: vi.fn((key: string) => key),
}))

vi.mock('@/i18n', () => ({
  getCurrentLocale: () => 'ko',
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

vi.mock('lucide-vue-next', async () => {
  const { defineComponent, h } = await import('vue')
  const icon = defineComponent({
    setup() {
      return () => h('span')
    },
  })
  mocks.icon = icon
  return {
    X: icon,
    Plus: icon,
    Minus: icon,
    RotateCcw: icon,
    Lock: icon,
    Unlock: icon,
    Loader2: icon,
  }
})

const { default: DDayModal } = await import('./DDayModal.vue')

function flush() {
  return nextTick().then(() => Promise.resolve()).then(() => nextTick())
}

function buttonByClass(root: HostNode, className: string): HostNode {
  const button = findHostNode(root, (node) =>
    node.type === 'button' && String(node.props.class ?? '').includes(className)
  )
  if (!button) throw new Error(`Could not find button with class ${className}`)
  return button
}

function textInput(root: HostNode): HostNode {
  const input = findHostNode(root, (node) => node.type === 'input' && node.props.type === 'text')
  if (!input) throw new Error('Could not find D-Day title input')
  return input
}

function mountDday() {
  const state = reactive<{
    isOpen: boolean
    isSubmitting: boolean
    dday: null | { id?: number; title: string; date: string; isPrivate: boolean }
  }>({
    isOpen: false,
    isSubmitting: false,
    dday: null,
  })
  const saved: Array<{ id?: number; title: string; date: string; isPrivate: boolean }> = []

  const wrapper = createHostWrapper(() => h(DDayModal, {
    isOpen: state.isOpen,
    isSubmitting: state.isSubmitting,
    dday: state.dday,
    onSave: (dday) => {
      saved.push(dday)
      state.isSubmitting = true
    },
    onClose: () => {
      state.isOpen = false
    },
  }))
  const mounted = mountHost(wrapper)
  state.isOpen = true

  return { ...mounted, state, saved }
}

describe('DDayModal save state', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('keeps the entered title and blocks duplicate clicks while saving', async () => {
    const mounted = mountDday()
    await flush()

    triggerHost(textInput(mounted.root), 'onInput', { target: { value: '여행' } })
    await flush()
    const saveButton = buttonByClass(mounted.root, 'bg-dp-accent')

    triggerHost(saveButton, 'onClick')
    await flush()

    expect(mounted.saved).toEqual([{
      title: '여행',
      date: expect.any(String),
      isPrivate: false,
    }])
    expect(mounted.state.isSubmitting).toBe(true)
    expect(saveButton.props.disabled).toBe(true)
    expect(hostText(saveButton)).toContain('duty.ddayModal.saving')

    triggerHost(saveButton, 'onClick')
    expect(mounted.saved).toHaveLength(1)

    mounted.state.isSubmitting = false
    await flush()
    expect(buttonByClass(mounted.root, 'bg-dp-accent').props.disabled).toBe(false)
  })
})
