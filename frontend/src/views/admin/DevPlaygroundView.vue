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

const expandedSections = ref<Set<string>>(new Set(['example']))

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
        class="rounded-xl p-4 transition"
        :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }"
        @mouseover="(e: Event) => setHoverBg(e)"
        @mouseleave="(e: Event) => clearHoverBg(e)"
      >
        <Users class="w-6 h-6 mb-2" :style="{ color: 'var(--dp-text-secondary)' }" />
        <span class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">회원 관리</span>
      </router-link>
      <router-link
        to="/admin/teams"
        class="rounded-xl p-4 transition"
        :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }"
        @mouseover="(e: Event) => setHoverBg(e)"
        @mouseleave="(e: Event) => clearHoverBg(e)"
      >
        <Building2 class="w-6 h-6 mb-2" :style="{ color: 'var(--dp-text-secondary)' }" />
        <span class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">팀 관리</span>
      </router-link>
      <router-link
        to="/admin/dev"
        class="bg-gray-700 text-white rounded-xl p-4 hover:bg-gray-800 transition"
      >
        <Code2 class="w-6 h-6 mb-2 text-white" />
        <span class="font-medium text-white">개발</span>
      </router-link>
      <a
        href="/docs/index.html"
        target="_blank"
        class="rounded-xl p-4 transition"
        :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }"
        @mouseover="(e: Event) => setHoverBg(e)"
        @mouseleave="(e: Event) => clearHoverBg(e)"
      >
        <div class="flex items-center gap-1 mb-2">
          <FileText class="w-6 h-6" :style="{ color: 'var(--dp-text-secondary)' }" />
          <ExternalLink class="w-3 h-3" :style="{ color: 'var(--dp-text-muted)' }" />
        </div>
        <span class="font-medium" :style="{ color: 'var(--dp-text-primary)' }">API 문서</span>
      </a>
    </div>

    <!-- Page Header -->
    <div class="mb-6">
      <h1 class="text-2xl font-bold" :style="{ color: 'var(--dp-text-primary)' }">
        개발 플레이그라운드
      </h1>
      <p class="mt-1" :style="{ color: 'var(--dp-text-secondary)' }">
        컴포넌트를 테스트하고 비교해볼 수 있는 공간입니다.
      </p>
    </div>

    <!-- Example Section -->
    <div
      class="rounded-xl mb-4"
      :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }"
    >
      <button
        class="w-full p-4 flex items-center justify-between cursor-pointer"
        @click="toggleSection('example')"
      >
        <h2 class="text-lg font-semibold" :style="{ color: 'var(--dp-text-primary)' }">
          예제 섹션
        </h2>
        <component
          :is="expandedSections.has('example') ? ChevronDown : ChevronRight"
          class="w-5 h-5"
          :style="{ color: 'var(--dp-text-muted)' }"
        />
      </button>
      <div
        v-if="expandedSections.has('example')"
        class="p-4"
        :style="{ borderTop: '1px solid var(--dp-border-primary)' }"
      >
        <p :style="{ color: 'var(--dp-text-secondary)' }">
          여기에 테스트할 컴포넌트를 추가하세요.
        </p>
        <div class="mt-4 p-4 rounded-lg" :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }">
          <code :style="{ color: 'var(--dp-text-primary)' }">
            &lt;YourComponent /&gt;
          </code>
        </div>
      </div>
    </div>

    <!-- Add more sections as needed -->
    <div
      class="rounded-xl"
      :style="{ backgroundColor: 'var(--dp-bg-card)', border: '1px solid var(--dp-border-primary)' }"
    >
      <button
        class="w-full p-4 flex items-center justify-between cursor-pointer"
        @click="toggleSection('buttons')"
      >
        <h2 class="text-lg font-semibold" :style="{ color: 'var(--dp-text-primary)' }">
          버튼 스타일
        </h2>
        <component
          :is="expandedSections.has('buttons') ? ChevronDown : ChevronRight"
          class="w-5 h-5"
          :style="{ color: 'var(--dp-text-muted)' }"
        />
      </button>
      <div
        v-if="expandedSections.has('buttons')"
        class="p-4"
        :style="{ borderTop: '1px solid var(--dp-border-primary)' }"
      >
        <div class="flex flex-wrap gap-3">
          <button class="px-4 py-2 bg-gray-900 text-white rounded-lg hover:bg-gray-800 transition cursor-pointer">
            Primary
          </button>
          <button
            class="px-4 py-2 rounded-lg transition cursor-pointer"
            :style="{ backgroundColor: 'var(--dp-bg-tertiary)', color: 'var(--dp-text-primary)' }"
          >
            Secondary
          </button>
          <button class="px-4 py-2 text-red-600 bg-red-50 hover:bg-red-100 rounded-lg transition cursor-pointer">
            Danger
          </button>
          <button class="px-4 py-2 text-green-600 bg-green-50 hover:bg-green-100 rounded-lg transition cursor-pointer">
            Success
          </button>
          <button class="px-4 py-2 text-yellow-600 bg-yellow-50 hover:bg-yellow-100 rounded-lg transition cursor-pointer">
            Warning
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
