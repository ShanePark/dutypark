import { reactive } from 'vue'
import { describe, expect, it } from 'vitest'
import { COLOR_CANDIDATES, DEFAULT_REVIEW_RULES } from './policy'
import { exportSelection, restoreState } from './reviewState'

describe('color review selection guards', () => {
  const selected = [...COLOR_CANDIDATES.filter(c => c.role === 'off').slice(0, 1), ...COLOR_CANDIDATES.filter(c => c.role === 'normal').slice(0, 11)]
  const state = () => ({ index: 0, decisions: Object.fromEntries(selected.map(c => [c.id, 'approved' as const])), defaultOffId: selected[0]!.id, rules: { ...DEFAULT_REVIEW_RULES } })
  it('exports exactly twelve eligible explicit approvals with an approved OFF default', () => {
    const result = exportSelection(state())
    expect(result.palette).toHaveLength(12)
    expect(exportSelection(reactive(state())).palette).toHaveLength(12)
    expect(result.defaultOff.id).toBe(selected[0]!.id)
    expect(() => exportSelection({ ...state(), defaultOffId: '' })).toThrow()
    expect(() => exportSelection({ ...state(), decisions: {} })).toThrow()
  })
  it('blocks export when adjusted rules invalidate a prior approval', () => {
    expect(() => exportSelection({ ...state(), rules: { ...DEFAULT_REVIEW_RULES, minContrast: 10 } })).toThrow()
  })
  it('restores review and exported files but rejects malformed settings and unknown decisions', () => {
    expect(restoreState(state()).defaultOffId).toBe(selected[0]!.id)
    expect(Object.values(restoreState(exportSelection(state())).decisions)).toHaveLength(12)
    expect(() => restoreState({ ...state(), rules: { ...DEFAULT_REVIEW_RULES, minContrast: -1 } })).toThrow()
    expect(() => restoreState({ ...state(), rules: { ...DEFAULT_REVIEW_RULES, minContrast: 3 } })).toThrow()
    expect(() => restoreState({ ...state(), decisions: { arbitrary: 'approved' } })).toThrow()
  })
})
