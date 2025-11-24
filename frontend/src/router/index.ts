import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'dashboard',
    component: () => import('@/views/dashboard/DashboardView.vue'),
    meta: { requiresAuth: false },
  },
  {
    path: '/auth/login',
    name: 'login',
    component: () => import('@/views/auth/LoginView.vue'),
    meta: { requiresAuth: false, guestOnly: true },
  },
  {
    path: '/auth/sso-signup',
    name: 'sso-signup',
    component: () => import('@/views/auth/SsoSignupView.vue'),
    meta: { requiresAuth: false },
  },
  {
    path: '/duty/:id',
    name: 'duty',
    component: () => import('@/views/duty/DutyView.vue'),
    meta: { requiresAuth: false },
  },
  {
    path: '/member',
    name: 'member',
    component: () => import('@/views/member/MemberView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/team',
    name: 'team',
    component: () => import('@/views/team/TeamView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/team/manage/:teamId',
    name: 'team-manage',
    component: () => import('@/views/team/TeamManageView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'not-found',
    component: () => import('@/views/NotFoundView.vue'),
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach(async (to, _from, next) => {
  const authStore = useAuthStore()

  // Initialize auth state on first navigation
  if (!authStore.isInitialized) {
    await authStore.initialize()
  }

  // Check authentication requirements
  if (to.meta.requiresAuth && !authStore.isLoggedIn) {
    next({ name: 'login', query: { redirect: to.fullPath } })
    return
  }

  // Redirect logged-in users away from guest-only pages
  if (to.meta.guestOnly && authStore.isLoggedIn) {
    next({ name: 'dashboard' })
    return
  }

  next()
})

export default router
