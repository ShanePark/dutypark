import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

vi.mock('@/api/publicContent', () => ({
  publicContentApi: {
    getBannedWords: vi.fn(),
  },
}))

import { publicContentApi } from '@/api/publicContent'
import { useContentFilterStore } from './contentFilter'

const CACHE_KEY = 'dp-banned-words'

const storage = new Map<string, string>()
const localStorageMock = {
  getItem: (key: string) => storage.get(key) ?? null,
  setItem: (key: string, value: string) => void storage.set(key, value),
  removeItem: (key: string) => void storage.delete(key),
  clear: () => storage.clear(),
}
Object.defineProperty(globalThis, 'localStorage', { value: localStorageMock, writable: true })

function bannedWords(words: string[]) {
  return { schemaVersion: 1, contentVersion: 'abc', words }
}

describe('content filter store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.clear()
    vi.clearAllMocks()
  })

  it('loads the list once per session and caches it for the next cold start', async () => {
    vi.mocked(publicContentApi.getBannedWords).mockResolvedValue(bannedWords(['시발']))
    const store = useContentFilterStore()

    await Promise.all([store.load(), store.load()])

    expect(publicContentApi.getBannedWords).toHaveBeenCalledTimes(1)
    expect(store.isBlocked('오늘 시발 회식')).toBe(true)
    expect(JSON.parse(localStorage.getItem(CACHE_KEY) ?? '[]')).toEqual(['시발'])
  })

  it('checks with the cached list before the request resolves', () => {
    localStorage.setItem(CACHE_KEY, JSON.stringify(['시발']))
    vi.mocked(publicContentApi.getBannedWords).mockResolvedValue(bannedWords(['시발', 'fuck']))

    const store = useContentFilterStore()

    expect(store.isBlocked('시발')).toBe(true)
    expect(store.findBlockedWord(['팀 회식'])).toBeNull()
  })

  it('keeps the cached list when the request fails', async () => {
    localStorage.setItem(CACHE_KEY, JSON.stringify(['시발']))
    vi.mocked(publicContentApi.getBannedWords).mockRejectedValue(new Error('offline'))
    const store = useContentFilterStore()

    await store.load()

    expect(store.isBlocked('시발')).toBe(true)
  })

  it('blocks nothing when neither a cache nor a response is available', async () => {
    vi.mocked(publicContentApi.getBannedWords).mockRejectedValue(new Error('offline'))
    const store = useContentFilterStore()

    await store.load()

    expect(store.isBlocked('시발')).toBe(false)
  })

  it('reports the first blocked field across every value it is given', async () => {
    vi.mocked(publicContentApi.getBannedWords).mockResolvedValue(bannedWords(['시발']))
    const store = useContentFilterStore()
    await store.load()

    expect(store.findBlockedWord(['제목', null, undefined, '본문 시.발'])).toBe('시발')
    expect(store.isBlocked('제목', '본문')).toBe(false)
  })
})
