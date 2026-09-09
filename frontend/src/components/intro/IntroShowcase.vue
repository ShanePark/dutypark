<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, inject, type Component, type Ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { ListTodo, Clock, Users, Heart, Flag, Sun } from 'lucide-vue-next'
import { getShowcaseProgress, getTransitionProgress, getScreenOpacity } from './showcaseMotion'

export interface Feature {
  id: string
  icon: string
  title: string
  descriptionLines: string[]
  mockupType: 'placeholder' | 'image'
  mockupSrc?: string
}

const props = defineProps<{
  features: Feature[]
}>()

const showcaseRef = ref<HTMLElement | null>(null)
const containerRef = inject<Ref<HTMLElement | null>>('introContainer', ref(null))
const { t } = useI18n()
const activeIndex = ref(0)
const featureProgress = ref(0)
const reducedMotion = ref(false)

const iconComponents: Record<string, Component> = {
  check: ListTodo,
  clock: Clock,
  users: Users,
  heart: Heart,
  flag: Flag,
  sun: Sun,
}

function getDescriptionLines(index: number, feature: Feature) {
  const progress = reducedMotion.value || index < activeIndex.value
    ? 1
    : index === activeIndex.value ? featureProgress.value : 0

  return feature.descriptionLines.map((line, lineIndex) => {
    const lineStart = 0.15 + lineIndex * 0.25
    const lineProgress = Math.max(0, Math.min(1, (progress - lineStart) / 0.25))
    return {
      text: line.slice(0, Math.floor(lineProgress * line.length)),
      complete: lineProgress >= 1,
    }
  })
}

const transitionProgress = computed(() =>
  getTransitionProgress(activeIndex.value, featureProgress.value, props.features.length),
)

function getFeatureStyle(index: number) {
  if (reducedMotion.value) {
    return { opacity: index === activeIndex.value ? 1 : 0, transform: 'none' }
  }

  const diff = index - activeIndex.value
  const transition = transitionProgress.value
  const opacity = diff === 0 ? 1 - transition : diff === 1 ? transition : 0
  const translateY = diff === 0 ? -50 * transition : 50 * (1 - transition)
  return { opacity, transform: `translateY(${translateY}px)` }
}

function getMockupStyle(index: number) {
  return {
    opacity: reducedMotion.value
      ? (index === activeIndex.value ? 1 : 0)
      : getScreenOpacity(index, activeIndex.value, featureProgress.value, props.features.length),
  }
}

let rafId: number | null = null
let resizeObserver: ResizeObserver | null = null
let scrollContainer: HTMLElement | null = null
let motionQuery: MediaQueryList | null = null

function updateProgress() {
  if (!showcaseRef.value || !containerRef.value) return
  const containerRect = containerRef.value.getBoundingClientRect()
  const showcaseRect = showcaseRef.value.getBoundingClientRect()
  const state = getShowcaseProgress(
    showcaseRect.top - containerRect.top,
    showcaseRect.height,
    containerRef.value.clientHeight,
    props.features.length,
  )
  activeIndex.value = state.activeIndex
  featureProgress.value = state.featureProgress
}

function onScroll() {
  if (rafId !== null) return
  rafId = requestAnimationFrame(() => {
    rafId = null
    updateProgress()
  })
}

function onMotionChange(event: MediaQueryListEvent) {
  reducedMotion.value = event.matches
}

onMounted(() => {
  motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)')
  reducedMotion.value = motionQuery.matches
  motionQuery.addEventListener('change', onMotionChange)

  scrollContainer = containerRef.value
  if (!scrollContainer || !showcaseRef.value) return
  scrollContainer.addEventListener('scroll', onScroll, { passive: true })
  resizeObserver = new ResizeObserver(onScroll)
  resizeObserver.observe(scrollContainer)
  resizeObserver.observe(showcaseRef.value)
  updateProgress()
})

onUnmounted(() => {
  scrollContainer?.removeEventListener('scroll', onScroll)
  resizeObserver?.disconnect()
  motionQuery?.removeEventListener('change', onMotionChange)
  if (rafId !== null) cancelAnimationFrame(rafId)
})

const progressDots = computed(() => props.features.map((_, index) => ({
  isActive: index === activeIndex.value,
  isPassed: index < activeIndex.value,
})))

