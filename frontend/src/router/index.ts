import { createRouter, createWebHistory } from 'vue-router'
import { authGuard } from './authGuard'
import { routes } from './routes'

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior(_to, _from, savedPosition) {
    // Restore scroll position for back/forward navigation
    if (savedPosition) {
      return savedPosition
    }
    // Scroll to top for new navigation
    return { top: 0 }
  },
})

router.beforeEach(authGuard)

export default router
