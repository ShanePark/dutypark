<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, inject, type Ref } from 'vue'
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
  descriptionLines: string[]
  mockupType: 'placeholder' | 'image'
  mockupSrc?: string
}

const props = defineProps<{
  features: Feature[]
}>()

const showcaseRef = ref<HTMLElement | null>(null)
const containerRef = inject<Ref<HTMLElement | null>>('introContainer', ref(null))

// Scroll progress within the showcase section (0 to 1)
const scrollProgress = ref(0)
// Which feature is currently active (0-indexed)
const activeIndex = ref(0)
// Progress within the current feature (0 to 1)
const featureProgress = ref(0)

// Typing animation phases within 0-80% of feature progress
// 0-15%: icon + title + mockup appear together
// 15-40%: first description line typing
// 40-65%: second description line typing
// 65-80%: complete state
// 80-100%: transition to next feature

interface TypingState {
  iconOpacity: number
  titleText: string
  titleComplete: boolean
  descriptionLines: { text: string; complete: boolean }[]
  mockupOpacity: number
}

function getTypingState(featureIndex: number, progress: number, feature: Feature): TypingState {
  const diff = featureIndex - activeIndex.value

  // Not the active feature - show nothing or full content
  if (diff !== 0) {
    if (diff < 0) {
      // Already passed - show full content
      return {
        iconOpacity: 0,
        titleText: feature.title,
        titleComplete: true,
        descriptionLines: feature.descriptionLines.map(line => ({ text: line, complete: true })),
        mockupOpacity: 0,
      }
    }
    // Future feature - show nothing
    return {
      iconOpacity: 0,
      titleText: '',
      titleComplete: false,
      descriptionLines: feature.descriptionLines.map(() => ({ text: '', complete: false })),
      mockupOpacity: 0,
    }
  }

  // Active feature - calculate typing state based on progress
  const p = progress // 0 to 1 within this feature

  // Icon + Title + Mockup: 0-15% (appear together)
  const initialOpacity = Math.min(1, p / 0.15)
  const iconOpacity = initialOpacity

  // Title appears all at once (no typing)
  const titleText = initialOpacity > 0.3 ? feature.title : ''
  const titleComplete = initialOpacity >= 1

  // Mockup appears with title
  const mockupOpacity = initialOpacity

  // Description lines
  const descriptionLines = feature.descriptionLines.map((line, idx) => {
    // Line 0: 15-40%, Line 1: 40-65%
    const lineStart = 0.15 + idx * 0.25
    const lineEnd = lineStart + 0.25

    if (p < lineStart) {
      return { text: '', complete: false }
    }

    const lineProgress = Math.min(1, (p - lineStart) / (lineEnd - lineStart))
    const chars = Math.floor(lineProgress * line.length)
    return {
      text: line.slice(0, chars),
      complete: lineProgress >= 1,
    }
  })

  return {
    iconOpacity,
    titleText,
    titleComplete,
    descriptionLines,
    mockupOpacity,
  }
}

const iconComponents: Record<string, typeof CalendarDays> = {
  calendar: CalendarDays,
  check: ListTodo,
  clock: Clock,
  users: Users,
  heart: Heart,
  flag: Flag,
  sun: Sun,
}

// Calculate scroll progress and active feature
let rafId: number | null = null

const updateProgress = () => {
  if (!showcaseRef.value || !containerRef?.value) return

  const container = containerRef.value
  const showcase = showcaseRef.value
  const containerRect = container.getBoundingClientRect()
  const showcaseRect = showcase.getBoundingClientRect()

  // How far into the showcase section we've scrolled
  const showcaseTop = showcaseRect.top - containerRect.top
  const showcaseHeight = showcaseRect.height
  const viewportHeight = containerRect.height

  // Total scrollable distance within showcase
  const scrollableDistance = showcaseHeight - viewportHeight

  // Current scroll position within showcase (0 = just entered, 1 = about to exit)
  let progress = -showcaseTop / scrollableDistance
  progress = Math.max(0, Math.min(1, progress))
  scrollProgress.value = progress

  // Map progress to feature index
  const totalFeatures = props.features.length
  const rawIndex = progress * totalFeatures
  const currentIndex = Math.min(Math.floor(rawIndex), totalFeatures - 1)
  activeIndex.value = currentIndex

  // Progress within current feature (0 = just entered, 1 = about to leave)
  featureProgress.value = rawIndex - currentIndex
}

const onScroll = () => {
  if (rafId) return
  rafId = requestAnimationFrame(() => {
    updateProgress()
    rafId = null
  })
}

onMounted(() => {
  if (!containerRef?.value) return
  containerRef.value.addEventListener('scroll', onScroll, { passive: true })
  updateProgress()
})

onUnmounted(() => {
  if (containerRef?.value) {
    containerRef.value.removeEventListener('scroll', onScroll)
  }
  if (rafId) {
    cancelAnimationFrame(rafId)
  }
})

