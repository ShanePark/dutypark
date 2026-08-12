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
  let requestSequence = 0

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
  }

  async function loadForMember(nextMemberId: number, force = false) {
    if (memberId.value !== nextMemberId) {
      reset(nextMemberId)
    } else if (consent.value && !force) {
      return consent.value
    }

    const sequence = ++requestSequence
    isLoading.value = true
    loadFailed.value = false
    try {
      const response = await aiScheduleParsingConsentApi.getCurrent()
      if (memberId.value === nextMemberId && requestSequence === sequence) {
        consent.value = response
      }
      return response
    } catch (error) {
      if (memberId.value === nextMemberId && requestSequence === sequence) {
        loadFailed.value = true
      }
      throw error
    } finally {
      if (memberId.value === nextMemberId && requestSequence === sequence) {
        isLoading.value = false
      }
    }
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
      if (memberId.value === nextMemberId) consent.value = response
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
      if (memberId.value === nextMemberId) consent.value = response
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
    grant,
    revoke,
  }
})
