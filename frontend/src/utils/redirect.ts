export function getSafeRedirect(redirect: unknown): string | null {
  if (typeof redirect !== 'string') {
    return null
  }
  if (!redirect.startsWith('/') || redirect.startsWith('//')) {
    return null
  }
  return redirect
}
