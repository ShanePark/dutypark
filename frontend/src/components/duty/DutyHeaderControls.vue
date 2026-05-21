<script setup lang="ts">
import { Search } from 'lucide-vue-next'
import { useI18n } from 'vue-i18n'
import CalendarMonthNavigator from '@/components/common/CalendarMonthNavigator.vue'
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
}>()

const emit = defineEmits<{
  (e: 'prev-month'): void
  (e: 'next-month'): void
  (e: 'open-year-month-picker'): void
  (e: 'search'): void
  (e: 'open-search-modal'): void
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
      <!-- Profile Photo (smaller on mobile) -->
      <ProfileAvatar :member-id="memberId" :has-profile-photo="memberHasProfilePhoto" :profile-photo-version="memberProfilePhotoVersion" size="md" class="flex-shrink-0 sm:hidden" :name="memberName" />
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
    />

    <!-- Right: Search -->
    <div class="flex min-w-0 justify-end">
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
    </div>
  </div>
</template>
