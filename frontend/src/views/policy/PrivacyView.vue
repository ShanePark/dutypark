<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { marked } from 'marked'

marked.setOptions({
  breaks: true,
})
import { policyApi, type PolicyDto } from '@/api/policy'

const policy = ref<PolicyDto | null>(null)
const isLoading = ref(true)
const error = ref('')

const renderedContent = computed(() => {
  if (!policy.value?.content) return ''
  return marked(policy.value.content) as string
})

onMounted(async () => {
  try {
    policy.value = await policyApi.getPolicy('PRIVACY')
  } catch {
    error.value = '개인정보 처리방침을 불러오는데 실패했습니다.'
  } finally {
    isLoading.value = false
  }
})
</script>

<template>
  <div class="min-h-screen py-8 px-4" :style="{ backgroundColor: 'var(--dp-bg-secondary)' }">
    <div class="max-w-3xl mx-auto">
      <div
        class="rounded-lg shadow-sm p-6 sm:p-8"
        :style="{
          backgroundColor: 'var(--dp-bg-primary)',
          border: '1px solid var(--dp-border-default)',
        }"
      >
        <h1 class="text-2xl font-bold mb-6" :style="{ color: 'var(--dp-text-primary)' }">
          개인정보 처리방침
        </h1>

        <div v-if="isLoading" class="flex justify-center py-12">
          <div class="animate-spin rounded-full h-8 w-8 border-2 border-blue-500 border-t-transparent"></div>
        </div>

        <div v-else-if="error" class="text-center py-12">
          <p :style="{ color: 'var(--dp-text-muted)' }">{{ error }}</p>
        </div>

        <div v-else-if="policy" class="prose prose-sm sm:prose-base max-w-none" :style="{ color: 'var(--dp-text-secondary)' }" v-html="renderedContent">
        </div>
      </div>

      <div class="text-center mt-6">
        <router-link to="/" class="text-sm hover:underline" :style="{ color: 'var(--dp-text-muted)' }">
          ← 홈으로 돌아가기
        </router-link>
      </div>
    </div>
  </div>
</template>
