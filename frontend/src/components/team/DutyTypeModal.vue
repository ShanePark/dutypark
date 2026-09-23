<script setup lang="ts">
import { computed, ref, watch, nextTick, onUnmounted } from 'vue'
import { useI18n } from 'vue-i18n'
import BaseModal from '@/components/common/BaseModal.vue'
import { useSwal } from '@/composables/useSwal'
import { teamApi } from '@/api/team'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import Pickr from '@simonwep/pickr'
import '@simonwep/pickr/dist/themes/monolith.min.css'
import type { DutyTypeDto } from '@/types'
import { X } from '@lucide/vue'
import { resolveApiErrorMessage } from '@/utils/resolveApiError'
import { useContentFilterStore } from '@/stores/contentFilter'
import {
  dutyAbbreviation,
  isValidDutyAbbreviation,
  normalizeDutyAbbreviation,
} from '@/utils/dutyAbbreviation'
import { isLightColor } from '@/utils/color'

const props = defineProps<{
  isOpen: boolean
  teamId: number
  dutyType: DutyTypeDto | null
  dutyTypes: DutyTypeDto[]
  saving: boolean
}>()

const emit = defineEmits<{
  close: []
  saved: []
  'update:saving': [boolean]
}>()

const { showWarning, showError, toastSuccess } = useSwal()
const { t } = useI18n()
const contentFilterStore = useContentFilterStore()

const defaultDutyColor = '#ffb3ba'

const dutyTypeForm = ref({
  id: null as number | null,
  name: '',
  abbreviation: '',
  color: defaultDutyColor,
  isDefault: false,
})
const trimmedDutyTypeName = computed(() => dutyTypeForm.value.name.trim())
const trimmedDutyAbbreviation = computed(() => normalizeDutyAbbreviation(dutyTypeForm.value.abbreviation))
const isDutyAbbreviationInvalid = computed(() => !isValidDutyAbbreviation(trimmedDutyAbbreviation.value))
const automaticDutyAbbreviation = computed(() => dutyAbbreviation(trimmedDutyTypeName.value))
const dutyTypePreviewStyle = computed(() => ({
  backgroundColor: dutyTypeForm.value.color || 'var(--dp-duty-type-fallback)',
  color: isLightColor(dutyTypeForm.value.color) ? 'var(--dp-text-on-light)' : 'var(--dp-text-on-dark)',
}))
const submitting = ref(false)
const isDutyAbbreviationComposing = ref(false)
const hasDuplicateDutyTypeName = computed(() =>
  props.dutyTypes.some(
    dt => dt.name === trimmedDutyTypeName.value && dt.id !== dutyTypeForm.value.id
  )
)
const isDutyTypeNameInvalid = computed(() => !trimmedDutyTypeName.value || hasDuplicateDutyTypeName.value)
const isDutyTypeSaveDisabled = computed(() => props.saving || submitting.value || isDutyTypeNameInvalid.value || isDutyAbbreviationInvalid.value)

let pickrInstance: Pickr | null = null
const colorPickerRef = ref<HTMLElement | null>(null)

function setFormFromProps() {
  if (!props.dutyType) {
      dutyTypeForm.value = {
        id: null,
        name: '',
        abbreviation: '',
        color: defaultDutyColor,
        isDefault: false,
      }
    return
  }

  dutyTypeForm.value = {
    id: props.dutyType.id,
    name: props.dutyType.name,
    abbreviation: normalizeDutyAbbreviation(props.dutyType.abbreviation),
    color: props.dutyType.color || defaultDutyColor,
    isDefault: props.dutyType.position === -1,
  }
}

function handleDutyAbbreviationInput(event: Event) {
  if (isDutyAbbreviationComposing.value || (event as InputEvent).isComposing) return
  const input = event.target as HTMLInputElement
  dutyTypeForm.value.abbreviation = normalizeDutyAbbreviation(input.value)
}

function startDutyAbbreviationComposition() {
  isDutyAbbreviationComposing.value = true
}

