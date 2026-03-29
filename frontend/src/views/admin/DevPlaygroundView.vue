<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import {
  Users,
  Building2,
  FileText,
  ExternalLink,
  Code2,
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

function setHoverBg(e: Event) {
  if (e.currentTarget) {
    (e.currentTarget as HTMLElement).style.backgroundColor = 'var(--dp-bg-hover)'
  }
}

function clearHoverBg(e: Event, bgColor = 'var(--dp-bg-card)') {
  if (e.currentTarget) {
    (e.currentTarget as HTMLElement).style.backgroundColor = bgColor
  }
}

onMounted(() => {
  if (!authStore.isAdmin) {
    router.push('/')
  }
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <!-- Admin Navigation -->
    <div class="grid grid-cols-4 gap-2 sm:gap-4 mb-4 sm:mb-6">
      <router-link
        to="/admin"
        class="admin-top-tile bg-dp-bg-card border border-dp-border-primary"
        @mouseover="(e: Event) => setHoverBg(e)"
        @mouseleave="(e: Event) => clearHoverBg(e)"
      >
        <Users class="admin-top-tile-icon text-dp-text-secondary" />
        <span class="admin-top-tile-label text-dp-text-primary">{{ t('admin.nav.members') }}</span>
      </router-link>
      <router-link
        to="/admin/teams"
        class="admin-top-tile bg-dp-bg-card border border-dp-border-primary"
        @mouseover="(e: Event) => setHoverBg(e)"
        @mouseleave="(e: Event) => clearHoverBg(e)"
      >
        <Building2 class="admin-top-tile-icon text-dp-text-secondary" />
        <span class="admin-top-tile-label text-dp-text-primary">{{ t('admin.nav.teams') }}</span>
      </router-link>
      <router-link
        to="/admin/dev"
        class="admin-top-tile admin-top-tile-active"
      >
        <Code2 class="admin-top-tile-icon text-dp-text-on-dark" />
        <span class="admin-top-tile-label text-dp-text-on-dark">{{ t('admin.nav.dev') }}</span>
      </router-link>
      <a
        href="/docs/index.html"
        target="_blank"
        class="admin-top-tile bg-dp-bg-card border border-dp-border-primary"
        @mouseover="(e: Event) => setHoverBg(e)"
        @mouseleave="(e: Event) => clearHoverBg(e)"
      >
        <div class="mb-2 flex items-center gap-1">
          <FileText class="admin-top-tile-icon mb-0 text-dp-text-secondary" />
          <ExternalLink class="hidden sm:block w-3 h-3 text-dp-text-muted" />
        </div>
        <span class="admin-top-tile-label text-dp-text-primary">{{ t('admin.nav.apiDocs') }}</span>
      </a>
    </div>

    <!-- Page Header -->
    <div class="mb-6">
      <h1 class="text-2xl font-bold text-dp-text-primary">
        {{ t('admin.devPlayground.title') }}
      </h1>
      <p class="mt-1 text-dp-text-secondary">
        {{ t('admin.devPlayground.description') }}
      </p>
    </div>

    <!-- Example Section -->
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

<style scoped>
.admin-top-tile {
  display: flex;
  min-width: 0;
  min-height: 5.2rem;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border-radius: 1rem;
  padding: 0.75rem 0.4rem;
  text-align: center;
  transition:
    background-color 160ms ease,
    box-shadow 180ms ease,
    transform 180ms ease;
}

.admin-top-tile-active {
  background-color: var(--dp-modal-header-bg);
}

.admin-top-tile-icon {
  width: 1.15rem;
  height: 1.15rem;
  margin-bottom: 0.5rem;
  flex-shrink: 0;
}

.admin-top-tile-label {
  font-size: 0.72rem;
  line-height: 1.1rem;
  font-weight: 700;
  word-break: keep-all;
}

@media (hover: hover) {
  .admin-top-tile:hover {
    transform: translateY(-1px);
    background-color: var(--dp-bg-hover);
  }

  .admin-top-tile-active:hover {
    background-color: var(--dp-bg-footer);
  }
}

@media (min-width: 640px) {
  .admin-top-tile {
    min-height: auto;
    align-items: flex-start;
    padding: 1rem;
    text-align: left;
  }

  .admin-top-tile-icon {
    width: 1.5rem;
    height: 1.5rem;
  }

  .admin-top-tile-label {
    font-size: 1rem;
    line-height: 1.4rem;
  }
}
</style>
