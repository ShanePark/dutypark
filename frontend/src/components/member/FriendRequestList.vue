<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { UserCheck, UserPlus, Home } from 'lucide-vue-next'
import type { DashboardFriendRequestDto } from '@/types'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'

const props = defineProps<{
  requestsTo: DashboardFriendRequestDto[]
  requestsFrom: DashboardFriendRequestDto[]
}>()

const emit = defineEmits<{
  accept: [request: DashboardFriendRequestDto]
  reject: [request: DashboardFriendRequestDto]
  cancel: [request: DashboardFriendRequestDto]
}>()

const { t } = useI18n()

const hasPendingRequests = computed(
  () => props.requestsTo.length > 0 || props.requestsFrom.length > 0,
)

function getRequestTypeLabel(requestType: string) {
  return requestType === 'FAMILY_REQUEST'
    ? t('friends.labels.familyRequest')
    : t('friends.labels.friendRequest')
}
</script>

<template>
  <div
    v-if="hasPendingRequests"
    class="rounded-2xl shadow-sm border mb-6 overflow-hidden bg-dp-bg-card border-dp-border-primary"
  >
    <div class="bg-gradient-to-r from-dp-warning to-dp-warning-hover px-5 py-3">
      <div class="flex items-center gap-2">
        <UserCheck class="w-5 h-5 text-dp-text-on-dark" />
        <span class="text-dp-text-on-dark font-bold">{{ t('friends.sections.requests') }}</span>
        <span class="ml-2 px-2 py-0.5 bg-dp-overlay-light/20 rounded-full text-xs text-dp-text-on-dark">
          {{ requestsTo.length + requestsFrom.length }}
        </span>
      </div>
    </div>
    <div class="p-4 space-y-3">
      <div
        v-for="req in requestsTo"
        :key="'to-' + req.fromMember.id"
        class="p-4 rounded-xl friend-request-received"
      >
        <div class="flex justify-between items-center">
          <div class="font-medium flex items-center gap-3 friend-request-name">
            <div class="relative">
              <ProfileAvatar
                :member-id="req.fromMember.id"
                :has-profile-photo="req.fromMember.hasProfilePhoto"
                :profile-photo-version="req.fromMember.profilePhotoVersion"
                size="md"
              />
              <div class="absolute -bottom-0.5 -right-0.5 w-5 h-5 rounded-full flex items-center justify-center ring-2 ring-dp-overlay-light" :class="req.requestType === 'FAMILY_REQUEST' ? 'bg-dp-warning' : 'bg-dp-accent'">
                <Home v-if="req.requestType === 'FAMILY_REQUEST'" class="w-3 h-3 text-dp-text-on-dark" />
                <UserPlus v-else class="w-3 h-3 text-dp-text-on-dark" />
              </div>
            </div>
            <div>
              <p class="text-dp-text-primary">{{ req.fromMember.name }}</p>
              <p class="text-xs text-dp-text-secondary">
                {{ getRequestTypeLabel(req.requestType) }}
              </p>
            </div>
          </div>
          <div class="flex gap-2">
            <button
              class="px-4 py-2 text-sm font-medium bg-dp-success text-dp-text-on-dark rounded-lg hover:bg-dp-success-hover transition shadow-sm cursor-pointer"
              @click="emit('accept', req)"
            >
              {{ t('friends.actions.approve') }}
            </button>
            <button
              class="px-4 py-2 text-sm font-medium border border-dp-danger-border rounded-lg hover:bg-dp-danger-soft transition cursor-pointer bg-dp-bg-card text-dp-danger"
              @click="emit('reject', req)"
            >
              {{ t('friends.actions.reject') }}
            </button>
          </div>
        </div>
      </div>

      <div
        v-for="req in requestsFrom"
        :key="'from-' + req.toMember.id"
        class="p-4 rounded-xl friend-request-sent"
      >
        <div class="flex justify-between items-center">
          <div class="font-medium flex items-center gap-3 friend-request-name">
            <div class="relative">
              <ProfileAvatar
                :member-id="req.toMember.id"
                :has-profile-photo="req.toMember.hasProfilePhoto"
                :profile-photo-version="req.toMember.profilePhotoVersion"
                size="md"
              />
              <div class="absolute -bottom-0.5 -right-0.5 w-5 h-5 rounded-full flex items-center justify-center bg-dp-warning ring-2 ring-dp-overlay-light">
                <Home v-if="req.requestType === 'FAMILY_REQUEST'" class="w-3 h-3 text-dp-text-on-dark" />
                <UserPlus v-else class="w-3 h-3 text-dp-text-on-dark" />
              </div>
            </div>
            <div>
              <p class="text-dp-text-primary">{{ req.toMember.name }}</p>
              <p class="text-xs text-dp-text-secondary">
                {{ t('friends.labels.sentRequestStatus', { type: getRequestTypeLabel(req.requestType) }) }}
              </p>
            </div>
          </div>
          <button
            class="px-4 py-2 text-sm font-medium border border-dp-warning-border rounded-lg hover:bg-dp-warning-soft transition cursor-pointer bg-dp-bg-card text-dp-warning-hover"
            @click="emit('cancel', req)"
          >
            {{ t('friends.actions.cancelRequest') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
