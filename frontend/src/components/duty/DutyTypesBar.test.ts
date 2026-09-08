import { describe, expect, it, vi } from 'vitest'
import { h } from 'vue'
import { createHostWrapper, findHostNodes, hostText, mountHost, triggerHost } from '@/test/hostRenderer'

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: (key: string) => key }) }))

const { default: DutyTypesBar } = await import('./DutyTypesBar.vue')
const types = [
  { id: 7, name: '야간근무', color: '#112233', abbreviation: 'N', shortName: 'N' },
  { id: 8, name: '심야근무', color: '#445566', abbreviation: 'N', shortName: 'N' },
  { id: null, name: '휴무', color: '#aabbcc' },
]

function mountBar(isMyCalendar: boolean, batchEditMode = true) {
  const selected: Array<number | null> = []
  const mounted = mountHost(createHostWrapper(() => h(DutyTypesBar, {
    batchEditMode,
    dutyTypes: types,
    dutyTypesWithCount: types.map(type => ({ ...type, cnt: 1 })),
    isLoadingDuties: false,
    focusedDay: 1,
    focusedDayDutyType: '야간근무',
    lastDayInMonth: 30,
    canEdit: true,
    canEditMyCalendar: isMyCalendar,
    otherDutyCount: 0,
    isOtherDutyActive: false,
    teamHasDutyBatchTemplate: false,
    onQuickDutyChange: (id: number | null) => selected.push(id),
  })))
  const buttons = findHostNodes(mounted.root, node => node.type === 'button'
    && String(node.props.class ?? '').includes('duty-quick-btn'))
  return { ...mounted, buttons, selected }
}

describe('duty quick input abbreviations', () => {
  it('shows abbreviations for the owner while preserving full accessible names and IDs', () => {
    const mounted = mountBar(true)
    expect(mounted.buttons.map(button => hostText(button).trim())).toEqual(['N', 'N', '휴'])
    expect(mounted.buttons.map(button => button.props['aria-label'])).toEqual(['야간근무', '심야근무', '휴무'])
    expect(String(mounted.buttons[0]!.props.class)).toContain('duty-quick-btn-active')
    expect(String(mounted.buttons[1]!.props.class)).not.toContain('duty-quick-btn-active')
    triggerHost(mounted.buttons[1]!, 'onClick')
    expect(mounted.selected).toEqual([8])
    mounted.app.unmount()
  })

  it('keeps full names for somebody else even when the viewer can edit', () => {
    const mounted = mountBar(false)
    expect(mounted.buttons.map(button => hostText(button).trim())).toEqual(['야간근무', '심야근무', '휴무'])
    mounted.app.unmount()
  })

  it('retains full explanatory names in the normal calendar legend', () => {
    const mounted = mountBar(false, false)
    expect(hostText(mounted.root)).toContain('야간근무')
    expect(hostText(mounted.root)).toContain('심야근무')
    mounted.app.unmount()
  })
})
