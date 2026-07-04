<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
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

const { t, locale } = useI18n()
const effectiveMember = computed(() => props.memberDetail ?? props.member)
const visibilityLabel = computed(() => {
  locale.value
  if (!props.memberDetail) return t('admin.memberDetail.loading')
  return getVisibilityLabel(props.memberDetail.calendarVisibility)
})
const visibilityIcon = computed(() => {
  if (!props.memberDetail) return Eye
  return getVisibilityIcon(props.memberDetail.calendarVisibility)
})

const roleBadges = computed(() => {
  if (!props.memberDetail) return []

  const badges: Array<{ label: string; tone: string }> = []
  if (props.memberDetail.serviceAdmin) badges.push({ label: t('admin.memberDetail.badges.serviceAdmin'), tone: 'accent' })
  if (props.memberDetail.teamAdmin) badges.push({ label: t('admin.memberDetail.badges.teamLead'), tone: 'success' })
  if (!props.memberDetail.teamAdmin && props.memberDetail.teamManager) badges.push({ label: t('admin.memberDetail.badges.teamManager'), tone: 'warning' })
  if (props.memberDetail.auxiliaryAccount) badges.push({ label: t('admin.memberDetail.badges.auxiliaryAccount'), tone: 'muted' })
  if (!badges.length) badges.push({ label: t('admin.memberDetail.badges.member'), tone: 'muted' })
  return badges
})

const loginBadges = computed(() => {
  if (!props.memberDetail) return []

  const badges: string[] = []
  if (props.memberDetail.hasPassword) badges.push(t('admin.memberDetail.badges.password'))
  props.memberDetail.authProviders.forEach((provider) => {
    if (provider === 'KAKAO') badges.push(t('admin.memberDetail.badges.kakao'))
    else if (provider === 'NAVER') badges.push(t('admin.memberDetail.badges.naver'))
    else badges.push(provider)
  })
  if (!badges.length) badges.push(t('admin.memberDetail.badges.noLoginMethods'))
  return badges
})

const heroStats = computed(() => {
  if (!props.memberDetail) return []

  return [
    {
      label: t('admin.memberDetail.hero.totalSchedules'),
      value: formatNumber(props.memberDetail.totalScheduleCount),
      caption: t('admin.memberDetail.hero.totalSchedulesCaption', {
        count: formatNumber(props.memberDetail.upcomingScheduleCount),
      }),
      icon: CalendarDays,
    },
    {
      label: t('admin.memberDetail.hero.totalTodos'),
      value: formatNumber(props.memberDetail.totalTodoCount),
      caption: t('admin.memberDetail.hero.totalTodosCaption', {
        count: formatNumber(props.memberDetail.inProgressTodoCount),
      }),
      icon: ListTodo,
    },
    {
      label: t('admin.memberDetail.hero.activeSessions'),
      value: formatNumber(props.memberDetail.activeSessionCount),
      caption: t('admin.memberDetail.hero.activeSessionsCaption', {
        count: formatNumber(props.memberDetail.pushEnabledSessionCount),
      }),
      icon: Smartphone,
    },
    {
      label: t('admin.memberDetail.hero.unreadNotifications'),
      value: formatNumber(props.memberDetail.unreadNotificationCount),
      caption: t('admin.memberDetail.hero.unreadNotificationsCaption', {
        count: formatNumber(props.memberDetail.totalNotificationCount),
      }),
      icon: Bell,
    },
    {
      label: t('admin.memberDetail.hero.friends'),
      value: formatNumber(props.memberDetail.friendCount),
      caption: t('admin.memberDetail.hero.friendsCaption', {
        count: formatNumber(props.memberDetail.familyCount),
      }),
      icon: Users,
    },
    {
      label: t('admin.memberDetail.hero.managedAccounts'),
      value: formatNumber(props.memberDetail.managedMemberCount),
      caption: t('admin.memberDetail.hero.managedAccountsCaption', {
        count: formatNumber(props.memberDetail.managerCount),
      }),
      icon: UserCog,
    },
  ]
})

