<script setup lang="ts">
import { ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import BaseModal from '@/components/common/BaseModal.vue'
import { useSwal } from '@/composables/useSwal'
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
const { t } = useI18n()

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
    showWarning(t('team.batchUpload.selectFile'))
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
      toastSuccess(t('team.batchUpload.success'))
      close()
    } else {
      showError(result.data.message || t('team.batchUpload.failed'))
    }
  } catch (error: any) {
    console.error('Failed to upload batch:', error)
    const message = error.response?.data?.message || t('team.batchUpload.failed')
    showError(message)
  } finally {
    emit('update:saving', false)
  }
}
</script>

<template>
  <BaseModal
    :is-open="isOpen"
    size="md"
    height="fit"
    @close="close"
  >
    <div class="modal-header">
      <h2>{{ t('team.batchUpload.title') }}</h2>
      <button
        @click="close"
        class="p-1.5 rounded-full hover-close-btn cursor-pointer"
        :aria-label="t('common.actions.close')"
      >
        <X class="w-5 h-5" />
      </button>
    </div>

    <div class="modal-body-form">
      <div>
        <label class="form-label">
          {{ t('team.batchUpload.fileLabel') }}
        </label>
        <input
          type="file"
          accept=".xlsx"
          @change="handleFileChange"
          class="form-control"
        />
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label class="form-label">
            {{ t('team.batchUpload.year') }}
          </label>
          <input
            v-model.number="batchForm.year"
            type="number"
            :min="new Date().getFullYear()"
            :max="new Date().getFullYear() + 1"
            class="form-control"
          />
        </div>
        <div>
          <label class="form-label">
            {{ t('team.batchUpload.month') }}
          </label>
          <input
            v-model.number="batchForm.month"
            type="number"
            min="1"
            max="12"
            class="form-control"
          />
        </div>
      </div>
    </div>

    <div class="modal-actions modal-actions-end modal-footer-safe">
      <button
        @click="uploadBatch"
        :disabled="saving || !batchForm.file"
        class="px-4 py-2 bg-dp-accent text-dp-text-on-dark rounded-lg font-medium hover:bg-dp-accent-hover transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2 cursor-pointer"
      >
        <Loader2 v-if="saving" class="w-4 h-4 animate-spin" />
        {{ t('common.actions.upload') }}
      </button>
      <button
        @click="close"
        class="px-4 py-2 rounded-lg font-medium hover-interactive cursor-pointer bg-dp-bg-tertiary text-dp-text-secondary"
      >
        {{ t('common.actions.cancel') }}
      </button>
    </div>
  </BaseModal>
</template>
