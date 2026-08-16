<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import type { ReleaseNoteCategory } from '@/api/publicContent'
import { useAuthStore } from '@/stores/auth'
import { useLocaleStore } from '@/stores/locale'
import { formatPublicContentLabel } from './publicContentLabel'
import { useGuideContent } from './useGuideContent'
import {
  resolveGuideIcon,
  resolveGuideToneClass,
  type GuideIconComponent,
} from './guideVisuals'
import {
  BookOpen,
  ArrowLeft,
  ChevronDown,
  ChevronUp,
  History,
  ExternalLink,
  Loader2,
  RotateCcw,
} from 'lucide-vue-next'

interface GuideCardView {
  id: string
  title: string
  icon: GuideIconComponent
  iconClass: string
  items: string[]
}

interface GuideSectionView {
  id: string
  title: string
  icon: GuideIconComponent
  iconClass: string
  isOpen: boolean
  summary: string
  cards: GuideCardView[]
}

const { t } = useI18n()
const authStore = useAuthStore()
const localeStore = useLocaleStore()
const {
  guideContent,
  releaseNotesContent,
  guideLoading,
  guideError,
  releaseNotesLoading,
  releaseNotesError,
  releaseNotesLoadingMore,
  releaseNotesLoadMoreError,
  hasMoreReleaseNotes,
  load,
  retryGuide,
  retryReleaseNotes,
  loadMoreReleaseNotes: fetchMoreReleaseNotes,
  retryLoadMoreReleaseNotes,
} = useGuideContent()

const sectionState = ref<Record<string, boolean>>({
  dashboard: true,
  calendar: false,
  team: false,
  friends: false,
  settings: false,
})
const releaseNotesPageSize = 5
const isReleaseNotesOpen = ref(false)
const visibleReleaseNotesCount = ref(releaseNotesPageSize)

const categoryClassMap: Record<ReleaseNoteCategory, string> = {
  feature: 'bg-dp-accent-soft text-dp-accent border-dp-accent-border',
  improvement: 'bg-dp-success-soft text-dp-success border-dp-success-border',
  fix: 'bg-dp-danger-soft text-dp-danger border-dp-danger-border',
  maintenance: 'bg-dp-bg-tertiary text-dp-text-secondary border-dp-border-secondary',
  security: 'bg-dp-warning-soft text-dp-warning border-dp-warning-border',
}

function formatReleaseDate(date: string) {
  return date.split('-').join('.')
}

const visibleReleaseNotes = computed(() => {
  return (releaseNotesContent.value?.items ?? []).slice(0, visibleReleaseNotesCount.value)
})

const hasMoreVisibleReleaseNotes = computed(() => {
  const loadedCount = releaseNotesContent.value?.items.length ?? 0
  return visibleReleaseNotesCount.value < loadedCount || hasMoreReleaseNotes.value
})

const releaseNotesHeaderTitle = computed(() => {
  if (releaseNotesContent.value) {
    return releaseNotesContent.value.labels.title
  }
  return releaseNotesError.value
    ? t('guide.status.releaseNotesLoadFailed')
    : t('guide.status.loadingReleaseNotes')
})

const guideSections = computed<GuideSectionView[]>(() => {
  const sections = guideContent.value?.sections ?? []

  return sections.map((section, sectionIndex) => {
    const defaultOpen = sectionIndex === 0

    return {
      id: section.id,
      title: section.title,
      icon: resolveGuideIcon(section.icon),
      iconClass: resolveGuideToneClass(section.tone),
      isOpen: sectionState.value[section.id] ?? defaultOpen,
      summary: section.summary,
      cards: section.cards.map(card => ({
        id: card.id,
        title: card.title,
        icon: resolveGuideIcon(card.icon),
        iconClass: resolveGuideToneClass(card.tone),
        items: card.items,
      })),
    }
  })
})

function toggleSection(id: string) {
  const section = guideSections.value.find(item => item.id === id)
  sectionState.value[id] = !(section?.isOpen ?? false)
}

function toggleReleaseNotes() {
  isReleaseNotesOpen.value = !isReleaseNotesOpen.value
  if (!isReleaseNotesOpen.value) {
    visibleReleaseNotesCount.value = releaseNotesPageSize
  }
}

async function loadMoreReleaseNotes() {
  const loadedCount = releaseNotesContent.value?.items.length ?? 0
  if (visibleReleaseNotesCount.value < loadedCount) {
    visibleReleaseNotesCount.value = Math.min(
      visibleReleaseNotesCount.value + releaseNotesPageSize,
      loadedCount,
    )
    return
  }

  await fetchMoreReleaseNotes()
  visibleReleaseNotesCount.value = Math.min(
    visibleReleaseNotesCount.value + releaseNotesPageSize,
    releaseNotesContent.value?.items.length ?? 0,
  )
}

