import type { NavigationGuard } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { buildLoginRoute } from '@/utils/redirect'

export const authGuard: NavigationGuard = async (to, _from, next) => {
  const authStore = useAuthStore()

  // Initialize auth state on first navigation
  if (!authStore.isInitialized) {
    await authStore.initialize()
  }

  // Check authentication requirements
  if (to.meta.requiresAuth && !authStore.isLoggedIn) {
    next(buildLoginRoute(to.fullPath))
    return
  }

  // Redirect logged-in users away from guest-only pages.
  // `replace` matters on back navigation: the bounce would otherwise push a new entry
  // on top of the page the user just left, so back could never get past it.
  if (to.meta.guestOnly && authStore.isLoggedIn) {
    next({ name: 'dashboard', replace: true })
    return
  }

  // Check admin requirements
  if (to.meta.requiresAdmin && !authStore.isAdmin) {
    next({ name: 'dashboard', replace: true })
    return
  }

  next()
}
