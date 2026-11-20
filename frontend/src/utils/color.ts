/**
 * Check if a hex color is light (for text contrast decisions)
 * Uses luminance formula: 0.299*R + 0.587*G + 0.114*B
 */
export function isLightColor(hexColor: string | null | undefined): boolean {
  if (!hexColor) return false
  const hex = hexColor.replace('#', '')
  if (hex.length !== 6) return false
  const r = parseInt(hex.substring(0, 2), 16)
  const g = parseInt(hex.substring(2, 4), 16)
  const b = parseInt(hex.substring(4, 6), 16)
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  return luminance > 0.5
}

function srgbToLinear(channel: number): number {
  const c = channel / 255
  return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
}

function linearToSrgb(channel: number): number {
  const c = Math.min(1, Math.max(0, channel))
  return Math.round(255 * (c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055))
}

function parseHex(hexColor: string): [number, number, number] | null {
  const hex = hexColor.replace('#', '')
  if (!/^[0-9a-f]{6}$/i.test(hex)) return null
  return [0, 2, 4].map(offset => parseInt(hex.substring(offset, offset + 2), 16)) as [number, number, number]
}

function toHex(rgb: number[]): string {
  return `#${rgb.map(value => value.toString(16).padStart(2, '0')).join('')}`
}

function rgbToOklch(rgb: [number, number, number]): [number, number, number] {
  const [r, g, b] = rgb.map(srgbToLinear) as [number, number, number]
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
  const lightness = 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s
  const a = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s
  const bAxis = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s
  return [lightness, Math.hypot(a, bAxis), Math.atan2(bAxis, a)]
}

// Out-of-gamut channels are clipped, as browsers paint oklch() in sRGB.
function oklchToHex(lightness: number, chroma: number, hue: number): string {
  const a = chroma * Math.cos(hue)
  const b = chroma * Math.sin(hue)
  const l = (lightness + 0.3963377774 * a + 0.2158037573 * b) ** 3
  const m = (lightness - 0.1055613458 * a - 0.0638541728 * b) ** 3
  const s = (lightness - 0.0894841775 * a - 1.291485548 * b) ** 3
  return toHex([
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
  ].map(linearToSrgb))
}

function relativeLuminance(hexColor: string): number {
  const [r, g, b] = parseHex(hexColor)!.map(srgbToLinear) as [number, number, number]
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

const MIN_TIME_CHIP_CONTRAST = 4.5

/**
 * Tone-on-tone time chip colours for a duty fill: a deeper, more saturated
 * shade of the fill behind a dark shade of the same hue. Returns null (use the
 * neutral chip) when the fill is not a hex colour or the pair would read below
 * 4.5:1, as on dark or mid-tone fills.
 */
export function getTimeChipColors(fillColor: string): { background: string; color: string } | null {
  const rgb = parseHex(fillColor)
  if (!rgb) return null
  const [lightness, chroma, hue] = rgbToOklch(rgb)
  const background = oklchToHex(lightness - 0.08, chroma * 1.25, hue)
  const color = oklchToHex(0.36, chroma * 1.4, hue)
  const [high, low] = [relativeLuminance(background), relativeLuminance(color)].sort((x, y) => y - x) as [number, number]
  if ((high + 0.05) / (low + 0.05) < MIN_TIME_CHIP_CONTRAST) return null
  return { background, color }
}