function scrollToFeature(index: number) {
  if (!showcaseRef.value || !containerRef.value || !props.features.length) return
  const container = containerRef.value
  const showcaseRect = showcaseRef.value.getBoundingClientRect()
  const containerRect = container.getBoundingClientRect()
  const showcaseTop = container.scrollTop + showcaseRect.top - containerRect.top
  const scrollableDistance = Math.max(0, showcaseRect.height - container.clientHeight)

  container.scrollTo({
    top: showcaseTop + index / props.features.length * scrollableDistance,
    behavior: reducedMotion.value ? 'instant' : 'smooth',
  })
}
</script>

<template>
  <section ref="showcaseRef" class="intro-showcase">
    <div class="intro-showcase-viewport">
      <div class="intro-showcase-progress">
        <button
          v-for="(dot, index) in progressDots"
          :key="index"
          type="button"
          class="progress-dot"
          :class="{ active: dot.isActive, passed: dot.isPassed }"
          :aria-current="dot.isActive ? 'step' : undefined"
          :aria-label="t('intro.hero.featureAriaLabel', { title: features[index]?.title ?? t('intro.hero.featureFallback') })"
          @click="scrollToFeature(index)"
        />
      </div>

      <div class="intro-showcase-stage">
        <div class="intro-showcase-text-stack">
          <div
            v-for="(feature, index) in features"
            :key="feature.id"
            class="intro-showcase-text"
            :style="getFeatureStyle(index)"
            :aria-hidden="index !== activeIndex"
          >
            <div class="intro-showcase-icon" aria-hidden="true">
              <component :is="iconComponents[feature.icon]" />
            </div>

            <h2 class="intro-showcase-title">{{ feature.title }}</h2>

            <div class="intro-showcase-description">
              <p
                v-for="(line, lineIdx) in getDescriptionLines(index, feature)"
                :key="lineIdx"
                class="description-line"
              >
                <span class="sr-only">{{ feature.descriptionLines[lineIdx] }}</span>
                <span class="description-line-size" aria-hidden="true">{{ feature.descriptionLines[lineIdx] }}</span>
                <span class="description-line-typed" aria-hidden="true">
                  <span class="typing-text">{{ line.text }}</span>
                  <span v-if="!line.complete && line.text.length > 0" class="typing-cursor">|</span>
                </span>
              </p>
            </div>
          </div>
        </div>

        <!-- The frame enters with the section's natural scroll, then stays pinned.
             Only its screens crossfade; text transforms and typing never move it. -->
        <div class="intro-showcase-mockup">
          <div class="intro-mockup-frame">
            <div
              v-for="(feature, index) in features"
              :key="feature.id"
              class="intro-mockup-screen"
              :style="getMockupStyle(index)"
              :aria-hidden="index !== activeIndex"
            >
              <img
                v-if="feature.mockupType === 'image' && feature.mockupSrc"
                :src="feature.mockupSrc"
                :alt="t('intro.hero.featureAlt', { title: feature.title })"
              />
              <div v-else class="intro-mockup-placeholder">
                <component :is="iconComponents[feature.icon]" />
                <span class="mockup-label">{{ feature.title }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.intro-showcase {
  height: calc(v-bind('features.length') * 100vh);
  height: calc(v-bind('features.length') * 100svh);
  position: relative;
}

.intro-showcase-viewport {
  position: sticky;
  top: 0;
  height: 100vh;
  height: 100svh;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.intro-showcase-progress {
  position: absolute;
  left: 0.75rem;
  top: 50%;
  transform: translateY(-50%);
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  z-index: 100;
}

@media (min-width: 768px) {
  .intro-showcase-progress {
    left: 2rem;
  }
}

.progress-dot {
  width: 8px;
  height: 8px;
  padding: 0;
  border: none;
  border-radius: 50%;
  background: var(--dp-border-primary);
  cursor: pointer;
  transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
}

.progress-dot:hover {
  background: var(--dp-text-secondary);
  transform: scale(1.3);
}

.progress-dot.active {
  background: var(--dp-text-primary);
  transform: scale(1.5);
}

.progress-dot.passed {
  background: var(--dp-text-muted);
}

.intro-showcase-stage {
  display: grid;
  grid-template-rows: auto minmax(0, 1fr);
  gap: 1.5rem;
  align-items: center;
  width: 100%;
  max-width: 1200px;
  height: 100%;
  padding: 4rem 2.5rem 2rem;
}

/* Every complete translation participates in sizing, not just the currently typed text. */
.intro-showcase-text-stack {
  display: grid;
  min-width: 0;
}

.intro-showcase-text {
  grid-area: 1 / 1;
  min-width: 0;
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  will-change: transform, opacity;
}

@media (min-width: 768px) {
  .intro-showcase-stage {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    grid-template-rows: minmax(0, 1fr);
    gap: 4rem;
    padding: 4rem;
  }

  .intro-showcase-text {
    text-align: left;
    align-items: flex-start;
  }
}

.intro-showcase-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 56px;
  height: 56px;
  flex-shrink: 0;
  border-radius: 1.25rem;
  margin-bottom: 1rem;
  background: linear-gradient(135deg, var(--dp-bg-tertiary) 0%, var(--dp-bg-secondary) 100%);
  border: 1px solid var(--dp-border-primary);
  will-change: transform, opacity;
}

.intro-showcase-icon svg {
  width: 36px;
  height: 36px;
  color: var(--dp-text-primary);
}

.intro-showcase-title {
  font-size: clamp(1.5rem, 4.5vw, 3.5rem);
  font-weight: 700;
  margin-bottom: 1rem;
  color: var(--dp-text-primary);
  line-height: 1.2;
}

.intro-showcase-description {
  font-size: clamp(1rem, 2.5vw, 1.35rem);
  color: var(--dp-text-secondary);
  line-height: 1.8;
  max-width: 480px;
}

@media (min-width: 768px) {
  .intro-showcase-description {
    max-width: none;
  }
}

.intro-showcase-mockup {
  min-height: 0;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.intro-mockup-frame {
  position: relative;
  height: 100%;
  max-height: calc(200px * 19.5 / 9);
  max-width: 100%;
  aspect-ratio: 9/19.5;
  flex-shrink: 0;
  border-radius: 1.75rem;
  overflow: hidden;
  background: var(--dp-bg-footer);
  box-shadow:
    0 25px 80px -20px color-mix(in srgb, var(--dp-overlay-scrim) 70%, transparent),
    0 0 0 6px color-mix(in srgb, var(--dp-bg-footer) 85%, var(--dp-bg-primary)),
    0 0 0 7px color-mix(in srgb, var(--dp-text-on-dark) 8%, transparent);
}

/* Dynamic Island */
.intro-mockup-frame::before {
  content: '';
  position: absolute;
  top: 7px;
  left: 50%;
  transform: translateX(-50%);
  width: 72px;
  height: 22px;
  background: var(--dp-bg-footer);
  border-radius: 20px;
  z-index: 10;
}

.dark .intro-mockup-frame {
  box-shadow:
    0 25px 80px -20px color-mix(in srgb, var(--dp-overlay-scrim) 100%, transparent),
    0 0 0 6px color-mix(in srgb, var(--dp-bg-footer) 70%, var(--dp-bg-secondary)),
    0 0 0 7px color-mix(in srgb, var(--dp-text-on-dark) 5%, transparent);
}

@media (min-width: 768px) {
  .intro-mockup-frame {
    max-height: calc(260px * 19.5 / 9);
  }
}

.intro-mockup-screen {
  position: absolute;
  inset: 0;
  background: var(--dp-bg-footer);
}

.intro-mockup-frame img {
  width: 100%;
  height: 100%;
  display: block;
  object-fit: cover;
  object-position: top;
}

.intro-mockup-placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  padding: 2rem;
  background: linear-gradient(
    180deg,
    var(--dp-bg-secondary) 0%,
    var(--dp-bg-tertiary) 100%
  );
}

.intro-mockup-placeholder svg {
  width: 56px;
  height: 56px;
  color: var(--dp-text-muted);
  margin-bottom: 1rem;
}

.mockup-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--dp-text-muted);
}

/* Typing animation styles */
.intro-showcase-title {
  min-height: 1.2em;
}

.description-line {
  position: relative;
  min-height: 1.8em;
  margin: 0;
}

.description-line-size {
  visibility: hidden;
  white-space: pre-wrap;
}

.description-line-typed {
  position: absolute;
  inset: 0;
}

.typing-text {
  white-space: pre-wrap;
}

.typing-cursor {
  position: absolute;
  color: var(--dp-primary);
  font-weight: 400;
  animation: blink 0.8s ease-in-out infinite;
  margin-left: 2px;
}

@keyframes blink {
  0%, 50% {
    opacity: 1;
  }
  51%, 100% {
    opacity: 0;
  }
}
@media (prefers-reduced-motion: reduce) {
  .typing-cursor {
    display: none;
  }

  .progress-dot {
    transition: none;
  }
}
</style>
