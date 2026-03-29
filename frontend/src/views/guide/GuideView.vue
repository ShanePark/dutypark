<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import {
  BookOpen,
  Home,
  ArrowLeft,
  Calendar,
  Users,
  UserPlus,
  Settings,
  CalendarCheck,
  ClipboardList,
  Search,
  FileSpreadsheet,
  Eye,
  Shield,
  Smartphone,
  Link,
  Lock,
  Sun,
  Moon,
  ChevronDown,
  ChevronUp,
  Building2,
  Pencil,
  Plus,
  Trash2,
  Bell,
  Sparkles,
  Camera,
  Palette,
  UserCog,
} from 'lucide-vue-next'

type GuideIcon = typeof Home

interface GuideCard {
  id: string
  title: string
  icon: GuideIcon
  iconClass: string
  items: string[]
}

interface GuideSection {
  id: GuideSectionId
  title: string
  icon: GuideIcon
  iconClass: string
  isOpen: boolean
  summary: string
  cards: GuideCard[]
}

const { t, tm } = useI18n()

const sectionConfigs = [
  {
    id: 'dashboard',
    icon: Home,
    iconClass: 'text-dp-accent',
    cards: [
      { id: 'today', icon: Calendar, iconClass: 'text-dp-accent' },
      { id: 'friends', icon: Users, iconClass: 'text-dp-text-secondary' },
    ],
  },
  {
    id: 'calendar',
    icon: Calendar,
    iconClass: 'text-dp-success',
    cards: [
      { id: 'duty', icon: Pencil, iconClass: 'text-dp-warning' },
      { id: 'excel', icon: FileSpreadsheet, iconClass: 'text-dp-success' },
      { id: 'schedule', icon: Plus, iconClass: 'text-dp-accent' },
      { id: 'ai', icon: Sparkles, iconClass: 'text-dp-accent-light' },
      { id: 'visibility', icon: Eye, iconClass: 'text-dp-success' },
      { id: 'dday', icon: CalendarCheck, iconClass: 'text-dp-accent-light' },
      { id: 'todo', icon: ClipboardList, iconClass: 'text-dp-accent' },
      { id: 'search', icon: Search, iconClass: 'text-dp-text-secondary' },
      { id: 'together', icon: Users, iconClass: 'text-dp-success' },
      { id: 'others', icon: UserPlus, iconClass: 'text-dp-accent-light' },
    ],
  },
  {
    id: 'team',
    icon: Building2,
    iconClass: 'text-dp-accent-light',
    cards: [
      { id: 'calendar', icon: Calendar, iconClass: 'text-dp-accent-light' },
      { id: 'staff', icon: Users, iconClass: 'text-dp-accent' },
      { id: 'schedule', icon: Plus, iconClass: 'text-dp-success' },
      { id: 'members', icon: UserCog, iconClass: 'text-dp-accent' },
      { id: 'dutyTypes', icon: Palette, iconClass: 'text-dp-accent-light' },
      { id: 'excel', icon: FileSpreadsheet, iconClass: 'text-dp-success' },
    ],
  },
  {
    id: 'friends',
    icon: UserPlus,
    iconClass: 'text-dp-warning',
    cards: [
      { id: 'add', icon: UserPlus, iconClass: 'text-dp-accent' },
      { id: 'requests', icon: Bell, iconClass: 'text-dp-danger' },
      { id: 'family', icon: Home, iconClass: 'text-dp-warning' },
      { id: 'pinning', icon: Users, iconClass: 'text-dp-warning' },
      { id: 'remove', icon: Trash2, iconClass: 'text-dp-danger' },
    ],
  },
  {
    id: 'settings',
    icon: Settings,
    iconClass: 'text-dp-text-muted',
    cards: [
      { id: 'photo', icon: Camera, iconClass: 'text-dp-accent-light' },
      { id: 'visibility', icon: Eye, iconClass: 'text-dp-accent' },
      { id: 'theme', icon: Sun, iconClass: 'text-dp-warning' },
      { id: 'delegation', icon: Shield, iconClass: 'text-dp-success' },
      { id: 'sessions', icon: Smartphone, iconClass: 'text-dp-accent-light' },
      { id: 'social', icon: Link, iconClass: 'text-dp-warning' },
      { id: 'password', icon: Lock, iconClass: 'text-dp-text-secondary' },
    ],
  },
] as const

type GuideSectionId = (typeof sectionConfigs)[number]['id']

const sectionState = ref<Record<GuideSectionId, boolean>>({
  dashboard: true,
  calendar: false,
  team: false,
  friends: false,
  settings: false,
})

