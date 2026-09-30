import { COLOR_CANDIDATES, DEFAULT_REVIEW_RULES, evaluateColor } from './policy'

export type Decision = 'approved' | 'rejected' | 'held'
export type Rules = typeof DEFAULT_REVIEW_RULES
export interface ReviewState { index: number; decisions: Record<string, Decision>; defaultOffId: string; rules: Rules }
export function initialState(): ReviewState {
  return { index: 0, decisions: {}, defaultOffId: '', rules: structuredClone(DEFAULT_REVIEW_RULES) }
}
export function exportSelection(state: ReviewState) {
  const palette = COLOR_CANDIDATES.filter(c => state.decisions[c.id] === 'approved')
  if (state.rules.minContrast < 4.5) throw new Error('최소 글자 대비는 4.5:1 이상이어야 합니다.')
  if (palette.length !== 12) throw new Error('합격 후보를 정확히 12개 선택해 주세요.')
  if (palette.some(c => !evaluateColor(c.hex, c.role, state.rules).eligible)) throw new Error('현재 기준에 부적합한 합격 후보를 다시 검토해 주세요.')
  const defaultOff = palette.find(c => c.id === state.defaultOffId && c.role === 'off')
  if (!defaultOff) throw new Error('합격한 빨강 계열 후보 중 OFF 기본색을 선택해 주세요.')
  return { schemaVersion: 1, purpose: 'dutypark-palette-review', palette, defaultOff, rules: JSON.parse(JSON.stringify(state.rules)) as Rules }
}
export function restoreState(input: unknown): ReviewState {
  if (!input || typeof input !== 'object') throw new Error('올바른 검토 JSON 파일이 아닙니다.')
  const source = input as Record<string, any>
  const rules = source.rules
  if (!rules || typeof rules !== 'object') throw new Error('검토 기준이 없습니다.')
  for (const key of Object.keys(DEFAULT_REVIEW_RULES)) {
    const value = rules[key]
    if (key.startsWith('excluded')) {
      if (value !== null && (!Array.isArray(value) || value.length !== 2 || value.some(v => !Number.isFinite(v) || v < 0 || v > 360))) throw new Error('색상 제외 범위를 확인해 주세요.')
    } else if (!Number.isFinite(value) || value < (key === 'minContrast' ? 4.5 : 0) || value > (key === 'minContrast' ? 21 : 1)) throw new Error('검토 기준 범위를 확인해 주세요.')
  }
  if (rules.minLightness > rules.maxLightness || rules.minSaturation > rules.maxSaturation) throw new Error('최솟값은 최댓값 이하여야 합니다.')
  const state = initialState()
  state.rules = Object.fromEntries(Object.keys(DEFAULT_REVIEW_RULES).map(key => [key, rules[key]])) as Rules
  if (Array.isArray(source.palette)) {
    state.decisions = Object.fromEntries(source.palette.map((c: any) => [c.id, 'approved']))
    state.defaultOffId = source.defaultOff?.id ?? ''
  } else {
    if (!source.decisions || typeof source.decisions !== 'object') throw new Error('검토 결과가 없습니다.')
    state.decisions = { ...source.decisions }
    state.defaultOffId = source.defaultOffId ?? ''
    state.index = Number.isInteger(source.index) ? Math.max(0, Math.min(COLOR_CANDIDATES.length - 1, source.index)) : 0
  }
  for (const [id, decision] of Object.entries(state.decisions)) {
    if (!COLOR_CANDIDATES.some(c => c.id === id) || !['approved', 'rejected', 'held'].includes(decision)) throw new Error('알 수 없는 후보 또는 판정입니다.')
  }
  if (state.defaultOffId && !COLOR_CANDIDATES.some(c => c.id === state.defaultOffId && c.role === 'off')) throw new Error('OFF 기본색 후보가 올바르지 않습니다.')
  return state
}
