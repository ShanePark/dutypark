<script setup lang="ts">
import { computed } from 'vue'
import BaseModal from '@/components/common/BaseModal.vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import type { AdminMemberDetailDto, AdminMemberDto } from '@/types'
import { getVisibilityIcon, getVisibilityLabel } from '@/utils/visibility'
import {
  Bell,
  CalendarDays,
  ChevronRight,
  Eye,
  Key,
  ListTodo,
  Loader2,
  Shield,
  Smartphone,
  UserCog,
  Users,
  X,
} from 'lucide-vue-next'

const props = defineProps<{
  open: boolean
  member: AdminMemberDto | null
  memberDetail: AdminMemberDetailDto | null
  loading: boolean
  loadError: string | null
}>()

const emit = defineEmits<{
  close: []
  retry: []
  goToSchedule: [memberId: number]
  changePassword: [member: AdminMemberDto]
}>()

const effectiveMember = computed(() => props.memberDetail ?? props.member)
const visibilityLabel = computed(() => {
  if (!props.memberDetail) return '불러오는 중'
  return getVisibilityLabel(props.memberDetail.calendarVisibility)
})
const visibilityIcon = computed(() => {
  if (!props.memberDetail) return Eye
  return getVisibilityIcon(props.memberDetail.calendarVisibility)
})

const roleBadges = computed(() => {
  if (!props.memberDetail) return []

  const badges: Array<{ label: string; tone: string }> = []
  if (props.memberDetail.serviceAdmin) badges.push({ label: '서비스 관리자', tone: 'accent' })
  if (props.memberDetail.teamAdmin) badges.push({ label: '팀장', tone: 'success' })
  if (!props.memberDetail.teamAdmin && props.memberDetail.teamManager) badges.push({ label: '팀 매니저', tone: 'warning' })
  if (props.memberDetail.auxiliaryAccount) badges.push({ label: '보조 계정', tone: 'muted' })
  if (!badges.length) badges.push({ label: '일반 회원', tone: 'muted' })
  return badges
})

const loginBadges = computed(() => {
  if (!props.memberDetail) return []

  const badges: string[] = []
  if (props.memberDetail.hasPassword) badges.push('비밀번호')
  props.memberDetail.authProviders.forEach((provider) => {
    if (provider === 'KAKAO') badges.push('카카오')
    else if (provider === 'NAVER') badges.push('네이버')
    else badges.push(provider)
  })
  if (!badges.length) badges.push('로그인 수단 없음')
  return badges
})

const heroStats = computed(() => {
  if (!props.memberDetail) return []

  return [
    {
      label: '등록 일정',
      value: formatNumber(props.memberDetail.totalScheduleCount),
      caption: `예정 ${formatNumber(props.memberDetail.upcomingScheduleCount)}개`,
      icon: CalendarDays,
    },
    {
      label: '전체 TODO',
      value: formatNumber(props.memberDetail.totalTodoCount),
      caption: `진행 중 ${formatNumber(props.memberDetail.inProgressTodoCount)}개`,
      icon: ListTodo,
    },
    {
      label: '활성 세션',
      value: formatNumber(props.memberDetail.activeSessionCount),
      caption: `푸시 연결 ${formatNumber(props.memberDetail.pushEnabledSessionCount)}개`,
      icon: Smartphone,
    },
    {
      label: '읽지 않은 알림',
      value: formatNumber(props.memberDetail.unreadNotificationCount),
      caption: `전체 ${formatNumber(props.memberDetail.totalNotificationCount)}개`,
      icon: Bell,
    },
    {
      label: '친구',
      value: formatNumber(props.memberDetail.friendCount),
      caption: `가족 ${formatNumber(props.memberDetail.familyCount)}명`,
      icon: Users,
    },
    {
      label: '관리 계정',
      value: formatNumber(props.memberDetail.managedMemberCount),
      caption: `이 회원을 관리 중 ${formatNumber(props.memberDetail.managerCount)}명`,
      icon: UserCog,
    },
  ]
})

