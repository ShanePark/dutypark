import { computed, ref } from 'vue'

export type LoginAttempt = 'PASSWORD' | 'KAKAO' | 'NAVER' | 'APPLE'

export function useLoginAttemptGate() {
  const activeAttempt = ref<LoginAttempt | null>(null)
  const isAttemptPending = computed(() => activeAttempt.value !== null)

  function startAttempt(attempt: LoginAttempt): boolean {
    if (activeAttempt.value !== null) return false
    activeAttempt.value = attempt
    return true
  }

  function finishAttempt(attempt: LoginAttempt) {
    if (activeAttempt.value === attempt) {
      activeAttempt.value = null
    }
  }

  return {
    activeAttempt,
    isAttemptPending,
    startAttempt,
    finishAttempt,
  }
}
