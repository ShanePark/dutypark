<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { Home, SlidersHorizontal } from '@lucide/vue'
import type { DashboardFriendDetail } from '@/types'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'

defineProps<{
  friend: DashboardFriendDetail
}>()

const emit = defineEmits<{
  select: []
  openMenu: [memberId: number, event: Event]
}>()

const { t } = useI18n()
</script>

<template>
  <!-- Sortable uses every friend card and its member id to persist the complete order. -->
  <div
    :data-member-id="friend.member.id"
    class="friend-card flex min-h-[72px] select-none items-stretch border-b border-dp-border-secondary touch-manipulation"
  >
    <button
      type="button"
      class="friend-card-calendar flex min-w-0 flex-1 items-center gap-3 px-4 py-3 text-left focus-visible:z-10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-dp-accent-ring cursor-pointer"
      :aria-label="t('friends.actions.openCalendar', { name: friend.member.name })"
      @click.stop="emit('select')"
    >
      <ProfileAvatar
        :member-id="friend.member.id"
        :name="friend.member.name"
        :has-profile-photo="friend.member.hasProfilePhoto"
        :profile-photo-version="friend.member.profilePhotoVersion"
        size="xl"
        class="!h-11 !w-11"
      />

      <div class="min-w-0 flex-1">
        <div class="flex min-w-0 items-center gap-1.5">
          <span class="min-w-0 truncate text-sm font-semibold text-dp-text-primary">{{ friend.member.name }}</span>
          <Home
            v-if="friend.isFamily"
            class="h-3.5 w-3.5 flex-shrink-0 text-dp-warning"
            :title="t('friends.labels.familyMember')"
          />
        </div>
      </div>
    </button>

    <button
      v-if="friend.member.id"
      type="button"
      class="friend-card-action mr-3 h-11 w-11 shrink-0 self-center rounded-lg text-dp-text-secondary transition hover:bg-dp-bg-tertiary hover:text-dp-text-primary focus-visible:z-10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-dp-accent-ring cursor-pointer"
      :aria-label="t('friends.actions.manageFriend', { name: friend.member.name })"
      :title="t('friends.actions.manageFriend', { name: friend.member.name })"
      @click.stop="emit('openMenu', friend.member.id, $event)"
    >
      <SlidersHorizontal class="h-6 w-6" aria-hidden="true" />
    </button>
  </div>
</template>
