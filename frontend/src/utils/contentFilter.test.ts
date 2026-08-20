import { describe, expect, it } from 'vitest'
import { findBannedWord, normalizeForMatching } from './contentFilter'

const WORDS = ['시발', 'fuck', 'nigger']

describe('normalizeForMatching', () => {
  it('lowercases, applies NFKC and drops everything that is not a letter or digit', () => {
    expect(normalizeForMatching('F.U-C*K!')).toBe('fuck')
    expect(normalizeForMatching('ｆｕｃｋ')).toBe('fuck')
    expect(normalizeForMatching('시 발')).toBe('시발')
    expect(normalizeForMatching('회식 19:30 @강남')).toBe('회식1930강남')
    expect(normalizeForMatching('시〇발')).toBe('시발')
    expect(normalizeForMatching('')).toBe('')
  })
})

describe('findBannedWord', () => {
  it('returns the matched word for text that contains one', () => {
    expect(findBannedWord(['오늘 시발 회식'], WORDS)).toBe('시발')
    expect(findBannedWord(['You FUCK'], WORDS)).toBe('fuck')
  })

  it('sees through separators and width variants used to slip a word past the filter', () => {
    expect(findBannedWord(['f u c k'], WORDS)).toBe('fuck')
    expect(findBannedWord(['시.발'], WORDS)).toBe('시발')
    expect(findBannedWord(['ｎｉｇｇｅｒ'], WORDS)).toBe('nigger')
  })

  it('checks every provided field and ignores blank ones', () => {
    expect(findBannedWord(['clean title', '본문에 시발'], WORDS)).toBe('시발')
    expect(findBannedWord([null, undefined, '', '  '], WORDS)).toBeNull()
  })

  it('returns null for ordinary content and for an empty word list', () => {
    expect(findBannedWord(['팀 회식 19:30 강남역'], WORDS)).toBeNull()
    expect(findBannedWord(['오늘 시발 회식'], [])).toBeNull()
  })

  it('matches by substring, so the list must exclude everyday superstrings', () => {
    // Documented trade-off: '시발' also matches '시발점'. Collision-prone entries such as
    // '보지' or 'rape' are therefore kept out of banned-words.json.
    expect(findBannedWord(['시발점'], WORDS)).toBe('시발')
    expect(findBannedWord(['보지 못했다', 'grape'], WORDS)).toBeNull()
  })
})