function finishDutyAbbreviationComposition(event: CompositionEvent) {
  isDutyAbbreviationComposing.value = false
  handleDutyAbbreviationInput(event)
}

function initPickr(defaultColor: string) {
  destroyPickr()
  nextTick(() => {
    if (colorPickerRef.value && !pickrInstance) {
      pickrInstance = Pickr.create({
        el: colorPickerRef.value,
        theme: 'monolith',
        default: defaultColor,
        inline: true,
        showAlways: true,
        components: {
          preview: true,
          opacity: false,
          hue: true,
          interaction: {
            hex: true,
            rgba: false,
            hsla: false,
            hsva: false,
            cmyk: false,
            input: true,
            save: false,
          },
        },
      })

      pickrInstance.on('change', (color: Pickr.HSVaColor) => {
        dutyTypeForm.value.color = color.toHEXA().toString()
      })
    }
  })
}

function destroyPickr() {
  if (pickrInstance) {
    pickrInstance.destroyAndRemove()
    pickrInstance = null
  }
}

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      setFormFromProps()
      initPickr(dutyTypeForm.value.color)
    } else {
      destroyPickr()
    }
  },
  { immediate: true }
)

onUnmounted(() => {
  destroyPickr()
})

function close() {
  if (props.saving || submitting.value) return
  emit('close')
}