// Animation styles for each feature
const getFeatureStyle = (index: number) => {
  const diff = index - activeIndex.value
  const progress = featureProgress.value

  // Current feature
  if (diff === 0) {
    // Crossfade: both exit and enter happen at 80-100%
    const exitProgress = Math.max(0, progress - 0.8) / 0.2
    const opacity = 1 - exitProgress
    const translateY = exitProgress * -50
    const scale = 1 - exitProgress * 0.03

    return {
      opacity,
      transform: `translate(-50%, -50%) translateY(${translateY}px) scale(${scale})`,
      zIndex: 10,
      pointerEvents: (exitProgress > 0.3 ? 'none' : 'auto') as 'none' | 'auto'
    }
  }

  // Next feature (coming in)
  if (diff === 1) {
    // Crossfade: enter at same time as current exits (80-100%)
    const enterProgress = Math.max(0, progress - 0.8) / 0.2
    const opacity = enterProgress
    const translateY = (1 - enterProgress) * 50
    const scale = 0.97 + enterProgress * 0.03

    return {
      opacity,
      transform: `translate(-50%, -50%) translateY(${translateY}px) scale(${scale})`,
      zIndex: 5,
      pointerEvents: 'none' as const
    }
  }

  // Previous features (already passed)
  if (diff < 0) {
    return {
      opacity: 0,
      transform: 'translate(-50%, -50%) translateY(-50px) scale(0.97)',
      zIndex: 1,
      pointerEvents: 'none' as const
    }
  }

  // Future features (not yet visible)
  return {
    opacity: 0,
    transform: 'translate(-50%, -50%) translateY(50px) scale(0.97)',
    zIndex: 1,
    pointerEvents: 'none' as const
  }
}

// Mockup animation (slightly delayed for stagger effect)
const getMockupStyle = (index: number) => {
  const diff = index - activeIndex.value
  const progress = featureProgress.value

  if (diff === 0) {
    // Mockup exits at 80-100% (same as text)
    const exitProgress = Math.max(0, progress - 0.8) / 0.2
    const opacity = 1 - exitProgress
    const translateY = exitProgress * -30
    const scale = 1 - exitProgress * 0.05
    const rotateY = exitProgress * 8

    return {
      opacity,
      transform: `translateY(${translateY}px) scale(${scale}) perspective(1000px) rotateY(${rotateY}deg)`,
    }
  }

  if (diff === 1) {
    // Mockup enters at 80-100% (same as text)
    const enterProgress = Math.max(0, progress - 0.8) / 0.2
    const opacity = enterProgress
    const translateY = (1 - enterProgress) * 40
    const scale = 0.95 + enterProgress * 0.05
    const rotateY = (1 - enterProgress) * -8

    return {
      opacity,
      transform: `translateY(${translateY}px) scale(${scale}) perspective(1000px) rotateY(${rotateY}deg)`,
    }
  }

  if (diff < 0) {
    return {
      opacity: 0,
      transform: 'translateY(-30px) scale(0.95)',
    }
  }

  return {
    opacity: 0,
    transform: 'translateY(40px) scale(0.95)',
  }
}

// Icon animation with bounce
const getIconStyle = (index: number) => {
  const diff = index - activeIndex.value
  const progress = featureProgress.value

  if (diff === 0) {
    // Icon exits at 80-100%
    const exitProgress = Math.max(0, progress - 0.8) / 0.2
    const scale = 1 - exitProgress * 0.15
    const rotate = exitProgress * 15

    return {
      opacity: 1 - exitProgress,
      transform: `scale(${scale}) rotate(${rotate}deg)`,
    }
  }

  if (diff === 1) {
    // Icon enters at 80-100% with subtle bounce
    const enterProgress = Math.max(0, progress - 0.8) / 0.2
    const bounce = enterProgress < 0.7
      ? enterProgress / 0.7 * 1.05
      : 1.05 - (enterProgress - 0.7) / 0.3 * 0.05
    const scale = Math.min(1, bounce)
    const rotate = (1 - enterProgress) * -15

    return {
      opacity: enterProgress,
      transform: `scale(${scale}) rotate(${rotate}deg)`,
    }
  }

  return {
    opacity: 0,
    transform: 'scale(0.85)',
  }
}

// Progress indicator
const progressDots = computed(() => {
  return props.features.map((_, index) => {
    const isActive = index === activeIndex.value
    const isPassed = index < activeIndex.value
    return { isActive, isPassed }
  })
})

// Navigate to specific feature when clicking progress dot
function scrollToFeature(index: number) {
  if (!showcaseRef.value || !containerRef?.value) return

  const container = containerRef.value
  const showcase = showcaseRef.value
  const showcaseRect = showcase.getBoundingClientRect()
  const containerRect = container.getBoundingClientRect()

  // Calculate showcase's top position relative to scroll
  const showcaseTop = showcase.offsetTop - container.offsetTop
  const showcaseHeight = showcaseRect.height
  const viewportHeight = containerRect.height
  const scrollableDistance = showcaseHeight - viewportHeight

  // Target scroll position for this feature
  const targetProgress = index / props.features.length
  const targetScroll = showcaseTop + targetProgress * scrollableDistance

  container.scrollTo({
    top: targetScroll,
    behavior: 'smooth'
  })
}
</script>

