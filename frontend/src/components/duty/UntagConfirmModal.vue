<script setup lang="ts">
import BaseModal from '@/components/common/BaseModal.vue'

const props = defineProps<{
  isOpen: boolean
}>()

const emit = defineEmits<{
  close: []
  confirm: []
}>()

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
        <div
          class="py-2.5 px-4 text-sm font-semibold"
          :style="{
            backgroundColor: 'var(--dp-bg-tertiary)',
            borderBottom: '1px solid var(--dp-border-primary)',
            color: 'var(--dp-text-primary)'
          }"
        >
          태그 제거
        </div>
        <div class="py-4 px-4 space-y-3">
          <p class="text-sm text-dp-text-secondary">
            이 일정에서 태그를 제거하시겠습니까?
          </p>
          <div
            class="p-3 rounded-lg text-xs space-y-1 bg-dp-bg-secondary text-dp-text-muted"
          >
            <p>• 태그를 제거하면 이 일정이 내 달력에서 사라집니다.</p>
            <p>• 태그 복원은 불가능하며, 다시 태그하려면 해당 사용자에게 요청해야 합니다.</p>
          </div>
        </div>
        <div class="pb-4 modal-footer-safe flex justify-center gap-2">
          <button
            @click="confirm"
            class="px-5 py-2 bg-dp-warning hover:bg-dp-warning-hover text-dp-text-on-dark rounded-lg text-sm font-medium transition-all duration-200 hover:-translate-y-px cursor-pointer"
            style="box-shadow: var(--dp-shadow-md), var(--dp-shadow-sm);"
          >
            태그 제거
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
            취소
          </button>
        </div>
      </div>
  </BaseModal>
</template>
