<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { Check, Info, Loader2, Trash2, X } from 'lucide-vue-next'
import BaseModal from '@/components/common/BaseModal.vue'
import type { SocialAccountProvider } from '@/api/member'

const props = defineProps<{
  isOpen: boolean
  provider: SocialAccountProvider
  providerLabel: string
  providerIcon: string
  canUnlink: boolean
  busy: boolean
}>()

const emit = defineEmits<{
  close: []
  unlink: []
}>()

const { t } = useI18n()
const closeButton = ref<HTMLButtonElement | null>(null)
const idSuffix = computed(() => props.provider.toLowerCase())
const titleId = computed(() => `social-account-modal-title-${idSuffix.value}`)
const descriptionId = computed(() => `social-account-modal-description-${idSuffix.value}`)
const restrictionId = computed(() => `social-account-modal-restriction-${idSuffix.value}`)

watch(
  () => props.isOpen,
  async (isOpen) => {
    if (!isOpen) return
    await nextTick()
    closeButton.value?.focus()
  },
  { immediate: true },
)

function close() {
  if (!props.busy) emit('close')
}
</script>

<template>
  <BaseModal
    :is-open="isOpen"
    size="sm"
    height="fit"
    overlay-padding="none"
    overlay-class="!items-end sm:!items-center"
    panel-class="w-full !rounded-t-2xl !rounded-b-none border border-dp-border-primary sm:!rounded-2xl"
    :aria-labelledby="titleId"
    :aria-describedby="canUnlink ? descriptionId : `${descriptionId} ${restrictionId}`"
    :close-on-backdrop="!busy"
    :close-on-escape="!busy"
    @close="close"
  >
    <section
      class="flex min-h-0 flex-1 flex-col overflow-hidden"
    >
      <div class="modal-header">
        <h2 :id="titleId" class="min-w-0 truncate">
          {{ t('member.sso.unlink.modalTitle', { provider: providerLabel }) }}
        </h2>
        <button
          ref="closeButton"
          type="button"
          class="flex min-h-11 min-w-11 shrink-0 items-center justify-center rounded-full text-dp-text-muted transition hover:bg-dp-bg-hover hover:text-dp-text-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="busy"
          :aria-label="t('common.actions.close')"
          @click="close"
        >
          <X class="h-5 w-5" aria-hidden="true" />
        </button>
      </div>

      <div class="min-h-0 space-y-4 overflow-x-hidden overflow-y-auto p-4 sm:p-5">
        <div class="flex items-center gap-3 rounded-xl border border-dp-border-primary bg-dp-bg-secondary p-4">
          <img :src="providerIcon" alt="" class="h-10 w-10 shrink-0 rounded-lg" />
          <div class="min-w-0">
            <p class="truncate font-semibold text-dp-text-primary">{{ providerLabel }}</p>
            <span class="mt-1 inline-flex items-center gap-1 rounded-full bg-dp-success-soft px-2 py-0.5 text-xs font-medium text-dp-success">
              <Check class="h-4 w-4" aria-hidden="true" />
              {{ t('member.sso.connected') }}
            </span>
          </div>
        </div>

        <div class="rounded-xl border border-dp-border-primary bg-dp-bg-card p-4">
          <h3 class="font-semibold text-dp-text-primary">
            {{ t('member.sso.unlink.localMappingTitle') }}
          </h3>
          <p :id="descriptionId" class="mt-2 text-sm leading-6 text-dp-text-secondary">
            {{ t('member.sso.unlink.localMappingDescription', { provider: providerLabel }) }}
          </p>
        </div>

        <div
          v-if="!canUnlink"
          :id="restrictionId"
          class="flex items-start gap-2 rounded-xl border border-dp-warning-border bg-dp-warning-soft p-4 text-sm leading-6 text-dp-warning"
        >
          <Info class="mt-1 h-4 w-4 shrink-0" aria-hidden="true" />
          <p>{{ t('member.sso.unlink.lastSocialReason') }}</p>
        </div>
      </div>

      <div class="modal-actions modal-footer-safe flex-col-reverse sm:flex-row sm:justify-end">
        <button
          type="button"
          class="min-h-11 w-full rounded-lg bg-dp-bg-tertiary px-4 py-2.5 font-medium text-dp-text-primary transition hover:bg-dp-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring disabled:cursor-not-allowed disabled:opacity-50 sm:w-auto"
          :disabled="busy"
          @click="close"
        >
          {{ t('common.actions.close') }}
        </button>
        <button
          type="button"
          class="flex min-h-11 w-full items-center justify-center gap-2 rounded-lg bg-dp-danger px-4 py-2.5 font-medium text-dp-text-on-dark transition hover:bg-dp-danger-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-danger disabled:cursor-not-allowed disabled:opacity-50 sm:w-auto"
          :disabled="busy || !canUnlink"
          :aria-describedby="canUnlink ? undefined : restrictionId"
          @click="emit('unlink')"
        >
          <Loader2 v-if="busy" class="h-4 w-4 animate-spin" aria-hidden="true" />
          <Trash2 v-else class="h-4 w-4" aria-hidden="true" />
          {{ busy ? t('member.sso.unlink.unlinking') : t('member.sso.unlink.action') }}
        </button>
      </div>
    </section>
  </BaseModal>
</template>
