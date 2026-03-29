<script setup lang="ts">
import { ref, inject, computed, type Ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useScrollProgress } from '@/composables/useScrollProgress'
import { ChevronRight, Sparkles, BookOpen } from 'lucide-vue-next'

const sectionRef = ref<HTMLElement | null>(null)
const containerRef = inject<Ref<HTMLElement | null>>('introContainer', ref(null))
const { t } = useI18n()

const { progress } = useScrollProgress(sectionRef, containerRef, {
  start: 0,
  end: 0.7
})

const iconStyle = computed(() => {
  const p = progress.value
  const scale = 0.5 + (p * 0.5) // 0.5 to 1.0
  const rotate = (1 - p) * 180 // 180 to 0

  return {
    transform: `scale(${scale}) rotate(${rotate}deg)`,
    opacity: p
  }
})

const titleStyle = computed(() => {
  const p = progress.value
  const translateY = (1 - p) * 40

  return {
    transform: `translateY(${translateY}px)`,
    opacity: p
  }
})

const descStyle = computed(() => {
  const p = progress.value
  const translateY = (1 - p) * 30

  return {
    transform: `translateY(${translateY}px)`,
    opacity: Math.min(1, p * 1.2)
  }
})

const buttonStyle = computed(() => {
  const p = progress.value
  const translateY = (1 - p) * 20
  const scale = 0.95 + (p * 0.05)

  return {
    transform: `translateY(${translateY}px) scale(${scale})`,
    opacity: Math.min(1, p * 1.3)
  }
})

const guideLinkStyle = computed(() => {
  const p = progress.value
  const translateY = (1 - p) * 15

  return {
    transform: `translateY(${translateY}px)`,
    opacity: Math.min(1, p * 1.4)
  }
})
</script>

<template>
  <section ref="sectionRef" class="intro-cta-section">
    <div class="max-w-2xl mx-auto px-4">
      <div class="mb-6" :style="iconStyle">
        <div
          class="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-dp-bg-tertiary"
        >
          <Sparkles class="w-8 h-8 text-dp-text-primary" />
        </div>
      </div>

      <h2 class="intro-cta-title" :style="titleStyle">
        {{ t('intro.cta.title') }}
      </h2>

      <p
        class="mb-8"
        :style="{ ...descStyle, color: 'var(--dp-text-secondary)' }"
      >
        {{ t('intro.cta.descriptionLine1') }}<br>
        {{ t('intro.cta.descriptionLine2') }}
      </p>

      <router-link
        to="/auth/login"
        class="intro-cta-button"
        :style="buttonStyle"
      >
        {{ t('intro.cta.login') }}
        <ChevronRight class="w-5 h-5" />
      </router-link>

      <router-link
        to="/guide"
        class="intro-guide-link"
        :style="guideLinkStyle"
      >
        <BookOpen class="w-4 h-4" />
        {{ t('intro.cta.guide') }}
      </router-link>
    </div>
  </section>
</template>
