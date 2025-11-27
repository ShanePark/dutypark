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
