import { describe, expect, it } from 'vitest'
import { defaultDutyTypeColor, dutyCalendarWeekendColor, dutyTypePalette, isDutyTypePaletteColor } from './dutyTypePalette'

function luminance(hex: string): number {
  const channels = hex.slice(1).match(/../g)!.map(channel => parseInt(channel, 16) / 255)
    .map(channel => channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4)
  return channels[0]! * 0.2126 + channels[1]! * 0.7152 + channels[2]! * 0.0722
}

function contrast(first: string, second: string): number {
  const values = [luminance(first), luminance(second)].sort((a, b) => b - a)
  return (values[0]! + 0.05) / (values[1]! + 0.05)
}

describe('representative duty palette', () => {
  it('matches the shared service and native palette contract', () => {
    expect(dutyTypePalette.map(option => option.color)).toEqual(['#ECC2C9', '#F6BC7A', '#F6D365', '#D8BF9B', '#C8DD70', '#A6D99B', '#8FDCBD', '#9DDBDE', '#D1B8EC', '#E9AEE9', '#CCC8BD'])
    expect(defaultDutyTypeColor).toBe('#F6D365')
  })
  it.each(dutyTypePalette)('keeps $name duty text and weekend dates readable', ({ color }) => {
    const [red, green, blue] = color.slice(1).match(/../g)!.map(channel => parseInt(channel, 16))
    expect((0.299 * red! + 0.587 * green! + 0.114 * blue!) / 255).toBeGreaterThan(0.64)
    expect(contrast(color, '#1F2937')).toBeGreaterThanOrEqual(4.5)
    expect(contrast(color, dutyCalendarWeekendColor(color, 'sunday'))).toBeGreaterThanOrEqual(4.5)
    expect(contrast(color, dutyCalendarWeekendColor(color, 'saturday'))).toBeGreaterThanOrEqual(4.5)
  })
  it('recognizes case variants while preserving legacy and empty backgrounds', () => {
    expect(isDutyTypePaletteColor('#f6d365')).toBe(true)
    for (const color of ['#123456', '#ffffff', '#000000', '#ffb3ba', '#ADD1AF', '#F2C094', null, undefined]) {
      expect(isDutyTypePaletteColor(color)).toBe(false)
      expect(dutyCalendarWeekendColor(color, 'sunday')).toBe('var(--dp-sunday)')
      expect(dutyCalendarWeekendColor(color, 'saturday')).toBe('var(--dp-saturday)')
    }
  })
})
