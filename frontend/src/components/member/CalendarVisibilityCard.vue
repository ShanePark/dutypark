<script setup lang="ts">
import { ref, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { friendApi, memberApi } from '@/api/member'
import { useSwal } from '@/composables/useSwal'
import type { CalendarVisibility, FriendDto } from '@/types'
import { VISIBILITY_COLORS } from '@/utils/visibility'
import BaseModal from '@/components/common/BaseModal.vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import { Eye, Info, Check, X, ChevronRight, Loader2 } from '@lucide/vue'

const props = defineProps<{
  modelValue: CalendarVisibility
}>()

const emit = defineEmits<{
  'update:modelValue': [value: CalendarVisibility]
}>()

const calendarVisibility = computed(() => props.modelValue)

const authStore = useAuthStore()
const { t } = useI18n()
const { showError } = useSwal()

const savingVisibility = ref(false)
const showVisibilityModal = ref(false)
const memberModalPanelStyle = { backgroundColor: 'var(--dp-bg-card)' }

const visibilityLabel = computed(() => {
  const labels: Record<CalendarVisibility, string> = {
    PUBLIC: t('member.visibility.options.public.label'),
    FRIENDS: t('member.visibility.options.friends.label'),
    FAMILY: t('member.visibility.options.family.label'),
    PRIVATE: t('member.visibility.options.private.label'),
  }
  return labels[calendarVisibility.value]
})

interface VisibilityAudience {
  viewers: FriendDto[]
  countLabel: string
  emptyText: string
}

const AUDIENCE_MAX_AVATARS = 5
const AUDIENCE_MAX_NAMES = 3

const audienceFriends = ref<FriendDto[]>([])
const audienceLoading = ref(false)
const audienceLoaded = ref(false)

function openVisibilityModal() {
  showVisibilityModal.value = true
  loadVisibilityAudience()
}

async function loadVisibilityAudience() {
  if (audienceLoading.value) return
  audienceLoading.value = true
  try {
    const response = await friendApi.getFriends()
    audienceFriends.value = response.data
    audienceLoaded.value = true
  } catch (error) {
    console.error('Failed to load visibility audience:', error)
  } finally {
    audienceLoading.value = false
  }
}

function audienceNames(viewers: FriendDto[]): string {
  const names = viewers
    .slice(0, AUDIENCE_MAX_NAMES)
    .map((viewer) => viewer.name)
    .join(t('member.visibility.audience.nameSeparator'))
  const rest = viewers.length - AUDIENCE_MAX_NAMES
  return rest > 0 ? t('member.visibility.audience.moreNames', { names, count: rest }) : names
}

const visibilityOptions = computed<
  {
    value: CalendarVisibility
    label: string
    color: string
    description: string
    audience?: VisibilityAudience
  }[]
>(() => {
  const friends = audienceFriends.value
  const family = friends.filter((friend) => friend.isFamily)
  return [
    {
      value: 'PUBLIC',
      label: t('member.visibility.options.public.label'),
      color: VISIBILITY_COLORS.PUBLIC,
      description: t('member.visibility.options.public.description'),
    },
    {
      value: 'FRIENDS',
      label: t('member.visibility.options.friends.label'),
      color: VISIBILITY_COLORS.FRIENDS,
      description: t('member.visibility.options.friends.description'),
      audience: {
        viewers: friends,
        countLabel: t(
          'member.visibility.audience.friendsCount',
          { count: friends.length },
          friends.length
        ),
        emptyText: t('member.visibility.audience.emptyFriends'),
      },
    },
    {
      value: 'FAMILY',
      label: t('member.visibility.options.family.label'),
      color: VISIBILITY_COLORS.FAMILY,
      description: t('member.visibility.options.family.description'),
      audience: {
        viewers: family,
        countLabel: t(
          'member.visibility.audience.familyCount',
          { count: family.length },
          family.length
        ),
        emptyText: t('member.visibility.audience.emptyFamily'),
      },
    },
    {
      value: 'PRIVATE',
      label: t('member.visibility.options.private.label'),
      color: VISIBILITY_COLORS.PRIVATE,
      description: t('member.visibility.options.private.description'),
    },
  ]
})

const visibilityColorClass = computed(() => VISIBILITY_COLORS[calendarVisibility.value] ?? 'bg-dp-accent')

async function setVisibility(value: CalendarVisibility) {
  if (!authStore.user) return

  savingVisibility.value = true
  try {
    await memberApi.updateVisibility(authStore.user.id, value)
    emit('update:modelValue', value)
    showVisibilityModal.value = false
  } catch (error) {
    console.error('Failed to update visibility:', error)
    showError(t('member.visibility.updateFailed'))
  } finally {
    savingVisibility.value = false
  }
}
</script>

<template>
  <section class="rounded-xl shadow-sm p-6 mb-4 bg-dp-bg-card border border-dp-border-primary">
    <h2 class="text-lg font-semibold mb-4 flex items-center gap-2 text-dp-text-primary">
      <Eye class="w-5 h-5 text-dp-text-secondary" />
      {{ t('member.visibility.sectionTitle') }}
    </h2>
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
      <div>
        <p class="text-dp-text-primary">{{ t('member.visibility.currentLabel') }}</p>
        <p class="text-sm mt-1 text-dp-text-secondary">{{ t('member.visibility.description') }}</p>
      </div>
      <button
        @click="openVisibilityModal"
        class="px-4 py-3 sm:py-2 min-h-11 rounded-lg font-medium flex items-center justify-center gap-2 hover-lift cursor-pointer bg-dp-bg-tertiary text-dp-text-primary"
      >
        <span
          class="w-2 h-2 rounded-full"
          :class="visibilityColorClass"
        ></span>
        {{ visibilityLabel }}
        <ChevronRight class="w-4 h-4" />
      </button>
    </div>
  </section>

  <BaseModal
    :is-open="showVisibilityModal"
    size="md"
    height="fit"
    rounded
    :panel-style="memberModalPanelStyle"
    @close="showVisibilityModal = false"
  >
    <div class="modal-header">
      <h2>{{ t('member.visibility.modalTitle') }}</h2>
      <button @click="showVisibilityModal = false" class="p-1.5 rounded-full hover-close-btn cursor-pointer text-dp-text-muted">
        <X class="w-5 h-5" />
      </button>
    </div>
    <div class="modal-body-form-lg">
      <p class="text-dp-text-secondary">{{ t('member.visibility.modalDescription') }}</p>
      <p class="text-sm text-dp-text-muted">{{ t('member.visibility.modalHint') }}</p>
      <div class="space-y-2">
        <button
          v-for="option in visibilityOptions"
          :key="option.value"
          @click="setVisibility(option.value)"
          :disabled="savingVisibility"
          class="w-full p-4 min-h-16 rounded-lg text-left disabled:opacity-50 disabled:cursor-not-allowed hover-lift cursor-pointer"
          :style="{
            borderWidth: '2px',
            borderColor: calendarVisibility === option.value ? 'var(--dp-accent)' : 'var(--dp-border-primary)',
            backgroundColor: calendarVisibility === option.value ? 'var(--dp-accent-bg)' : 'var(--dp-bg-secondary)'
          }"
        >
          <div class="flex items-center gap-3">
            <span class="w-3 h-3 rounded-full" :class="option.color"></span>
            <span class="font-medium text-dp-text-primary">{{ option.label }}</span>
            <Check
              v-if="calendarVisibility === option.value"
              class="w-5 h-5 text-dp-accent ml-auto"
            />
            <Loader2
              v-if="savingVisibility && calendarVisibility !== option.value"
              class="w-5 h-5 animate-spin ml-auto text-dp-text-muted"
            />
          </div>
          <p class="text-sm mt-1 ml-6 text-dp-text-secondary">{{ option.description }}</p>
          <div v-if="option.audience" class="mt-2.5 ml-6">
            <div v-if="audienceLoading && !audienceLoaded" class="flex items-center min-h-6">
              <Loader2 class="w-4 h-4 animate-spin text-dp-text-muted" />
            </div>
            <template v-else-if="audienceLoaded">
              <div
                v-if="option.audience.viewers.length > 0"
                class="flex items-center gap-2.5"
              >
                <div class="flex shrink-0">
                  <ProfileAvatar
                    v-for="viewer in option.audience.viewers.slice(0, AUDIENCE_MAX_AVATARS)"
                    :key="viewer.id"
                    :member-id="viewer.id"
                    :name="viewer.name"
                    :has-profile-photo="viewer.hasProfilePhoto"
                    :profile-photo-version="viewer.profilePhotoVersion"
                    size="sm"
                    class="audience-avatar"
                    :title="viewer.name"
                  />
                  <span
                    v-if="option.audience.viewers.length > AUDIENCE_MAX_AVATARS"
                    class="audience-avatar audience-overflow-badge w-6 h-6 sm:w-8 sm:h-8 rounded-full flex items-center justify-center text-[10px] sm:text-xs font-semibold"
                  >
                    +{{ option.audience.viewers.length - AUDIENCE_MAX_AVATARS }}
                  </span>
                </div>
                <div class="min-w-0">
                  <p class="text-xs font-medium text-dp-text-primary">
                    {{ option.audience.countLabel }}
                  </p>
                  <p class="text-xs mt-0.5 text-dp-text-muted truncate">
                    {{ audienceNames(option.audience.viewers) }}
                  </p>
                </div>
              </div>
              <p v-else class="flex items-center gap-1.5 text-xs text-dp-warning">
                <Info class="w-3.5 h-3.5 shrink-0" />
                {{ option.audience.emptyText }}
              </p>
            </template>
          </div>
        </button>
      </div>
    </div>
    <div class="modal-actions modal-footer-safe sm:px-6 sm:py-6">
      <button
        @click="showVisibilityModal = false"
        class="w-full px-4 py-3 sm:py-2 min-h-11 rounded-lg font-medium hover-interactive cursor-pointer bg-dp-bg-tertiary text-dp-text-primary"
      >
        {{ t('member.visibility.closeButton') }}
      </button>
    </div>
  </BaseModal>
</template>

<style scoped>
.audience-avatar + .audience-avatar {
  margin-left: -0.375rem;
}

.audience-overflow-badge {
  background-color: var(--dp-bg-tertiary);
  border: 2px solid var(--dp-border-primary);
  color: var(--dp-text-secondary);
}
</style>
