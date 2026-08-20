<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { Info, X } from 'lucide-vue-next'
import BaseModal from '@/components/common/BaseModal.vue'

// Screens supply their own blocks — HelpSection for the explanations, HelpNote for
// the closing aside — and the panel owns everything around them, so two help panels
// can never drift apart in header, sizing or body spacing.
defineProps<{
  isOpen: boolean
  title: string
}>()

const emit = defineEmits<{
  close: []
}>()

const { t } = useI18n()
</script>

<template>
  <BaseModal
    :is-open="isOpen"
    size="lg"
    height="default"
    rounded
    overlay-class="backdrop-blur-sm"
    panel-class="border border-dp-border-primary"
    :panel-style="{ backgroundColor: 'var(--dp-bg-card)' }"
    @close="emit('close')"
  >
    <div class="modal-header">
      <h2 class="help-modal-title">
        <Info class="help-modal-title-icon" />
        {{ title }}
      </h2>
      <button
        class="p-2 rounded-full hover-close-btn cursor-pointer text-dp-text-muted"
        :aria-label="t('common.actions.close')"
        @click="emit('close')"
      >
        <X class="w-5 h-5" />
      </button>
    </div>
    <div class="help-modal-body">
      <slot />
    </div>
  </BaseModal>
</template>

<style scoped>
.help-modal-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.help-modal-title-icon {
  width: 1.25rem;
  height: 1.25rem;
  flex-shrink: 0;
  color: var(--dp-accent);
}

/* Mirrors .modal-body-form-lg, but spaces the blocks with a gap instead of the
   utility's sibling margins: the blocks arrive through the slot, so the panel has to
   own the rhythm between them. */
.help-modal-body {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  flex: 1 1 0%;
  min-height: 0;
  max-height: 580px;
  overflow-y: auto;
  padding: 1rem;
}

@media (min-width: 640px) {
  .help-modal-body {
    padding: 1.5rem;
  }
}
</style>
