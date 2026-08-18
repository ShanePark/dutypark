<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { Ban } from 'lucide-vue-next'
import type { BlockedMember } from '@/types/block'
import { formatDateNumeric } from '@/utils/date'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'

withDefaults(
  defineProps<{
    members: BlockedMember[]
    loading?: boolean
    loadFailed?: boolean
    unblockingId?: number | null
  }>(),
  { loading: false, loadFailed: false, unblockingId: null },
)

const emit = defineEmits<{
  unblock: [member: BlockedMember]
  retry: []
}>()

const { t } = useI18n()
</script>

<template>
  <div class="rounded-2xl shadow-sm border overflow-hidden bg-dp-bg-card border-dp-border-primary">
    <div class="bg-gradient-to-r from-dp-surface-strong to-dp-surface-strong-alt px-6 py-3">
      <div class="flex items-center gap-2">
        <Ban class="w-5 h-5 text-dp-text-on-dark" />
        <span class="text-dp-text-on-dark font-bold">{{ t('friends.block.sectionTitle') }}</span>
        <span v-if="!loadFailed" class="ml-2 px-2 py-0.5 bg-dp-overlay-light/20 rounded-full text-xs text-dp-text-on-dark">
          {{ members.length }}
        </span>
      </div>
    </div>
    <div class="p-5">
      <div v-if="loading" class="flex justify-center py-6">
        <div class="w-6 h-6 border-3 rounded-full animate-spin" :style="{ borderColor: 'var(--dp-border-secondary)', borderTopColor: 'var(--dp-text-primary)' }"></div>
      </div>

      <!-- A failed load must never look like "nothing is blocked", so it gets its own state with a retry. -->
      <div v-else-if="loadFailed" class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 py-2">
        <p class="text-sm text-dp-text-secondary">{{ t('friends.messages.loadFailed') }}</p>
        <button
          type="button"
          class="min-h-11 px-4 py-2 rounded-lg font-medium cursor-pointer hover-lift bg-dp-bg-tertiary text-dp-text-primary"
          @click="emit('retry')"
        >
          {{ t('common.actions.retry') }}
        </button>
      </div>

      <!-- The section stays visible with an empty state so blocking is always discoverable and reversible. -->
      <div v-else-if="members.length === 0" class="text-center py-8">
        <Ban class="w-12 h-12 mx-auto mb-3 text-dp-text-muted" />
        <p class="text-sm text-dp-text-secondary">{{ t('friends.block.empty') }}</p>
      </div>

      <div v-else class="space-y-2">
        <div
          v-for="member in members"
          :key="member.id"
          class="flex items-center gap-3 p-3 rounded-xl border border-dp-border-primary"
        >
          <ProfileAvatar
            :member-id="member.id"
            :name="member.name"
            :has-profile-photo="member.hasProfilePhoto"
            :profile-photo-version="member.profilePhotoVersion"
            size="md"
          />
          <div class="flex-1 min-w-0">
            <p class="font-medium text-sm truncate text-dp-text-primary">{{ member.name }}</p>
            <p class="text-xs text-dp-text-secondary">
              {{ t('friends.block.blockedAt', { date: formatDateNumeric(member.blockedAt) }) }}
            </p>
          </div>
          <button
            class="flex-shrink-0 px-3 py-2 text-sm font-medium border border-dp-border-secondary rounded-lg hover:bg-dp-bg-hover transition cursor-pointer bg-dp-bg-card text-dp-text-primary disabled:opacity-50 disabled:cursor-not-allowed"
            :disabled="unblockingId === member.id"
            @click="emit('unblock', member)"
          >
            {{ t('friends.block.unblockAction') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
