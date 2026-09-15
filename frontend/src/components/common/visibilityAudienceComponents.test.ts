import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { h, nextTick, reactive } from 'vue'
import { createI18n } from 'vue-i18n'
import { createHostWrapper, findHostNode, findHostNodes, hostText, mountHost, triggerHost, type HostNode } from '@/test/hostRenderer'
import type { AudienceVisibility } from '@/utils/visibilityAudience'

const mocks = vi.hoisted(() => ({
  auth: { user: null as { id: number } | null },
  friends: vi.fn(),
  member: vi.fn(),
  updateVisibility: vi.fn(),
}))
vi.mock('@/stores/auth', () => ({ useAuthStore: () => mocks.auth }))
vi.mock('@/api/member', () => ({
  friendApi: { getFriends: mocks.friends },
  memberApi: { getMyInfo: mocks.member, updateVisibility: mocks.updateVisibility },
}))
vi.mock('@/i18n', () => ({ translateGlobal: (key: string) => key }))
vi.mock('@lucide/vue', async () => {
  const { defineComponent, h } = await import('vue')
  const icon = defineComponent({ setup: () => () => h('span') })
  return { Eye: icon, Users: icon, House: icon, Lock: icon, Check: icon, X: icon, ChevronDown: icon, Info: icon, Loader2: icon, Search: icon }
})
vi.mock('@/components/common/ProfileAvatar.vue', async () => {
  const { defineComponent, h } = await import('vue')
  return { default: defineComponent({ props: ['name'], setup: () => () => h('span', { 'data-avatar': true }) }) }
})
vi.mock('@/components/common/BaseModal.vue', async () => {
  const { defineComponent, h } = await import('vue')
  return { default: defineComponent({
    props: { isOpen: Boolean },
    setup: (props, { slots }) => () => props.isOpen ? h('div', { role: 'dialog' }, slots.default?.()) : null,
  }) }
})

const { default: VisibilityAudiencePreview } = await import('./VisibilityAudiencePreview.vue')
const { default: CalendarVisibilityModal } = await import('./CalendarVisibilityModal.vue')
const mountedApps: Array<ReturnType<typeof mountHost>['app']> = []
const relations = [
  { id: 2, name: '친구 가람', isFamily: false, hasProfilePhoto: false, profilePhotoVersion: 0 },
  { id: 3, name: '가족 나래', isFamily: true, hasProfilePhoto: false, profilePhotoVersion: 0 },
]

beforeEach(() => {
  vi.clearAllMocks()
  vi.stubGlobal('document', { activeElement: null })
  mocks.auth = reactive({ user: { id: 1 } })
  mocks.friends.mockReset().mockResolvedValue({ data: relations })
  mocks.member.mockReset().mockResolvedValue({ data: { id: 1, calendarVisibility: 'PUBLIC' } })
})
afterEach(() => {
  mountedApps.splice(0).forEach(app => app.unmount())
  vi.unstubAllGlobals()
})
async function flush() {
  for (let index = 0; index < 6; index++) { await Promise.resolve(); await nextTick() }
}
function mount(component: Parameters<typeof mountHost>[0]) {
  const result = mountHost(component, {}, [createI18n({ legacy: false, locale: 'ko', messages: { ko: {}, en: {} } })])
  mountedApps.push(result.app)
  return result.root
}
function button(root: HostNode, label: string): HostNode {
  const found = findHostNode(root, node => node.type === 'button' && hostText(node).includes(label))
  if (!found) throw new Error(`Button not found: ${label}`)
  return found
}
function click(node: HostNode) { triggerHost(node, 'onClick', { stopPropagation() {}, preventDefault() {} }) }
function roster(root: HostNode) { return findHostNodes(root, node => node.type === 'li').map(hostText) }
function mountPreview(visibility: AudienceVisibility = 'FRIENDS', scope: 'calendar' | 'schedule' = 'calendar') {
  const state = reactive({ visibility, scope })
  const root = mount(createHostWrapper(() => h(VisibilityAudiencePreview, state)))
  return { root, state }
}

