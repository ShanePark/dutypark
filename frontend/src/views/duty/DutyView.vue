<script setup lang="ts">
import { useRoute } from 'vue-router'

const route = useRoute()
const memberId = route.params.id
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <h1 class="text-2xl font-bold text-gray-900 mb-6">근무 달력</h1>
    <div class="bg-white rounded-lg shadow p-6">
      <p class="text-gray-600">Member ID: {{ memberId }}</p>
      <p class="text-gray-600 mt-2">근무 달력 콘텐츠 (구현 예정)</p>
    </div>
  </div>
</template>
