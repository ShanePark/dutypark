<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch, type Component, type ComponentPublicInstance } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { Calendar, Home, ListTodo, Settings, Users } from 'lucide-vue-next'
import { useAuthStore } from '@/stores/auth'
import { useDragClickGuard } from '@/composables/useDragClickGuard'

type FooterNavItem = {
  id: string
  path: string
  icon: Component
  label: string
}

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { t } = useI18n()
const dragClickGuard = useDragClickGuard({ resetDelay: 320 })
const navListRef = ref<HTMLElement | null>(null)
const navItemRefs = ref<Array<HTMLElement | null>>([])
const indicatorStyle = ref<Record<string, string>>({
  width: '0px',
  height: '0px',
  transform: 'translate3d(0, 0, 0)',
  opacity: '0',
})
const indicatorReady = ref(false)
const isIndicatorDragging = ref(false)
const touchStartX = ref(0)
const touchStartY = ref(0)
const touchCurrentX = ref(0)
const touchCurrentY = ref(0)
const gestureAxis = ref<'horizontal' | 'vertical' | null>(null)
let resizeObserver: ResizeObserver | null = null

const SWIPE_ACTIVATION_THRESHOLD = 12
const SWIPE_COMMIT_THRESHOLD = 44

const navItems = computed(() => {
  const items: FooterNavItem[] = [
    { id: 'home', path: '/', icon: Home, label: t('footer.home') },
    {
      id: 'calendar',
      path: authStore.user ? `/duty/${authStore.user.id}` : '/',
      icon: Calendar,
      label: t('footer.myCalendar'),
    },
    { id: 'todo', path: '/todo', icon: ListTodo, label: t('footer.todo') },
    { id: 'team', path: '/team', icon: Users, label: t('footer.myTeam') },
    { id: 'settings', path: '/member', icon: Settings, label: t('footer.settings') },
  ]
  return items
})

const activeIndex = computed(() => {
  return navItems.value.findIndex((item) => isActive(item.path))
})

const isActive = (path: string) => {
  if (path === '/') return route.path === '/'
  return route.path.startsWith(path)
}

function setNavItemRef(element: Element | ComponentPublicInstance | null, index: number) {
  if (element instanceof HTMLElement) {
    navItemRefs.value[index] = element
    return
  }

  if (element && !(element instanceof Element) && '$el' in element && element.$el instanceof HTMLElement) {
    navItemRefs.value[index] = element.$el
    return
  }

  navItemRefs.value[index] = null
}

function getIndicatorMetrics(index: number) {
  const navList = navListRef.value
  const item = navItemRefs.value[index]

  if (!navList || !item) {
    return null
  }

  const listRect = navList.getBoundingClientRect()
  const itemRect = item.getBoundingClientRect()

  return {
    x: itemRect.left - listRect.left,
    y: itemRect.top - listRect.top,
    width: itemRect.width,
    height: itemRect.height,
  }
}

function setIndicatorPosition(x: number, y: number, width: number, height: number) {
  indicatorStyle.value = {
    width: `${width}px`,
    height: `${height}px`,
    transform: `translate3d(${x}px, ${y}px, 0)`,
    opacity: '1',
  }
}

async function updateIndicator() {
  await nextTick()

  const metrics = activeIndex.value >= 0 ? getIndicatorMetrics(activeIndex.value) : null

  if (!metrics) {
    indicatorStyle.value = {
      ...indicatorStyle.value,
      opacity: '0',
    }
    return
  }

  setIndicatorPosition(metrics.x, metrics.y, metrics.width, metrics.height)

  if (!indicatorReady.value) {
    requestAnimationFrame(() => {
      indicatorReady.value = true
    })
  }
}

function handleResize() {
  void updateIndicator()
}

function setupResizeObserver() {
  resizeObserver?.disconnect()

  if (!navListRef.value || typeof ResizeObserver === 'undefined') {
    return
  }

  resizeObserver = new ResizeObserver(() => {
    void updateIndicator()
  })

  resizeObserver.observe(navListRef.value)
}

function resetSwipeState() {
  touchStartX.value = 0
  touchStartY.value = 0
  touchCurrentX.value = 0
  touchCurrentY.value = 0
  gestureAxis.value = null
}

