<script setup lang="ts">
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-50 px-4">
    <div class="text-center">
      <h1 class="text-6xl font-bold text-gray-300">404</h1>
      <p class="text-xl text-gray-600 mt-4">페이지를 찾을 수 없습니다</p>
      <router-link
        to="/"
        class="inline-block mt-6 bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition"
      >
        홈으로 돌아가기
      </router-link>
    </div>
  </div>
</template>
