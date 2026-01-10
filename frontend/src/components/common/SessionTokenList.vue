<script setup lang="ts">
import { ref, computed } from 'vue'
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

const expanded = ref(false)

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

  if (diffMins < 1) return '방금 전'
  if (diffMins < 60) return `${diffMins}분 전`
  if (diffHours < 24) return `${diffHours}시간 전`
  if (diffDays < 7) return `${diffDays}일 전`
  return date.toLocaleDateString('ko-KR')
}

function formatDate(dateStr: string | null | undefined): string {
  if (!dateStr) return '-'
  const date = new Date(dateStr)
  if (isNaN(date.getTime())) return '-'
  return date.toLocaleDateString('ko-KR', { year: 'numeric', month: 'short', day: 'numeric' })
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
      <Loader2 class="w-6 h-6 animate-spin text-blue-500" />
    </div>

    <template v-else-if="sortedTokens.length === 0">
      <div class="py-8 text-center text-sm" :style="{ color: 'var(--dp-text-muted)' }">
        세션 정보가 없습니다
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
            class="text-sm rounded-lg p-3"
            :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }"
          >
            <div class="flex items-center justify-between gap-2 mb-2">
              <div class="flex flex-col" :style="{ color: 'var(--dp-text-secondary)' }">
                <div class="flex items-center gap-1">
                  <Clock class="w-4 h-4 flex-shrink-0" :style="{ color: 'var(--dp-text-muted)' }" />
                  <span>{{ formatRelativeTime(token.lastUsed) }}</span>
                </div>
                <span class="text-xs ml-5" :style="{ color: 'var(--dp-text-muted)' }">
                  최초: {{ formatDate(token.createdDate) }}
                </span>
              </div>
              <div class="flex items-center gap-2">
                <!-- Delete button or current login badge -->
                <span v-if="token.isCurrentLogin" class="px-2 py-0.5 text-xs font-medium text-green-700 bg-green-100 rounded-full">
                  현재
                </span>
                <button
                  v-else-if="showDeleteButton"
                  @click="handleDelete(token.id)"
                  class="w-6 h-6 flex items-center justify-center text-red-500 hover:bg-red-100 rounded-full transition cursor-pointer"
                  title="접속 종료"
                >
                  <LogOut class="w-3.5 h-3.5" />
                </button>
                <!-- Expand/Collapse badge (always reserve space when collapsible) -->
                <div v-if="collapsible" class="w-6 h-6 flex items-center justify-center">
                  <button
                    v-if="idx === 0 && hiddenCount > 0"
                    @click="expanded = !expanded"
                    class="w-6 h-6 flex items-center justify-center text-xs font-medium rounded-full cursor-pointer transition"
                    :class="expanded ? 'bg-gray-600 text-white' : 'bg-gray-200 text-gray-600 hover:bg-gray-300'"
                  >
                    {{ expanded ? '-' : `+${hiddenCount}` }}
                  </button>
                </div>
              </div>
            </div>
            <div class="space-y-1">
              <div class="flex items-center gap-2" :style="{ color: 'var(--dp-text-secondary)' }">
                <Globe class="w-4 h-4 flex-shrink-0" :style="{ color: 'var(--dp-text-muted)' }" />
                <span>{{ token.remoteAddr || '-' }}</span>
              </div>
              <div class="flex items-center gap-2" :style="{ color: 'var(--dp-text-secondary)' }">
                <component :is="isDesktopDevice(token.userAgent?.device) ? Monitor : Smartphone" class="w-4 h-4 flex-shrink-0" :style="{ color: 'var(--dp-text-muted)' }" />
                <span>{{ token.userAgent?.device || '-' }}</span>
                <span :style="{ color: 'var(--dp-text-muted)' }">{{ token.userAgent?.browser || '-' }}</span>
              </div>
            </div>
          </div>
        </div>
        <!-- Desktop -->
        <div class="hidden sm:block space-y-2">
          <div
            v-for="(token, idx) in visibleTokens"
            :key="token.id"
            class="grid text-sm rounded-lg p-3 gap-x-2"
            :class="[
              collapsible
                ? (showDeleteButton ? 'grid-cols-[1fr_1fr_1fr_1fr_auto_28px]' : 'grid-cols-[1fr_1fr_1fr_1fr_28px]')
                : (showDeleteButton ? 'grid-cols-[1fr_1fr_1fr_1fr_auto]' : 'grid-cols-[1fr_1fr_1fr_1fr]')
            ]"
            :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }"
          >
            <div class="flex flex-col justify-center" :style="{ color: 'var(--dp-text-secondary)' }">
              <div class="flex items-center gap-1">
                <Clock class="w-4 h-4 flex-shrink-0" :style="{ color: 'var(--dp-text-muted)' }" />
                <span>{{ formatRelativeTime(token.lastUsed) }}</span>
              </div>
              <span class="text-xs ml-5" :style="{ color: 'var(--dp-text-muted)' }">
                최초: {{ formatDate(token.createdDate) }}
              </span>
            </div>
            <div class="flex items-center gap-2" :style="{ color: 'var(--dp-text-secondary)' }">
              <Globe class="w-4 h-4 flex-shrink-0" :style="{ color: 'var(--dp-text-muted)' }" />
              <span class="truncate">{{ token.remoteAddr || '-' }}</span>
            </div>
            <div class="flex items-center gap-2" :style="{ color: 'var(--dp-text-secondary)' }">
              <component :is="isDesktopDevice(token.userAgent?.device) ? Monitor : Smartphone" class="w-4 h-4 flex-shrink-0" :style="{ color: 'var(--dp-text-muted)' }" />
              <span class="truncate">{{ token.userAgent?.device || '-' }}</span>
            </div>
            <div class="truncate flex items-center" :style="{ color: 'var(--dp-text-muted)' }">
              {{ token.userAgent?.browser || '-' }}
            </div>
            <div v-if="showDeleteButton" class="flex items-center justify-end">
              <button
                v-if="!token.isCurrentLogin"
                @click="handleDelete(token.id)"
                class="w-6 h-6 flex items-center justify-center text-red-500 hover:bg-red-100 rounded-full transition cursor-pointer"
                title="접속 종료"
              >
                <LogOut class="w-3.5 h-3.5" />
              </button>
              <span v-else class="px-2 py-0.5 text-xs font-medium text-green-700 bg-green-100 rounded-full">
                현재 접속
              </span>
            </div>
            <!-- Expand/Collapse column (always reserved when collapsible) -->
            <div v-if="collapsible" class="flex items-center justify-end">
              <button
                v-if="idx === 0 && hiddenCount > 0"
                @click="expanded = !expanded"
                class="w-6 h-6 flex items-center justify-center text-xs font-medium rounded-full cursor-pointer transition"
                :class="expanded ? 'bg-gray-600 text-white' : 'bg-gray-200 text-gray-600 hover:bg-gray-300'"
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
            class="p-4 rounded-lg"
            :style="{ backgroundColor: 'var(--dp-bg-secondary)', borderWidth: '1px', borderColor: 'var(--dp-border-primary)' }"
          >
            <div class="flex items-center justify-between mb-3">
              <div class="flex flex-col">
                <span class="text-sm font-medium" :style="{ color: 'var(--dp-text-primary)' }">
                  {{ formatRelativeTime(token.lastUsed) }}
                </span>
                <span class="text-xs" :style="{ color: 'var(--dp-text-muted)' }">
                  최초: {{ formatDate(token.createdDate) }}
                </span>
              </div>
              <span v-if="token.isCurrentLogin" class="px-3 py-1 text-xs font-medium text-green-700 bg-green-100 rounded-full">
                현재 접속
              </span>
              <button
                v-else-if="showDeleteButton"
                @click="handleDelete(token.id)"
                class="w-10 h-10 flex items-center justify-center text-red-500 hover:bg-red-100 rounded-full transition cursor-pointer"
                title="접속 종료"
              >
                <LogOut class="w-5 h-5" />
              </button>
            </div>
            <div class="space-y-2 text-sm">
              <div class="flex items-center gap-2" :style="{ color: 'var(--dp-text-secondary)' }">
                <span class="w-16" :style="{ color: 'var(--dp-text-muted)' }">IP</span>
                <span>{{ token.remoteAddr || '-' }}</span>
              </div>
              <div class="flex items-center gap-2" :style="{ color: 'var(--dp-text-secondary)' }">
                <span class="w-16" :style="{ color: 'var(--dp-text-muted)' }">기기</span>
                <span class="flex items-center gap-1">
                  <component :is="isDesktopDevice(token.userAgent?.device) ? Monitor : Smartphone" class="w-4 h-4" :style="{ color: 'var(--dp-text-muted)' }" />
                  {{ token.userAgent?.device || '-' }}
                </span>
              </div>
              <div class="flex items-center gap-2" :style="{ color: 'var(--dp-text-secondary)' }">
                <span class="w-16" :style="{ color: 'var(--dp-text-muted)' }">브라우저</span>
                <span class="flex items-center gap-1">
                  <Globe class="w-4 h-4" :style="{ color: 'var(--dp-text-muted)' }" />
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
              <tr :style="{ borderBottomWidth: '1px', borderColor: 'var(--dp-border-primary)' }">
                <th class="text-left py-3 px-2 font-medium" :style="{ color: 'var(--dp-text-secondary)' }">최근 접속</th>
                <th class="text-left py-3 px-2 font-medium" :style="{ color: 'var(--dp-text-secondary)' }">최초 로그인</th>
                <th class="text-left py-3 px-2 font-medium" :style="{ color: 'var(--dp-text-secondary)' }">IP</th>
                <th class="text-left py-3 px-2 font-medium" :style="{ color: 'var(--dp-text-secondary)' }">기기</th>
                <th class="text-left py-3 px-2 font-medium" :style="{ color: 'var(--dp-text-secondary)' }">브라우저</th>
                <th v-if="showDeleteButton" class="text-center py-3 px-2 font-medium" :style="{ color: 'var(--dp-text-secondary)' }">관리</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="token in sortedTokens"
                :key="token.id"
                class="hover:opacity-90"
                :style="{ borderBottomWidth: '1px', borderColor: 'var(--dp-border-secondary)' }"
              >
                <td class="py-3 px-2" :style="{ color: 'var(--dp-text-primary)' }">
                  {{ formatRelativeTime(token.lastUsed) }}
                </td>
                <td class="py-3 px-2" :style="{ color: 'var(--dp-text-muted)' }">
                  {{ formatDate(token.createdDate) }}
                </td>
                <td class="py-3 px-2" :style="{ color: 'var(--dp-text-primary)' }">
                  {{ token.remoteAddr || '-' }}
                </td>
                <td class="py-3 px-2">
                  <span class="flex items-center gap-1" :style="{ color: 'var(--dp-text-primary)' }">
                    <component :is="isDesktopDevice(token.userAgent?.device) ? Monitor : Smartphone" class="w-4 h-4" :style="{ color: 'var(--dp-text-muted)' }" />
                    {{ token.userAgent?.device || '-' }}
                  </span>
                </td>
                <td class="py-3 px-2">
                  <span class="flex items-center gap-1" :style="{ color: 'var(--dp-text-primary)' }">
                    <Globe class="w-4 h-4" :style="{ color: 'var(--dp-text-muted)' }" />
                    {{ token.userAgent?.browser || '-' }}
                  </span>
                </td>
                <td v-if="showDeleteButton" class="py-3 px-2 text-center">
                  <button
                    v-if="!token.isCurrentLogin"
                    @click="handleDelete(token.id)"
                    class="w-8 h-8 inline-flex items-center justify-center text-red-500 hover:bg-red-100 rounded-full transition cursor-pointer"
                    title="접속 종료"
                  >
                    <LogOut class="w-4 h-4" />
                  </button>
                  <span v-else class="px-3 py-1 text-xs font-medium text-green-700 bg-green-100 rounded-full">
                    현재 접속
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
