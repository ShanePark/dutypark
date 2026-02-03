<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { Bell, X, Check } from 'lucide-vue-next'
import { usePushNotification } from '@/composables/usePushNotification'

const STORAGE_KEY = 'push-permission-guide-dismissed-until'
const DISMISS_DAYS = 7

const isVisible = ref(false)
const isSubscribing = ref(false)
const forceShow = ref(false)
const pushNotification = usePushNotification()

// Check URL param for dev testing: ?push-guide=true
function checkDevMode() {
  const params = new URLSearchParams(window.location.search)
  forceShow.value = params.get('push-guide') === 'true'
}

const isIOS = computed(() => {
  return /iPad|iPhone|iPod/.test(navigator.userAgent) && !(window as any).MSStream
})

const isStandalone = computed(() => {
  if (forceShow.value) return true
  return window.matchMedia('(display-mode: standalone)').matches ||
    (window.navigator as any).standalone === true
})

const isDismissed = computed(() => {
  if (forceShow.value) return false
  const dismissedUntil = localStorage.getItem(STORAGE_KEY)
  if (!dismissedUntil) return false
  return Date.now() < parseInt(dismissedUntil, 10)
})

async function checkVisibility() {
  checkDevMode()

  // Only show for iOS PWA (standalone mode) or dev mode
  if (!forceShow.value && (!isIOS.value || !isStandalone.value)) {
    isVisible.value = false
    return
  }

  if (isDismissed.value) {
    isVisible.value = false
    return
  }

  // Check push support
  pushNotification.checkSupport()
  if (!forceShow.value && !pushNotification.isSupported.value) {
    isVisible.value = false
    return
  }

  // Check if already granted (skip in dev mode to test UI)
  if (!forceShow.value && pushNotification.permission.value === 'granted') {
    isVisible.value = false
    return
  }

  // Check if server has push enabled
  await pushNotification.checkEnabled()
  if (!forceShow.value && !pushNotification.isEnabled.value) {
    isVisible.value = false
    return
  }

  isVisible.value = true
}

async function handleAllowClick() {
  if (isSubscribing.value) return
  isSubscribing.value = true

  try {
    const success = await pushNotification.subscribe()
    if (success) {
      isVisible.value = false
    }
  } finally {
    isSubscribing.value = false
  }
}

function dismiss() {
  isVisible.value = false
}

function dismissForDays() {
  const dismissUntil = Date.now() + (DISMISS_DAYS * 24 * 60 * 60 * 1000)
  localStorage.setItem(STORAGE_KEY, dismissUntil.toString())
  isVisible.value = false
}

onMounted(() => {
  checkVisibility()
})

defineExpose({ checkVisibility })
</script>

<template>
  <Transition name="slide-up">
    <div
      v-if="isVisible"
      class="push-guide-backdrop"
      @click.self="dismiss"
    >
      <div class="push-guide-container">
        <!-- Header -->
        <div class="push-guide-header">
          <div class="flex items-center gap-2">
            <Bell class="w-5 h-5 push-guide-icon" />
            <span class="font-semibold">알림 허용</span>
          </div>
          <button
            type="button"
            class="push-guide-close-btn"
            @click="dismiss"
            aria-label="닫기"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- Content -->
        <div class="push-guide-content">
          <p class="push-guide-benefit">
            알림을 허용하면<br />
            <strong>근무 일정</strong>과 <strong>새 소식</strong>을 바로 받을 수 있어요!
          </p>

          <!-- Allow Button -->
          <button
            type="button"
            class="push-guide-allow-btn"
            :disabled="isSubscribing"
            @click="handleAllowClick"
          >
            <template v-if="isSubscribing">
              <span class="push-guide-spinner"></span>
              <span>처리 중...</span>
            </template>
            <template v-else>
              <Check class="w-5 h-5" />
              <span>알림 허용하기</span>
            </template>
          </button>
        </div>

        <!-- Footer -->
        <div class="push-guide-footer">
          <button
            type="button"
            class="push-guide-dismiss-btn"
            @click="dismissForDays"
          >
            7일간 보지 않기
          </button>
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.push-guide-backdrop {
  position: fixed;
  inset: 0;
  z-index: 100;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  background-color: rgba(0, 0, 0, 0.5);
  padding: 0.75rem;
  padding-bottom: calc(0.75rem + env(safe-area-inset-bottom));
}

.push-guide-container {
  max-width: 28rem;
  width: 100%;
  background-color: var(--dp-bg-card);
  border: 2px solid var(--dp-accent);
  border-radius: 1.25rem;
  box-shadow:
    0 -8px 32px rgba(59, 130, 246, 0.25),
    0 -2px 16px rgba(0, 0, 0, 0.2),
    0 0 0 1px rgba(255, 255, 255, 0.1) inset;
  overflow: hidden;
}

.dark .push-guide-container {
  box-shadow:
    0 -8px 32px rgba(59, 130, 246, 0.3),
    0 -2px 16px rgba(0, 0, 0, 0.5),
    0 0 0 1px rgba(255, 255, 255, 0.05) inset;
}

.push-guide-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.875rem 1rem;
  background-color: var(--dp-bg-tertiary);
  border-bottom: 1px solid var(--dp-border-primary);
  color: var(--dp-text-primary);
}

.push-guide-icon {
  color: var(--dp-accent);
}

.push-guide-close-btn {
  padding: 0.375rem;
  border-radius: 0.5rem;
  color: var(--dp-text-muted);
  transition: all 0.15s ease;
  cursor: pointer;
}

.push-guide-close-btn:hover {
  background-color: var(--dp-bg-hover);
  color: var(--dp-text-primary);
}

.push-guide-content {
  padding: 1rem;
}

.push-guide-benefit {
  text-align: center;
  color: var(--dp-text-secondary);
  font-size: 0.9375rem;
  line-height: 1.5;
  margin-bottom: 1rem;
}

.push-guide-benefit strong {
  color: var(--dp-accent);
}

.push-guide-allow-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.875rem 1rem;
  background-color: var(--dp-accent);
  color: white;
  font-weight: 600;
  border-radius: 0.75rem;
  transition: all 0.15s ease;
  cursor: pointer;
}

.push-guide-allow-btn:hover:not(:disabled) {
  background-color: var(--dp-accent-hover);
  transform: translateY(-1px);
}

.push-guide-allow-btn:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.push-guide-spinner {
  width: 1.25rem;
  height: 1.25rem;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.push-guide-footer {
  padding: 0.75rem 1rem;
  border-top: 1px solid var(--dp-border-primary);
  text-align: center;
}

.push-guide-dismiss-btn {
  font-size: 0.8125rem;
  color: var(--dp-text-muted);
  padding: 0.375rem 0.75rem;
  border-radius: 0.375rem;
  transition: all 0.15s ease;
  cursor: pointer;
}

.push-guide-dismiss-btn:hover {
  background-color: var(--dp-bg-hover);
  color: var(--dp-text-secondary);
}

/* Transition */
.slide-up-enter-active,
.slide-up-leave-active {
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.slide-up-enter-active .push-guide-container,
.slide-up-leave-active .push-guide-container {
  transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.slide-up-enter-from,
.slide-up-leave-to {
  background-color: rgba(0, 0, 0, 0);
}

.slide-up-enter-from .push-guide-container,
.slide-up-leave-to .push-guide-container {
  transform: translateY(100%);
}
</style>
