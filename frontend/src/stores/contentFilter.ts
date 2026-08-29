import { defineStore } from 'pinia'
import { ref } from 'vue'
import { publicContentApi } from '@/api/publicContent'
import { findBannedWord } from '@/utils/contentFilter'

const BANNED_WORDS_CACHE_KEY = 'dp-banned-words'

function loadCachedWords(): string[] {
  try {
    const cached = localStorage.getItem(BANNED_WORDS_CACHE_KEY)
    if (!cached) return []
    const parsed: unknown = JSON.parse(cached)
    return Array.isArray(parsed) ? parsed.filter((word): word is string => typeof word === 'string') : []
  } catch {
    return []
  }
}

function saveCachedWords(words: string[]) {
  try {
    localStorage.setItem(BANNED_WORDS_CACHE_KEY, JSON.stringify(words))
  } catch {
    // A full or unavailable storage only costs the next cold start its cached list.
  }
}

export const useContentFilterStore = defineStore('contentFilter', () => {
  const words = ref<string[]>(loadCachedWords())
  let inFlight: Promise<void> | null = null

  /**
   * Serves the cached list immediately and refreshes it once per session, so a list update reaches the web
   * without a redeploy. A cold start with no cache and no network leaves the list empty, and an empty list
   * blocks nothing. The server remains the final guard for supported shared mutations such as public
   * D-Days and duty types, while client-only paths remain fail-open until this list is available.
   */
  function load(): Promise<void> {
    if (inFlight) return inFlight

    inFlight = publicContentApi
      .getBannedWords()
      .then((content) => {
        words.value = content.words
        saveCachedWords(content.words)
      })
      .catch(() => {
        // Keep whatever the cache already provided.
      })
      .finally(() => {
        inFlight = null
      })

    return inFlight
  }

  function findBlockedWord(values: readonly (string | null | undefined)[]): string | null {
    return findBannedWord(values, words.value)
  }

  function isBlocked(...values: (string | null | undefined)[]): boolean {
    return findBlockedWord(values) !== null
  }

  return { words, load, findBlockedWord, isBlocked }
})