const primaryInfoRows = computed(() => {
  if (!props.memberDetail) return []

  return [
    {
      label: t('admin.memberDetail.fields.joinedAt'),
      value: formatDateLabel(props.memberDetail.createdDate),
      inlineMeta: formatTimeLabel(props.memberDetail.createdDate),
      inlineNote: formatSince(props.memberDetail.createdDate),
      valueClass: 'member-detail-main-strong',
    },
    {
      label: t('admin.memberDetail.fields.lastUpdated'),
      value: formatDateLabel(props.memberDetail.lastModifiedDate),
      inlineMeta: formatTimeLabel(props.memberDetail.lastModifiedDate),
      inlineNote: formatSince(props.memberDetail.lastModifiedDate),
      valueClass: 'member-detail-main-strong',
    },
    {
      label: t('admin.memberDetail.fields.lastActive'),
      value: props.memberDetail.lastActiveAt ? formatDateLabel(props.memberDetail.lastActiveAt) : t('admin.memberDetail.values.noActivity'),
      inlineMeta: props.memberDetail.lastActiveAt ? formatTimeLabel(props.memberDetail.lastActiveAt) : null,
      inlineNote: props.memberDetail.lastActiveAt ? formatSince(props.memberDetail.lastActiveAt) : null,
      valueClass: props.memberDetail.lastActiveAt ? 'member-detail-main-strong' : 'member-detail-main-muted',
    },
    {
      label: t('admin.memberDetail.fields.email'),
      value: props.memberDetail.email || t('admin.memberDetail.values.noEmail'),
      valueClass: props.memberDetail.email ? 'member-detail-main-break' : 'member-detail-main-muted',
    },
    {
      label: t('admin.memberDetail.fields.team'),
      value: props.memberDetail.teamName || t('admin.memberDetail.values.noTeam'),
      valueClass: 'member-detail-main-strong',
    },
    {
      label: t('admin.memberDetail.fields.visibility'),
      value: visibilityLabel.value,
      valueClass: 'member-detail-main-strong',
    },
  ]
})