function updateIndicatorPreview(deltaX: number) {
  const currentIndex = activeIndex.value
  const currentMetrics = currentIndex >= 0 ? getIndicatorMetrics(currentIndex) : null

  if (!currentMetrics) {
    return
  }

  const prevMetrics = currentIndex > 0 ? getIndicatorMetrics(currentIndex - 1) : null
  const nextMetrics = currentIndex < navItems.value.length - 1 ? getIndicatorMetrics(currentIndex + 1) : null
  const minOffset = prevMetrics ? prevMetrics.x - currentMetrics.x : 0
  const maxOffset = nextMetrics ? nextMetrics.x - currentMetrics.x : 0
  const clampedOffset = Math.min(Math.max(deltaX, minOffset), maxOffset)

  let previewWidth = currentMetrics.width

  if (clampedOffset > 0 && nextMetrics && maxOffset > 0) {
    const ratio = clampedOffset / maxOffset
    previewWidth = currentMetrics.width + (nextMetrics.width - currentMetrics.width) * ratio
  } else if (clampedOffset < 0 && prevMetrics && minOffset < 0) {
    const ratio = clampedOffset / minOffset
    previewWidth = currentMetrics.width + (prevMetrics.width - currentMetrics.width) * ratio
  }

  setIndicatorPosition(
    currentMetrics.x + clampedOffset,
    currentMetrics.y,
    previewWidth,
    currentMetrics.height
  )
}

function getSwipeTargetIndex(deltaX: number) {
  if (activeIndex.value < 0) {
    return -1
  }

  if (deltaX >= SWIPE_COMMIT_THRESHOLD) {
    return Math.min(activeIndex.value + 1, navItems.value.length - 1)
  }

  if (deltaX <= -SWIPE_COMMIT_THRESHOLD) {
    return Math.max(activeIndex.value - 1, 0)
  }

  return activeIndex.value
}

function handleNavClick(item: FooterNavItem, event: MouseEvent) {
  if (item.id === 'calendar' && isActive(item.path)) {
    event.preventDefault()
    window.dispatchEvent(new CustomEvent('duty-go-to-today'))
  }
}

function handleTouchStart(event: TouchEvent) {
  const touch = event.touches[0]

  if (!touch) {
    return
  }

  touchStartX.value = touch.clientX
  touchStartY.value = touch.clientY
  touchCurrentX.value = touch.clientX
  touchCurrentY.value = touch.clientY
  gestureAxis.value = null
  isIndicatorDragging.value = false
}

function handleTouchMove(event: TouchEvent) {
  const touch = event.touches[0]

  if (!touch) {
    return
  }

  touchCurrentX.value = touch.clientX
  touchCurrentY.value = touch.clientY

  const deltaX = touchCurrentX.value - touchStartX.value
  const deltaY = touchCurrentY.value - touchStartY.value
  const absDeltaX = Math.abs(deltaX)
  const absDeltaY = Math.abs(deltaY)

  if (!gestureAxis.value) {
    if (absDeltaX < SWIPE_ACTIVATION_THRESHOLD && absDeltaY < SWIPE_ACTIVATION_THRESHOLD) {
      return
    }

    gestureAxis.value = absDeltaX > absDeltaY ? 'horizontal' : 'vertical'
  }

  if (gestureAxis.value !== 'horizontal') {
    return
  }

  if (event.cancelable) {
    event.preventDefault()
  }

  isIndicatorDragging.value = true
  updateIndicatorPreview(deltaX)
}

function handleTouchEnd() {
  const deltaX = touchCurrentX.value - touchStartX.value
  const deltaY = Math.abs(touchCurrentY.value - touchStartY.value)
  const didSwipeHorizontally =
    gestureAxis.value === 'horizontal'
    && Math.abs(deltaX) > SWIPE_ACTIVATION_THRESHOLD
    && Math.abs(deltaX) > deltaY

  isIndicatorDragging.value = false

  if (!didSwipeHorizontally) {
    resetSwipeState()
    return
  }

  dragClickGuard.suppressNextClick()

  const targetIndex = getSwipeTargetIndex(deltaX)

  if (targetIndex === activeIndex.value || targetIndex < 0) {
    resetSwipeState()
    void updateIndicator()
    return
  }

  const targetItem = navItems.value[targetIndex]

  resetSwipeState()

  if (targetItem) {
    void router.push(targetItem.path)
  }
}

