<script setup lang="ts">
import { ref, watch, nextTick, onUnmounted } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import { useSwal } from '@/composables/useSwal'
import { teamApi } from '@/api/team'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import Pickr from '@simonwep/pickr'
import '@simonwep/pickr/dist/themes/monolith.min.css'
import type { DutyTypeDto } from '@/types'
import { X } from 'lucide-vue-next'

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

const defaultDutyColor = '#ffb3ba'

const dutyTypeForm = ref({
  id: null as number | null,
  name: '',
  color: defaultDutyColor,
  isDefault: false,
})

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
  if (!dutyTypeForm.value.name) {
    showWarning('근무유형 이름을 입력해주세요.')
    return
  }

  const exists = props.dutyTypes.some(
    dt => dt.name === dutyTypeForm.value.name && dt.id !== dutyTypeForm.value.id
  )
  if (exists) {
    showWarning(`${dutyTypeForm.value.name} 이름의 근무유형이 이미 존재합니다.`)
    return
  }

  emit('update:saving', true)
  try {
    if (dutyTypeForm.value.isDefault) {
      await teamApi.updateDefaultDuty(
        props.teamId,
        dutyTypeForm.value.name,
        dutyTypeForm.value.color
      )
    } else if (dutyTypeForm.value.id) {
      await teamApi.updateDutyType(props.teamId, {
        id: dutyTypeForm.value.id,
        name: dutyTypeForm.value.name,
        color: dutyTypeForm.value.color,
      })
    } else {
      await teamApi.addDutyType(props.teamId, {
        teamId: props.teamId,
        name: dutyTypeForm.value.name,
        color: dutyTypeForm.value.color,
      })
    }
    toastSuccess('근무 유형이 저장되었습니다.')
    emit('saved')
    close()
  } catch (error) {
    console.error('Failed to save duty type:', error)
    showError('근무 유형 저장에 실패했습니다.')
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
      <h2>{{ dutyTypeForm.id !== null || dutyTypeForm.isDefault ? '근무 유형 수정' : '근무 유형 추가' }}</h2>
      <button
        @click="close"
        class="p-1.5 rounded-full hover-close-btn cursor-pointer"
      >
        <X class="w-5 h-5" />
      </button>
    </div>

    <div class="modal-body-form">
      <p class="text-sm text-dp-text-secondary">
        해당 근무유형의 명칭 및 색상을 선택해주세요.
      </p>

      <div
        v-if="dutyTypeForm.isDefault"
        class="bg-dp-accent-soft border border-dp-accent-border rounded-lg p-3 text-sm text-dp-accent-hover"
      >
        현재 선택한 근무 유형은 <strong>휴무일</strong>에 해당합니다.
      </div>

      <div>
        <label class="form-label">
          근무명
          <CharacterCounter :current="dutyTypeForm.name.length" :max="10" />
        </label>
        <input
          v-model="dutyTypeForm.name"
          type="text"
          maxlength="10"
          placeholder="근무명"
          class="form-control"
        />
      </div>

      <div class="color-picker-container">
        <label class="form-label mb-2">
          색상 선택
        </label>
        <div class="color-picker-wrapper flex justify-center items-center">
          <div ref="colorPickerRef" class="color-picker"></div>
        </div>
      </div>

      <div>
        <label class="form-label">
          미리보기
        </label>
        <div
          class="inline-block px-4 py-2 rounded-lg border font-medium"
          :style="{ backgroundColor: dutyTypeForm.color, borderColor: 'var(--dp-border-primary)' }"
        >
          {{ dutyTypeForm.name || '근무명 입력' }}
        </div>
      </div>
    </div>

    <div class="modal-actions modal-actions-end modal-footer-safe">
      <button
        @click="saveDutyType"
        :disabled="!dutyTypeForm.name.trim()"
        class="px-4 py-2 bg-dp-success text-dp-text-on-dark rounded-lg font-medium hover:bg-dp-success-hover transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
      >
        {{ dutyTypeForm.id !== null || dutyTypeForm.isDefault ? '저장' : '추가' }}
      </button>
      <button
        @click="close"
        class="px-4 py-2 rounded-lg font-medium hover-interactive cursor-pointer bg-dp-bg-tertiary text-dp-text-secondary"
      >
        취소
      </button>
    </div>
  </BaseModal>
</template>
