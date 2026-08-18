<script setup lang="ts">
import { ChevronLeft, Flag, Search, UserX } from 'lucide-vue-next'
import { useI18n } from 'vue-i18n'
import CalendarMonthNavigator from '@/components/common/CalendarMonthNavigator.vue'
import OverflowMenu from '@/components/common/OverflowMenu.vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'

const props = defineProps<{
  memberId: number
  memberName: string
  memberHasProfilePhoto: boolean
  memberProfilePhotoVersion: number
  currentYear: number
  currentMonth: number
  canSearch: boolean
  searchQuery: string
  showBack?: boolean
  showOverflow?: boolean
  showBlock?: boolean
}>()

const emit = defineEmits<{
  (e: 'back'): void
  (e: 'prev-month'): void
  (e: 'next-month'): void
  (e: 'open-year-month-picker'): void
  (e: 'go-to-this-month'): void
  (e: 'search'): void
  (e: 'open-search-modal'): void
  (e: 'report-member'): void
  (e: 'block-member'): void
  (e: 'update:searchQuery', value: string): void
}>()

const { t } = useI18n()

function handleSearchInput(event: Event) {
  emit('update:searchQuery', (event.target as HTMLInputElement).value)
}

function handleSearchClick() {
  if (props.searchQuery.trim()) {
    emit('search')
  } else {
    emit('open-search-modal')
  }
}
</script>

<template>
  <!-- Header: Profile + Year-Month (centered) + Search -->
  <div class="grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center mb-2 px-1 gap-0.5 sm:gap-1">
    <!-- Left: Profile Photo + Name -->
    <div class="flex items-center gap-1.5 min-w-0">
      <!-- Back (only when viewing someone else's calendar) -->
      <button
        v-if="showBack"
        type="button"
        @click="emit('back')"
        :aria-label="t('common.navigation.back')"
        class="calendar-nav-btn flex min-h-11 min-w-11 flex-shrink-0 cursor-pointer items-center justify-center rounded-full p-1 sm:p-2"
      >
        <ChevronLeft class="h-5 w-5 sm:h-6 sm:w-6" />
      </button>
      <!-- Profile Photo (smaller on mobile; dropped when the back button is shown so the name keeps its room) -->
      <ProfileAvatar v-if="!showBack" :member-id="memberId" :has-profile-photo="memberHasProfilePhoto" :profile-photo-version="memberProfilePhotoVersion" size="md" class="flex-shrink-0 sm:hidden" :name="memberName" />
      <ProfileAvatar :member-id="memberId" :has-profile-photo="memberHasProfilePhoto" :profile-photo-version="memberProfilePhotoVersion" size="xl" class="flex-shrink-0 hidden sm:block" :name="memberName" />
      <!-- Name -->
      <span
        class="text-xs sm:text-sm font-semibold truncate text-dp-text-primary"
      >{{ memberName }}</span>
    </div>

    <!-- Center: Year-Month Navigation -->
    <CalendarMonthNavigator
      :current-year="currentYear"
      :current-month="currentMonth"
      @prev-month="emit('prev-month')"
      @next-month="emit('next-month')"
      @open-year-month-picker="emit('open-year-month-picker')"
      @go-to-this-month="emit('go-to-this-month')"
    />

    <!-- Right: Search + overflow menu -->
    <div class="flex min-w-0 items-center justify-end gap-0.5 sm:gap-1">
      <div
        v-if="canSearch"
        class="flex min-h-[42px] min-w-0 w-full max-w-[8.5rem] items-stretch overflow-hidden rounded-lg border border-dp-border-secondary bg-dp-bg-card transition-colors focus-within:border-dp-accent sm:min-h-[44px] sm:max-w-[10rem] sm:rounded-xl sm:shadow-sm"
      >
        <input
          :value="searchQuery"
          type="text"
          :placeholder="t('duty.header.searchPlaceholder')"
          @input="handleSearchInput"
          @keyup.enter="emit('search')"
          class="min-w-0 w-0 flex-1 border-none bg-dp-bg-input px-2 text-[13px] text-dp-text-primary placeholder:text-dp-text-muted focus:outline-none sm:px-2.5 sm:text-sm"
        />
        <button
          type="button"
          @click="handleSearchClick"
          :aria-label="t('common.actions.search')"
          class="flex min-h-[42px] min-w-[42px] shrink-0 items-center justify-center border-l border-dp-search-action-border bg-dp-search-action px-2.5 text-dp-search-action-text transition-colors hover:bg-dp-search-action-hover cursor-pointer sm:min-h-[44px] sm:min-w-[44px] sm:px-3"
        >
          <Search class="h-[15px] w-[15px] sm:h-4 sm:w-4" />
        </button>
      </div>

      <OverflowMenu v-if="showOverflow" :menu-label="t('report.actions.menu')">
        <button
          type="button"
          class="flex w-full min-h-11 cursor-pointer items-center gap-2.5 px-4 py-2.5 text-left text-sm text-dp-text-primary transition hover:bg-dp-bg-hover"
          role="menuitem"
          @click="emit('report-member')"
        >
          <Flag class="h-4 w-4 flex-shrink-0" />
          {{ t('report.actions.reportMember') }}
        </button>
        <button
          v-if="showBlock"
          type="button"
          class="flex w-full min-h-11 cursor-pointer items-center gap-2.5 px-4 py-2.5 text-left text-sm text-dp-danger transition hover:bg-dp-danger-soft"
          role="menuitem"
          @click="emit('block-member')"
        >
          <UserX class="h-4 w-4 flex-shrink-0" />
          {{ t('report.actions.blockMember') }}
        </button>
      </OverflowMenu>
    </div>
  </div>
</template>