function getItems(key: string): string[] {
  const items = tm(key)
  return Array.isArray(items) ? items.map(item => String(item)) : []
}

const guideSections = computed<GuideSection[]>(() => {
  return sectionConfigs.map(section => ({
    id: section.id,
    title: t(`guide.sections.${section.id}.title`),
    icon: section.icon,
    iconClass: section.iconClass,
    isOpen: sectionState.value[section.id],
    summary: t(`guide.sections.${section.id}.summary`),
    cards: section.cards.map(card => ({
      id: card.id,
      title: t(`guide.sections.${section.id}.cards.${card.id}.title`),
      icon: card.icon,
      iconClass: card.iconClass,
      items: getItems(`guide.sections.${section.id}.cards.${card.id}.items`),
    })),
  }))
})

function toggleSection(id: GuideSectionId) {
  sectionState.value[id] = !sectionState.value[id]
}

function openAllSections() {
  sectionState.value = {
    dashboard: true,
    calendar: true,
    team: true,
    friends: true,
    settings: true,
  }
}

function closeAllSections() {
  sectionState.value = {
    dashboard: false,
    calendar: false,
    team: false,
    friends: false,
    settings: false,
  }
}
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <div class="mb-8">
      <router-link
        to="/"
        class="inline-flex items-center gap-1.5 mb-4 text-sm transition-colors hover:opacity-80 text-dp-text-secondary"
      >
        <ArrowLeft class="w-4 h-4" />
        {{ t('common.navigation.backHome') }}
      </router-link>

      <div class="flex items-center gap-3 mb-4">
        <div class="w-12 h-12 bg-gradient-to-br from-dp-accent to-dp-accent-hover rounded-xl flex items-center justify-center">
          <BookOpen class="w-6 h-6 text-dp-text-on-dark" />
        </div>
        <div>
          <h1 class="text-2xl font-bold text-dp-text-primary">{{ t('guide.title') }}</h1>
          <p class="text-sm text-dp-text-secondary">{{ t('guide.description') }}</p>
        </div>
      </div>

      <div class="flex gap-2">
        <button
          @click="openAllSections"
          class="px-3 py-1.5 text-sm rounded-lg border transition hover:bg-opacity-80 cursor-pointer border-dp-border-secondary text-dp-text-secondary"
        >
          {{ t('guide.actions.expandAll') }}
        </button>
        <button
          @click="closeAllSections"
          class="px-3 py-1.5 text-sm rounded-lg border transition hover:bg-opacity-80 cursor-pointer border-dp-border-secondary text-dp-text-secondary"
        >
          {{ t('guide.actions.collapseAll') }}
        </button>
      </div>
    </div>

    <div class="space-y-4">
      <section
        v-for="section in guideSections"
        :key="section.id"
        class="rounded-xl border shadow-sm overflow-hidden bg-dp-bg-card border-dp-border-primary"
      >
        <button
          @click="toggleSection(section.id)"
          class="w-full px-5 py-4 flex items-center justify-between cursor-pointer hover:bg-opacity-50 transition bg-dp-bg-secondary"
        >
          <div class="flex items-center gap-3">
            <component :is="section.icon" class="w-5 h-5" :class="section.iconClass" />
            <span class="font-semibold text-dp-text-primary">{{ section.title }}</span>
          </div>
          <ChevronUp
            v-if="section.isOpen"
            class="w-5 h-5"
            :style="{ color: 'var(--dp-text-muted)' }"
          />
          <ChevronDown v-else class="w-5 h-5 text-dp-text-muted" />
        </button>

        <div v-if="section.isOpen" class="p-5 space-y-6">
          <p class="text-dp-text-secondary">{{ section.summary }}</p>

          <div class="space-y-4">
            <div
              v-for="card in section.cards"
              :key="`${section.id}-${card.id}`"
              class="p-4 rounded-lg bg-dp-bg-secondary"
            >
              <h4 class="font-medium mb-2 flex items-center gap-2 text-dp-text-primary">
                <component :is="card.icon" class="w-4 h-4" :class="card.iconClass" />
                {{ card.title }}
              </h4>
              <ul class="text-sm space-y-1.5 ml-6 text-dp-text-secondary">
                <li v-for="(item, itemIndex) in card.items" :key="itemIndex">{{ item }}</li>
              </ul>
            </div>
          </div>
        </div>
      </section>
    </div>

    <div class="mt-8 p-4 rounded-lg text-center bg-dp-bg-secondary">
      <p class="text-sm text-dp-text-muted">
        {{ t('guide.footer') }}
      </p>
    </div>
  </div>
</template>
