<script setup lang="ts">
import { ref, watch, toRef, nextTick, onUnmounted } from 'vue'
import { useSwal } from '@/composables/useSwal'
import { useBodyScrollLock } from '@/composables/useBodyScrollLock'
import { useEscapeKey } from '@/composables/useEscapeKey'
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
const isOpenRef = toRef(props, 'isOpen')

useBodyScrollLock(isOpenRef)
useEscapeKey(isOpenRef, () => emit('close'))

const dutyTypeForm = ref({
  id: null as number | null,
  name: '',
  color: '#ffb3ba',
  isDefault: false,
})

let pickrInstance: Pickr | null = null
const colorPickerRef = ref<HTMLElement | null>(null)

function setFormFromProps() {
  if (!props.dutyType) {
    dutyTypeForm.value = {
      id: null,
      name: '',
      color: '#ffb3ba',
      isDefault: false,
    }
    return
  }

  dutyTypeForm.value = {
    id: props.dutyType.id,
    name: props.dutyType.name,
    color: props.dutyType.color || '#ffb3ba',
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
  <div
    v-if="isOpen"
    class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
    @click.self="close"
  >
    <div class="rounded-lg shadow-xl w-full max-w-md" :style="{ backgroundColor: 'var(--dp-bg-modal)' }">
      <div class="flex items-center justify-between p-4 border-b" :style="{ borderColor: 'var(--dp-border-primary)' }">
        <h3 class="text-lg font-bold" :style="{ color: 'var(--dp-text-primary)' }">
          {{ dutyTypeForm.id !== null || dutyTypeForm.isDefault ? '근무 유형 수정' : '근무 유형 추가' }}
        </h3>
        <button
          @click="close"
          class="p-1.5 rounded-full hover-close-btn cursor-pointer"
        >
          <X class="w-5 h-5" />
        </button>
      </div>

      <div class="p-4 space-y-4">
        <p class="text-sm" :style="{ color: 'var(--dp-text-secondary)' }">
          해당 근무유형의 명칭 및 색상을 선택해주세요.
        </p>

        <div
          v-if="dutyTypeForm.isDefault"
          class="bg-blue-50 border border-blue-200 rounded-lg p-3 text-sm text-blue-700"
        >
          현재 선택한 근무 유형은 <strong>휴무일</strong>에 해당합니다.
        </div>

        <div>
          <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
            근무명
            <CharacterCounter :current="dutyTypeForm.name.length" :max="10" />
          </label>
          <input
            v-model="dutyTypeForm.name"
            type="text"
            maxlength="10"
            placeholder="근무명"
            class="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            :style="{ backgroundColor: 'var(--dp-bg-input)', borderColor: 'var(--dp-border-input)', color: 'var(--dp-text-primary)' }"
          />
        </div>

        <div class="color-picker-container">
          <label class="block text-sm font-medium mb-2" :style="{ color: 'var(--dp-text-secondary)' }">
            색상 선택
          </label>
          <div class="color-picker-wrapper flex justify-center items-center">
            <div ref="colorPickerRef" class="color-picker"></div>
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium mb-1" :style="{ color: 'var(--dp-text-secondary)' }">
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

      <div class="flex justify-end gap-2 p-4 border-t" :style="{ borderColor: 'var(--dp-border-primary)' }">
        <button
          @click="saveDutyType"
          :disabled="!dutyTypeForm.name.trim()"
          class="px-4 py-2 bg-green-500 text-white rounded-lg font-medium hover:bg-green-600 transition disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {{ dutyTypeForm.id !== null || dutyTypeForm.isDefault ? '저장' : '추가' }}
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
