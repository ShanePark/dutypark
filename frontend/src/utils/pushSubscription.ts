import type { PushSubscriptionRequest } from '@/api/push'

export function buildPushSubscriptionRequest(
  subscription: PushSubscription,
): PushSubscriptionRequest {
  const p256dh = arrayBufferToBase64(subscription.getKey('p256dh')!)
  const auth = arrayBufferToBase64(subscription.getKey('auth')!)

  return {
    endpoint: subscription.endpoint,
    keys: { p256dh, auth },
  }
}

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer)
  let binary = ''
  bytes.forEach(b => binary += String.fromCharCode(b))
  return window.btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}
