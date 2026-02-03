<script setup lang="ts">
import { ChevronLeft, ChevronRight, Search } from 'lucide-vue-next'
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
  <div class="grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center mb-2 px-1 gap-1">
    <!-- Left: Profile Photo + Name -->
    <div class="flex items-center gap-1.5 min-w-0">
      <!-- Profile Photo (smaller on mobile) -->
      <ProfileAvatar :member-id="memberId" :has-profile-photo="memberHasProfilePhoto" :profile-photo-version="memberProfilePhotoVersion" size="lg" class="flex-shrink-0 sm:hidden" :name="memberName" />
      <ProfileAvatar :member-id="memberId" :has-profile-photo="memberHasProfilePhoto" :profile-photo-version="memberProfilePhotoVersion" size="xl" class="flex-shrink-0 hidden sm:block" :name="memberName" />
      <!-- Name -->
      <span
        class="text-xs sm:text-sm font-semibold truncate"
        :style="{ color: 'var(--dp-text-primary)' }"
      >{{ memberName }}</span>
    </div>

    <!-- Center: Year-Month Navigation -->
    <div class="flex items-center justify-center">
      <button @click="emit('prev-month')" class="calendar-nav-btn p-0.5 sm:p-2 rounded-full flex items-center justify-center flex-shrink-0 cursor-pointer">
        <ChevronLeft class="w-5 h-5 sm:w-6 sm:h-6" />
      </button>
      <button
        @click="emit('open-year-month-picker')"
        class="calendar-nav-btn px-1 sm:px-3 py-1 text-lg sm:text-2xl font-semibold rounded whitespace-nowrap cursor-pointer"
      >
        {{ currentYear }}-{{ String(currentMonth).padStart(2, '0') }}
      </button>
      <button @click="emit('next-month')" class="calendar-nav-btn p-0.5 sm:p-2 rounded-full flex items-center justify-center flex-shrink-0 cursor-pointer">
        <ChevronRight class="w-5 h-5 sm:w-6 sm:h-6" />
      </button>
    </div>

    <!-- Right: Search -->
    <div class="flex justify-end">
      <div v-if="canSearch" class="flex items-stretch rounded-lg border overflow-hidden" :style="{ borderColor: 'var(--dp-border-secondary)' }">
        <input
          :value="searchQuery"
          type="text"
          placeholder="검색"
          @input="handleSearchInput"
          @keyup.enter="emit('search')"
          class="px-2 py-1.5 text-sm focus:ring-2 focus:ring-blue-500 focus:outline-none w-12 sm:w-20 border-none"
          :style="{ backgroundColor: 'var(--dp-bg-input)', color: 'var(--dp-text-primary)' }"
        />
        <button
          @click="handleSearchClick"
          class="px-2 py-1.5 bg-gray-800 text-white hover:bg-gray-700 transition flex items-center justify-center cursor-pointer"
        >
          <Search class="w-4 h-4" />
        </button>
      </div>
    </div>
  </div>
</template>
