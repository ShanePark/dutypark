import type { RefreshTokenDto } from '@/types'
import { extractDatePart, formatDateOnly } from '@/utils/date'

export function countTodayLogins(tokens: RefreshTokenDto[], now: Date = new Date()): number {
  const today = formatDateOnly(now)

  return tokens.filter((token) => {
    if (!token.lastUsed) return false
    return extractDatePart(token.lastUsed) === today
  }).length
}