function handleTouchCancel() {
  isIndicatorDragging.value = false
  resetSwipeState()
  void updateIndicator()
}

onMounted(async () => {
  await updateIndicator()
  setupResizeObserver()
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  resizeObserver?.disconnect()
  window.removeEventListener('resize', handleResize)
})

watch(
  () => route.fullPath,
  () => {
    void updateIndicator()
  }
)

watch(
  navItems,
  () => {
    indicatorReady.value = false
    void updateIndicator()
    setupResizeObserver()
  },
  { deep: true }
)
</script>

<template>
  <footer
    class="footer-shell fixed bottom-0 left-0 right-0 z-50 border-t border-dp-border-secondary bg-dp-bg-footer"
    :style="{
      paddingLeft: 'env(safe-area-inset-left)',
      paddingRight: 'env(safe-area-inset-right)'
    }"
  >
    <nav class="max-w-lg mx-auto px-2 pt-1 pb-0.5 sm:px-4 sm:pt-2 sm:pb-2">
      <div
        ref="navListRef"
        :class="[
          'footer-nav-track relative',
          { 'footer-nav-list--indicator-ready': indicatorReady }
        ]"
        @touchstart="handleTouchStart"
        @touchmove="handleTouchMove"
        @touchend="handleTouchEnd"
        @touchcancel="handleTouchCancel"
        @pointerdown.capture="dragClickGuard.handlePointerDown"
        @click.capture="dragClickGuard.handleClick"
      >
        <div
          aria-hidden="true"
          class="footer-nav-indicator"
          :class="{
            'footer-nav-indicator--ready': indicatorReady && !isIndicatorDragging,
            'footer-nav-indicator--dragging': isIndicatorDragging
          }"
          :style="indicatorStyle"
        />
        <ul class="footer-nav-list relative flex justify-around gap-1">
          <li
            v-for="(item, index) in navItems"
            :key="item.id"
            :ref="(element) => setNavItemRef(element, index)"
            class="footer-nav-item-shell relative z-10 flex-1"
          >
            <router-link
              :to="item.path"
              @click="handleNavClick(item, $event)"
              class="footer-nav-link relative flex w-full flex-col items-center justify-center rounded-xl px-2 py-1.5 text-xs transition-colors min-h-[48px] sm:min-h-[64px] sm:px-3 sm:py-3 sm:text-sm"
              :class="isActive(item.path) ? 'footer-nav-active' : 'footer-nav-inactive'"
            >
              <component
                :is="item.icon"
                class="w-6 h-6 sm:w-7 sm:h-7 mb-0.5 sm:mb-1"
                :stroke-width="2"
                aria-hidden="true"
              />
              <span class="footer-nav-label">{{ item.label }}</span>
            </router-link>
          </li>
        </ul>
      </div>
    </nav>
  </footer>
</template>

<style scoped>
.footer-shell {
  padding-bottom: max(0.375rem, calc(env(safe-area-inset-bottom) - 0.5rem));
}

.footer-nav-track {
  isolation: isolate;
  touch-action: pan-y;
  -webkit-user-select: none;
  user-select: none;
}

.footer-nav-list {
  padding-bottom: 0;
}

.footer-nav-indicator {
  position: absolute;
  top: 0;
  left: 0;
  border-radius: 0.75rem;
  background-color: var(--dp-footer-active-bg);
  border: 1px solid var(--dp-border-on-dark);
  pointer-events: none;
  opacity: 0;
}

.footer-nav-indicator--ready {
  transition:
    transform 280ms cubic-bezier(0.22, 1, 0.36, 1),
    width 280ms cubic-bezier(0.22, 1, 0.36, 1),
    height 280ms cubic-bezier(0.22, 1, 0.36, 1),
    opacity 180ms ease;
}

.footer-nav-indicator--dragging {
  transition: none;
}

.footer-nav-link {
  line-height: 1.1;
}

.footer-nav-list--indicator-ready .footer-nav-active {
  background-color: transparent;
}

.footer-nav-list--indicator-ready .footer-nav-active:hover {
  background-color: transparent;
}

.footer-nav-label {
  display: block;
  white-space: nowrap;
  text-align: center;
  font-size: 0.68rem;
}

@media (min-width: 640px) {
  .footer-shell {
    padding-bottom: 0;
  }

  .footer-nav-label {
    font-size: 0.875rem;
  }
}
</style>
