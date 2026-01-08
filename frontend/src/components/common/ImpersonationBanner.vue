<script setup lang="ts">
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useSwal } from '@/composables/useSwal'
import { ArrowLeftCircle, AlertTriangle, Loader2 } from 'lucide-vue-next'

const authStore = useAuthStore()
const { confirm, showError } = useSwal()

const restoring = ref(false)

async function handleRestore() {
  const confirmed = await confirm(
    '원래 계정으로 돌아가시겠습니까?',
    '계정 복귀'
  )

  if (!confirmed) return

  restoring.value = true
  try {
    await authStore.restore()
    window.location.href = '/'
  } catch (error) {
    console.error('Failed to restore account:', error)
    showError('원래 계정으로 복귀하는데 실패했습니다.')
  } finally {
    restoring.value = false
  }
}
</script>

<template>
  <div
    class="impersonation-banner flex items-center justify-between px-4 py-2 sm:py-1.5 fixed top-0 left-0 right-0 z-50"
  >
    <div class="flex items-center gap-2 min-w-0">
      <AlertTriangle class="w-4 h-4 flex-shrink-0 text-amber-800" />
      <span class="text-xs sm:text-sm text-amber-900 truncate">
        <span class="font-semibold">{{ authStore.user?.name }}</span>
        <span class="hidden sm:inline"> 계정으로 활동 중</span>
        <span class="sm:hidden"> 계정</span>
      </span>
    </div>
    <button
      @click="handleRestore"
      :disabled="restoring"
      class="flex items-center gap-1.5 px-3 py-1.5 text-xs sm:text-sm font-medium rounded-lg transition-all duration-150 flex-shrink-0 cursor-pointer impersonation-restore-btn"
    >
      <Loader2 v-if="restoring" class="w-3.5 h-3.5 animate-spin" />
      <ArrowLeftCircle v-else class="w-3.5 h-3.5" />
      <span class="hidden sm:inline">원래 계정으로 돌아가기</span>
      <span class="sm:hidden">복귀</span>
    </button>
  </div>
</template>

<style scoped>
.impersonation-banner {
  background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
  border-bottom: 1px solid #f59e0b;
}

.dark .impersonation-banner {
  background: linear-gradient(135deg, #78350f 0%, #92400e 100%);
  border-bottom: 1px solid #d97706;
}

.dark .impersonation-banner span {
  color: #fef3c7;
}

.dark .impersonation-banner .text-amber-700 {
  color: #fcd34d;
}

.dark .impersonation-banner .text-amber-800,
.dark .impersonation-banner .text-amber-900 {
  color: #fef3c7;
}

.impersonation-restore-btn {
  background-color: rgba(180, 83, 9, 0.15);
  color: #92400e;
  border: 1px solid rgba(180, 83, 9, 0.3);
}

.impersonation-restore-btn:hover:not(:disabled) {
  background-color: rgba(180, 83, 9, 0.25);
  border-color: rgba(180, 83, 9, 0.5);
}

.impersonation-restore-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.dark .impersonation-restore-btn {
  background-color: rgba(254, 243, 199, 0.15);
  color: #fef3c7;
  border: 1px solid rgba(254, 243, 199, 0.3);
}

.dark .impersonation-restore-btn:hover:not(:disabled) {
  background-color: rgba(254, 243, 199, 0.25);
  border-color: rgba(254, 243, 199, 0.5);
}
</style>
