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
    id: 'share',
    icon: 'heart',
    title: '일상을 함께',
    descriptionLines: [
      '가족, 친구와 서로의 일정을 공유하세요.',
      '"오늘 뭐 해?" 더 이상 물어볼 필요 없어요.',
    ],
    mockupType: 'image',
    mockupSrc: '/img/intro/schedule.png',
  },
  {
    id: 'duty',
    icon: 'clock',
    title: '근무 & 연차 관리',
    descriptionLines: [
      '교대근무도, 평일 근무도 한눈에 정리.',
      '연차는 휴무로 바꾸고, 팀원들과 공유하세요.',
    ],
    mockupType: 'image',
    mockupSrc: '/img/intro/duty.png',
  },
  {
    id: 'life',
    icon: 'users',
    title: '다양한 일상',
    descriptionLines: [
      '아이 등하원, 응원팀 경기 일정, 모임까지.',
      '내 일상의 모든 것을 한 곳에서 관리하세요.',
    ],
    mockupType: 'placeholder',
  },
  {
    id: 'todo',
    icon: 'check',
    title: '할일 관리',
    descriptionLines: [
      '까먹지 않는 일상을 위한 투두 보드.',
      '드래그로 순서 변경, 완료 체크까지.',
    ],
    mockupType: 'image',
    mockupSrc: '/img/intro/todo.png',
  },
  {
    id: 'dday',
    icon: 'flag',
    title: 'D-Day 카운트다운',
    descriptionLines: [
      '기념일, 마감일, 중요한 날.',
      '함께 기다리고, 함께 기억해요.',
    ],
    mockupType: 'image',
    mockupSrc: '/img/intro/dday.png',
  },
  {
    id: 'holiday',
    icon: 'sun',
    title: '공휴일 자동 연동',
    descriptionLines: [
      '대한민국 공휴일이 자동으로 표시됩니다.',
      '일정 계획이 더 쉬워집니다.',
    ],
    mockupType: 'image',
    mockupSrc: '/img/intro/holiday.png',
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
