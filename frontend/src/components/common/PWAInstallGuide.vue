<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { X, Share, Download, MoreVertical, Plus, Smartphone, Ellipsis } from 'lucide-vue-next'

const STORAGE_KEY = 'pwa-install-guide-dismissed-until'
const DISMISS_DAYS = 7
const isVisible = ref(false)
const deferredPrompt = ref<BeforeInstallPromptEvent | null>(null)
const forceMode = ref<'ios' | 'android' | null>(null)

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>
}

// Check URL param for dev testing: ?pwa-guide=ios or ?pwa-guide=android
function checkDevMode() {
  const params = new URLSearchParams(window.location.search)
  const mode = params.get('pwa-guide')
  if (mode === 'ios' || mode === 'android') {
    forceMode.value = mode
  }
}

const isIOS = computed(() => {
  if (forceMode.value === 'ios') return true
  if (forceMode.value === 'android') return false
  return /iPad|iPhone|iPod/.test(navigator.userAgent) && !(window as any).MSStream
})

const isAndroid = computed(() => {
  if (forceMode.value === 'android') return true
  if (forceMode.value === 'ios') return false
  return /Android/.test(navigator.userAgent)
})

const isStandalone = computed(() => {
  if (forceMode.value) return false
  return window.matchMedia('(display-mode: standalone)').matches ||
    (window.navigator as any).standalone === true
})

const isMobile = computed(() => {
  return isIOS.value || isAndroid.value
})

const isDismissed = computed(() => {
  if (forceMode.value) return false
  const dismissedUntil = localStorage.getItem(STORAGE_KEY)
  if (!dismissedUntil) return false
  return Date.now() < parseInt(dismissedUntil, 10)
})

const canShowNativePrompt = computed(() => {
  return isAndroid.value && deferredPrompt.value !== null
})

function handleBeforeInstallPrompt(e: Event) {
  e.preventDefault()
  deferredPrompt.value = e as BeforeInstallPromptEvent
}

function checkVisibility() {
  checkDevMode()
  if (isStandalone.value || isDismissed.value || !isMobile.value) {
    isVisible.value = false
    return
  }
  isVisible.value = true
}

async function handleInstallClick() {
  if (canShowNativePrompt.value && deferredPrompt.value) {
    await deferredPrompt.value.prompt()
    const { outcome } = await deferredPrompt.value.userChoice
    if (outcome === 'accepted') {
      isVisible.value = false
    }
    deferredPrompt.value = null
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
  window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
  checkVisibility()
})

onUnmounted(() => {
  window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
})

defineExpose({ checkVisibility })
</script>

