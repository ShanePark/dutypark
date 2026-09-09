<script setup lang="ts">
import { ref, provide, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import '@/styles/intro.css'
import IntroHero from './IntroHero.vue'
import IntroShowcase, { type Feature } from './IntroShowcase.vue'
import IntroCTA from './IntroCTA.vue'
import LocaleSwitcher from '@/components/layout/LocaleSwitcher.vue'
import ThemeSwitcher from '@/components/layout/ThemeSwitcher.vue'

const containerRef = ref<HTMLElement | null>(null)
const { t } = useI18n()
provide('introContainer', containerRef)

const features = computed<Feature[]>(() => [
  {
    id: 'share',
    icon: 'heart',
    title: t('intro.features.share.title'),
    descriptionLines: [
      t('intro.features.share.descriptionLine1'),
      t('intro.features.share.descriptionLine2'),
    ],
    mockupType: 'image',
    mockupSrc: '/img/intro/schedule.png',
  },
  {
    id: 'duty',
    icon: 'clock',
    title: t('intro.features.duty.title'),
    descriptionLines: [
      t('intro.features.duty.descriptionLine1'),
      t('intro.features.duty.descriptionLine2'),
    ],
    mockupType: 'image',
    mockupSrc: '/img/intro/duty.png',
  },
  {
    id: 'life',
    icon: 'users',
    title: t('intro.features.life.title'),
    descriptionLines: [
      t('intro.features.life.descriptionLine1'),
      t('intro.features.life.descriptionLine2'),
    ],
    mockupType: 'image',
    mockupSrc: '/img/intro/life.png',
  },
  {
    id: 'todo',
    icon: 'check',
    title: t('intro.features.todo.title'),
    descriptionLines: [
      t('intro.features.todo.descriptionLine1'),
      t('intro.features.todo.descriptionLine2'),
    ],
    mockupType: 'image',
    mockupSrc: '/img/intro/todo.png',
  },
  {
    id: 'dday',
    icon: 'flag',
    title: t('intro.features.dday.title'),
    descriptionLines: [
      t('intro.features.dday.descriptionLine1'),
      t('intro.features.dday.descriptionLine2'),
    ],
    mockupType: 'image',
    mockupSrc: '/img/intro/dday.png',
  },
  {
    id: 'holiday',
    icon: 'sun',
    title: t('intro.features.holiday.title'),
    descriptionLines: [
      t('intro.features.holiday.descriptionLine1'),
      t('intro.features.holiday.descriptionLine2'),
    ],
    mockupType: 'image',
    mockupSrc: '/img/intro/holiday.png',
  },
])
</script>

<template>
  <div class="intro-shell">
    <div class="intro-controls">
      <LocaleSwitcher />
      <ThemeSwitcher />
    </div>

    <div ref="containerRef" class="intro-container">
      <IntroHero />

      <IntroShowcase :features="features" />

      <IntroCTA />
    </div>
  </div>
</template>

<style scoped>
.intro-shell {
  position: relative;
}

.intro-controls {
  position: absolute;
  top: max(1rem, env(safe-area-inset-top));
  right: max(1rem, env(safe-area-inset-right));
  z-index: 200;
  display: flex;
  align-items: center;
  gap: 0.125rem;
}

/* The header's mobile suggestion offset does not apply to this right-aligned control. */
.intro-controls :deep(.locale-suggestion) {
  right: 0;
  max-width: calc(100vw - 2rem);
}

.intro-container {
  height: 100vh;
  height: 100svh;
  overflow-x: hidden;
  overflow-y: auto;
  scroll-behavior: smooth;
}
@media (prefers-reduced-motion: reduce) {
  .intro-container {
    scroll-behavior: auto;
  }
}
</style>
