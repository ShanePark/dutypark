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
    path: '/auth/sso-congrats',
    name: 'sso-congrats',
    component: () => import('@/views/auth/SsoCongratsView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/auth/oauth-callback',
    name: 'oauth-callback',
    component: () => import('@/views/auth/OAuthCallbackView.vue'),
    meta: { requiresAuth: false },
  },
  {
    path: '/duty/:id',
    name: 'duty',
    component: () => import('@/views/duty/DutyView.vue'),
    meta: { requiresAuth: false },
  },
  {
    path: '/todo',
    name: 'todo',
    component: () => import('@/views/todo/TodoBoardView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/member',
    name: 'member',
    component: () => import('@/views/member/MemberView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/friends',
    name: 'friends',
    component: () => import('@/views/member/FriendsView.vue'),
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
    path: '/notifications',
    name: 'notifications',
    component: () => import('@/views/notification/NotificationListView.vue'),
    meta: { requiresAuth: true },
  },
  // Admin routes
  {
    path: '/admin',
    name: 'admin',
    component: () => import('@/views/admin/AdminDashboardView.vue'),
    meta: { requiresAuth: true, requiresAdmin: true },
  },
  {
    path: '/admin/teams',
    name: 'admin-teams',
    component: () => import('@/views/admin/AdminTeamListView.vue'),
    meta: { requiresAuth: true, requiresAdmin: true },
  },
  {
    path: '/admin/dev',
    name: 'admin-dev',
    component: () => import('@/views/admin/DevPlaygroundView.vue'),
    meta: { requiresAuth: true, requiresAdmin: true },
  },
  // Guide page
  {
    path: '/guide',
    name: 'guide',
    component: () => import('@/views/guide/GuideView.vue'),
    meta: { requiresAuth: false },
  },
  // Policy pages
  {
    path: '/terms',
    name: 'terms',
    component: () => import('@/views/policy/TermsView.vue'),
    meta: { requiresAuth: false },
  },
  {
    path: '/privacy',
    name: 'privacy',
    component: () => import('@/views/policy/PrivacyView.vue'),
    meta: { requiresAuth: false },
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
  scrollBehavior(_to, _from, savedPosition) {
    // Restore scroll position for back/forward navigation
    if (savedPosition) {
      return savedPosition
    }
    // Scroll to top for new navigation
    return { top: 0 }
  },
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

  // Check admin requirements
  if (to.meta.requiresAdmin && !authStore.isAdmin) {
    next({ name: 'dashboard' })
    return
  }

  next()
})

export default router
