<script setup lang="ts">
import { computed, nextTick, ref, useId, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { ChevronDown, House, Info, Loader2, Search, Users } from '@lucide/vue'
import { friendApi, memberApi } from '@/api/member'
import { useAuthStore } from '@/stores/auth'
import { useVisibilityAudience } from '@/composables/useVisibilityAudience'
import { isRestrictedAudience, searchVisibilityAudience, type AudienceScope, type AudienceVisibility } from '@/utils/visibilityAudience'
import messages from '@/i18n/messages/visibilityAudience'
import ProfileAvatar from './ProfileAvatar.vue'

const props = withDefaults(defineProps<{
  visibility: AudienceVisibility
  scope?: AudienceScope
}>(), { scope: 'calendar' })
const { t, locale } = useI18n({ useScope: 'local', messages })
const auth = useAuthStore()
const id = useId()
const isOpen = ref(false)
const toggleButton = ref<HTMLButtonElement | null>(null)
const query = ref('')
const isAvailable = computed(() => !!auth.user?.id && isRestrictedAudience(props.visibility))
const title = computed(() => t(props.visibility === 'FAMILY' ? 'familyTitle' : 'friendsTitle'))
const Icon = computed(() => props.visibility === 'FAMILY' ? House : Users)
const audience = useVisibilityAudience(
  () => ({ ownerId: auth.user?.id ?? null, visibility: props.visibility, scope: props.scope }),
  async () => {
    const [friends, member] = await Promise.all([friendApi.getFriends(), memberApi.getMyInfo()])
    if (member.data.id === null) throw new Error('Audience owner unavailable')
    return { ownerId: member.data.id, friends: friends.data, calendarVisibility: member.data.calendarVisibility }
  },
)
const visibleMembers = computed(() => searchVisibilityAudience(audience.members.value, query.value, locale.value))

watch(() => [props.visibility, props.scope, auth.user?.id], () => {
  isOpen.value = false
  query.value = ''
}, { flush: 'sync' })

async function toggle() {
  isOpen.value = !isOpen.value
  query.value = ''
  if (!isOpen.value) {
    audience.reset()
    return
  }
  await audience.load()
  await nextTick()
  // Keep the roster discoverable when the disclosure sits below the fold in a small modal.
  if (isOpen.value && typeof toggleButton.value?.scrollIntoView === 'function') {
    toggleButton.value.scrollIntoView({
      block: 'start',
      behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth',
    })
  }
}
</script>

<template>
  <section v-if="isAvailable" class="audience-preview" :class="{ 'audience-preview--family': visibility === 'FAMILY' }">
    <button
      ref="toggleButton" :id="`${id}-trigger`" type="button" class="audience-preview__trigger"
      :aria-expanded="isOpen" :aria-controls="`${id}-panel`" @click.stop="toggle"
    >
      <component :is="Icon" class="audience-preview__icon" aria-hidden="true" />
      <span class="audience-preview__trigger-label">{{ isOpen ? t('close') : t('open') }}</span>
      <Loader2 v-if="audience.status.value === 'loading'" class="audience-preview__spinner" aria-hidden="true" />
      <span v-if="audience.status.value === 'ready'" class="audience-preview__count">{{ t('count', { count: audience.members.value.length }) }}</span>
      <ChevronDown class="audience-preview__chevron" :class="{ 'audience-preview__chevron--open': isOpen }" aria-hidden="true" />
    </button>
    <div v-if="isOpen" :id="`${id}-panel`" role="region" :aria-labelledby="`${id}-trigger`" class="audience-preview__panel" :aria-busy="audience.status.value === 'loading'">
      <h3 class="audience-preview__title">{{ title }}</h3>
      <p class="audience-preview__description">{{ t(visibility === 'FAMILY' ? 'familyDescription' : 'friendsDescription') }}</p>
      <p v-if="audience.status.value === 'loading'" role="status" class="audience-preview__state">
        <Loader2 class="audience-preview__spinner" aria-hidden="true" />{{ t('loading') }}
      </p>
      <div v-else-if="audience.status.value === 'error'" role="alert" class="audience-preview__state audience-preview__state--error">
        <p>{{ t('error') }}</p>
        <button type="button" class="audience-preview__retry" @click.stop="audience.load()">{{ t('retry') }}</button>
      </div>
      <template v-else-if="audience.status.value === 'ready'">
        <p v-if="audience.calendarRestrictsAudience.value" class="audience-preview__notice">
          <Info class="audience-preview__icon" aria-hidden="true" />{{ t('restricted') }}
        </p>
        <div v-if="audience.members.value.length >= 8" class="audience-preview__search">
          <Search class="audience-preview__icon" aria-hidden="true" />
          <input v-model="query" type="search" :aria-label="t('search')" :placeholder="t('search')" autocomplete="off" />
        </div>
        <p v-if="query.trim()" role="status" class="audience-preview__description">{{ t('resultCount', { count: visibleMembers.length, total: audience.members.value.length }) }}</p>
        <ul v-if="visibleMembers.length" class="audience-preview__list" :aria-label="title">
          <li v-for="person in visibleMembers" :key="person.id!" class="audience-preview__person">
            <ProfileAvatar :member-id="person.id" :name="person.name" :has-profile-photo="person.hasProfilePhoto" :profile-photo-version="person.profilePhotoVersion" size="sm" />
            <span class="audience-preview__name">{{ person.name }}</span>
            <span class="audience-preview__relationship" :class="{ 'audience-preview__relationship--family': person.isFamily }">{{ t(person.isFamily ? 'family' : 'friend') }}</span>
          </li>
        </ul>
        <p v-else class="audience-preview__state">{{ t(query.trim() ? 'noResults' : 'empty') }}</p>
      </template>
      <div class="audience-preview__footnote">
        <p>{{ t('readOnly') }}</p>
        <p>{{ t('relationshipNote') }}</p>
        <p>{{ t(scope === 'schedule' ? 'scheduleNote' : 'calendarNote') }}</p>
      </div>
    </div>
  </section>
</template>

<style scoped>
.audience-preview { --audience-accent: var(--dp-text-primary); border: 1px solid var(--dp-border-primary); border-radius: .75rem; background: var(--dp-bg-card); overflow: hidden; }
.audience-preview__trigger > .audience-preview__icon { color: var(--dp-accent); }
.audience-preview__trigger { display: flex; align-items: center; gap: .625rem; width: 100%; min-height: 44px; padding: .625rem .875rem; color: var(--audience-accent); text-align: left; cursor: pointer; }
.audience-preview__trigger-label { flex: 1; font-size: .875rem; font-weight: 600; }
.audience-preview__icon, .audience-preview__chevron, .audience-preview__spinner { width: 1rem; height: 1rem; flex-shrink: 0; }
.audience-preview__chevron { transition: transform .15s ease; }
.audience-preview__chevron--open { transform: rotate(180deg); }
.audience-preview__count { font-size: .75rem; font-variant-numeric: tabular-nums; padding: .125rem .5rem; border-radius: 999px; background: var(--dp-bg-tertiary); color: var(--dp-text-secondary); }
.audience-preview__panel { padding: .875rem; border-top: 1px solid var(--dp-border-primary); }
.audience-preview__title { font-size: .9375rem; font-weight: 700; color: var(--dp-text-primary); }
.audience-preview__description { margin-top: .375rem; font-size: .8125rem; line-height: 1.6; color: var(--dp-text-secondary); }
.audience-preview__state { display: flex; align-items: center; justify-content: center; gap: .5rem; min-height: 88px; padding: 1rem .5rem; font-size: .875rem; line-height: 1.6; color: var(--dp-text-secondary); text-align: center; }
.audience-preview__state--error { flex-direction: column; }
.audience-preview__spinner { animation: audience-spin 1s linear infinite; }
.audience-preview__retry { min-height: 44px; padding: .5rem 1rem; border: 1px solid var(--dp-border-primary); border-radius: .5rem; font-weight: 600; color: var(--audience-accent); cursor: pointer; }
.audience-preview__notice { display: flex; align-items: flex-start; gap: .5rem; margin-top: .75rem; padding: .75rem; border-radius: .5rem; background: var(--dp-bg-tertiary); font-size: .8125rem; line-height: 1.6; color: var(--dp-text-secondary); }
.audience-preview__notice .audience-preview__icon { margin-top: .125rem; }
.audience-preview__search { display: flex; align-items: center; gap: .5rem; margin-top: .75rem; padding: 0 .75rem; border: 1px solid var(--dp-border-primary); border-radius: .5rem; color: var(--dp-text-muted); background: var(--dp-bg-input, var(--dp-bg-card)); }
.audience-preview__search input { min-width: 0; width: 100%; min-height: 44px; background: transparent; color: var(--dp-text-primary); font-size: 1rem; outline: none; }
.audience-preview__list { max-height: 15rem; overflow-y: auto; overscroll-behavior: contain; margin-top: .75rem; scrollbar-gutter: stable; }
.audience-preview__person { display: flex; align-items: center; gap: .75rem; min-height: 52px; padding: .5rem .25rem; }
.audience-preview__person + .audience-preview__person { border-top: 1px solid var(--dp-border-primary); }
.audience-preview__name { flex: 1; min-width: 0; overflow-wrap: anywhere; font-size: .875rem; line-height: 1.5; color: var(--dp-text-primary); }
.audience-preview__relationship { flex-shrink: 0; border-radius: 999px; padding: .125rem .5rem; font-size: .75rem; background: var(--dp-bg-tertiary); color: var(--dp-text-secondary); }
.audience-preview__relationship--family { color: var(--dp-text-primary); font-weight: 600; }
.audience-preview__footnote { display: grid; gap: .375rem; margin-top: .75rem; padding-top: .75rem; border-top: 1px solid var(--dp-border-primary); font-size: .75rem; line-height: 1.65; color: var(--dp-text-secondary); }
.audience-preview__trigger:focus-visible, .audience-preview__retry:focus-visible { outline: 2px solid var(--dp-accent); outline-offset: -3px; }
.audience-preview__search:focus-within { outline: 2px solid var(--dp-accent); outline-offset: 2px; }
@media (hover: hover) { .audience-preview__trigger:hover, .audience-preview__retry:hover { background: var(--dp-bg-hover); } }
@keyframes audience-spin { to { transform: rotate(360deg); } }
@media (prefers-reduced-motion: reduce) { .audience-preview__chevron { transition: none; } .audience-preview__spinner { animation: none; } }
</style>
