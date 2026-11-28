const LATIN_WORD_START = /^\p{Script=Latin}/u
// The first letter with any combining marks after it, so a decomposed "É" stays whole.
const FIRST_LETTER = /^\P{M}\p{M}*/u

/**
 * Initials for a narrow name slot: "Shane Park" → "S.P". Only names of two or more
 * space-separated words that all start with a Latin letter have them; any other
 * name returns null and keeps the slot's usual truncation.
 * Shares its test vectors with iOS MemberNameInitials (docs/design/member-name-length.md).
 */
export function memberInitials(name: string): string | null {
  const words = name.trim().split(/\s+/).filter(Boolean)
  if (words.length < 2 || !words.every((word) => LATIN_WORD_START.test(word))) return null
  return words.map((word) => word.match(FIRST_LETTER)![0].toUpperCase()).join('.')
}

const CALENDAR_TAG_MAX_CHARS = 3

/** A calendar-cell tag: up to three characters whole, then initials, else two characters and "…". */
export function calendarTagLabel(name: string): string {
  const chars = Array.from(name)
  if (chars.length <= CALENDAR_TAG_MAX_CHARS) return name
  return memberInitials(name) ?? `${chars.slice(0, 2).join('')}…`
}
