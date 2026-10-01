export const dutyTypePalette = [
  { name: 'blush', color: '#ECC2C9' },
  { name: 'orange', color: '#F6BC7A' },
  { name: 'yellow', color: '#F6D365' },
  { name: 'sand', color: '#D8BF9B' },
  { name: 'lime', color: '#C8DD70' },
  { name: 'leaf', color: '#A6D99B' },
  { name: 'mint', color: '#8FDCBD' },
  { name: 'aqua', color: '#9DDBDE' },
  { name: 'lilac', color: '#D1B8EC' },
  { name: 'magenta', color: '#E9AEE9' },
  { name: 'stone', color: '#CCC8BD' },
] as const

export const defaultDutyTypeColor = '#F6D365'

export function isDutyTypePaletteColor(color: string | null | undefined): boolean {
  return dutyTypePalette.some(option => option.color.toLowerCase() === color?.toLowerCase())
}

export function dutyCalendarWeekendColor(color: string | null | undefined, day: 'sunday' | 'saturday'): string {
  // Pale duty backgrounds need the same readable weekend foreground in either theme.
  if (isDutyTypePaletteColor(color)) return day === 'sunday' ? '#991B1B' : '#1E40AF'
  return day === 'sunday' ? 'var(--dp-sunday)' : 'var(--dp-saturday)'
}
