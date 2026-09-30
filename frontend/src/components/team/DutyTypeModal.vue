<script setup lang="ts">
import { computed, ref, watch, nextTick, onUnmounted } from 'vue'
import { useI18n } from 'vue-i18n'
import BaseModal from '@/components/common/BaseModal.vue'
import { useSwal } from '@/composables/useSwal'
import { teamApi } from '@/api/team'
import Pickr from '@simonwep/pickr'
import '@simonwep/pickr/dist/themes/monolith.min.css'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import type { DutyTypeDto } from '@/types'
import { Check, X } from '@lucide/vue'
import { resolveApiErrorMessage } from '@/utils/resolveApiError'
import { useContentFilterStore } from '@/stores/contentFilter'
import {
  dutyAbbreviation,
  isValidDutyAbbreviation,
  normalizeDutyAbbreviation,
} from '@/utils/dutyAbbreviation'
import { isLightColor } from '@/utils/color'
import { defaultDutyTypeColor, dutyTypePalette, isDutyTypePaletteColor } from '@/utils/dutyTypePalette'

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

const defaultDutyColor: string = defaultDutyTypeColor

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

const customColorMode = ref(false)
const colorPickerRef = ref<HTMLElement | null>(null)
let pickrInstance: Pickr | null = null

const hasLegacyColor = computed(() => !!props.dutyType?.color && !isDutyTypePaletteColor(props.dutyType.color))

function setFormFromProps() {
  customColorMode.value = !!props.dutyType?.color && !isDutyTypePaletteColor(props.dutyType.color)
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

watch(
  () => props.isOpen,
  (open) => { if (open) setFormFromProps() },
  { immediate: true }
)

function selectColor(color: string) {
  if (props.saving || submitting.value) return
  customColorMode.value = false
  if (dutyTypeForm.value.color.toLowerCase() !== color.toLowerCase()) dutyTypeForm.value.color = color
}

function selectCustomColor() {
  if (props.saving || submitting.value || customColorMode.value) return
  customColorMode.value = true
}

function destroyPickr() {
  pickrInstance?.destroyAndRemove()
  pickrInstance = null
}

watch(
  () => props.isOpen && customColorMode.value,
  async (showCustomPicker) => {
    destroyPickr()
    if (!showCustomPicker) return
    await nextTick()
    if (!props.isOpen || !customColorMode.value || !colorPickerRef.value || pickrInstance) return
    const instance = Pickr.create({
      el: colorPickerRef.value,
      theme: 'monolith',
      default: dutyTypeForm.value.color,
      defaultRepresentation: 'HEXA',
      inline: true,
      showAlways: true,
      components: {
        preview: true,
        opacity: false,
        hue: true,
        interaction: { hex: true, rgba: false, hsla: false, hsva: false, cmyk: false, input: true, save: false },
      },
    })
    pickrInstance = instance
    // Pickr initializes its internal color to black before applying the configured default.
    instance.setColor(dutyTypeForm.value.color, true)
    let initialized = false
    instance.on('init', () => { initialized = true })
    instance.on('change', (color: Pickr.HSVaColor) => {
      if (!initialized || pickrInstance !== instance || !props.isOpen || !customColorMode.value || props.saving || submitting.value) return
      const selectedColor = color.toHEXA().toString()
      if (dutyTypeForm.value.color.toLowerCase() !== selectedColor.toLowerCase()) dutyTypeForm.value.color = selectedColor
    })
  },
  { immediate: true }
)

onUnmounted(destroyPickr)

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

      <fieldset class="min-w-0">
        <legend class="form-label">{{ t('team.dutyType.fields.color') }}</legend>
        <div class="grid grid-cols-2 gap-2">
          <label v-for="option in dutyTypePalette" :key="option.color" class="relative cursor-pointer">
            <input
              type="radio"
              name="duty-type-color"
              :value="option.color"
              :checked="!customColorMode && dutyTypeForm.color.toLowerCase() === option.color.toLowerCase()"
              :disabled="saving || submitting"
              :aria-label="t(`team.dutyType.palette.${option.name}`)"
              class="peer sr-only"
              @change="selectColor(option.color)"
            />
            <span
              class="flex min-h-11 items-center justify-center gap-1 rounded-lg border-2 border-transparent px-1 text-xs font-semibold text-dp-text-on-light transition peer-checked:border-dp-text-on-light peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-dp-accent peer-disabled:cursor-not-allowed peer-disabled:opacity-50 hover:brightness-95"
              :style="{ backgroundColor: option.color }"
            >
              {{ t(`team.dutyType.palette.${option.name}`) }}
              <Check v-if="!customColorMode && dutyTypeForm.color.toLowerCase() === option.color.toLowerCase()" class="h-3.5 w-3.5 shrink-0" aria-hidden="true" />
            </span>
          </label>
          <label class="relative cursor-pointer">
            <input
              type="radio"
              name="duty-type-color"
              value="custom"
              :checked="customColorMode"
              :disabled="saving || submitting"
              :aria-label="t('team.dutyType.palette.custom')"
              class="peer sr-only"
              @change="selectCustomColor"
            />
            <span class="flex min-h-11 items-center justify-center gap-1 rounded-lg border-2 border-dp-border-primary bg-dp-bg-secondary px-2 text-xs font-semibold text-dp-text-primary transition peer-checked:border-dp-text-primary peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-dp-accent peer-disabled:cursor-not-allowed peer-disabled:opacity-50 hover:bg-dp-bg-hover">
              {{ t('team.dutyType.palette.custom') }}
              <Check v-if="customColorMode" class="h-3.5 w-3.5 shrink-0" aria-hidden="true" />
            </span>
          </label>
        </div>
        <div v-if="hasLegacyColor" class="mt-2 flex items-center gap-2 text-xs text-dp-text-secondary">
          <span class="h-5 w-5 shrink-0 rounded border border-dp-border-primary" :style="{ backgroundColor: dutyType?.color || undefined }" aria-hidden="true"></span>
          {{ t('team.dutyType.palette.currentColor') }}
        </div>
      </fieldset>

      <div v-if="customColorMode" class="color-picker-wrapper items-center" :inert="saving || submitting" :aria-disabled="saving || submitting">
        <div ref="colorPickerRef" class="color-picker color-picker--compact"></div>
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
