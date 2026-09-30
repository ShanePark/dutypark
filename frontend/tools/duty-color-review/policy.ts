export type ColorRole = 'normal' | 'off'
export interface ColorCandidate { id: string; name: string; hex: string; role: ColorRole }
export interface ReviewRules {
  minContrast: number
  minLightness: number
  maxLightness: number
  minSaturation: number
  maxSaturation: number
  minWhiteDistance: number
  minBlackDistance: number
  excludedRedHue: [number, number] | null
  excludedBlueHue: [number, number] | null
}
export const DEFAULT_REVIEW_RULES: ReviewRules = {
  minContrast: 4.5, minLightness: 0.62, maxLightness: 0.86,
  minSaturation: 0.12, maxSaturation: 0.92,
  minWhiteDistance: 0.12, minBlackDistance: 0.16,
  excludedRedHue: [345, 15], excludedBlueHue: [190, 260],
}
const PRIMARY_DARK = '#1F2937'
const PRIMARY_LIGHT = '#FFFFFF'
const SUNDAY = '#991B1B'
const SATURDAY = '#1E40AF'
const validHex = (hex: string) => /^#[0-9a-f]{6}$/i.test(hex)
const rgb = (hex: string) => [1, 3, 5].map(offset => parseInt(hex.slice(offset, offset + 2), 16) / 255)

export function contrastRatio(first: string, second: string): number {
  if (!validHex(first) || !validHex(second)) return NaN
  const luminance = (hex: string) => {
    const linear = rgb(hex).map(channel => channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4)
    return linear[0]! * 0.2126 + linear[1]! * 0.7152 + linear[2]! * 0.0722
  }
  const a = luminance(first), b = luminance(second)
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
}

export function rgbToHsl(hex: string) {
  const [r, g, b] = rgb(hex) as [number, number, number]
  const max = Math.max(r, g, b), min = Math.min(r, g, b), delta = max - min
  const lightness = (max + min) / 2
  let hue = 0
  if (delta) {
    if (max === r) hue = ((g - b) / delta) % 6
    else if (max === g) hue = (b - r) / delta + 2
    else hue = (r - g) / delta + 4
    hue = (hue * 60 + 360) % 360
  }
  return { hue, saturation: delta ? delta / (1 - Math.abs(2 * lightness - 1)) : 0, lightness }
}

function withinHue(hue: number, band: [number, number] | null) {
  if (!band) return false
  return band[0] <= band[1] ? hue >= band[0] && hue <= band[1] : hue >= band[0] || hue <= band[1]
}

export function evaluateColor(hex: string, role: ColorRole, rules: ReviewRules = DEFAULT_REVIEW_RULES) {
  const black = contrastRatio(hex, PRIMARY_DARK), white = contrastRatio(hex, PRIMARY_LIGHT)
  const foreground = black >= white ? PRIMARY_DARK : PRIMARY_LIGHT
  const contrast = { primary: Math.max(black, white), sunday: contrastRatio(hex, SUNDAY), saturday: contrastRatio(hex, SATURDAY), black, white }
  const legacyContrast = {
    sundayLight: contrastRatio(hex, '#DC2626'), sundayDark: contrastRatio(hex, '#F87171'),
    saturdayLight: contrastRatio(hex, '#2563EB'), saturdayDark: contrastRatio(hex, '#60A5FA'),
  }
  const hsl = rgbToHsl(hex)
  const reasons: string[] = []
  if (!validHex(hex)) reasons.push('invalid-hex')
  else {
    // Distances are Euclidean RGB distances normalized to 0..1, separate from HSL lightness.
    const channels = rgb(hex)
    if (Math.sqrt(channels.reduce((sum, c) => sum + (1 - c) ** 2, 0) / 3) < rules.minWhiteDistance) reasons.push('near-white')
    if (Math.sqrt(channels.reduce((sum, c) => sum + c ** 2, 0) / 3) < rules.minBlackDistance) reasons.push('near-black')
    if (hsl.lightness < rules.minLightness) reasons.push('lightness-low')
    if (hsl.lightness > rules.maxLightness) reasons.push('lightness-high')
    if (hsl.saturation < rules.minSaturation) reasons.push('saturation-low')
    if (hsl.saturation > rules.maxSaturation) reasons.push('saturation-high')
    if (role !== 'off' && withinHue(hsl.hue, rules.excludedRedHue)) reasons.push('excluded-red-hue')
    if (withinHue(hsl.hue, rules.excludedBlueHue)) reasons.push('excluded-blue-hue')
    for (const key of ['primary', 'sunday', 'saturday'] as const) if (contrast[key] < rules.minContrast) reasons.push(`${key}-contrast`)
  }
  return { eligible: reasons.length === 0, reasons, foreground, hsl, contrast, legacyContrast }
}