const relationshipGroups = computed(() => {
  if (!props.memberDetail) return []

  return [
    {
      title: t('admin.memberDetail.relationships.managersOfMemberTitle'),
      emptyText: t('admin.memberDetail.relationships.managersOfMemberEmpty'),
      items: props.memberDetail.managerNames,
      countText: t('admin.memberDetail.relationships.countText', {
        count: formatNumber(props.memberDetail.managerCount),
      }),
    },
    {
      title: t('admin.memberDetail.relationships.managedByMemberTitle'),
      emptyText: t('admin.memberDetail.relationships.managedByMemberEmpty'),
      items: props.memberDetail.managedMemberNames,
      countText: t('admin.memberDetail.relationships.countText', {
        count: formatNumber(props.memberDetail.managedMemberCount),
      }),
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
  return new Intl.NumberFormat(locale.value).format(value)
}

function formatDateLabel(value: string) {
  const date = new Date(value)
  return new Intl.DateTimeFormat(locale.value, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  }).format(date)
}

function formatTimeLabel(value: string) {
  const date = new Date(value)
  return new Intl.DateTimeFormat(locale.value, {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(date)
}

function formatSince(value: string) {
  const diffMs = Date.now() - new Date(value).getTime()
  const diffDays = Math.max(0, Math.floor(diffMs / 86400000))

  if (diffDays === 0) return t('admin.memberDetail.relativeTime.today')
  if (diffDays < 30) return t('admin.memberDetail.relativeTime.daysAgo', { count: diffDays })
  if (diffDays < 365) return t('admin.memberDetail.relativeTime.monthsAgo', { count: Math.floor(diffDays / 30) })
  return t('admin.memberDetail.relativeTime.yearsAgo', { count: Math.floor(diffDays / 365) })
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
            <h2>{{ effectiveMember?.name ?? t('admin.memberDetail.titleFallback') }}</h2>
            <p class="mt-1 text-xs sm:text-sm text-dp-text-secondary">{{ t('admin.memberDetail.subtitle') }}</p>
          </div>
          <button
            class="p-2 rounded-full hover-close-btn cursor-pointer text-dp-text-muted"
            @click="emit('close')"
            :aria-label="t('admin.memberDetail.closeAria')"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <div class="member-detail-body modal-body p-4 sm:p-5">
          <div v-if="loading" class="flex min-h-64 items-center justify-center">
            <div class="flex items-center gap-3 text-dp-text-secondary">
              <Loader2 class="w-5 h-5 animate-spin" />
              <span>{{ t('admin.memberDetail.loadingMessage') }}</span>
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
              {{ t('admin.memberDetail.retry') }}
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
                        {{ effectiveMember?.name ?? t('admin.memberDetail.titleFallback') }}
                      </h3>
                      <span class="member-inline-badge">ID {{ effectiveMember?.id ?? '-' }}</span>
                    </div>
                    <p class="mt-1 text-sm sm:text-base text-dp-text-secondary break-all">
                      {{ effectiveMember?.email || t('admin.memberDetail.values.noEmail') }}
                    </p>
                    <p class="mt-1 text-sm text-dp-text-muted">
                      {{ effectiveMember?.teamName || t('admin.memberDetail.values.noTeam') }}
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
                      {{ t('admin.memberDetail.actions.viewSchedule') }}
                      <ChevronRight class="member-action-button-icon w-4 h-4" />
                    </span>
                  </button>
                  <button
                    class="member-action-button member-action-button-warning"
                    @click="openPasswordModal"
                  >
                    {{ t('admin.memberDetail.actions.changePassword') }}
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
                <h3 class="text-base font-semibold text-dp-text-primary">{{ t('admin.memberDetail.sections.basicInfo') }}</h3>
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
                <h3 class="text-base font-semibold text-dp-text-primary">{{ t('admin.memberDetail.sections.accountStatus') }}</h3>
              </div>
              <div class="mt-3 space-y-3">
                <div class="member-detail-item">
                  <p class="member-detail-label">{{ t('admin.memberDetail.fields.loginMethods') }}</p>
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
                    <p class="member-detail-label">{{ t('admin.memberDetail.fields.visibility') }}</p>
                    <div class="mt-1 flex items-center gap-2">
                      <component :is="visibilityIcon" class="w-4 h-4 text-dp-text-secondary" />
                      <span class="member-detail-main member-detail-main-strong">{{ visibilityLabel }}</span>
                    </div>
                  </article>
                  <article class="member-detail-item">
                    <p class="member-detail-label">{{ t('admin.memberDetail.fields.pushSessions') }}</p>
                    <p class="mt-1 member-detail-main member-detail-main-strong">
                      {{ t('admin.memberDetail.metrics.sessions', { count: formatNumber(memberDetail.pushEnabledSessionCount) }) }}
                    </p>
                  </article>
                </div>
              </div>
            </section>

            <section class="member-section-card xl:col-span-2">
              <div class="flex items-center gap-2">
                <CalendarDays class="w-4 h-4 text-dp-text-secondary" />
                <h3 class="text-base font-semibold text-dp-text-primary">{{ t('admin.memberDetail.sections.summary') }}</h3>
              </div>
              <div class="mt-3 grid gap-2 lg:grid-cols-3">
                <article class="member-mini-card">
                  <p class="text-xs font-medium text-dp-text-muted">{{ t('admin.memberDetail.summaryCards.schedules') }}</p>
                  <div class="mt-2 space-y-1.5 text-sm text-dp-text-primary">
                    <div class="member-summary-row">
                      <span>{{ t('admin.memberDetail.summaryCards.directCreated') }}</span>
                      <strong>{{ formatNumber(memberDetail.totalScheduleCount) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>{{ t('admin.memberDetail.summaryCards.upcoming') }}</span>
                      <strong>{{ formatNumber(memberDetail.upcomingScheduleCount) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>{{ t('admin.memberDetail.summaryCards.tagged') }}</span>
                      <strong>{{ formatNumber(memberDetail.taggedScheduleCount) }}</strong>
                    </div>
                  </div>
                </article>

                <article class="member-mini-card">
                  <p class="text-xs font-medium text-dp-text-muted">{{ t('admin.memberDetail.summaryCards.todo') }}</p>
                  <div class="mt-2 space-y-1.5 text-sm text-dp-text-primary">
                    <div class="member-summary-row">
                      <span>{{ t('admin.memberDetail.summaryCards.pending') }}</span>
                      <strong>{{ formatNumber(memberDetail.todoCount) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>{{ t('admin.memberDetail.summaryCards.inProgress') }}</span>
                      <strong>{{ formatNumber(memberDetail.inProgressTodoCount) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>{{ t('admin.memberDetail.summaryCards.done') }}</span>
                      <strong>{{ formatNumber(memberDetail.doneTodoCount) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>{{ t('admin.memberDetail.summaryCards.overdue') }}</span>
                      <strong class="text-dp-warning">{{ formatNumber(memberDetail.overdueTodoCount) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>{{ t('admin.memberDetail.summaryCards.dueToday') }}</span>
                      <strong>{{ formatNumber(memberDetail.dueTodayTodoCount) }}</strong>
                    </div>
                  </div>
                </article>

                <article class="member-mini-card">
                  <div class="flex items-start justify-between gap-3">
                    <div>
                      <p class="text-xs font-medium text-dp-text-muted">{{ t('admin.memberDetail.summaryCards.dday') }}</p>
                      <p class="mt-1 text-lg font-bold text-dp-text-primary">{{ t('admin.memberDetail.metrics.items', { count: formatNumber(dDaySummary.total) }) }}</p>
                    </div>
                    <span class="member-inline-badge">{{ t('admin.memberDetail.badges.adminViewOnly') }}</span>
                  </div>
                  <div class="mt-2 space-y-1.5 text-sm text-dp-text-primary">
                    <div class="member-summary-row">
                      <span>{{ t('admin.memberDetail.summaryCards.total') }}</span>
                      <strong>{{ formatNumber(dDaySummary.total) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>{{ t('admin.memberDetail.summaryCards.public') }}</span>
                      <strong>{{ formatNumber(dDaySummary.publicCount) }}</strong>
                    </div>
                    <div class="member-summary-row">
                      <span>{{ t('admin.memberDetail.summaryCards.private') }}</span>
                      <strong>{{ formatNumber(dDaySummary.privateCount) }}</strong>
                    </div>
                  </div>
                </article>
              </div>
            </section>

            <section class="member-section-card xl:col-span-2">
              <div class="flex items-center gap-2">
                <Users class="w-4 h-4 text-dp-text-secondary" />
                <h3 class="text-base font-semibold text-dp-text-primary">{{ t('admin.memberDetail.sections.relationships') }}</h3>
              </div>
              <div class="mt-3 grid gap-2 sm:grid-cols-2">
                <article class="member-mini-card">
                  <p class="text-xs font-medium text-dp-text-muted">{{ t('admin.memberDetail.relationships.friendRequests') }}</p>
                  <div class="mt-3 grid grid-cols-2 gap-3 text-sm">
                    <div>
                      <p class="text-dp-text-secondary">{{ t('admin.memberDetail.relationships.received') }}</p>
                      <p class="mt-1 text-lg font-bold text-dp-text-primary">{{ formatNumber(memberDetail.pendingReceivedFriendRequestCount) }}</p>
                    </div>
                    <div>
                      <p class="text-dp-text-secondary">{{ t('admin.memberDetail.relationships.sent') }}</p>
                      <p class="mt-1 text-lg font-bold text-dp-text-primary">{{ formatNumber(memberDetail.pendingSentFriendRequestCount) }}</p>
                    </div>
                  </div>
                </article>

                <article class="member-mini-card">
                  <p class="text-xs font-medium text-dp-text-muted">{{ t('admin.memberDetail.relationships.friendsFamily') }}</p>
                  <div class="mt-3 grid grid-cols-2 gap-3 text-sm">
                    <div>
                      <p class="text-dp-text-secondary">{{ t('admin.memberDetail.relationships.friends') }}</p>
                      <p class="mt-1 text-lg font-bold text-dp-text-primary">{{ formatNumber(memberDetail.friendCount) }}</p>
                    </div>
                    <div>
                      <p class="text-dp-text-secondary">{{ t('admin.memberDetail.relationships.family') }}</p>
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
