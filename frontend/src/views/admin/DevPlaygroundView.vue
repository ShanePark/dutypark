<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
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
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
      <router-link
        to="/admin"
        class="rounded-xl p-4 transition bg-dp-bg-card border border-dp-border-primary"
        @mouseover="(e: Event) => setHoverBg(e)"
        @mouseleave="(e: Event) => clearHoverBg(e)"
      >
        <Users class="w-6 h-6 mb-2 text-dp-text-secondary" />
        <span class="font-medium text-dp-text-primary">회원 관리</span>
      </router-link>
      <router-link
        to="/admin/teams"
        class="rounded-xl p-4 transition bg-dp-bg-card border border-dp-border-primary"
        @mouseover="(e: Event) => setHoverBg(e)"
        @mouseleave="(e: Event) => clearHoverBg(e)"
      >
        <Building2 class="w-6 h-6 mb-2 text-dp-text-secondary" />
        <span class="font-medium text-dp-text-primary">팀 관리</span>
      </router-link>
      <router-link
        to="/admin/dev"
        class="bg-dp-surface-strong text-dp-text-on-dark rounded-xl p-4 hover:bg-dp-surface-strong-hover transition"
      >
        <Code2 class="w-6 h-6 mb-2 text-dp-text-on-dark" />
        <span class="font-medium text-dp-text-on-dark">개발</span>
      </router-link>
      <a
        href="/docs/index.html"
        target="_blank"
        class="rounded-xl p-4 transition bg-dp-bg-card border border-dp-border-primary"
        @mouseover="(e: Event) => setHoverBg(e)"
        @mouseleave="(e: Event) => clearHoverBg(e)"
      >
        <div class="flex items-center gap-1 mb-2">
          <FileText class="w-6 h-6 text-dp-text-secondary" />
          <ExternalLink class="w-3 h-3 text-dp-text-muted" />
        </div>
        <span class="font-medium text-dp-text-primary">API 문서</span>
      </a>
    </div>

    <!-- Page Header -->
    <div class="mb-6">
      <h1 class="text-2xl font-bold text-dp-text-primary">
        개발 플레이그라운드
      </h1>
      <p class="mt-1 text-dp-text-secondary">
        컴포넌트를 테스트하고 비교해볼 수 있는 공간입니다.
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
          예제 섹션
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
          여기에 테스트할 컴포넌트를 추가하세요.
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