<template>
  <Transition name="slide-up">
    <div
      v-if="isVisible"
      class="pwa-guide-backdrop"
      @click.self="dismiss"
    >
      <div class="pwa-guide-container">
        <!-- Header -->
        <div class="pwa-guide-header">
          <div class="flex items-center gap-2">
            <Smartphone class="w-5 h-5 pwa-guide-icon" />
            <span class="font-semibold">앱처럼 사용하기</span>
          </div>
          <button
            type="button"
            class="pwa-guide-close-btn"
            @click="dismiss"
            aria-label="닫기"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- Content -->
        <div class="pwa-guide-content">
          <p class="pwa-guide-benefit">
            홈 화면에 추가하면 앱처럼 사용하고<br />
            <strong>실시간 푸시 알림</strong>을 받을 수 있어요!
          </p>

          <!-- iOS Instructions -->
          <div v-if="isIOS" class="pwa-guide-steps">
            <div class="pwa-guide-step">
              <div class="pwa-guide-step-number">1</div>
              <div class="pwa-guide-step-content">
                <div class="flex items-center gap-2">
                  <span>주소창 옆</span>
                  <span class="pwa-guide-icon-badge">
                    <Ellipsis class="w-4 h-4" />
                  </span>
                  <span>버튼을 탭하세요</span>
                </div>
              </div>
            </div>
            <div class="pwa-guide-step">
              <div class="pwa-guide-step-number">2</div>
              <div class="pwa-guide-step-content">
                <div class="flex items-center gap-2">
                  <span class="pwa-guide-icon-badge">
                    <Share class="w-4 h-4" />
                  </span>
                  <span><strong>공유</strong> 버튼을 탭하세요</span>
                </div>
              </div>
            </div>
            <div class="pwa-guide-step">
              <div class="pwa-guide-step-number">3</div>
              <div class="pwa-guide-step-content">
                <div class="flex items-center gap-2">
                  <span class="pwa-guide-icon-badge">
                    <Plus class="w-4 h-4" />
                  </span>
                  <span><strong>홈 화면에 추가</strong>를 선택하세요</span>
                </div>
              </div>
            </div>
          </div>

          <!-- Android Instructions -->
          <div v-else-if="isAndroid" class="pwa-guide-steps">
            <!-- Native Install Button -->
            <button
              v-if="canShowNativePrompt"
              type="button"
              class="pwa-guide-install-btn"
              @click="handleInstallClick"
            >
              <Download class="w-5 h-5" />
              <span>앱 설치하기</span>
            </button>

            <!-- Manual Instructions -->
            <template v-else>
              <div class="pwa-guide-step">
                <div class="pwa-guide-step-number">1</div>
                <div class="pwa-guide-step-content">
                  <div class="flex items-center gap-2">
                    <span>브라우저 상단의</span>
                    <span class="pwa-guide-icon-badge">
                      <MoreVertical class="w-4 h-4" />
                    </span>
                    <span>메뉴를 탭하세요</span>
                  </div>
                </div>
              </div>
              <div class="pwa-guide-step">
                <div class="pwa-guide-step-number">2</div>
                <div class="pwa-guide-step-content">
                  <div class="flex items-center gap-2">
                    <span class="pwa-guide-icon-badge">
                      <Download class="w-4 h-4" />
                    </span>
                    <span><strong>앱 설치</strong> 또는 <strong>홈 화면에 추가</strong>를 선택하세요</span>
                  </div>
                </div>
              </div>
            </template>
          </div>
        </div>

        <!-- Footer -->
        <div class="pwa-guide-footer">
          <button
            type="button"
            class="pwa-guide-dismiss-btn"
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
.pwa-guide-backdrop {
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

.pwa-guide-container {
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

.dark .pwa-guide-container {
  box-shadow:
    0 -8px 32px rgba(59, 130, 246, 0.3),
    0 -2px 16px rgba(0, 0, 0, 0.5),
    0 0 0 1px rgba(255, 255, 255, 0.05) inset;
}

.pwa-guide-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.875rem 1rem;
  background-color: var(--dp-bg-tertiary);
  border-bottom: 1px solid var(--dp-border-primary);
  color: var(--dp-text-primary);
}

.pwa-guide-icon {
  color: var(--dp-accent);
}

.pwa-guide-close-btn {
  padding: 0.375rem;
  border-radius: 0.5rem;
  color: var(--dp-text-muted);
  transition: all 0.15s ease;
  cursor: pointer;
}

.pwa-guide-close-btn:hover {
  background-color: var(--dp-bg-hover);
  color: var(--dp-text-primary);
}

.pwa-guide-content {
  padding: 1rem;
}

.pwa-guide-benefit {
  text-align: center;
  color: var(--dp-text-secondary);
  font-size: 0.9375rem;
  line-height: 1.5;
  margin-bottom: 1rem;
}

.pwa-guide-benefit strong {
  color: var(--dp-accent);
}

.pwa-guide-steps {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.pwa-guide-step {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem;
  background-color: var(--dp-bg-secondary);
  border-radius: 0.75rem;
}

.pwa-guide-step-number {
  flex-shrink: 0;
  width: 1.5rem;
  height: 1.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: var(--dp-accent);
  color: white;
  font-size: 0.75rem;
  font-weight: 600;
  border-radius: 50%;
}

.pwa-guide-step-content {
  font-size: 0.875rem;
  color: var(--dp-text-secondary);
}

.pwa-guide-step-content strong {
  color: var(--dp-text-primary);
}

.pwa-guide-icon-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0.25rem;
  background-color: var(--dp-bg-tertiary);
  border: 1px solid var(--dp-border-secondary);
  border-radius: 0.375rem;
  color: var(--dp-accent);
}

.pwa-guide-install-btn {
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

.pwa-guide-install-btn:hover {
  background-color: var(--dp-accent-hover);
  transform: translateY(-1px);
}

.pwa-guide-footer {
  padding: 0.75rem 1rem;
  border-top: 1px solid var(--dp-border-primary);
  text-align: center;
}

.pwa-guide-dismiss-btn {
  font-size: 0.8125rem;
  color: var(--dp-text-muted);
  padding: 0.375rem 0.75rem;
  border-radius: 0.375rem;
  transition: all 0.15s ease;
  cursor: pointer;
}

.pwa-guide-dismiss-btn:hover {
  background-color: var(--dp-bg-hover);
  color: var(--dp-text-secondary);
}

/* Transition */
.slide-up-enter-active,
.slide-up-leave-active {
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.slide-up-enter-active .pwa-guide-container,
.slide-up-leave-active .pwa-guide-container {
  transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.slide-up-enter-from,
.slide-up-leave-to {
  background-color: rgba(0, 0, 0, 0);
}

.slide-up-enter-from .pwa-guide-container,
.slide-up-leave-to .pwa-guide-container {
  transform: translateY(100%);
}
</style>
