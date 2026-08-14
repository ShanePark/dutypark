const NON_RETRYABLE_ONE_TIME_POST_PATHS = new Set([
  '/auth/reauth/password',
  '/members/me/deletion',
  '/auth/mobile/oauth/exchange',
  '/auth/web/oauth/apple/exchange',
])

export function shouldSkipUnauthorizedRefresh(method: string | undefined, url: string | undefined): boolean {
  if (method?.toLowerCase() !== 'post' || !url) return false
  const path = url.split('?', 1)[0] ?? ''
  return NON_RETRYABLE_ONE_TIME_POST_PATHS.has(path)
}
