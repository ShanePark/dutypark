<script setup lang="ts">
import BaseModal from '@/components/common/BaseModal.vue'
import { useI18n } from 'vue-i18n'

const props = defineProps<{
  isOpen: boolean
}>()

const emit = defineEmits<{
  close: []
  confirm: []
}>()

const { t } = useI18n()

function close() {
  emit('close')
}

function confirm() {
  emit('confirm')
}
</script>

<template>
  <BaseModal
    :is-open="props.isOpen"
    size="sm"
    height="fit"
    rounded
    z-index="detail"
    panel-class="max-w-[340px] min-w-[280px] border border-dp-border-primary"
    @close="close"
  >
    <div class="overflow-hidden">
      <div class="modal-header-compact">
        <h2 class="text-sm font-semibold text-dp-text-primary">{{ t('duty.untagConfirm.title') }}</h2>
      </div>
      <div class="modal-body-form-compact">
        <p class="text-sm text-dp-text-secondary">
          {{ t('duty.untagConfirm.message') }}
        </p>
        <div
          class="p-3 rounded-lg text-xs space-y-1 bg-dp-bg-secondary text-dp-text-muted"
        >
          <p>{{ t('duty.untagConfirm.warning1') }}</p>
          <p>{{ t('duty.untagConfirm.warning2') }}</p>
        </div>
      </div>
      <div class="modal-actions modal-actions-center modal-footer-safe pt-0">
        <button
          @click="confirm"
        class="px-5 py-2 bg-dp-warning hover:bg-dp-warning-hover text-dp-text-on-dark rounded-lg text-sm font-medium transition-all duration-200 hover:-translate-y-px cursor-pointer"
        style="box-shadow: var(--dp-shadow-md), var(--dp-shadow-sm);"
      >
          {{ t('duty.untagConfirm.action') }}
        </button>
        <button
          @click="close"
          class="px-5 py-2 rounded-lg text-sm font-medium transition-all duration-200 border hover:-translate-y-px cursor-pointer"
          :style="{
            backgroundColor: 'var(--dp-bg-card)',
            color: 'var(--dp-text-secondary)',
            borderColor: 'var(--dp-border-primary)',
            boxShadow: 'var(--dp-shadow-sm)'
          }"
        >
          {{ t('common.actions.cancel') }}
        </button>
      </div>
    </div>
  </BaseModal>
</template>
