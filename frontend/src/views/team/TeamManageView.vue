<script setup lang="ts">
import { useRoute } from 'vue-router'

const route = useRoute()
const teamId = route.params.teamId
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <h1 class="text-2xl font-bold text-gray-900 mb-6">팀 관리</h1>
    <div class="bg-white rounded-lg shadow p-6">
      <p class="text-gray-600">Team ID: {{ teamId }}</p>
      <p class="text-gray-600 mt-2">팀 관리 콘텐츠 (구현 예정)</p>
    </div>
  </div>
</template>