const groups: Array<[ColorRole, Array<[string, string, string]>]> = [
  ['off', [
    ['rose', '로즈', '#F0B9BA'], ['salmon', '살몬', '#F2BCA8'], ['coral', '코랄', '#F2BCB2'],
    ['blush', '블러시', '#ECC2C9'], ['peach-rose', '피치 로즈', '#EFBFAF'], ['dusty-rose', '더스티 로즈', '#E2BFC0'],
  ]],
  ['normal', [
    ['apricot', '살구 · 기존', '#F2C094'], ['peach', '피치', '#F1C6AB'], ['orange', '소프트 오렌지', '#EDBD88'], ['amber', '앰버', '#EAC298'],
    ['yellow', '노랑 · 기존', '#F6D365'], ['butter', '버터', '#EFDA91'], ['gold', '골드', '#E9CB82'], ['straw', '스트로', '#E7D49C'],
    ['sand', '샌드 · 기존', '#D8C6A5'], ['oat', '오트', '#E0CFB3'], ['beige', '베이지', '#DFD1BD'], ['cream', '크림', '#E8D8B7'],
    ['lime', '라임 · 기존', '#CDD98B'], ['olive', '라이트 올리브', '#C6CD9B'], ['pistachio', '피스타치오', '#D5DCAD'],
    ['sage', '세이지 · 기존', '#ADD1AF'], ['leaf', '리프', '#BAD8A7'], ['celadon', '청자', '#BED4BB'], ['fern', '라이트 펀', '#B4CF9D'],
    ['mint', '민트 · 기존', '#A8D8C2'], ['seafoam', '씨폼', '#B7DDCD'], ['eucalyptus', '유칼립투스', '#B4D0C3'], ['jade', '라이트 제이드', '#A9D4B7'],
    ['lavender', '라벤더 · 기존', '#D3BCE2'], ['lilac', '라일락', '#DAC5E8'], ['orchid', '오키드', '#DEC0DD'], ['mauve', '모브', '#D5BFD3'],
    ['taupe', '토프', '#D4C1B6'], ['latte', '라떼', '#D9C3AB'], ['clay', '클레이', '#DABFA9'],
  ]],
]
export const COLOR_CANDIDATES: ColorCandidate[] = groups.flatMap(([role, entries]) => entries.map(([id, name, hex]) => ({ id, name, hex, role })))

function hslToHex(hue: number, saturation: number, lightness: number) {
  const a = saturation * Math.min(lightness, 1 - lightness)
  const channel = (n: number) => {
    const k = (n + hue / 30) % 12
    return Math.round(255 * (lightness - a * Math.max(-1, Math.min(k - 3, 9 - k, 1)))).toString(16).padStart(2, '0')
  }
  return `#${channel(0)}${channel(8)}${channel(4)}`.toUpperCase()
}
// Includes dark, washed-out, vivid, red, and blue bands. These are samples, not approved candidates.
export const SPECTRUM_SAMPLES: ColorCandidate[] = [0.08, 0.45, 0.65, 0.78, 0.96].flatMap((lightness, li) =>
  [0.06, 0.3, 0.6, 0.95].flatMap((saturation, si) =>
    Array.from({ length: 12 }, (_, hi) => ({ id: `spectrum-${li}-${si}-${hi}`, name: `HSL ${hi * 30}° / ${Math.round(saturation * 100)}% / ${Math.round(lightness * 100)}%`, hex: hslToHex(hi * 30, saturation, lightness), role: 'normal' as const })),
  ),
)