const primaryInfoRows = computed(() => {
  if (!props.memberDetail) return []

  return [
    {
      label: '가입일',
      value: formatDateLabel(props.memberDetail.createdDate),
      inlineMeta: formatTimeLabel(props.memberDetail.createdDate),
      inlineNote: formatSince(props.memberDetail.createdDate),
      valueClass: 'member-detail-main-strong',
    },
    {
      label: '최근 수정',
      value: formatDateLabel(props.memberDetail.lastModifiedDate),
      inlineMeta: formatTimeLabel(props.memberDetail.lastModifiedDate),
      inlineNote: formatSince(props.memberDetail.lastModifiedDate),
      valueClass: 'member-detail-main-strong',
    },
    {
      label: '최근 활동',
      value: props.memberDetail.lastActiveAt ? formatDateLabel(props.memberDetail.lastActiveAt) : '활동 기록 없음',
      inlineMeta: props.memberDetail.lastActiveAt ? formatTimeLabel(props.memberDetail.lastActiveAt) : null,
      inlineNote: props.memberDetail.lastActiveAt ? formatSince(props.memberDetail.lastActiveAt) : null,
      valueClass: props.memberDetail.lastActiveAt ? 'member-detail-main-strong' : 'member-detail-main-muted',
    },
    {
      label: '이메일',
      value: props.memberDetail.email || '등록된 이메일 없음',
      valueClass: props.memberDetail.email ? 'member-detail-main-break' : 'member-detail-main-muted',
    },
    {
      label: '소속 팀',
      value: props.memberDetail.teamName || '팀 없음',
      valueClass: 'member-detail-main-strong',
    },
    {
      label: '공개 범위',
      value: visibilityLabel.value,
      valueClass: 'member-detail-main-strong',
    },
  ]
})

const relationshipGroups = computed(() => {
  if (!props.memberDetail) return []

  return [
    {
      title: '이 회원을 관리하는 계정',
      emptyText: '등록된 관리자 계정이 없어요',
      items: props.memberDetail.managerNames,
      countText: `${formatNumber(props.memberDetail.managerCount)}명`,
    },
    {
      title: '이 회원이 관리하는 계정',
      emptyText: '관리 중인 계정이 없어요',
      items: props.memberDetail.managedMemberNames,
      countText: `${formatNumber(props.memberDetail.managedMemberCount)}명`,
    },
  ]
})

const dDaySummary = computed(() => {
  const dDays = props.memberDetail?.dDays ?? []
  const privateCount = dDays.filter((dday) => dday.isPrivate).length

  return {
    total: dDays.length,
    privateCount,
    publicCount: dDays.length - privateCount,
  }
})

function formatNumber(value: number) {
  return new Intl.NumberFormat('ko-KR').format(value)
}

function formatDateLabel(value: string) {
  const date = new Date(value)
  return `${date.getFullYear()}년 ${date.getMonth() + 1}월 ${date.getDate()}일`
}

function formatTimeLabel(value: string) {
  const date = new Date(value)
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
}

function formatSince(value: string) {
  const diffMs = Date.now() - new Date(value).getTime()
  const diffDays = Math.max(0, Math.floor(diffMs / 86400000))

  if (diffDays === 0) return '오늘'
  if (diffDays < 30) return `${diffDays}일 전`
  if (diffDays < 365) return `${Math.floor(diffDays / 30)}개월 전`
  return `${Math.floor(diffDays / 365)}년 전`
}

function roleBadgeClass(tone: string) {
  if (tone === 'accent') return 'bg-dp-accent-soft text-dp-accent'
  if (tone === 'success') return 'bg-dp-success-soft text-dp-success'
  if (tone === 'warning') return 'bg-dp-warning-soft text-dp-warning'
  return 'bg-dp-bg-tertiary text-dp-text-secondary'
}

function goToSchedule() {
  if (!effectiveMember.value?.id) return
  emit('goToSchedule', effectiveMember.value.id)
}

function openPasswordModal() {
  if (!props.member) return
  emit('changePassword', props.member)
}
</script>

