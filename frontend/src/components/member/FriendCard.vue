<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { Home, Star, GripVertical, MoreVertical } from 'lucide-vue-next'
import type { DashboardFriendDetail } from '@/types'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'

defineProps<{
  friend: DashboardFriendDetail
}>()

const emit = defineEmits<{
  select: []
  pin: []
  unpin: []
  openMenu: [memberId: number, event: Event]
}>()

const { t } = useI18n()
</script>

<template>
  <!-- Sortable reads .pinned-friend children and their data-member-id to persist the pin order. -->
  <div
    :data-member-id="friend.member.id"
    class="friend-card relative overflow-hidden rounded-xl sm:rounded-2xl cursor-pointer"
    :class="[
      friend.pinOrder
        ? 'pinned-friend pinned-friend-highlight border-2 shadow-md'
        : 'border hover:border-dp-accent-border'
    ]"
    :style="!friend.pinOrder ? { backgroundColor: 'var(--dp-bg-card)', borderColor: 'var(--dp-border-primary)' } : {}"
    @click="emit('select')"
  >
    <div class="flex p-3">
      <div class="flex-shrink-0 mr-3">
        <ProfileAvatar
          :member-id="friend.member.id"
          :name="friend.member.name"
          :has-profile-photo="friend.member.hasProfilePhoto"
          :profile-photo-version="friend.member.profilePhotoVersion"
          size="xl"
        />
      </div>

      <div class="flex-1 min-w-0">
        <div class="flex items-center justify-between mb-1.5">
          <div class="flex items-center gap-1.5 min-w-0">
            <span class="font-medium text-sm truncate text-dp-text-primary">{{ friend.member.name }}</span>
            <Home v-if="friend.isFamily" class="w-3.5 h-3.5 flex-shrink-0 text-dp-warning" :title="t('friends.labels.familyMember')" />
          </div>
          <div class="flex items-center flex-shrink-0" @click.stop>
            <button
              v-if="friend.pinOrder"
              class="p-1 text-dp-warning hover:text-dp-warning transition cursor-pointer"
              @click.stop="emit('unpin')"
              :title="t('friends.actions.unpin')"
            >
              <Star class="w-4 h-4" fill="currentColor" />
            </button>
            <button
              v-else
              class="p-1 text-dp-text-muted hover:text-dp-warning transition cursor-pointer"
              @click.stop="emit('pin')"
              :title="t('friends.actions.pin')"
            >
              <Star class="w-4 h-4" />
            </button>
            <button
              v-if="friend.member.id"
              class="p-1.5 rounded-lg transition hover:bg-opacity-80 cursor-pointer text-dp-text-muted"
              @click="emit('openMenu', friend.member.id, $event)"
            >
              <MoreVertical class="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="friend.pinOrder" class="absolute bottom-2 right-2" @click.stop>
      <div
        class="handle friend-drag-handle rounded-lg p-1.5 transition hover:bg-dp-overlay-dark/10 !cursor-grab active:!cursor-grabbing"
        :title="t('friends.actions.dragToReorder')"
      >
        <GripVertical class="w-4 h-4" />
      </div>
    </div>
  </div>
</template>
