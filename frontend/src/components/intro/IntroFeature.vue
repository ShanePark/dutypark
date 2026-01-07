<script setup lang="ts">
import { ref, inject, computed, type Ref } from 'vue'
import { useScrollProgress } from '@/composables/useScrollProgress'
import {
  CalendarDays,
  ListTodo,
  Clock,
  Users,
  Heart,
  Flag,
  Sun,
} from 'lucide-vue-next'

export interface Feature {
  id: string
  icon: string
  title: string
  description: string
  mockupType: 'placeholder' | 'image'
  mockupSrc?: string
}

const props = defineProps<{
  feature: Feature
  index: number
  reverse?: boolean
}>()

const sectionRef = ref<HTMLElement | null>(null)
const containerRef = inject<Ref<HTMLElement | null>>('introContainer', ref(null))

const { progress } = useScrollProgress(sectionRef, containerRef, {
  start: 0,
  end: 0.7
})

// Text: slides up and fades in
const textStyle = computed(() => {
  const p = progress.value
  const translateY = (1 - p) * 60 // Start 60px down, move to 0
  const opacity = p // Fade in as progress increases

  return {
    transform: `translateY(${translateY}px)`,
    opacity: opacity
  }
})

// Mockup: scale up and slide up with 3D effect
const mockupStyle = computed(() => {
  const p = progress.value
  const scale = 0.8 + (p * 0.2) // Start at 0.8, scale to 1.0
  const translateY = (1 - p) * 80 // Start 80px down
  const opacity = p
  const rotateX = (1 - p) * 8 // Slight 3D tilt that reduces to 0

  return {
    transform: `translateY(${translateY}px) scale(${scale}) perspective(1000px) rotateX(${rotateX}deg)`,
    opacity: opacity
  }
})

// Icon: scale with slight bounce
const iconStyle = computed(() => {
  const p = progress.value
  // Overshoot then settle
  const scale = p < 0.8 ? p * 1.25 : 1 + (1 - p) * 0.5

  return {
    transform: `scale(${Math.min(1, scale)})`,
    opacity: Math.min(1, p * 1.5)
  }
})

const iconComponents: Record<string, typeof CalendarDays> = {
  calendar: CalendarDays,
  check: ListTodo,
  clock: Clock,
  users: Users,
  heart: Heart,
  flag: Flag,
  sun: Sun,
}
</script>

<template>
  <section ref="sectionRef" class="intro-feature-section">
    <div
      class="intro-feature-content"
      :class="{ reverse: reverse }"
    >
      <div
        class="intro-feature-text"
        :style="textStyle"
      >
        <div class="intro-feature-icon" :style="iconStyle">
          <component :is="iconComponents[feature.icon]" />
        </div>

        <h2 class="intro-feature-title">
          {{ feature.title }}
        </h2>

        <p class="intro-feature-description">
          {{ feature.description }}
        </p>
      </div>

      <div
        class="intro-feature-mockup"
        :style="mockupStyle"
      >
        <div class="intro-mockup-container">
          <img
            v-if="feature.mockupType === 'image' && feature.mockupSrc"
            :src="feature.mockupSrc"
            :alt="`${feature.title} 미리보기`"
          />

          <div v-else class="intro-mockup-placeholder">
            <component :is="iconComponents[feature.icon]" />
            <span class="text-sm font-medium" :style="{ color: 'var(--dp-text-muted)' }">
              {{ feature.title }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
