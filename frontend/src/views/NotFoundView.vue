<script setup lang="ts">
import { useI18n } from 'vue-i18n'

const { t } = useI18n()
</script>

<template>
  <div class="min-h-screen flex items-center justify-center px-4 bg-dp-bg-secondary">
    <div class="text-center">
      <h1 class="text-6xl font-bold text-dp-text-muted">404</h1>
      <p class="text-xl mt-4 text-dp-text-secondary">{{ t('errors.notFound.message') }}</p>
      <router-link
        to="/"
        class="inline-block mt-6 bg-dp-accent text-dp-text-on-dark px-6 py-3 rounded-lg hover:bg-dp-accent-hover transition"
      >
        {{ t('common.navigation.backHome') }}
      </router-link>
    </div>
  </div>
</template>
