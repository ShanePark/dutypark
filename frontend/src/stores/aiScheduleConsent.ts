import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import {
  aiScheduleParsingConsentApi,
  type AiScheduleParsingConsentDto,
} from '@/api/consent'

export const useAiScheduleConsentStore = defineStore('aiScheduleConsent', () => {
  const memberId = ref<number | null>(null)
  const consent = ref<AiScheduleParsingConsentDto | null>(null)
  const isLoading = ref(false)
  const isSaving = ref(false)
  const loadFailed = ref(false)
  const lastSuccessfulAt = ref<number | null>(null)
  let requestSequence = 0
  let inFlightLoad: {
    memberId: number
    promise: Promise<AiScheduleParsingConsentDto>
  } | null = null

  const isCurrent = computed(() =>
    consent.value?.consented === true && consent.value.needsRenewal === false,
  )

  function reset(nextMemberId: number | null = null) {
    requestSequence += 1
    memberId.value = nextMemberId
    consent.value = null
    isLoading.value = false
    isSaving.value = false
    loadFailed.value = false
    lastSuccessfulAt.value = null
    inFlightLoad = null
  }

  function loadForMember(
    nextMemberId: number,
    force = false,
  ): Promise<AiScheduleParsingConsentDto> {
    if (memberId.value !== nextMemberId) {
      reset(nextMemberId)
    }

    if (inFlightLoad?.memberId === nextMemberId) return inFlightLoad.promise
    if (consent.value && !force) return Promise.resolve(consent.value)

    const sequence = ++requestSequence
    isLoading.value = true
    loadFailed.value = false
    const promise: Promise<AiScheduleParsingConsentDto> = aiScheduleParsingConsentApi.getCurrent()
      .then((response) => {
        if (memberId.value === nextMemberId && requestSequence === sequence) {
          consent.value = response
          lastSuccessfulAt.value = Date.now()
        }
        return response
      })
      .catch((error: unknown) => {
        if (memberId.value === nextMemberId && requestSequence === sequence) {
          loadFailed.value = true
        }
        throw error
      })
      .finally(() => {
        if (inFlightLoad?.promise === promise) inFlightLoad = null
        if (memberId.value === nextMemberId && requestSequence === sequence) {
          isLoading.value = false
        }
      })

    inFlightLoad = { memberId: nextMemberId, promise }
    return promise
  }

  function refreshIfStaleForMember(
    nextMemberId: number,
    minimumIntervalMs: number,
  ): Promise<AiScheduleParsingConsentDto> {
    const freshnessWindow = Math.max(0, minimumIntervalMs)
    const cachedConsent = consent.value
    const isFresh = memberId.value === nextMemberId
      && cachedConsent !== null
      && lastSuccessfulAt.value !== null
      && Date.now() - lastSuccessfulAt.value < freshnessWindow

    if (isFresh && cachedConsent) return Promise.resolve(cachedConsent)
    return loadForMember(nextMemberId, true)
  }

  async function grant(nextMemberId: number) {
    if (memberId.value !== nextMemberId) {
      await loadForMember(nextMemberId)
    }
    const version = consent.value?.policy.version
    if (!version) throw new Error('AI schedule parsing policy is unavailable')

    isSaving.value = true
    try {
      const response = await aiScheduleParsingConsentApi.grant(version)
      if (memberId.value === nextMemberId) {
        consent.value = response
        lastSuccessfulAt.value = Date.now()
        loadFailed.value = false
      }
      return response
    } finally {
      if (memberId.value === nextMemberId) isSaving.value = false
    }
  }

  async function revoke(nextMemberId: number) {
    if (memberId.value !== nextMemberId) reset(nextMemberId)
    isSaving.value = true
    try {
      const response = await aiScheduleParsingConsentApi.revoke()
      if (memberId.value === nextMemberId) {
        consent.value = response
        lastSuccessfulAt.value = Date.now()
        loadFailed.value = false
      }
      return response
    } finally {
      if (memberId.value === nextMemberId) isSaving.value = false
    }
  }

  return {
    memberId,
    consent,
    isLoading,
    isSaving,
    loadFailed,
    isCurrent,
    reset,
    loadForMember,
    refreshIfStaleForMember,
    grant,
    revoke,
  }
})
