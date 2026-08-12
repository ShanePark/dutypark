import { describe, expect, it, vi } from 'vitest'
import {
  clearPendingSocialLinkProvider,
  consumeConnectedPendingSocialLinkProvider,
  consumeSocialLinkCallback,
  storePendingSocialLinkProvider,
} from './socialLinkCallback'

function createStorage() {
  const values = new Map<string, string>()
  return {
    getItem: vi.fn((key: string) => values.get(key) ?? null),
    setItem: vi.fn((key: string, value: string) => { values.set(key, value) }),
    removeItem: vi.fn((key: string) => { values.delete(key) }),
  }
}

describe('consumeSocialLinkCallback', () => {
  it('removes all callback parameters, preserves other query values, and waits for replacement', async () => {
    let finishReplacement!: () => void
    const replacement = new Promise<void>((resolve) => {
      finishReplacement = resolve
    })
    const replaceQuery = vi.fn(async () => replacement)
    let settled = false

    const resultPromise = consumeSocialLinkCallback({
      tab: 'account',
      socialLinkSuccess: 'true',
      socialLinkError: 'already_linked',
      socialProvider: 'kakao',
    }, replaceQuery)
    resultPromise.then(() => { settled = true })

    await Promise.resolve()
    expect(replaceQuery).toHaveBeenCalledWith({ tab: 'account' })
    expect(settled).toBe(false)

    finishReplacement()
    await expect(resultPromise).resolves.toEqual({ type: 'success', provider: 'kakao' })
  })

  it('handles the existing already-linked callback after removing its query', async () => {
    const replaceQuery = vi.fn(async () => undefined)

    await expect(consumeSocialLinkCallback({
      socialLinkError: 'already_linked',
      socialProvider: 'naver',
    }, replaceQuery)).resolves.toEqual({ type: 'alreadyLinked', provider: 'naver' })

    expect(replaceQuery).toHaveBeenCalledWith({})
  })

  it.each([
    [{ socialLinkSuccess: 'TRUE', socialProvider: 'kakao' }],
    [{ socialLinkSuccess: '1', socialProvider: 'naver' }],
    [{ socialLinkSuccess: 'true', socialProvider: 'google' }],
    [{ socialLinkError: 'unknown', socialProvider: 'kakao' }],
  ])('cleans but ignores invalid callback query %o', async (query) => {
    const replaceQuery = vi.fn(async () => undefined)

    await expect(consumeSocialLinkCallback(query, replaceQuery)).resolves.toBeNull()
    expect(replaceQuery).toHaveBeenCalledWith({})
  })

  it('does nothing when no callback query is present', async () => {
    const replaceQuery = vi.fn(async () => undefined)

    await expect(consumeSocialLinkCallback({ tab: 'account' }, replaceQuery)).resolves.toBeNull()
    expect(replaceQuery).not.toHaveBeenCalled()
  })
})

describe('pending social link fallback', () => {
  it.each([
    ['kakao' as const, { kakaoId: 'kakao-123', naverId: null }],
    ['naver' as const, { kakaoId: null, naverId: 'naver-123' }],
  ])('stores and consumes a connected %s provider once', (provider, member) => {
    const storage = createStorage()

    storePendingSocialLinkProvider(provider, storage)

    expect(consumeConnectedPendingSocialLinkProvider(member, storage)).toBe(provider)
    expect(consumeConnectedPendingSocialLinkProvider(member, storage)).toBeNull()
  })

  it('clears a stale marker without reporting success when the provider is not connected', () => {
    const storage = createStorage()
    storePendingSocialLinkProvider('kakao', storage)

    expect(consumeConnectedPendingSocialLinkProvider({ kakaoId: null, naverId: null }, storage)).toBeNull()
    expect(consumeConnectedPendingSocialLinkProvider({ kakaoId: 'later-connected' }, storage)).toBeNull()
  })

  it('can clear a pending marker for callback errors', () => {
    const storage = createStorage()
    storePendingSocialLinkProvider('naver', storage)

    clearPendingSocialLinkProvider(storage)

    expect(consumeConnectedPendingSocialLinkProvider({ naverId: 'naver-123' }, storage)).toBeNull()
  })

  it('does not throw when session storage access fails', () => {
    const storage = {
      getItem: vi.fn(() => { throw new Error('blocked') }),
      setItem: vi.fn(() => { throw new Error('blocked') }),
      removeItem: vi.fn(() => { throw new Error('blocked') }),
    }

    expect(() => storePendingSocialLinkProvider('kakao', storage)).not.toThrow()
    expect(() => clearPendingSocialLinkProvider(storage)).not.toThrow()
    expect(consumeConnectedPendingSocialLinkProvider({ kakaoId: 'kakao-123' }, storage)).toBeNull()
  })
})
