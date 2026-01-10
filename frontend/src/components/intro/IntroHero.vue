<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ChevronDown, ChevronRight } from 'lucide-vue-next'

const isLoaded = ref(false)

onMounted(() => {
  setTimeout(() => {
    isLoaded.value = true
  }, 100)
})

function scrollToFeatures() {
  const showcase = document.querySelector('.intro-showcase')
  showcase?.scrollIntoView({ behavior: 'smooth' })
}
</script>

<template>
  <section class="intro-hero">
    <div class="px-4 max-w-4xl mx-auto">
      <h1
        class="intro-hero-title"
        :class="{ 'hero-loaded': isLoaded }"
      >
        Dutypark
      </h1>

      <p
        class="intro-hero-tagline hero-stagger-1"
        :class="{ 'hero-loaded': isLoaded }"
      >
        나와 소중한 사람들을 위한 소셜 캘린더
      </p>

      <p
        class="intro-hero-subtitle hero-stagger-2"
        :class="{ 'hero-loaded': isLoaded }"
      >
        근무 일정, 아이 등원, 응원하는 팀의 경기까지.<br>
        서로의 일상을 공유하고 함께 계획하세요.
      </p>

      <router-link
        to="/auth/login"
        class="intro-hero-cta hero-stagger-3"
        :class="{ 'hero-loaded': isLoaded }"
      >
        시작하기
        <ChevronRight class="w-5 h-5" />
      </router-link>
    </div>

    <button
      class="scroll-indicator hero-stagger-4"
      :class="{ 'hero-loaded': isLoaded }"
      @click="scrollToFeatures"
    >
      <span class="text-sm">스크롤하여 더 알아보기</span>
      <ChevronDown class="w-6 h-6" />
    </button>
  </section>
</template>

<style scoped>
/* Title uses global styles from style.css for gradient + dark mode support */
.intro-hero-title {
  transform: translateY(40px);
  transition: transform 0.8s cubic-bezier(0.16, 1, 0.3, 1);
}

.intro-hero-title.hero-loaded {
  transform: translateY(0);
}

.intro-hero-tagline {
  font-size: clamp(1.125rem, 4vw, 1.5rem);
  font-weight: 600;
  color: var(--dp-accent);
  margin: 0 auto 1rem;
  transform: translateY(30px);
  opacity: 0;
  transition: all 0.6s cubic-bezier(0.16, 1, 0.3, 1);
}

.intro-hero-tagline.hero-loaded {
  opacity: 1;
  transform: translateY(0);
}

.intro-hero-subtitle {
  font-size: clamp(0.95rem, 2.5vw, 1.125rem);
  color: var(--dp-text-secondary);
  max-width: 600px;
  margin: 0 auto 2.5rem;
  line-height: 1.8;
  transform: translateY(30px);
  opacity: 0;
  transition: all 0.6s cubic-bezier(0.16, 1, 0.3, 1);
}

.intro-hero-subtitle.hero-loaded {
  opacity: 1;
  transform: translateY(0);
}

.intro-hero-cta {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 1rem 2rem;
  border-radius: 9999px;
  font-weight: 600;
  font-size: 1.125rem;
  background-color: var(--dp-accent) !important;
  color: white !important;
  box-shadow: 0 10px 40px -10px var(--dp-accent-ring);
  transform: translateY(20px);
  opacity: 0;
  transition: all 0.5s cubic-bezier(0.16, 1, 0.3, 1);
  cursor: pointer;
}

.intro-hero-cta:hover {
  background-color: var(--dp-accent-hover) !important;
  transform: translateY(-2px);
  box-shadow: 0 20px 50px -10px var(--dp-accent-ring);
}

.intro-hero-cta.hero-loaded {
  opacity: 1;
  transform: translateY(0);
}

.hero-stagger-1 {
  transition-delay: 0.15s;
}

.hero-stagger-2 {
  transition-delay: 0.3s;
}

.hero-stagger-3 {
  transition-delay: 0.45s;
}

.hero-stagger-4 {
  transition-delay: 0.6s;
}

.scroll-indicator {
  opacity: 0;
  transform: translateY(10px);
  transition: all 0.5s cubic-bezier(0.16, 1, 0.3, 1);
}

.scroll-indicator.hero-loaded {
  opacity: 1;
  transform: translateY(0);
}
</style>
