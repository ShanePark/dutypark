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
import { X } from 'lucide-vue-next'
import { countVisibleDutyTypes, leavesSingleVisibleDutyType } from '@/utils/dutyTypeVisibility'

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

const { confirm, showWarning, showError, toastSuccess } = useSwal()
const { t } = useI18n()

const defaultDutyColor = '#ffb3ba'

const dutyTypeForm = ref({
  id: null as number | null,
  name: '',
  color: defaultDutyColor,
  isDefault: false,
})
const trimmedDutyTypeName = computed(() => dutyTypeForm.value.name.trim())
const hasDuplicateDutyTypeName = computed(() =>
  props.dutyTypes.some(
    dt => dt.name === trimmedDutyTypeName.value && dt.id !== dutyTypeForm.value.id
  )
)
const isDutyTypeNameInvalid = computed(() => !trimmedDutyTypeName.value || hasDuplicateDutyTypeName.value)
const isDutyTypeSaveDisabled = computed(() => props.saving || isDutyTypeNameInvalid.value)

let pickrInstance: Pickr | null = null
const colorPickerRef = ref<HTMLElement | null>(null)

function setFormFromProps() {
  if (!props.dutyType) {
      dutyTypeForm.value = {
        id: null,
        name: '',
        color: defaultDutyColor,
        isDefault: false,
      }
    return
  }

  dutyTypeForm.value = {
    id: props.dutyType.id,
    name: props.dutyType.name,
    color: props.dutyType.color || defaultDutyColor,
    isDefault: props.dutyType.position === -1,
  }
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
  emit('close')
}

async function saveDutyType() {
  if (!trimmedDutyTypeName.value) {
    showWarning(t('team.dutyType.warnings.nameRequired'))
    return
  }

  if (hasDuplicateDutyTypeName.value) {
    showWarning(t('team.dutyType.warnings.duplicate', { name: trimmedDutyTypeName.value }))
    return
  }

  const isAddingDutyType = !dutyTypeForm.value.isDefault && dutyTypeForm.value.id === null
  const visibleCount = countVisibleDutyTypes(props.dutyTypes)
  if (
    isAddingDutyType &&
    leavesSingleVisibleDutyType(visibleCount, visibleCount + 1) &&
    !await confirm(t('team.manage.messages.patternTerminationWarning'))
  ) return

  emit('update:saving', true)
  try {
    if (dutyTypeForm.value.isDefault) {
      await teamApi.updateDefaultDuty(
        props.teamId,
        trimmedDutyTypeName.value,
        dutyTypeForm.value.color
      )
    } else if (dutyTypeForm.value.id) {
      await teamApi.updateDutyType(props.teamId, {
        id: dutyTypeForm.value.id,
        name: trimmedDutyTypeName.value,
        color: dutyTypeForm.value.color,
      })
    } else {
      await teamApi.addDutyType(props.teamId, {
        teamId: props.teamId,
        name: trimmedDutyTypeName.value,
        color: dutyTypeForm.value.color,
      })
    }
    toastSuccess(t('team.dutyType.messages.saveSuccess'))
    emit('saved')
    close()
  } catch (error) {
    console.error('Failed to save duty type:', error)
    showError(t('team.dutyType.messages.saveFailed'))
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
      <h2>{{ dutyTypeForm.id !== null || dutyTypeForm.isDefault ? t('team.dutyType.titleEdit') : t('team.dutyType.titleAdd') }}</h2>
      <button
        @click="close"
        class="p-1.5 rounded-full hover-close-btn cursor-pointer"
        :aria-label="t('common.actions.close')"
      >
        <X class="w-5 h-5" />
      </button>
    </div>

    <div class="modal-body-form">
      <p class="text-sm text-dp-text-secondary">
        {{ t('team.dutyType.description') }}
      </p>

      <div
        v-if="dutyTypeForm.isDefault"
        class="bg-dp-accent-soft border border-dp-accent-border rounded-lg p-3 text-sm text-dp-accent-hover"
      >
        {{ t('team.dutyType.defaultNoticeStart') }} <strong>{{ t('team.dutyType.defaultNoticeStrong') }}</strong>{{ t('team.dutyType.defaultNoticeEnd') }}
      </div>

      <div>
        <label class="form-label">
          {{ t('team.dutyType.fields.name') }}
          <CharacterCounter :current="dutyTypeForm.name.length" :max="10" />
        </label>
        <input
          v-model="dutyTypeForm.name"
          type="text"
          maxlength="10"
          :placeholder="t('team.dutyType.placeholders.name')"
          class="form-control"
          :aria-invalid="isDutyTypeNameInvalid"
        />
      </div>

      <div class="color-picker-container">
        <label class="form-label mb-2">
          {{ t('team.dutyType.fields.color') }}
        </label>
        <div class="color-picker-wrapper flex justify-center items-center">
          <div ref="colorPickerRef" class="color-picker"></div>
        </div>
      </div>

      <div>
        <label class="form-label">
          {{ t('team.dutyType.fields.preview') }}
        </label>
        <div
          class="inline-block px-4 py-2 rounded-lg border font-medium"
          :style="{ backgroundColor: dutyTypeForm.color, borderColor: 'var(--dp-border-primary)' }"
        >
          {{ dutyTypeForm.name || t('team.dutyType.placeholders.preview') }}
        </div>
      </div>
    </div>

    <div class="modal-actions modal-actions-end modal-footer-safe">
      <button
        @click="saveDutyType"
        :disabled="isDutyTypeSaveDisabled"
        class="px-4 py-2 bg-dp-success text-dp-text-on-dark rounded-lg font-medium hover:bg-dp-success-hover transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
      >
        {{ dutyTypeForm.id !== null || dutyTypeForm.isDefault ? t('common.actions.save') : t('common.actions.add') }}
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
