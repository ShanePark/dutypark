import { describe, expect, it } from 'vitest'
import { getTimeChipColors } from './color'
import { dutyTypePalette } from './dutyTypePalette'

function channels(hex: string): number[] {
  return [1, 3, 5].map(offset => parseInt(hex.slice(offset, offset + 2), 16))
}

function luminance(hex: string): number {
  const [r, g, b] = channels(hex).map(value => {
    const c = value / 255
    return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
  }) as [number, number, number]
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

function contrast(a: string, b: string): number {
  const [high, low] = [luminance(a), luminance(b)].sort((x, y) => y - x) as [number, number]
  return (high + 0.05) / (low + 0.05)
}

describe('getTimeChipColors', () => {
  // Expected values are what Chrome renders for the spec's CSS:
  // oklch(from F calc(l - 0.08) calc(c * 1.25) h) and oklch(from F 0.36 calc(c * 1.4) h).
  it('darkens and saturates the duty fill for the chip and uses a deep shade of it for the text', () => {
    expect(getTimeChipColors('#a2d9dd')).toEqual({ background: '#7cc2c7', color: '#00494f' })
    expect(getTimeChipColors('#ECC5CA')).toEqual({ background: '#d8a9af', color: '#592e36' })
    expect(getTimeChipColors('#F6BC7A')).toEqual({ background: '#e59e45', color: '#6b2400' })
  })

  it('stays readable on every palette fill, including faded out-of-month fills', () => {
    const faded = (hex: string) => `#${channels(hex).map(value => Math.round(value * 0.6 + 255 * 0.4).toString(16).padStart(2, '0')).join('')}`
    for (const { color } of dutyTypePalette) {
      for (const fill of [color, faded(color)]) {
        const chip = getTimeChipColors(fill)
        expect(chip, fill).not.toBeNull()
        expect(contrast(chip!.background, chip!.color), fill).toBeGreaterThanOrEqual(4.5)
      }
    }
  })

  it('falls back to the neutral chip when a fill cannot keep 4.5:1 or is not a hex colour', () => {
    expect(getTimeChipColors('#334155')).toBeNull()
    expect(getTimeChipColors('#808080')).toBeNull()
    expect(getTimeChipColors('var(--dp-calendar-cell-bg)')).toBeNull()
    expect(getTimeChipColors('')).toBeNull()
  })
})
