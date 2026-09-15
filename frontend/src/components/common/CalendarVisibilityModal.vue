<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, useId, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { Check, Loader2, X } from '@lucide/vue'
import { translateGlobal } from '@/i18n'
import { getVisibilityDescription, getVisibilityIcon, getVisibilityLabel, type CalendarVisibility } from '@/utils/visibility'
import messages from '@/i18n/messages/visibilityAudience'
import BaseModal from './BaseModal.vue'
import VisibilityAudiencePreview from './VisibilityAudiencePreview.vue'

const props = defineProps<{ isOpen: boolean; value: CalendarVisibility; saving: boolean }>()
const emit = defineEmits<{ close: []; save: [value: CalendarVisibility] }>()
const { t } = useI18n({ useScope: 'local', messages })
const id = useId()
const selected = ref<CalendarVisibility>(props.value)
const content = ref<HTMLElement | null>(null)
let previousFocus: HTMLElement | null = null
const options: CalendarVisibility[] = ['PUBLIC', 'FRIENDS', 'FAMILY', 'PRIVATE']
const canSave = computed(() => selected.value !== props.value && !props.saving)

function restoreFocus() {
  if (previousFocus?.isConnected) previousFocus.focus()
  previousFocus = null
}
watch(() => props.isOpen, async open => {
  if (!open) { restoreFocus(); return }
  selected.value = props.value
  previousFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null
  await nextTick()
  if (props.isOpen) content.value?.querySelector<HTMLInputElement>('input:checked')?.focus()
})
onBeforeUnmount(restoreFocus)

function close() { if (!props.saving) emit('close') }
function save() { if (canSave.value) emit('save', selected.value) }
function trapFocus(event: KeyboardEvent) {
  if (event.key !== 'Tab') return
  const elements = content.value?.querySelectorAll<HTMLElement>('button:not(:disabled), input:not(:disabled):not([type="radio"]), input[type="radio"]:checked')
  const focusable = [...(elements ?? [])].filter(element => element.getClientRects().length > 0)
  const first = focusable[0]
  const last = focusable[focusable.length - 1]
  if (!first || !last) { event.preventDefault(); return }
  if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus() }
  else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus() }
}
</script>

<template>
  <BaseModal
    :is-open="isOpen" size="md" height="fit" rounded
    :close-on-backdrop="!saving" :close-on-escape="!saving"
    :aria-labelledby="`${id}-title`" :aria-describedby="`${id}-hint`"
    :panel-style="{ backgroundColor: 'var(--dp-bg-card)' }" @close="close"
  >
    <div ref="content" class="visibility-modal" @keydown="trapFocus">
      <div class="modal-header">
        <h2 :id="`${id}-title`">{{ translateGlobal('member.visibility.modalTitle') }}</h2>
        <button type="button" :disabled="saving" :aria-label="t('cancel')" class="visibility-modal__close hover-close-btn" @click="close"><X class="w-5 h-5" aria-hidden="true" /></button>
      </div>
      <div class="modal-body-form-lg">
        <p :id="`${id}-hint`" class="text-sm leading-6 text-dp-text-secondary">{{ t('selectionHint') }}</p>
        <fieldset class="space-y-2" :disabled="saving">
          <legend class="sr-only">{{ translateGlobal('member.visibility.modalTitle') }}</legend>
          <label v-for="option in options" :key="option" class="visibility-modal__option" :class="{ 'visibility-modal__option--selected': selected === option }">
            <input v-model="selected" type="radio" :name="`${id}-visibility`" :value="option" class="visibility-modal__radio" />
            <component :is="getVisibilityIcon(option)" class="w-5 h-5 shrink-0" aria-hidden="true" />
            <span class="min-w-0 flex-1">
              <span class="block font-semibold">{{ getVisibilityLabel(option) }}</span>
              <span class="mt-1 block text-sm leading-5 text-dp-text-secondary">{{ getVisibilityDescription(option) }}</span>
            </span>
            <Check v-if="selected === option" class="w-5 h-5 shrink-0 text-dp-accent" aria-hidden="true" />
          </label>
        </fieldset>
        <VisibilityAudiencePreview v-if="isOpen" :visibility="selected" />
      </div>
      <div class="modal-actions modal-footer-safe sm:px-6 sm:py-6">
        <button type="button" :disabled="saving" class="visibility-modal__cancel" @click="close">{{ t('cancel') }}</button>
        <button type="button" :disabled="!canSave" class="visibility-modal__save" @click="save">
          <Loader2 v-if="saving" class="w-4 h-4 animate-spin" aria-hidden="true" />{{ t('save') }}
        </button>
      </div>
    </div>
  </BaseModal>
</template>

<style scoped>
.visibility-modal { display: contents; }
.visibility-modal__close { display: flex; align-items: center; justify-content: center; min-width: 44px; min-height: 44px; border-radius: 50%; color: var(--dp-text-muted); cursor: pointer; }
.visibility-modal__option { position: relative; display: flex; align-items: center; gap: .75rem; min-height: 72px; padding: .875rem; border: 2px solid var(--dp-border-primary); border-radius: .75rem; background: var(--dp-bg-secondary); color: var(--dp-text-primary); cursor: pointer; }
.visibility-modal__option--selected { border-color: var(--dp-accent); background: var(--dp-accent-bg); }
.visibility-modal__radio { position: absolute; opacity: 0; width: 1px; height: 1px; }
.visibility-modal__option:has(input:focus-visible), .visibility-modal button:focus-visible { outline: 2px solid var(--dp-accent); outline-offset: 3px; }
.visibility-modal__cancel, .visibility-modal__save { display: flex; align-items: center; justify-content: center; gap: .5rem; min-height: 44px; padding: .75rem 1rem; border-radius: .625rem; font-weight: 600; cursor: pointer; }
.visibility-modal__cancel { background: var(--dp-bg-tertiary); color: var(--dp-text-primary); }
.visibility-modal__save { flex: 1; background: var(--dp-accent); color: var(--dp-text-on-dark); }
.visibility-modal button:disabled, .visibility-modal fieldset:disabled { opacity: .5; cursor: not-allowed; }
@media (hover: hover) { .visibility-modal__option:hover { border-color: var(--dp-accent); } .visibility-modal__save:hover:not(:disabled) { background: var(--dp-accent-hover); } }
</style>
