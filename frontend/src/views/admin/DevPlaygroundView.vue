<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import AdminNavTiles from '@/components/admin/AdminNavTiles.vue'
import {
  ChevronDown,
  ChevronRight,
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const { t } = useI18n()

const expandedSections = ref<Set<string>>(new Set())

function toggleSection(section: string) {
  if (expandedSections.value.has(section)) {
    expandedSections.value.delete(section)
  } else {
    expandedSections.value.add(section)
  }
}

onMounted(() => {
  if (!authStore.isAdmin) {
    router.replace('/')
  }
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <AdminNavTiles active="dev" />

    <div class="mb-6">
      <h1 class="text-2xl font-bold text-dp-text-primary">
        {{ t('admin.devPlayground.title') }}
      </h1>
      <p class="mt-1 text-dp-text-secondary">
        {{ t('admin.devPlayground.description') }}
      </p>
    </div>

    <div
      class="rounded-xl bg-dp-bg-card border border-dp-border-primary"
    >
      <button
        class="w-full p-4 flex items-center justify-between cursor-pointer"
        @click="toggleSection('example')"
      >
        <h2 class="text-lg font-semibold text-dp-text-primary">
          {{ t('admin.devPlayground.exampleSectionTitle') }}
        </h2>
        <component
          :is="expandedSections.has('example') ? ChevronDown : ChevronRight"
          class="w-5 h-5 text-dp-text-muted"
        />
      </button>
      <div
        v-if="expandedSections.has('example')"
        class="p-4 border-t border-dp-border-primary"
      >
        <p class="text-dp-text-secondary">
          {{ t('admin.devPlayground.exampleSectionDescription') }}
        </p>
        <div class="mt-4 p-4 rounded-lg bg-dp-bg-tertiary">
          <code class="text-dp-text-primary">
            &lt;YourComponent /&gt;
          </code>
        </div>
      </div>
    </div>
  </div>
</template>
