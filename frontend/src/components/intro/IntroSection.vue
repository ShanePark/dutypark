<script setup lang="ts">
import { ref, provide } from 'vue'
import '@/styles/intro.css'
import IntroHero from './IntroHero.vue'
import IntroShowcase, { type Feature } from './IntroShowcase.vue'
import IntroCTA from './IntroCTA.vue'

const containerRef = ref<HTMLElement | null>(null)
provide('introContainer', containerRef)

const features: Feature[] = [
  {
    id: 'schedule',
    icon: 'calendar',
    title: '일정 관리',
    description: '일정을 등록하고 검색하세요. 공개 설정으로 원하는 사람에게만 공유할 수 있습니다.',
    mockupType: 'placeholder',
  },
  {
    id: 'todo',
    icon: 'check',
    title: '할일 관리',
    description: '까먹지 않는 일상을 위한 할일 관리. 드래그로 순서 변경, 완료 체크까지.',
    mockupType: 'placeholder',
  },
  {
    id: 'duty',
    icon: 'clock',
    title: '근무 관리',
    description: '나의 근무 일정을 한눈에. 시간표를 등록하고 팀원들과 공유하세요.',
    mockupType: 'placeholder',
  },
  {
    id: 'team',
    icon: 'users',
    title: '팀원 시간표',
    description: '팀원들의 시간표와 일정을 한눈에 조회. 업무 협업이 더 쉬워집니다.',
    mockupType: 'placeholder',
  },
  {
    id: 'friends',
    icon: 'heart',
    title: '친구/가족 일정',
    description: '소중한 사람들의 일정을 확인하고 태그 기능으로 함께하세요.',
    mockupType: 'placeholder',
  },
  {
    id: 'dday',
    icon: 'flag',
    title: 'D-Day 관리',
    description: '기념일, 중요한 날을 카운트다운. 놓치지 않도록 알려드립니다.',
    mockupType: 'placeholder',
  },
  {
    id: 'holiday',
    icon: 'sun',
    title: '공휴일 자동 표시',
    description: '대한민국 공휴일이 자동으로 표시됩니다. 일정 계획이 더 쉬워집니다.',
    mockupType: 'placeholder',
  },
]
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