<template>
  <BaseModal
    :is-open="open"
    size="5xl"
    height="default"
    rounded
    z-index="admin"
    panel-class="member-detail-shell"
    @close="emit('close')"
  >
        <div class="modal-header">
          <div class="min-w-0">
            <h2>{{ effectiveMember?.name ?? '회원 상세' }}</h2>
            <p class="mt-1 text-xs sm:text-sm text-dp-text-secondary">회원 상세 정보</p>
          </div>
          <button
            class="p-2 rounded-full hover-close-btn cursor-pointer text-dp-text-muted"
            @click="emit('close')"
            aria-label="상세 모달 닫기"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="member-detail-body modal-body p-4 sm:p-5">
          <div v-if="loading" class="flex min-h-64 items-center justify-center">
            <div class="flex items-center gap-3 text-dp-text-secondary">
              <Loader2 class="w-5 h-5 animate-spin" />
              <span>회원 상세 정보를 불러오는 중입니다...</span>
            </div>
          </div>

          <div v-else-if="loadError" class="member-section-card flex min-h-64 flex-col items-center justify-center gap-4 text-center">
            <p class="max-w-md text-sm sm:text-base text-dp-text-secondary">
              {{ loadError }}
            </p>
            <button
              class="min-h-11 rounded-xl bg-dp-surface-strong px-4 py-2 text-sm font-semibold text-dp-text-on-dark transition hover:bg-dp-surface-strong-hover cursor-pointer"
              @click="emit('retry')"
            >
              다시 불러오기
            </button>
          </div>

          <div v-else-if="memberDetail" class="space-y-4">
            <section class="member-section-card member-summary-card">
              <div class="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
                <div class="flex items-start gap-4 min-w-0">
                  <ProfileAvatar
                    :member-id="effectiveMember?.id"
                    :name="effectiveMember?.name"
                    :has-profile-photo="effectiveMember?.hasProfilePhoto"
                    :profile-photo-version="effectiveMember?.profilePhotoVersion"
                    size="xl"
                  />
                  <div class="min-w-0">
                    <div class="flex flex-wrap items-center gap-2">
                      <h3 class="text-xl sm:text-2xl font-bold text-dp-text-primary truncate">
                        {{ effectiveMember?.name ?? '회원 상세' }}
                      </h3>
                      <span class="member-inline-badge">ID {{ effectiveMember?.id ?? '-' }}</span>
                    </div>
                    <p class="mt-1 text-sm sm:text-base text-dp-text-secondary break-all">
                      {{ effectiveMember?.email || '등록된 이메일 없음' }}
                    </p>
                    <p class="mt-1 text-sm text-dp-text-muted">
                      {{ effectiveMember?.teamName || '팀 없음' }}
                    </p>
                    <div class="mt-3 flex flex-wrap gap-2">
                      <span
                        v-for="badge in roleBadges"
                        :key="badge.label"
                        class="member-chip"
                        :class="roleBadgeClass(badge.tone)"
                      >
                        {{ badge.label }}
                      </span>
                    </div>
                  </div>
                </div>

                <div class="grid grid-cols-2 gap-2 xl:w-[18rem]">
                  <button
                    class="member-action-button member-action-button-primary"
                    @click="goToSchedule"
                  >
                    <span class="inline-flex items-center gap-1.5">
                      시간표 보기
                      <ChevronRight class="member-action-button-icon w-4 h-4" />
                    </span>
                  </button>
                  <button
                    class="member-action-button member-action-button-warning"
                    @click="openPasswordModal"
                  >
                    비밀번호 변경
                  </button>
                </div>
              </div>

              <div class="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-3 xl:grid-cols-6">
                <article
                  v-for="stat in heroStats"
                  :key="stat.label"
                  class="member-stat-card"
                >
                  <div class="flex items-start justify-between gap-2">
                    <div>
                      <p class="text-[11px] sm:text-xs font-medium leading-tight text-dp-text-muted">{{ stat.label }}</p>
                      <p class="mt-1 text-base sm:text-xl font-bold text-dp-text-primary">{{ stat.value }}</p>
                    </div>
                    <component :is="stat.icon" class="h-4 w-4 sm:h-5 sm:w-5 text-dp-text-secondary" />
                  </div>
                  <p class="mt-2 hidden sm:block text-xs text-dp-text-secondary">{{ stat.caption }}</p>
                </article>
              </div>
            </section>

            <div class="grid gap-3 xl:grid-cols-[minmax(0,1.12fr)_minmax(0,0.88fr)]">
            <section class="member-section-card">
              <div class="flex items-center gap-2">
                <Shield class="w-4 h-4 text-dp-text-secondary" />
                <h3 class="text-base font-semibold text-dp-text-primary">기본 정보</h3>
              </div>
              <div class="mt-3 grid gap-2 sm:grid-cols-2">
                <article
                  v-for="row in primaryInfoRows"
                  :key="row.label"
                  class="member-detail-item"
                >
                  <p class="member-detail-label">{{ row.label }}</p>
                  <div class="mt-1 flex flex-wrap items-center gap-2">
                    <p class="member-detail-main" :class="row.valueClass">{{ row.value }}</p>
                    <span v-if="row.inlineMeta" class="member-detail-inline-meta">{{ row.inlineMeta }}</span>
                    <span v-if="row.inlineNote" class="member-detail-inline-note">{{ row.inlineNote }}</span>
                  </div>
                </article>
              </div>
            </section>

            <section class="member-section-card">
              <div class="flex items-center gap-2">
                <Key class="w-4 h-4 text-dp-text-secondary" />
                <h3 class="text-base font-semibold text-dp-text-primary">계정 상태</h3>
              </div>
              <div class="mt-3 space-y-3">
                <div class="member-detail-item">
                  <p class="member-detail-label">로그인 방식</p>
                  <div class="mt-2 flex flex-wrap gap-2">
                    <span
                      v-for="badge in loginBadges"
                      :key="badge"
                      class="member-chip bg-dp-bg-tertiary text-dp-text-primary"
                    >
                      {{ badge }}
                    </span>
                  </div>
                </div>
                <div class="grid grid-cols-2 gap-2">
                  <article class="member-detail-item">
                    <p class="member-detail-label">공개 범위</p>
                    <div class="mt-1 flex items-center gap-2">
                      <component :is="visibilityIcon" class="w-4 h-4 text-dp-text-secondary" />
                      <span class="member-detail-main member-detail-main-strong">{{ visibilityLabel }}</span>
                    </div>
                  </article>
                  <article class="member-detail-item">
                    <p class="member-detail-label">푸시 연결</p>
                    <p class="mt-1 member-detail-main member-detail-main-strong">
                      {{ formatNumber(memberDetail.pushEnabledSessionCount) }}개 세션
                    </p>
                  </article>
                </div>
              </div>
            </section>

            <section class="member-section-card xl:col-span-2">
              <div class="flex items-center gap-2">
                <CalendarDays class="w-4 h-4 text-dp-text-secondary" />
                <h3 class="text-base font-semibold text-dp-text-primary">일정 / TODO / D-Day 요약</h3>
              </div>
              <div class="mt-3 grid gap-2 lg:grid-cols-3">
                <article class="member-mini-card">
                  <p class="text-xs font-medium text-dp-text-muted">일정</p>
                  <div class="mt-2 space-y-1.5 text-sm text-dp-text-primary">
                    <div class="member-summary-row">
                      <span>직접 등록</span>
                      <strong>{{ formatNumber(memberDetail.totalScheduleCount) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>예정 일정</span>
                      <strong>{{ formatNumber(memberDetail.upcomingScheduleCount) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>태그된 일정</span>
                      <strong>{{ formatNumber(memberDetail.taggedScheduleCount) }}</strong>
                    </div>
                  </div>
                </article>

                <article class="member-mini-card">
                  <p class="text-xs font-medium text-dp-text-muted">TODO</p>
                  <div class="mt-2 space-y-1.5 text-sm text-dp-text-primary">
                    <div class="member-summary-row">
                      <span>대기</span>
                      <strong>{{ formatNumber(memberDetail.todoCount) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>진행 중</span>
                      <strong>{{ formatNumber(memberDetail.inProgressTodoCount) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>완료</span>
                      <strong>{{ formatNumber(memberDetail.doneTodoCount) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>기한 초과</span>
                      <strong class="text-dp-warning">{{ formatNumber(memberDetail.overdueTodoCount) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>오늘 마감</span>
                      <strong>{{ formatNumber(memberDetail.dueTodayTodoCount) }}</strong>
                    </div>
                  </div>
                </article>

                <article class="member-mini-card">
                  <div class="flex items-start justify-between gap-3">
                    <div>
                      <p class="text-xs font-medium text-dp-text-muted">D-Day</p>
                      <p class="mt-1 text-lg font-bold text-dp-text-primary">{{ formatNumber(dDaySummary.total) }}개</p>
                    </div>
                    <span class="member-inline-badge">관리자 조회 기준</span>
                  </div>
                  <div class="mt-2 space-y-1.5 text-sm text-dp-text-primary">
                    <div class="member-summary-row">
                      <span>전체</span>
                      <strong>{{ formatNumber(dDaySummary.total) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>공개</span>
                      <strong>{{ formatNumber(dDaySummary.publicCount) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>비공개</span>
                      <strong>{{ formatNumber(dDaySummary.privateCount) }}</strong>
                    </div>
                  </div>
                </article>
              </div>
            </section>

            <section class="member-section-card xl:col-span-2">
              <div class="flex items-center gap-2">
                <Users class="w-4 h-4 text-dp-text-secondary" />
                <h3 class="text-base font-semibold text-dp-text-primary">관계 / 알림</h3>
              </div>
              <div class="mt-3 grid gap-2 sm:grid-cols-2">
                <article class="member-mini-card">
                  <p class="text-xs font-medium text-dp-text-muted">친구 요청</p>
                  <div class="mt-3 grid grid-cols-2 gap-3 text-sm">
                    <div>
                      <p class="text-dp-text-secondary">받은 요청</p>
                      <p class="mt-1 text-lg font-bold text-dp-text-primary">{{ formatNumber(memberDetail.pendingReceivedFriendRequestCount) }}</p>
                    </div>
                    <div>
                      <p class="text-dp-text-secondary">보낸 요청</p>
                      <p class="mt-1 text-lg font-bold text-dp-text-primary">{{ formatNumber(memberDetail.pendingSentFriendRequestCount) }}</p>
                    </div>
                  </div>
                </article>

                <article class="member-mini-card">
                  <p class="text-xs font-medium text-dp-text-muted">친구 / 가족</p>
                  <div class="mt-3 grid grid-cols-2 gap-3 text-sm">
                    <div>
                      <p class="text-dp-text-secondary">친구</p>
                      <p class="mt-1 text-lg font-bold text-dp-text-primary">{{ formatNumber(memberDetail.friendCount) }}</p>
                    </div>
                    <div>
                      <p class="text-dp-text-secondary">가족</p>
                      <p class="mt-1 text-lg font-bold text-dp-text-primary">{{ formatNumber(memberDetail.familyCount) }}</p>
                    </div>
                  </div>
                </article>

                <article
                  v-for="group in relationshipGroups"
                  :key="group.title"
                  class="member-mini-card"
                >
                  <div class="flex items-center justify-between gap-3">
                    <p class="text-xs font-medium text-dp-text-muted">{{ group.title }}</p>
                    <span class="text-xs text-dp-text-secondary">{{ group.countText }}</span>
                  </div>
                  <div v-if="group.items.length" class="mt-3 flex flex-wrap gap-2">
                    <span
                      v-for="name in group.items"
                      :key="name"
                      class="member-chip bg-dp-bg-tertiary text-dp-text-primary"
                    >
                      {{ name }}
                    </span>
                  </div>
                  <p v-else class="mt-3 text-sm text-dp-text-secondary">{{ group.emptyText }}</p>
                </article>
              </div>
            </section>
            </div>
          </div>
        </div>
  </BaseModal>
</template>

<style scoped>
.member-detail-shell {
  position: relative;
}

.member-detail-body {
  min-height: 0;
  max-height: min(calc(90dvh - 4.75rem), 46rem);
  overflow-y: auto;
}

.member-action-button {
  min-height: 2.75rem;
  border-radius: 0.85rem;
  padding: 0.7rem 1rem;
  font-size: 0.875rem;
  font-weight: 700;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.member-action-button-primary {
  background-color: var(--dp-modal-header-bg);
  color: var(--dp-text-on-dark);
}

.member-action-button-warning {
  background-color: var(--dp-warning-bg);
  color: var(--dp-warning);
}

.member-action-button-icon {
  transition: transform 180ms ease;
}

.member-inline-badge {
  border: 1px solid var(--dp-border-primary);
  background-color: color-mix(in srgb, var(--dp-bg-tertiary) 92%, transparent);
  color: var(--dp-text-secondary);
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 600;
  padding: 0.3rem 0.7rem;
}

.member-stat-card,
.member-section-card,
.member-mini-card,
.member-detail-item {
  transition:
    transform 180ms ease,
    box-shadow 180ms ease,
    border-color 180ms ease,
    background-color 180ms ease,
    color 180ms ease;
  border: 1px solid var(--dp-border-primary);
  background-color: color-mix(in srgb, var(--dp-bg-card) 94%, var(--dp-bg-secondary));
}

.member-stat-card {
  border-radius: 1rem;
  padding: 0.85rem;
}

.member-section-card {
  border-radius: 1.15rem;
  padding: 0.9rem;
}

.member-summary-card {
  background-color: color-mix(in srgb, var(--dp-bg-secondary) 88%, var(--dp-bg-card));
}

.member-mini-card {
  border-radius: 1rem;
  padding: 0.85rem;
}

.member-detail-item {
  border-radius: 1rem;
  padding: 0.78rem 0.85rem;
}

.member-detail-label {
  font-size: 0.74rem;
  line-height: 1rem;
  font-weight: 600;
  color: var(--dp-text-muted);
}

.member-detail-main {
  font-size: 0.96rem;
  line-height: 1.35;
  color: var(--dp-text-primary);
}

.member-detail-main-strong {
  font-weight: 700;
}

.member-detail-main-muted {
  font-weight: 600;
  color: var(--dp-text-secondary);
}

.member-detail-main-break {
  word-break: break-all;
  font-weight: 700;
}

.member-detail-inline-meta {
  display: inline-flex;
  align-items: center;
  border-radius: 9999px;
  background-color: color-mix(in srgb, var(--dp-bg-tertiary) 92%, transparent);
  color: var(--dp-text-secondary);
  font-size: 0.72rem;
  line-height: 0.95rem;
  font-weight: 700;
  padding: 0.18rem 0.5rem;
}

.member-detail-inline-note {
  font-size: 0.77rem;
  line-height: 1rem;
  font-weight: 600;
  color: var(--dp-text-secondary);
}

.member-chip {
  border-radius: 9999px;
  padding: 0.38rem 0.8rem;
  font-size: 0.75rem;
  font-weight: 700;
}

.member-summary-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
}

@media (hover: hover) {
  .member-action-button:hover,
  .member-action-button:focus-visible {
    box-shadow:
      0 12px 24px color-mix(in srgb, var(--dp-overlay-scrim) 18%, transparent),
      0 0 0 1px color-mix(in srgb, var(--dp-border-primary) 50%, transparent);
    transform: translateY(-1px);
  }

  .member-action-button-primary:hover,
  .member-action-button-primary:focus-visible {
    background-color: var(--dp-bg-footer);
  }

  .member-action-button-warning:hover,
  .member-action-button-warning:focus-visible {
    background-color: color-mix(in srgb, var(--dp-warning-bg) 88%, var(--dp-accent-bg));
  }

  .member-action-button:hover .member-action-button-icon,
  .member-action-button:focus-visible .member-action-button-icon {
    transform: translateX(3px);
  }

  .member-stat-card:hover,
  .member-section-card:hover,
  .member-mini-card:hover,
  .member-detail-item:hover {
    border-color: color-mix(in srgb, var(--dp-accent) 22%, var(--dp-border-primary));
    background-color: color-mix(in srgb, var(--dp-bg-card) 92%, var(--dp-accent-bg));
  }
}

@media (min-width: 1024px) {
  .member-detail-body {
    max-height: min(calc(90dvh - 5rem), 48rem);
  }
}

@media (max-width: 640px) {
  .member-section-card {
    border-radius: 1rem;
    padding: 0.85rem;
  }

  .member-detail-item,
  .member-mini-card,
  .member-stat-card {
    padding: 0.8rem;
  }

  .member-detail-main {
    font-size: 0.93rem;
  }

  .member-detail-inline-meta {
    font-size: 0.72rem;
  }

  .member-detail-inline-note {
    font-size: 0.74rem;
  }
}
</style>
