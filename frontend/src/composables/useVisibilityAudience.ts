import { computed, onScopeDispose, ref, shallowRef, watch } from 'vue'
import {
  isRestrictedAudience,
  resolveVisibilityAudience,
  type AudienceFriend,
  type AudienceScope,
  type AudienceVisibility,
} from '@/utils/visibilityAudience'

export interface AudienceSource {
  ownerId: number | null
  visibility: AudienceVisibility
  scope: AudienceScope
}

export interface AudienceSnapshot {
  ownerId: number
  friends: AudienceFriend[]
  calendarVisibility: AudienceVisibility
}

export function useVisibilityAudience(
  source: () => AudienceSource,
  fetchSnapshot: () => Promise<AudienceSnapshot>,
) {
  const status = ref<'idle' | 'loading' | 'ready' | 'error'>('idle')
  const snapshot = shallowRef<AudienceSnapshot | null>(null)
  let generation = 0
  let disposed = false

  function reset() {
    generation++
    snapshot.value = null
    status.value = 'idle'
  }

  const sourceKey = () => {
    const current = source()
    return `${current.ownerId}:${current.visibility}:${current.scope}`
  }
  watch(sourceKey, reset, { flush: 'sync' })
  onScopeDispose(() => { disposed = true; reset() })

  async function load() {
    const current = { ...source() }
    if (disposed || !current.ownerId || !isRestrictedAudience(current.visibility)) {
      reset()
      return
    }
    const requestGeneration = ++generation
    const key = sourceKey()
    const isCurrent = () => !disposed && generation === requestGeneration && sourceKey() === key
    snapshot.value = null
    status.value = 'loading'
    try {
      const result = await fetchSnapshot()
      if (!isCurrent()) return
      if (result.ownerId !== current.ownerId) throw new Error('Audience account changed')
      snapshot.value = result
      status.value = 'ready'
    } catch {
      if (!isCurrent()) return
      snapshot.value = null
      status.value = 'error'
    }
  }

  const members = computed(() => {
    const current = source()
    if (status.value !== 'ready' || !snapshot.value || !current.ownerId) return []
    return resolveVisibilityAudience(snapshot.value.friends, {
      ownerId: current.ownerId,
      visibility: current.visibility,
      scope: current.scope,
      calendarVisibility: snapshot.value.calendarVisibility,
    })
  })

  const calendarRestrictsAudience = computed(() => source().scope === 'schedule'
    && status.value === 'ready'
    && (snapshot.value?.calendarVisibility === 'PRIVATE'
      || (snapshot.value?.calendarVisibility === 'FAMILY' && source().visibility === 'FRIENDS')))

  return { status, members, calendarRestrictsAudience, load, reset }
}
