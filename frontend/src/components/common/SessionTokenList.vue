<script setup lang="ts">
import { ref, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import type { RefreshTokenDto } from '@/types'
import {
  Clock,
  Monitor,
  Globe,
  Smartphone,
  Loader2,
  LogOut,
} from 'lucide-vue-next'

const props = withDefaults(defineProps<{
  tokens: RefreshTokenDto[]
  loading?: boolean
  showDeleteButton?: boolean
  compact?: boolean
  collapsible?: boolean
}>(), {
  loading: false,
  showDeleteButton: true,
  compact: false,
  collapsible: false,
})

const emit = defineEmits<{
  delete: [tokenId: number]
}>()

const { locale, t } = useI18n()
const expanded = ref(false)

const compactDateFormatter = computed(() => {
  return new Intl.DateTimeFormat(locale.value, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  })
})

const fullDateFormatter = computed(() => {
  return new Intl.DateTimeFormat(locale.value)
})

const relativeTimeFormatter = computed(() => {
  return new Intl.RelativeTimeFormat(locale.value, { numeric: 'auto' })
})

const sortedTokens = computed(() => {
  return [...props.tokens].sort((a, b) => {
    if (a.isCurrentLogin) return -1
    if (b.isCurrentLogin) return 1
    const aTime = a.lastUsed ? new Date(a.lastUsed).getTime() : 0
    const bTime = b.lastUsed ? new Date(b.lastUsed).getTime() : 0
    return bTime - aTime
  })
})

const visibleTokens = computed(() => {
  if (!props.collapsible || expanded.value) {
    return sortedTokens.value
  }
  return sortedTokens.value.slice(0, 1)
})

const hiddenCount = computed(() => {
  if (!props.collapsible) return 0
  return sortedTokens.value.length - 1
})

function formatRelativeTime(dateStr: string | null): string {
  if (!dateStr) return '-'

  const date = new Date(dateStr)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffMins = Math.floor(diffMs / 60000)
  const diffHours = Math.floor(diffMs / 3600000)
  const diffDays = Math.floor(diffMs / 86400000)

  if (diffMins < 1) return t('common.relativeTime.justNow')
  if (diffMins < 60) return relativeTimeFormatter.value.format(-diffMins, 'minute')
  if (diffHours < 24) return relativeTimeFormatter.value.format(-diffHours, 'hour')
  if (diffDays < 7) return relativeTimeFormatter.value.format(-diffDays, 'day')
  return fullDateFormatter.value.format(date)
}

function formatDate(dateStr: string | null | undefined): string {
  if (!dateStr) return '-'
  const date = new Date(dateStr)
  if (isNaN(date.getTime())) return '-'
  return compactDateFormatter.value.format(date)
}

function isDesktopDevice(device: string | undefined): boolean {
  return device === 'Other'
}

function handleDelete(tokenId: number) {
  emit('delete', tokenId)
}
</script>

