<script setup lang="ts">
import { ref, watch, toRef } from 'vue'
import { useSwal } from '@/composables/useSwal'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
import { teamApi } from '@/api/team'
import { X, Loader2 } from 'lucide-vue-next'

const props = defineProps<{
  isOpen: boolean
  teamId: number
  saving: boolean
}>()

const emit = defineEmits<{
  close: []
  'update:saving': [boolean]
}>()

const { showWarning, showError, toastSuccess } = useSwal()
const isOpenRef = toRef(props, 'isOpen')

useBodyScrollLock(isOpenRef)
useEscapeKey(isOpenRef, () => emit('close'))

const batchForm = ref({
  file: null as File | null,
  year: new Date().getFullYear(),
  month: new Date().getMonth() + 1,
})

watch(() => props.isOpen, (open) => {
  if (!open) return
  batchForm.value = {
    file: null,
    year: new Date().getFullYear(),
    month: new Date().getMonth() + 1,
  }
})

function close() {
  emit('close')
}

function handleFileChange(event: Event) {
  const target = event.target as HTMLInputElement
  if (target.files && target.files[0]) {
    batchForm.value.file = target.files[0]
  }
}

async function uploadBatch() {
  if (!batchForm.value.file) {
    showWarning('파일을 선택해주세요.')
    return
  }

  emit('update:saving', true)
  try {
    const result = await teamApi.uploadDutyBatch(
      props.teamId,
      batchForm.value.file,
      batchForm.value.year,
      batchForm.value.month
    )
    if (result.data.success) {
      toastSuccess('근무표가 업로드되었습니다.')
      close()
    } else {
      showError(result.data.message || '근무표 업로드에 실패했습니다.')
    }
  } catch (error: any) {
    console.error('Failed to upload batch:', error)
    const message = error.response?.data?.message || '근무표 업로드에 실패했습니다.'
    showError(message)
  } finally {
    emit('update:saving', false)
  }
}
</script>

<template>
  <div
    v-if="isOpen"
    class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
    @click.self="close"
  >
    <div class="rounded-lg shadow-xl w-full max-w-md" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
      <div class="flex items-center justify-between p-4 border-b" :style="{ borderColor: 'var(--dp-border-primary)' }">
        <h3 class="text-lg font-bold" :style="{ color: 'var(--dp-text-primary)' }">근무표 업로드</h3>
        <button
          @click="close"
          class="p-1.5 rounded-full hover-close-btn cursor-pointer"
        >
          <X class="w-5 h-5" />
        </button>
      </div>

      <div class="p-4 space-y-4">
        <div>
          <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
            근무표 파일 업로드 (.xlsx)
          </label>
          <input
            type="file"
            accept=".xlsx"
            @change="handleFileChange"
            class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            :style="{ backgroundColor: 'var(--dp-bg-input)', borderColor: 'var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
          />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
              연도
            </label>
            <input
              v-model.number="batchForm.year"
              type="number"
              :min="new Date().getFullYear()"
              :max="new Date().getFullYear() + 1"
              class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              :style="{ backgroundColor: 'var(--dp-bg-input)', borderColor: 'var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
            />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
              월
            </label>
            <input
              v-model.number="batchForm.month"
              type="number"
              min="1"
              max="12"
              class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              :style="{ backgroundColor: 'var(--dp-bg-input)', borderColor: 'var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
            />
          </div>
        </div>
      </div>

      <div class="flex justify-end gap-2 p-4 border-t" :style="{ borderColor: 'var(--dp-border-primary)' }">
        <button
          @click="uploadBatch"
          :disabled="saving || !batchForm.file"
          class="px-4 py-2 bg-blue-500 text-white rounded-lg font-medium hover:bg-blue-600 transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
        >
          <Loader2 v-if="saving" class="w-4 h-4 animate-spin" />
          업로드
        </button>
        <button
          @click="close"
          class="px-4 py-2 rounded-lg font-medium hover-interactive cursor-pointer"
          :style="{ backgroundColor: 'var(--dp-bg-tertiary)', color: 'var(--dp-text-secondary)' }"
        >
          취소
        </button>
      </div>
    </div>
  </div>
</template>
