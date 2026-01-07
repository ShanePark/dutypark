<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { marked } from 'marked'
import { policyApi, type CurrentPoliciesDto } from '@/api/policy'

marked.setOptions({
  breaks: true,
})

const props = defineProps<{
  type: 'terms' | 'privacy' | null
  policies?: CurrentPoliciesDto | null
}>()

const emit = defineEmits<{
  close: []
}>()

const localPolicies = ref<CurrentPoliciesDto | null>(null)
const isLoading = ref(false)

const effectivePolicies = computed(() => props.policies ?? localPolicies.value)

const modalTitle = computed(() => {
  return props.type === 'terms' ? '이용약관' : '개인정보 처리방침'
})

const modalContent = computed(() => {
  if (!effectivePolicies.value) return ''
  if (props.type === 'terms') {
    return effectivePolicies.value.terms?.content ? marked(effectivePolicies.value.terms.content) as string : ''
  }
  return effectivePolicies.value.privacy?.content ? marked(effectivePolicies.value.privacy.content) as string : ''
})

watch(() => props.type, async (newType) => {
  if (newType && !effectivePolicies.value) {
    isLoading.value = true
    try {
      localPolicies.value = await policyApi.getCurrentPolicies()
    } catch {
      // Silently fail
    } finally {
      isLoading.value = false
    }
  }
}, { immediate: true })

function close() {
  emit('close')
}
</script>

<template>
  <Teleport to="body">
    <div
      v-if="type"
      class="fixed inset-0 z-50 flex items-center justify-center p-4"
      @click.self="close"
    >
      <div class="fixed inset-0 bg-black/50" @click="close"></div>
      <div
        class="relative w-full max-w-3xl max-h-[90vh] rounded-xl shadow-xl overflow-hidden flex flex-col"
        :style="{ backgroundColor: 'var(--dp-bg-modal)' }"
      >
        <!-- Modal Header -->
        <div class="modal-header flex-shrink-0">
          <h2>{{ modalTitle }}</h2>
          <button
            type="button"
            class="p-2 rounded-full hover-close-btn"
            @click="close"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        <!-- Modal Body -->
        <div
          class="flex-1 overflow-y-auto p-6 prose prose-sm sm:prose-base max-w-none"
          :style="{ color: 'var(--dp-text-secondary)' }"
        >
          <div v-if="isLoading" class="flex items-center justify-center h-32">
            <div class="animate-spin rounded-full h-6 w-6 border-2 border-blue-500 border-t-transparent"></div>
          </div>
          <div v-else-if="!modalContent" class="flex items-center justify-center h-32 text-sm">
            내용을 불러올 수 없습니다.
          </div>
          <div v-else v-html="modalContent"></div>
        </div>
        <!-- Modal Footer -->
        <div class="flex-shrink-0 p-4 border-t" :style="{ borderColor: 'var(--dp-border-primary)' }">
          <button
            type="button"
            class="w-full py-2.5 px-4 rounded-lg font-medium transition"
            :style="{
              backgroundColor: 'var(--dp-bg-tertiary)',
              color: 'var(--dp-text-primary)'
            }"
            @click="close"
          >
            닫기
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