<template>
  <section ref="showcaseRef" class="intro-showcase">
    <!-- Sticky viewport that stays fixed during scroll -->
    <div class="intro-showcase-viewport">
      <!-- Progress dots on the side -->
      <div class="intro-showcase-progress">
        <button
          v-for="(dot, index) in progressDots"
          :key="index"
          class="progress-dot"
          :class="{ active: dot.isActive, passed: dot.isPassed }"
          :aria-label="`${features[index]?.title ?? '기능'}으로 이동`"
          @click="scrollToFeature(index)"
        />
      </div>

      <!-- Feature cards stack -->
      <div class="intro-showcase-stage">
        <div
          v-for="(feature, index) in features"
          :key="feature.id"
          class="intro-showcase-card"
          :style="getFeatureStyle(index)"
        >
          <div class="intro-showcase-content">
            <!-- Text side -->
            <div class="intro-showcase-text">
              <div
                class="intro-showcase-icon"
                :style="{
                  ...getIconStyle(index),
                  opacity: getTypingState(index, featureProgress, feature).iconOpacity
                }"
              >
                <component :is="iconComponents[feature.icon]" />
              </div>

              <h2
                class="intro-showcase-title"
                :style="{ opacity: getTypingState(index, featureProgress, feature).titleText ? 1 : 0 }"
              >
                {{ getTypingState(index, featureProgress, feature).titleText }}
              </h2>

              <div class="intro-showcase-description">
                <p
                  v-for="(line, lineIdx) in getTypingState(index, featureProgress, feature).descriptionLines"
                  :key="lineIdx"
                  class="description-line"
                >
                  <span class="typing-text">{{ line.text }}</span>
                  <span
                    v-if="!line.complete && line.text.length > 0"
                    class="typing-cursor"
                  >|</span>
                </p>
              </div>
            </div>

            <!-- Mockup side -->
            <div
              class="intro-showcase-mockup"
              :style="{
                ...getMockupStyle(index),
                opacity: index === activeIndex ? getTypingState(index, featureProgress, feature).mockupOpacity : getMockupStyle(index).opacity
              }"
            >
              <div class="intro-mockup-frame">
                <img
                  v-if="feature.mockupType === 'image' && feature.mockupSrc"
                  :src="feature.mockupSrc"
                  :alt="`${feature.title} 미리보기`"
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
    </div>
  </section>
</template>

<style scoped>
.intro-showcase {
  /* Each feature gets 100vh of scroll space */
  height: calc(v-bind('features.length') * 100vh);
  position: relative;
}

.intro-showcase-viewport {
  position: sticky;
  top: 0;
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.intro-showcase-progress {
  position: absolute;
  left: 1.5rem;
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
  position: relative;
  width: 100%;
  max-width: 1200px;
  padding: 0 1rem;
}

@media (min-width: 768px) {
  .intro-showcase-stage {
    padding: 0 4rem;
  }
}

.intro-showcase-card {
  position: absolute;
  top: 50%;
  left: 50%;
  width: calc(100% - 2rem);
  max-width: 1100px;
  will-change: transform, opacity;
  transition: none;
}

@media (min-width: 768px) {
  .intro-showcase-card {
    width: calc(100% - 8rem);
  }
}

.intro-showcase-content {
  display: flex;
  flex-direction: column;
  gap: 2rem;
  align-items: center;
}

@media (min-width: 768px) {
  .intro-showcase-content {
    flex-direction: row;
    gap: 4rem;
  }
}

.intro-showcase-text {
  flex: 1;
  text-align: center;
}

@media (min-width: 768px) {
  .intro-showcase-text {
    text-align: left;
  }
}

.intro-showcase-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 72px;
  height: 72px;
  border-radius: 1.25rem;
  margin-bottom: 1.5rem;
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
  font-size: clamp(2rem, 6vw, 3.5rem);
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
  flex: 1;
  display: flex;
  justify-content: center;
  will-change: transform, opacity;
}

.intro-mockup-frame {
  position: relative;
  width: 100%;
  max-width: 220px;
  aspect-ratio: 9/19.5;
  border-radius: 1.75rem;
  overflow: hidden;
  background: #000;
  box-shadow:
    0 25px 80px -20px rgba(0, 0, 0, 0.35),
    0 0 0 6px #1a1a1a,
    0 0 0 7px rgba(255, 255, 255, 0.08);
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
  background: #000;
  border-radius: 20px;
  z-index: 10;
}

.dark .intro-mockup-frame {
  box-shadow:
    0 25px 80px -20px rgba(0, 0, 0, 0.6),
    0 0 0 6px #2a2a2a,
    0 0 0 7px rgba(255, 255, 255, 0.05);
}

@media (min-width: 768px) {
  .intro-mockup-frame {
    max-width: 260px;
  }
}

.intro-mockup-frame img {
  width: 100%;
  height: 100%;
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
  min-height: 1.8em;
  margin: 0;
}

.typing-text {
  white-space: pre-wrap;
}

.typing-cursor {
  display: inline-block;
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
</style>