async function saveDutyType() {
  if (props.saving || submitting.value) return
  if (!trimmedDutyTypeName.value) {
    showWarning(t('team.dutyType.warnings.nameRequired'))
    return
  }

  if (hasDuplicateDutyTypeName.value) {
    showWarning(t('team.dutyType.warnings.duplicate', { name: trimmedDutyTypeName.value }))
    return
  }

  if (isDutyAbbreviationInvalid.value) {
    showWarning(t('dutyAbbreviation.invalid'))
    return
  }

  if (contentFilterStore.isBlocked(trimmedDutyTypeName.value)
    || (trimmedDutyAbbreviation.value && contentFilterStore.isBlocked(trimmedDutyAbbreviation.value))) {
    showError(t('contentFilter.blocked'))
    return
  }

  submitting.value = true
  emit('update:saving', true)
  let succeeded = false
  try {
    if (dutyTypeForm.value.isDefault) {
      await teamApi.updateDefaultDuty(
        props.teamId,
        trimmedDutyTypeName.value,
        dutyTypeForm.value.color,
        trimmedDutyAbbreviation.value
      )
    } else if (dutyTypeForm.value.id) {
      await teamApi.updateDutyType(props.teamId, {
        id: dutyTypeForm.value.id,
        name: trimmedDutyTypeName.value,
        color: dutyTypeForm.value.color,
        abbreviation: trimmedDutyAbbreviation.value || null,
      })
    } else {
      await teamApi.addDutyType(props.teamId, {
        teamId: props.teamId,
        name: trimmedDutyTypeName.value,
        color: dutyTypeForm.value.color,
        abbreviation: trimmedDutyAbbreviation.value || null,
      })
    }
    toastSuccess(t('team.dutyType.messages.saveSuccess'))
    emit('saved')
    succeeded = true
  } catch (error) {
    console.error('Failed to save duty type:', error)
    showError(resolveApiErrorMessage(error, {
      fallbackKey: 'team.dutyType.messages.saveFailed',
    }, t))
  } finally {
    emit('update:saving', false)
    submitting.value = false
  }
  if (succeeded) emit('close')
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
      <h2>{{ dutyTypeForm.id !== null || dutyTypeForm.isDefault ? t('team.dutyType.titleEdit') : t('team.dutyType.titleAdd') }}</h2>
      <button
        @click="close"
        class="p-1.5 rounded-full hover-close-btn cursor-pointer"
        :aria-label="t('common.actions.close')"
      >
        <X class="w-5 h-5" />
      </button>
    </div>

    <div class="modal-body-form-compact !space-y-3">
      <div class="grid grid-cols-[minmax(0,1fr)_minmax(0,0.8fr)] gap-3">
        <div class="min-w-0">
          <label for="duty-type-name" class="form-label !flex !min-h-5 !items-center !justify-between !gap-1 !whitespace-nowrap !text-xs">
            <span class="inline-flex min-w-0 items-center gap-1 whitespace-nowrap">
              {{ t('team.dutyType.fields.name') }}
              <span
                aria-hidden="true"
                class="duty-type-required-indicator h-1.5 w-1.5 shrink-0 rounded-full bg-dp-danger"
              ></span>
            </span>
            <CharacterCounter :current="dutyTypeForm.name.length" :max="10" />
          </label>
          <input
            id="duty-type-name"
            v-model="dutyTypeForm.name"
            type="text"
            maxlength="10"
            :placeholder="t('team.dutyType.placeholders.name')"
            class="form-control"
            required
            aria-required="true"
            :aria-invalid="isDutyTypeNameInvalid"
          />
        </div>

        <div class="min-w-0">
          <label for="duty-type-abbreviation" class="form-label !flex !min-h-5 !items-center !justify-between !gap-1 !whitespace-nowrap !text-xs">
            <span class="min-w-0 truncate">{{ t('dutyAbbreviation.label') }}</span>
            <CharacterCounter :current="dutyTypeForm.abbreviation.length" :max="3" />
          </label>
          <input
            id="duty-type-abbreviation"
            :value="dutyTypeForm.abbreviation"
            type="text"
            maxlength="3"
            pattern="[A-Za-z가-힣]{1,3}"
            autocomplete="off"
            :placeholder="automaticDutyAbbreviation || t('dutyAbbreviation.placeholder')"
            class="form-control"
            :aria-invalid="isDutyAbbreviationInvalid"
            :aria-describedby="isDutyAbbreviationInvalid ? 'duty-type-abbreviation-error' : undefined"
            @input="handleDutyAbbreviationInput"
            @compositionstart="startDutyAbbreviationComposition"
            @compositionend="finishDutyAbbreviationComposition"
          />
          <p
            v-if="isDutyAbbreviationInvalid"
            id="duty-type-abbreviation-error"
            class="mt-1 text-xs text-dp-danger"
            role="alert"
          >
            {{ t('dutyAbbreviation.invalid') }}
          </p>
        </div>
      </div>

      <div class="color-picker-container !gap-2 !mt-0">
        <label class="form-label mb-0">
          {{ t('team.dutyType.fields.color') }}
        </label>
        <div class="color-picker-wrapper !flex-row justify-center items-center">
          <div ref="colorPickerRef" class="color-picker color-picker--compact"></div>
        </div>
      </div>

      <div class="flex items-center gap-3">
        <label class="form-label mb-0 shrink-0">
          {{ t('team.dutyType.fields.preview') }}
        </label>
        <span
          class="duty-type-preview px-2.5 py-0.5 rounded-md font-semibold text-sm"
          :style="dutyTypePreviewStyle"
        >
          {{ dutyTypeForm.name || t('team.dutyType.placeholders.preview') }}
        </span>
      </div>
    </div>

    <div class="modal-actions-compact modal-actions-end modal-footer-safe">
      <button
        @click="close"
        :disabled="saving || submitting"
        class="flex-1 sm:flex-none px-4 py-2 rounded-lg font-medium hover-interactive cursor-pointer bg-dp-bg-tertiary text-dp-text-secondary disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {{ t('common.actions.close') }}
      </button>
      <button
        @click="saveDutyType"
        :disabled="isDutyTypeSaveDisabled"
        class="flex-1 sm:flex-none px-4 py-2 bg-dp-success text-dp-text-on-dark rounded-lg font-medium hover:bg-dp-success-hover transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
      >
        {{ dutyTypeForm.id !== null || dutyTypeForm.isDefault ? t('common.actions.save') : t('common.actions.add') }}
      </button>
    </div>
  </BaseModal>
</template>
