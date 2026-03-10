import type { RouteLocationRaw } from 'vue-router'

export function getSafeRedirect(redirect: unknown): string | null {
  if (typeof redirect !== 'string') {
    return null
  }
  if (!redirect.startsWith('/') || redirect.startsWith('//')) {
    return null
  }
  return redirect
}

export function buildLoginRoute(redirect: unknown): RouteLocationRaw {
  const safeRedirect = getSafeRedirect(redirect)
  if (!safeRedirect) {
    return { name: 'login' }
  }
  return {
    name: 'login',
    query: {
      redirect: safeRedirect,
    },
  }
}

export function buildLoginPath(redirect: unknown): string {
  const safeRedirect = getSafeRedirect(redirect)
  if (!safeRedirect) {
    return '/auth/login'
  }
  return `/auth/login?redirect=${encodeURIComponent(safeRedirect)}`
}