async function retryLoadingMoreReleaseNotes() {
  await retryLoadMoreReleaseNotes()
  visibleReleaseNotesCount.value = Math.min(
    visibleReleaseNotesCount.value + releaseNotesPageSize,
    releaseNotesContent.value?.items.length ?? 0,
  )
}

function openAllSections() {
  isReleaseNotesOpen.value = true
  visibleReleaseNotesCount.value = releaseNotesPageSize
  sectionState.value = Object.fromEntries(guideSections.value.map(section => [section.id, true]))
}

function closeAllSections() {
  isReleaseNotesOpen.value = false
  visibleReleaseNotesCount.value = releaseNotesPageSize
  sectionState.value = Object.fromEntries(guideSections.value.map(section => [section.id, false]))
}

watch(
  () => localeStore.locale,
  locale => {
    visibleReleaseNotesCount.value = releaseNotesPageSize
    void load(locale)
  },
  { immediate: true },
)
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <div class="mb-8">
      <router-link
        v-if="!authStore.isLoggedIn"
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
          <h1 class="text-2xl font-bold text-dp-text-primary">
            {{ guideContent?.title ?? t('header.menu.guide') }}
          </h1>
          <p v-if="guideContent" class="text-sm text-dp-text-secondary">
            {{ guideContent.description }}
          </p>
        </div>
      </div>

      <div v-if="guideContent" class="flex gap-2">
        <button
          @click="openAllSections"
          class="px-3 py-1.5 text-sm rounded-lg border transition hover:bg-opacity-80 cursor-pointer border-dp-border-secondary text-dp-text-secondary"
        >
          {{ guideContent.actions.expandAll }}
        </button>
        <button
          @click="closeAllSections"
          class="px-3 py-1.5 text-sm rounded-lg border transition hover:bg-opacity-80 cursor-pointer border-dp-border-secondary text-dp-text-secondary"
        >
          {{ guideContent.actions.collapseAll }}
        </button>
      </div>
    </div>

    <div class="space-y-4">
      <div
        v-if="guideLoading && !guideContent"
        class="flex min-h-40 items-center justify-center rounded-xl border bg-dp-bg-card border-dp-border-primary"
      >
        <div class="flex items-center gap-2 text-sm text-dp-text-secondary">
          <Loader2 class="h-5 w-5 animate-spin" />
          {{ t('guide.status.loadingGuide') }}
        </div>
      </div>

      <div
        v-else-if="guideError && !guideContent"
        class="rounded-xl border p-6 text-center bg-dp-bg-card border-dp-border-primary"
      >
        <p class="mb-4 text-sm text-dp-text-secondary">{{ t('guide.status.guideLoadFailed') }}</p>
        <button
          type="button"
          class="mx-auto inline-flex min-h-[44px] items-center gap-2 rounded-lg border px-4 py-2 text-sm text-dp-accent border-dp-accent-border hover:bg-dp-accent-soft"
          @click="retryGuide"
        >
          <RotateCcw class="h-4 w-4" />
          {{ t('common.actions.retry') }}
        </button>
      </div>

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

      <section class="rounded-xl border shadow-sm overflow-hidden bg-dp-bg-card border-dp-border-primary">
        <button
          @click="toggleReleaseNotes"
          class="w-full px-5 py-4 flex items-center justify-between cursor-pointer hover:bg-opacity-50 transition bg-dp-bg-secondary"
        >
          <div class="min-w-0 flex flex-wrap items-center gap-3 text-left">
            <History class="w-5 h-5 text-dp-accent" />
            <span class="font-semibold text-dp-text-primary">
              {{ releaseNotesHeaderTitle }}
            </span>
            <span
              v-if="releaseNotesContent"
              class="rounded-full border px-2 py-1 text-xs border-dp-border-secondary text-dp-text-secondary"
            >
              {{ formatPublicContentLabel(releaseNotesContent.labels.count, {
                count: releaseNotesContent.totalElements,
              }) }}
            </span>
          </div>
          <ChevronUp
            v-if="isReleaseNotesOpen"
            class="w-5 h-5 shrink-0"
            :style="{ color: 'var(--dp-text-muted)' }"
          />
          <ChevronDown v-else class="w-5 h-5 shrink-0 text-dp-text-muted" />
        </button>

        <div v-if="isReleaseNotesOpen" class="p-5">
          <div
            v-if="releaseNotesLoading && !releaseNotesContent"
            class="flex min-h-32 items-center justify-center gap-2 text-sm text-dp-text-secondary"
          >
            <Loader2 class="h-5 w-5 animate-spin" />
            {{ t('guide.status.loadingReleaseNotes') }}
          </div>

          <div
            v-else-if="releaseNotesError && !releaseNotesContent"
            class="py-6 text-center"
          >
            <p class="mb-4 text-sm text-dp-text-secondary">
              {{ t('guide.status.releaseNotesLoadFailed') }}
            </p>
            <button
              type="button"
              class="mx-auto inline-flex min-h-[44px] items-center gap-2 rounded-lg border px-4 py-2 text-sm text-dp-accent border-dp-accent-border hover:bg-dp-accent-soft"
              @click="retryReleaseNotes"
            >
              <RotateCcw class="h-4 w-4" />
              {{ t('common.actions.retry') }}
            </button>
          </div>

          <div v-else class="space-y-3">
            <article
              v-for="(note, noteIndex) in visibleReleaseNotes"
              :key="note.id"
              class="rounded-lg border p-4 bg-dp-bg-secondary border-dp-border-primary"
            >
              <div class="mb-3 flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                <div class="flex flex-wrap items-center gap-2">
                  <span class="font-semibold text-dp-text-primary">{{ note.version }}</span>
                  <span
                    v-if="noteIndex === 0"
                    class="rounded-full border px-2 py-1 text-xs bg-dp-accent-soft text-dp-accent border-dp-accent-border"
                  >
                    {{ releaseNotesContent?.labels.latest }}
                  </span>
                  <span
                    class="rounded-full border px-2 py-1 text-xs"
                    :class="categoryClassMap[note.category]"
                  >
                    {{ releaseNotesContent?.labels.categoryLabels[note.category] ?? note.category }}
                  </span>
                  <span class="text-xs text-dp-text-muted">{{ formatReleaseDate(note.date) }}</span>
                </div>

                <a
                  :href="note.url"
                  target="_blank"
                  rel="noreferrer"
                  class="inline-flex min-h-[44px] items-center gap-1.5 self-start text-sm transition-colors text-dp-accent hover:text-dp-accent-hover"
                >
                  {{ formatPublicContentLabel(releaseNotesContent?.labels.pr ?? '', {
                    number: note.pr,
                  }) }}
                  <ExternalLink class="w-4 h-4" />
                </a>
              </div>

              <h3 class="mb-2 text-base font-semibold text-dp-text-primary">{{ note.title }}</h3>
              <p class="mb-3 text-sm leading-6 text-dp-text-secondary">{{ note.summary }}</p>

              <ul class="mb-3 ml-5 list-disc space-y-1.5 text-sm leading-6 text-dp-text-secondary">
                <li v-for="(change, changeIndex) in note.changes" :key="changeIndex">{{ change }}</li>
              </ul>

              <div class="flex flex-wrap items-center gap-2">
                <span class="text-xs text-dp-text-muted">
                  {{ releaseNotesContent?.labels.areas }}
                </span>
                <span
                  v-for="area in note.areas"
                  :key="`${note.id}-${area}`"
                  class="rounded-full border px-2 py-1 text-xs border-dp-border-secondary text-dp-text-secondary"
                >
                  {{ releaseNotesContent?.labels.areaLabels[area] ?? area }}
                </span>
              </div>
            </article>

            <div
              v-if="releaseNotesLoadMoreError"
              class="rounded-lg border p-4 text-center border-dp-danger-border bg-dp-danger-soft"
            >
              <p class="mb-3 text-sm text-dp-danger">
                {{ t('guide.status.releaseNotesLoadMoreFailed') }}
              </p>
              <button
                type="button"
                class="mx-auto inline-flex min-h-[44px] items-center gap-2 rounded-lg border px-4 py-2 text-sm text-dp-danger border-dp-danger-border"
                :disabled="releaseNotesLoadingMore"
                @click="retryLoadingMoreReleaseNotes"
              >
                <Loader2 v-if="releaseNotesLoadingMore" class="h-4 w-4 animate-spin" />
                <RotateCcw v-else class="h-4 w-4" />
                {{ releaseNotesLoadingMore ? t('guide.status.loadingReleaseNotes') : t('common.actions.retry') }}
              </button>
            </div>

            <button
              v-if="hasMoreVisibleReleaseNotes && !releaseNotesLoadMoreError"
              type="button"
              class="mx-auto flex min-h-[44px] items-center justify-center rounded-lg border px-4 py-2 text-sm transition hover:bg-dp-bg-hover border-dp-border-secondary text-dp-text-secondary"
              :disabled="releaseNotesLoadingMore"
              @click="loadMoreReleaseNotes"
            >
              <Loader2 v-if="releaseNotesLoadingMore" class="mr-2 h-4 w-4 animate-spin" />
              {{ releaseNotesLoadingMore
                ? t('guide.status.loadingReleaseNotes')
                : releaseNotesContent?.labels.loadMore }}
            </button>
          </div>
        </div>
      </section>
    </div>

    <div v-if="guideContent" class="mt-8 p-4 rounded-lg text-center bg-dp-bg-secondary">
      <p class="text-sm text-dp-text-muted">
        {{ guideContent.footer }}
      </p>
    </div>
  </div>
</template>