describe('audience disclosure interactions', () => {
  it('does not load or save anything until opened, then includes family in Friends', async () => {
    const { root } = mountPreview()
    expect(mocks.friends).not.toHaveBeenCalled()
    const toggle = button(root, '공개 대상 확인')
    expect(toggle.props['aria-expanded']).toBe(false)
    click(toggle)
    await flush()
    expect(mocks.friends).toHaveBeenCalledTimes(1)
    expect(mocks.member).toHaveBeenCalledTimes(1)
    expect(roster(root)).toEqual(['가족 나래가족', '친구 가람친구'])
    expect(button(root, '명단 접기').props['aria-expanded']).toBe(true)
    expect(hostText(root)).toContain('2명')
    expect(mocks.updateVisibility).not.toHaveBeenCalled()
  })

  it('lists only accepted family members and keeps the roster read-only', async () => {
    const { root } = mountPreview('FAMILY')
    click(button(root, '공개 대상 확인'))
    await flush()
    expect(roster(root)).toEqual(['가족 나래가족'])
    expect(findHostNodes(root, node => node.type === 'input' && node.props.type === 'checkbox')).toEqual([])
    expect(hostText(root)).toContain('확인용 명단입니다')
  })

  it('clears the roster when collapsed and refreshes it on the next open', async () => {
    const { root } = mountPreview()
    click(button(root, '공개 대상 확인'))
    await flush()
    click(button(root, '명단 접기'))
    await flush()
    expect(roster(root)).toEqual([])
    mocks.friends.mockResolvedValue({ data: [] })
    click(button(root, '공개 대상 확인'))
    await flush()
    expect(mocks.friends).toHaveBeenCalledTimes(2)
    expect(hostText(root)).toContain('현재 이 공개 범위에 해당하는 사람이 없어요')
  })

  it('renders retryable errors separately from a successfully empty list', async () => {
    mocks.friends.mockRejectedValueOnce(new Error('offline'))
    const { root } = mountPreview()
    click(button(root, '공개 대상 확인'))
    await flush()
    expect(findHostNode(root, node => node.props.role === 'alert')).not.toBeNull()
    expect(hostText(root)).not.toContain('현재 이 공개 범위에 해당하는 사람이 없어요')
    mocks.friends.mockResolvedValue({ data: [] })
    click(button(root, '다시 시도'))
    await flush()
    expect(findHostNode(root, node => node.props.role === 'alert')).toBeNull()
    expect(hostText(root)).toContain('현재 이 공개 범위에 해당하는 사람이 없어요')
  })

  it('shows search for a longer list and reports a no-match result', async () => {
    mocks.friends.mockResolvedValue({ data: Array.from({ length: 10 }, (_, index) => ({
      id: index + 10, name: `친구 ${index}`, isFamily: false,
    })) })
    const { root } = mountPreview()
    click(button(root, '공개 대상 확인'))
    await flush()
    const input = findHostNode(root, node => node.type === 'input' && node.props.type === 'search')!
    expect(input.props['aria-label']).toBe('이름으로 찾기')
    triggerHost(input, 'onInput', { target: { value: '친구 7' } })
    await flush()
    expect(roster(root)).toEqual(['친구 7친구'])
    triggerHost(input, 'onInput', { target: { value: '존재하지 않는 이름' } })
    await flush()
    expect(hostText(root)).toContain('일치하는 이름이 없어요')
    expect(roster(root)).toEqual([])
  })

  it('explains a schedule audience narrowed by the calendar gate', async () => {
    mocks.member.mockResolvedValue({ data: { id: 1, calendarVisibility: 'FAMILY' } })
    const { root } = mountPreview('FRIENDS', 'schedule')
    click(button(root, '공개 대상 확인'))
    await flush()
    expect(roster(root)).toEqual(['가족 나래가족'])
    expect(hostText(root)).toContain('현재 내 캘린더 공개 설정이 더 제한적')
    expect(hostText(root)).toContain('일정 태그와 관리자')
  })

  it('closes immediately when the audience or account changes', async () => {
    const { root, state } = mountPreview()
    click(button(root, '공개 대상 확인'))
    await flush()
    state.visibility = 'FAMILY'
    await flush()
    expect(roster(root)).toEqual([])
    click(button(root, '공개 대상 확인'))
    await flush()
    mocks.auth.user = null
    await flush()
    expect(hostText(root)).toBe('')
    expect(mocks.updateVisibility).not.toHaveBeenCalled()
  })

  it.each([true, false])('reveals the loaded roster and respects reduced motion (%s)', async reducedMotion => {
    let resolve!: (value: { data: typeof relations }) => void
    mocks.friends.mockReturnValue(new Promise(res => { resolve = res }))
    vi.stubGlobal('window', { matchMedia: () => ({ matches: reducedMotion }) })
    const { root } = mountPreview()
    const toggle = button(root, '공개 대상 확인')
    const scrollIntoView = vi.fn()
    Object.assign(toggle, { scrollIntoView })
    click(toggle)
    await flush()
    // The final roster can be taller than the loading placeholder. Scroll after it renders.
    expect(scrollIntoView).not.toHaveBeenCalled()
    resolve({ data: relations })
    await flush()
    expect(scrollIntoView).toHaveBeenCalledWith({
      block: 'start', behavior: reducedMotion ? 'auto' : 'smooth',
    })
  })

  it.each(['PUBLIC', 'PRIVATE'] as const)('does not enumerate %s viewers', visibility => {
    const { root } = mountPreview(visibility)
    expect(hostText(root)).toBe('')
    expect(mocks.friends).not.toHaveBeenCalled()
  })
})

