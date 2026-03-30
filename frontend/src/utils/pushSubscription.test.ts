import { describe, expect, it } from 'vitest'
import { buildPushSubscriptionRequest } from './pushSubscription'

function keyBuffer(values: number[]): ArrayBuffer {
  return Uint8Array.from(values).buffer
}

describe('buildPushSubscriptionRequest', () => {
  it('builds a request without locale and encodes keys as base64url', () => {
    Object.defineProperty(globalThis, 'window', {
      value: {
        btoa: (value: string) => Buffer.from(value, 'binary').toString('base64'),
      },
      configurable: true,
    })

    const subscription = {
      endpoint: 'https://push.example/subscription',
      getKey: (name: string) => {
        if (name === 'p256dh') return keyBuffer([251, 255, 0])
        if (name === 'auth') return keyBuffer([1, 2, 3])
        return null
      },
    } as unknown as PushSubscription

    const request = buildPushSubscriptionRequest(subscription)

    expect(request).toEqual({
      endpoint: 'https://push.example/subscription',
      keys: {
        p256dh: '-_8A',
        auth: 'AQID',
      },
    })
    expect('locale' in request).toBe(false)
  })
})