<template>
  <div>
    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center py-8">
      <Loader2 class="w-6 h-6 animate-spin text-dp-accent" />
    </div>

    <template v-else-if="sortedTokens.length === 0">
      <div class="py-8 text-center text-sm text-dp-text-muted">
        {{ t('member.sessions.empty') }}
      </div>
    </template>

    <template v-else>
      <!-- Compact Mode -->
      <template v-if="compact">
        <!-- Mobile -->
        <div class="sm:hidden space-y-2">
          <div
            v-for="(token, idx) in visibleTokens"
            :key="token.id"
            class="text-sm rounded-lg p-3 bg-dp-bg-tertiary"
          >
            <div class="flex items-center justify-between gap-2 mb-2">
              <div class="flex flex-col text-dp-text-secondary">
                <div class="flex items-center gap-1">
                  <Clock class="w-4 h-4 flex-shrink-0 text-dp-text-muted" />
                  <span>{{ formatRelativeTime(token.lastUsed) }}</span>
                </div>
                <span class="text-xs ml-5 text-dp-text-muted">
                  {{ t('member.sessions.createdAt') }}: {{ formatDate(token.createdDate) }}
                </span>
              </div>
              <div class="flex items-center gap-2">
                <!-- Delete button or current login badge -->
                <span v-if="token.isCurrentLogin" class="px-2 py-0.5 text-xs font-medium text-dp-success bg-dp-success-soft rounded-full">
                  {{ t('member.sessions.current') }}
                </span>
                <button
                  v-else-if="showDeleteButton"
                  @click="handleDelete(token.id)"
                  class="w-6 h-6 flex items-center justify-center text-dp-danger hover:bg-dp-danger-soft rounded-full transition cursor-pointer"
                  :title="t('member.sessions.terminate')"
                >
                  <LogOut class="w-3.5 h-3.5" />
                </button>
                <!-- Expand/Collapse badge (always reserve space when collapsible) -->
                <div v-if="collapsible" class="w-6 h-6 flex items-center justify-center">
                  <button
                    v-if="idx === 0 && hiddenCount > 0"
                    @click="expanded = !expanded"
                    class="w-6 h-6 flex items-center justify-center text-xs font-medium rounded-full cursor-pointer transition"
                    :class="expanded ? 'bg-dp-surface-strong text-dp-text-on-dark' : 'bg-dp-bg-tertiary text-dp-text-secondary hover:bg-dp-bg-tertiary'"
                  >
                    {{ expanded ? '-' : `+${hiddenCount}` }}
                  </button>
                </div>
              </div>
            </div>
            <div class="space-y-1">
              <div class="flex items-center gap-2 text-dp-text-secondary">
                <Globe class="w-4 h-4 flex-shrink-0 text-dp-text-muted" />
                <span>{{ token.remoteAddr || '-' }}</span>
              </div>
              <div class="flex items-center gap-2 text-dp-text-secondary">
                <component :is="isDesktopDevice(token.userAgent?.device) ? Monitor : Smartphone" class="w-4 h-4 flex-shrink-0 text-dp-text-muted" />
                <span>{{ token.userAgent?.device || '-' }}</span>
                <span class="text-dp-text-muted">{{ token.userAgent?.browser || '-' }}</span>
              </div>
            </div>
          </div>
        </div>
        <!-- Desktop -->
        <div class="hidden sm:block space-y-2">
          <div
            v-for="(token, idx) in visibleTokens"
            :key="token.id"
            class="grid text-sm rounded-lg p-3 gap-x-2 bg-dp-bg-tertiary"
            :class="[
              collapsible
                ? (showDeleteButton ? 'grid-cols-[1fr_1fr_1fr_1fr_auto_28px]' : 'grid-cols-[1fr_1fr_1fr_1fr_28px]')
                : (showDeleteButton ? 'grid-cols-[1fr_1fr_1fr_1fr_auto]' : 'grid-cols-[1fr_1fr_1fr_1fr]')
            ]"
          >
            <div class="flex flex-col justify-center text-dp-text-secondary">
              <div class="flex items-center gap-1">
                <Clock class="w-4 h-4 flex-shrink-0 text-dp-text-muted" />
                <span>{{ formatRelativeTime(token.lastUsed) }}</span>
              </div>
                <span class="text-xs ml-5 text-dp-text-muted">
                  {{ t('member.sessions.createdAt') }}: {{ formatDate(token.createdDate) }}
                </span>
              </div>
            <div class="flex items-center gap-2 text-dp-text-secondary">
              <Globe class="w-4 h-4 flex-shrink-0 text-dp-text-muted" />
              <span class="truncate">{{ token.remoteAddr || '-' }}</span>
            </div>
            <div class="flex items-center gap-2 text-dp-text-secondary">
              <component :is="isDesktopDevice(token.userAgent?.device) ? Monitor : Smartphone" class="w-4 h-4 flex-shrink-0 text-dp-text-muted" />
              <span class="truncate">{{ token.userAgent?.device || '-' }}</span>
            </div>
            <div class="truncate flex items-center text-dp-text-muted">
              {{ token.userAgent?.browser || '-' }}
            </div>
            <div v-if="showDeleteButton" class="flex items-center justify-end">
              <button
                v-if="!token.isCurrentLogin"
                @click="handleDelete(token.id)"
                class="w-6 h-6 flex items-center justify-center text-dp-danger hover:bg-dp-danger-soft rounded-full transition cursor-pointer"
                :title="t('member.sessions.terminate')"
              >
                <LogOut class="w-3.5 h-3.5" />
              </button>
              <span v-else class="px-2 py-0.5 text-xs font-medium text-dp-success bg-dp-success-soft rounded-full">
                {{ t('member.sessions.currentLogin') }}
              </span>
            </div>
            <!-- Expand/Collapse column (always reserved when collapsible) -->
            <div v-if="collapsible" class="flex items-center justify-end">
              <button
                v-if="idx === 0 && hiddenCount > 0"
                @click="expanded = !expanded"
                class="w-6 h-6 flex items-center justify-center text-xs font-medium rounded-full cursor-pointer transition"
                :class="expanded ? 'bg-dp-surface-strong text-dp-text-on-dark' : 'bg-dp-bg-tertiary text-dp-text-secondary hover:bg-dp-bg-tertiary'"
              >
                {{ expanded ? '-' : `+${hiddenCount}` }}
              </button>
            </div>
          </div>
        </div>
      </template>

      <!-- Full Mode (with table headers) -->
      <template v-else>
        <!-- Mobile -->
        <div class="sm:hidden space-y-3">
          <div
            v-for="token in sortedTokens"
            :key="token.id"
            class="p-4 rounded-lg bg-dp-bg-secondary border border-dp-border-primary"
          >
            <div class="flex items-center justify-between mb-3">
              <div class="flex flex-col">
                <span class="text-sm font-medium text-dp-text-primary">
                  {{ formatRelativeTime(token.lastUsed) }}
                </span>
                <span class="text-xs text-dp-text-muted">
                  {{ t('member.sessions.createdAt') }}: {{ formatDate(token.createdDate) }}
                </span>
              </div>
              <span v-if="token.isCurrentLogin" class="px-3 py-1 text-xs font-medium text-dp-success bg-dp-success-soft rounded-full">
                {{ t('member.sessions.currentLogin') }}
              </span>
              <button
                v-else-if="showDeleteButton"
                @click="handleDelete(token.id)"
                class="w-10 h-10 flex items-center justify-center text-dp-danger hover:bg-dp-danger-soft rounded-full transition cursor-pointer"
                :title="t('member.sessions.terminate')"
              >
                <LogOut class="w-5 h-5" />
              </button>
            </div>
            <div class="space-y-2 text-sm">
              <div class="flex items-center gap-2 text-dp-text-secondary">
                <span class="w-16 text-dp-text-muted">{{ t('member.sessions.ipLabel') }}</span>
                <span>{{ token.remoteAddr || '-' }}</span>
              </div>
              <div class="flex items-center gap-2 text-dp-text-secondary">
                <span class="w-16 text-dp-text-muted">{{ t('member.sessions.deviceLabel') }}</span>
                <span class="flex items-center gap-1">
                  <component :is="isDesktopDevice(token.userAgent?.device) ? Monitor : Smartphone" class="w-4 h-4 text-dp-text-muted" />
                  {{ token.userAgent?.device || '-' }}
                </span>
              </div>
              <div class="flex items-center gap-2 text-dp-text-secondary">
                <span class="w-16 text-dp-text-muted">{{ t('member.sessions.browserLabel') }}</span>
                <span class="flex items-center gap-1">
                  <Globe class="w-4 h-4 text-dp-text-muted" />
                  {{ token.userAgent?.browser || '-' }}
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Desktop -->
        <div class="hidden sm:block overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-dp-border-primary">
                <th class="text-left py-3 px-2 font-medium text-dp-text-secondary">{{ t('member.sessions.recentAccess') }}</th>
                <th class="text-left py-3 px-2 font-medium text-dp-text-secondary">{{ t('member.sessions.firstLogin') }}</th>
                <th class="text-left py-3 px-2 font-medium text-dp-text-secondary">{{ t('member.sessions.ipLabel') }}</th>
                <th class="text-left py-3 px-2 font-medium text-dp-text-secondary">{{ t('member.sessions.deviceLabel') }}</th>
                <th class="text-left py-3 px-2 font-medium text-dp-text-secondary">{{ t('member.sessions.browserLabel') }}</th>
                <th v-if="showDeleteButton" class="text-center py-3 px-2 font-medium text-dp-text-secondary">{{ t('member.sessions.manageLabel') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="token in sortedTokens"
                :key="token.id"
                class="hover:opacity-90 border-b border-dp-border-secondary"
              >
                <td class="py-3 px-2 text-dp-text-primary">
                  {{ formatRelativeTime(token.lastUsed) }}
                </td>
                <td class="py-3 px-2 text-dp-text-muted">
                  {{ formatDate(token.createdDate) }}
                </td>
                <td class="py-3 px-2 text-dp-text-primary">
                  {{ token.remoteAddr || '-' }}
                </td>
                <td class="py-3 px-2">
                  <span class="flex items-center gap-1 text-dp-text-primary">
                    <component :is="isDesktopDevice(token.userAgent?.device) ? Monitor : Smartphone" class="w-4 h-4 text-dp-text-muted" />
                    {{ token.userAgent?.device || '-' }}
                  </span>
                </td>
                <td class="py-3 px-2">
                  <span class="flex items-center gap-1 text-dp-text-primary">
                    <Globe class="w-4 h-4 text-dp-text-muted" />
                    {{ token.userAgent?.browser || '-' }}
                  </span>
                </td>
                <td v-if="showDeleteButton" class="py-3 px-2 text-center">
                  <button
                    v-if="!token.isCurrentLogin"
                    @click="handleDelete(token.id)"
                    class="w-8 h-8 inline-flex items-center justify-center text-dp-danger hover:bg-dp-danger-soft rounded-full transition cursor-pointer"
                    :title="t('member.sessions.terminate')"
                  >
                    <LogOut class="w-4 h-4" />
                  </button>
                  <span v-else class="px-3 py-1 text-xs font-medium text-dp-success bg-dp-success-soft rounded-full">
                    {{ t('member.sessions.currentLogin') }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </template>
  </div>
</template>
