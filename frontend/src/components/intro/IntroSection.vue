<script setup lang="ts">
import { ref, provide, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import '@/styles/intro.css'
import IntroHero from './IntroHero.vue'
import IntroShowcase, { type Feature } from './IntroShowcase.vue'
import IntroCTA from './IntroCTA.vue'

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
    mockupType: 'placeholder',
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
  <div ref="containerRef" class="intro-container">
    <IntroHero />

    <IntroShowcase :features="features" />

    <IntroCTA />
  </div>
</template>

<style scoped>
.intro-container {
  height: 100vh;
  overflow-x: hidden;
  overflow-y: auto;
  scroll-behavior: smooth;
}
</style>