function mountVisibilityModal() {
  const state = reactive({ isOpen: true, value: 'PRIVATE' as AudienceVisibility, saving: false })
  const saved: AudienceVisibility[] = []
  const closed = vi.fn()
  const root = mount(createHostWrapper(() => h(CalendarVisibilityModal, {
    ...state, onSave: value => saved.push(value), onClose: closed,
  })))
  const select = async (value: AudienceVisibility) => {
    const input = findHostNode(root, node => node.type === 'input' && node.props.value === value)!
    triggerHost(input, 'onChange', { target: input })
    await flush()
  }
  return { root, state, saved, closed, select }
}

describe('explicit calendar visibility confirmation', () => {
  it('selects and inspects without saving, and saves only after confirmation', async () => {
    const { root, saved, select } = mountVisibilityModal()
    expect(button(root, '선택한 공개 범위 저장').props.disabled).toBe(true)
    await select('FRIENDS')
    expect(saved).toEqual([])
    click(button(root, '공개 대상 확인'))
    await flush()
    expect(roster(root)).toHaveLength(2)
    expect(saved).toEqual([])
    expect(mocks.updateVisibility).not.toHaveBeenCalled()
    click(button(root, '선택한 공개 범위 저장'))
    expect(saved).toEqual(['FRIENDS'])
  })

  it('cancels without committing the selected option', async () => {
    const { root, saved, closed, select } = mountVisibilityModal()
    await select('FAMILY')
    click(button(root, '취소'))
    expect(closed).toHaveBeenCalledTimes(1)
    expect(saved).toEqual([])
  })

  it('guards no-op confirmation and further saves or dismissal during a save', async () => {
    const { root, state, saved, closed, select } = mountVisibilityModal()
    click(button(root, '선택한 공개 범위 저장'))
    expect(saved).toEqual([])
    await select('FRIENDS')
    state.saving = true
    await flush()
    expect(button(root, '선택한 공개 범위 저장').props.disabled).toBe(true)
    click(button(root, '선택한 공개 범위 저장'))
    click(button(root, '취소'))
    expect(saved).toEqual([])
    expect(closed).not.toHaveBeenCalled()
  })
})
