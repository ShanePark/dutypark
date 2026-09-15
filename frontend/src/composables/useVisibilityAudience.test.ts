import { afterEach, describe, expect, it, vi } from 'vitest'
import { effectScope, reactive, type EffectScope } from 'vue'
import { useVisibilityAudience, type AudienceSnapshot, type AudienceSource } from './useVisibilityAudience'

const snapshot: AudienceSnapshot = {
  ownerId: 1, calendarVisibility: 'FRIENDS',
  friends: [{ id: 2, name: 'Friend', isFamily: false }, { id: 3, name: 'Family', isFamily: true }],
}
const scopes: EffectScope[] = []
afterEach(() => { scopes.splice(0).forEach(scope => scope.stop()) })
function deferred<T>() {
  let resolve!: (value: T) => void
  let reject!: (reason?: unknown) => void
  const promise = new Promise<T>((res, rej) => { resolve = res; reject = rej })
  return { promise, resolve, reject }
}
function setup(fetcher: () => Promise<AudienceSnapshot>) {
  const source = reactive<AudienceSource>({ ownerId: 1, visibility: 'FRIENDS', scope: 'calendar' })
  const scope = effectScope()
  scopes.push(scope)
  const audience = scope.run(() => useVisibilityAudience(() => source, fetcher))!
  return { source, audience, scope }
}

describe('useVisibilityAudience', () => {
  it('loads only on request, not when the control is displayed', async () => {
    const fetcher = vi.fn().mockResolvedValue(snapshot)
    const { audience } = setup(fetcher)
    expect(fetcher).not.toHaveBeenCalled()
    expect(audience.status.value).toBe('idle')
    await audience.load()
    expect(audience.status.value).toBe('ready')
    expect(audience.members.value).toHaveLength(2)
  })
  it('distinguishes a failed request from a successful empty audience and supports retry', async () => {
    const fetcher = vi.fn().mockRejectedValueOnce(new Error('offline')).mockResolvedValueOnce({ ...snapshot, friends: [] })
    const { audience } = setup(fetcher)
    await audience.load()
    expect(audience.status.value).toBe('error')
    await audience.load()
    expect(audience.status.value).toBe('ready')
    expect(audience.members.value).toEqual([])
  })
  it('does not expose a previous account response after an account switch', async () => {
    const request = deferred<AudienceSnapshot>()
    const { audience, source } = setup(() => request.promise)
    const pending = audience.load()
    source.ownerId = 9
    expect(audience.status.value).toBe('idle')
    request.resolve(snapshot)
    await pending
    expect(audience.members.value).toEqual([])
    expect(audience.status.value).toBe('idle')
  })
  it('rejects a response identifying a different owner', async () => {
    const { audience } = setup(async () => ({ ...snapshot, ownerId: 9 }))
    await audience.load()
    expect(audience.status.value).toBe('error')
    expect(audience.members.value).toEqual([])
  })
  it('ignores late responses and errors after visibility changes', async () => {
    const request = deferred<AudienceSnapshot>()
    const { audience, source } = setup(() => request.promise)
    const pending = audience.load()
    source.visibility = 'FAMILY'
    request.reject(new Error('old request'))
    await pending
    expect(audience.status.value).toBe('idle')
  })
  it('lets only the latest request update the list', async () => {
    const first = deferred<AudienceSnapshot>()
    const second = deferred<AudienceSnapshot>()
    const fetcher = vi.fn().mockReturnValueOnce(first.promise).mockReturnValueOnce(second.promise)
    const { audience } = setup(fetcher)
    const old = audience.load()
    const recent = audience.load()
    second.resolve({ ...snapshot, friends: [snapshot.friends[1]!] })
    await recent
    first.resolve(snapshot)
    await old
    expect(audience.members.value.map(member => member.id)).toEqual([3])
  })
  it('clears the list on close and does not apply a pending response after disposal', async () => {
    const request = deferred<AudienceSnapshot>()
    const { audience, scope } = setup(() => request.promise)
    const pending = audience.load()
    scope.stop()
    request.resolve(snapshot)
    await pending
    expect(audience.status.value).toBe('idle')
    expect(audience.members.value).toEqual([])
  })
  it('does not fetch after logout or for a non-restricted visibility', async () => {
    const fetcher = vi.fn().mockResolvedValue(snapshot)
    const { source, audience } = setup(fetcher)
    source.ownerId = null
    await audience.load()
    source.ownerId = 1
    source.visibility = 'PUBLIC'
    await audience.load()
    expect(fetcher).not.toHaveBeenCalled()
  })
  it('explains when a schedule is constrained by calendar visibility', async () => {
    const { audience, source } = setup(async () => ({ ...snapshot, calendarVisibility: 'FAMILY' }))
    source.scope = 'schedule'
    await audience.load()
    expect(audience.calendarRestrictsAudience.value).toBe(true)
    expect(audience.members.value.map(member => member.id)).toEqual([3])
  })
})
