import { describe, expect, it } from 'vitest'
import { COLOR_CANDIDATES, DEFAULT_REVIEW_RULES, SPECTRUM_SAMPLES, contrastRatio, evaluateColor, rgbToHsl } from './policy'

describe('duty color review policy', () => {
  it('computes WCAG linearized sRGB contrast and HSL hue', () => {
    expect(contrastRatio('#000000', '#FFFFFF')).toBe(21)
    expect(contrastRatio('#777777', '#FFFFFF')).toBeCloseTo(4.478, 3)
    expect(rgbToHsl('#FF0000')).toEqual({ hue: 0, saturation: 1, lightness: 0.5 })
    expect(rgbToHsl('#808080').saturation).toBe(0)
  })
  it('keeps all seven current colors and stable, unique candidate identities', () => {
    expect(COLOR_CANDIDATES).toHaveLength(36)
    expect(new Set(COLOR_CANDIDATES.map(c => c.id)).size).toBe(36)
    for (const hex of ['#F6D365', '#F2C094', '#D8C6A5', '#CDD98B', '#ADD1AF', '#A8D8C2', '#D3BCE2']) {
      expect(COLOR_CANDIDATES.some(c => c.hex === hex)).toBe(true)
    }
  })
  it('all curated colors pass primary and fixed weekend contrast', () => {
    for (const candidate of COLOR_CANDIDATES) {
      const result = evaluateColor(candidate.hex, candidate.role)
      expect(result.reasons, candidate.id).toEqual([])
      for (const key of ['primary', 'sunday', 'saturday'] as const) expect(result.contrast[key], candidate.id).toBeGreaterThanOrEqual(4.5)
    }
  })
  it('allows red specifically for OFF while excluding it for normal duty', () => {
    expect(evaluateColor('#F0B9BA', 'off').eligible).toBe(true)
    expect(evaluateColor('#F0B9BA', 'normal').reasons).toContain('excluded-red-hue')
  })
  it('rejects blue, white, black, invalid input, and insufficient date contrast', () => {
    expect(evaluateColor('#ACC9EC', 'normal').reasons).toContain('excluded-blue-hue')
    expect(evaluateColor('#FFFFFF', 'normal').reasons).toContain('near-white')
    expect(evaluateColor('#000000', 'normal').reasons).toContain('near-black')
    expect(evaluateColor('oops', 'normal').reasons).toEqual(['invalid-hex'])
    expect(evaluateColor('#9C7575', 'off').reasons).toContain('sunday-contrast')
  })
  it('recomputes eligibility after criterion changes, including boundary equality', () => {
    const hex = '#F0B9BA'
    const result = evaluateColor(hex, 'off')
    const exact = { ...DEFAULT_REVIEW_RULES, minContrast: result.contrast.sunday }
    expect(evaluateColor(hex, 'off', exact).eligible).toBe(true)
    expect(evaluateColor(hex, 'off', { ...exact, minContrast: exact.minContrast + 0.000001 }).eligible).toBe(false)
    const blue = '#ACC9EC'
    expect(evaluateColor(blue, 'normal', { ...DEFAULT_REVIEW_RULES, excludedBlueHue: null }).eligible).toBe(true)
  })
  it('selects the higher-contrast primary foreground and exposes both metrics', () => {
    const result = evaluateColor('#F6D365', 'normal')
    expect(result.foreground).toBe('#1F2937')
    expect(result.contrast.primary).toBe(Math.max(result.contrast.black, result.contrast.white))
    expect(result.contrast.white).toBeLessThan(4.5)
    const dark = evaluateColor('#222222', 'normal')
    expect(dark.foreground).toBe('#FFFFFF')
  })
  it('samples rejected spectrum colors deterministically for adjustable review', () => {
    expect(SPECTRUM_SAMPLES).toHaveLength(240)
    expect(SPECTRUM_SAMPLES.some(c => evaluateColor(c.hex, c.role).reasons.includes('excluded-blue-hue'))).toBe(true)
    expect(SPECTRUM_SAMPLES.some(c => evaluateColor(c.hex, c.role).reasons.includes('near-black'))).toBe(true)
    expect(SPECTRUM_SAMPLES.some(c => evaluateColor(c.hex, c.role).reasons.includes('near-white'))).toBe(true)
  })
})
