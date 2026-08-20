/**
 * Client-side check that keeps prohibited content from being posted, as App Store Guideline 1.2 requires.
 *
 * The banned word list is served already normalized by `GET /api/public-content/banned-words`, so input
 * must be normalized the same way before matching: NFKC, lowercased, and stripped of everything that is
 * not a Unicode letter or digit. Dropping separators is what makes `f.u.c.k` and `시 발` match too.
 *
 * Matching is a plain substring test. See `src/main/resources/public-content/README.md` for the list rules
 * that keep that from flagging everyday text.
 */
const NON_ALPHANUMERIC = /[^\p{L}\p{Nd}]/gu

export function normalizeForMatching(value: string): string {
  return value.normalize('NFKC').toLowerCase().replace(NON_ALPHANUMERIC, '')
}

export function findBannedWord(
  values: readonly (string | null | undefined)[],
  words: readonly string[],
): string | null {
  if (words.length === 0) return null

  for (const value of values) {
    if (!value) continue
    const normalized = normalizeForMatching(value)
    if (!normalized) continue

    const match = words.find((word) => normalized.includes(word))
    if (match) return match
  }

  return null
}
