<script setup lang="ts">
import { ref, watch, toRef } from 'vue'
import { ChevronLeft, ChevronRight } from 'lucide-vue-next'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'

const props = defineProps<{
  isOpen: boolean
  currentYear: number
  currentMonth: number
}>()

const emit = defineEmits<{
  close: []
  select: [year: number, month: number]
  goToThisMonth: []
}>()

const pickerYear = ref(props.currentYear)
const monthNames = ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월']

useBodyScrollLock(toRef(props, 'isOpen'))
useEscapeKey(toRef(props, 'isOpen'), () => emit('close'))

// Sync pickerYear when modal opens
watch(() => props.isOpen, (open) => {
  if (open) {
    pickerYear.value = props.currentYear
  }
})

function selectYearMonth(month: number) {
  emit('select', pickerYear.value, month)
}

function handleGoToThisMonth() {
  emit('goToThisMonth')
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-2 sm:p-4"
      @click.self="emit('close')"
    >
      <div
        class="rounded-xl shadow-xl w-full max-w-[95vw] sm:max-w-sm mx-2 sm:mx-4"
        :style="{
          backgroundColor: 'var(--dp-bg-modal)',
          border: '1px solid var(--dp-border-primary)',
        }"
      >
        <!-- Year Navigation -->
        <div
          class="flex items-center justify-between p-3 sm:p-4 border-b"
          :style="{ borderColor: 'var(--dp-border-primary)' }"
        >
          <button
            @click="pickerYear--"
            class="calendar-nav-btn p-2 rounded-full cursor-pointer"
          >
            <ChevronLeft class="w-6 h-6 sm:w-5 sm:h-5" />
          </button>
          <span class="text-xl font-bold" :style="{ color: 'var(--dp-text-primary)' }">{{ pickerYear }}년</span>
          <button
            @click="pickerYear++"
            class="calendar-nav-btn p-2 rounded-full cursor-pointer"
          >
            <ChevronRight class="w-6 h-6 sm:w-5 sm:h-5" />
          </button>
        </div>

        <!-- Month Grid -->
        <div class="p-3 sm:p-4">
          <div class="grid grid-cols-4 gap-1.5 sm:gap-2">
            <button
              v-for="(name, idx) in monthNames"
              :key="idx"
              @click="selectYearMonth(idx + 1)"
              class="py-2.5 sm:py-3 px-1.5 sm:px-2 rounded-lg text-sm font-medium transition cursor-pointer"
              :class="
                pickerYear === currentYear && idx + 1 === currentMonth
                  ? 'bg-blue-600 text-white'
                  : 'month-btn'
              "
              :style="
                pickerYear === currentYear && idx + 1 === currentMonth
                  ? {}
                  : { color: 'var(--dp-text-secondary)' }
              "
            >
              {{ name }}
            </button>
          </div>
        </div>

        <!-- Buttons -->
        <div class="p-3 sm:p-4 border-t flex flex-row gap-2" :style="{ borderColor: 'var(--dp-border-primary)' }">
          <button
            @click="handleGoToThisMonth"
            class="flex-[3] px-3 sm:px-4 py-2 bg-indigo-500 hover:bg-indigo-600 rounded-lg text-white font-medium transition text-sm cursor-pointer"
          >
            이번달 ({{ new Date().getFullYear() }}년{{ new Date().getMonth() + 1 }}월)
          </button>
          <button
            @click="emit('close')"
            class="close-btn flex-1 px-3 sm:px-4 py-2 rounded-lg font-medium transition text-sm cursor-pointer"
            :style="{ backgroundColor: 'var(--dp-bg-tertiary)', color: 'var(--dp-text-secondary)' }"
          >
            닫기
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
