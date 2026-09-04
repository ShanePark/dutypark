<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useAdminModerationCounts } from '@/composables/useAdminModerationCounts'
import {
  Building2,
  Code2,
  ExternalLink,
  FileText,
  Flag,
  MessageSquare,
  Users,
} from 'lucide-vue-next'

const props = defineProps<{
  active: 'members' | 'teams' | 'reports' | 'inquiries' | 'dev'
  /** Unhandled report count shown as a tile badge. Omit to use the shared count; pass null to hide it. */
  openReportCount?: number | null
  /** Unhandled inquiry count shown as a tile badge. Omit to use the shared count; pass null to hide it. */
  openInquiryCount?: number | null
}>()

const {
  openReportCount: sharedOpenReportCount,
  openInquiryCount: sharedOpenInquiryCount,
  loadReports,
  loadInquiries,
} = useAdminModerationCounts()

const displayOpenReportCount = computed(() =>
  props.openReportCount === undefined ? sharedOpenReportCount.value : props.openReportCount,
)
const displayOpenInquiryCount = computed(() =>
  props.openInquiryCount === undefined ? sharedOpenInquiryCount.value : props.openInquiryCount,
)

// Keep the badge source in the shared composable when a view does not provide
// an explicit count, so it survives navigation between admin screens.
onMounted(() => {
  if (props.openReportCount === undefined) void loadReports(true)
  if (props.openInquiryCount === undefined) void loadInquiries(true)
})

const { t } = useI18n()

function setHoverBg(e: Event) {
  if (e.currentTarget) {
    (e.currentTarget as HTMLElement).style.backgroundColor = 'var(--dp-bg-hover)'
  }
}

function clearHoverBg(e: Event, bgColor = 'var(--dp-bg-card)') {
  if (e.currentTarget) {
    (e.currentTarget as HTMLElement).style.backgroundColor = bgColor
  }
}
</script>

<template>
  <div class="grid grid-cols-3 gap-2 sm:gap-4 mb-4 sm:mb-6">
    <router-link
      to="/admin"
      class="admin-top-tile"
      :class="active === 'members'
        ? 'admin-top-tile-active hover:bg-dp-surface-strong-hover'
        : 'bg-dp-bg-card border border-dp-border-primary'"
      @mouseover="(e: Event) => active !== 'members' && setHoverBg(e)"
      @mouseleave="(e: Event) => active !== 'members' && clearHoverBg(e)"
    >
      <Users class="admin-top-tile-icon" :class="active === 'members' ? 'text-dp-text-on-dark' : 'text-dp-text-secondary'" />
      <span class="admin-top-tile-label" :class="active === 'members' ? 'text-dp-text-on-dark' : 'text-dp-text-primary'">
        {{ t('admin.nav.members') }}
      </span>
    </router-link>

    <router-link
      to="/admin/teams"
      class="admin-top-tile"
      :class="active === 'teams'
        ? 'admin-top-tile-active hover:bg-dp-surface-strong-hover'
        : 'bg-dp-bg-card border border-dp-border-primary'"
      @mouseover="(e: Event) => active !== 'teams' && setHoverBg(e)"
      @mouseleave="(e: Event) => active !== 'teams' && clearHoverBg(e)"
    >
      <Building2 class="admin-top-tile-icon" :class="active === 'teams' ? 'text-dp-text-on-dark' : 'text-dp-text-secondary'" />
      <span class="admin-top-tile-label" :class="active === 'teams' ? 'text-dp-text-on-dark' : 'text-dp-text-primary'">
        {{ t('admin.nav.teams') }}
      </span>
    </router-link>

    <router-link
      to="/admin/reports"
      class="admin-top-tile"
      :class="active === 'reports'
        ? 'admin-top-tile-active hover:bg-dp-surface-strong-hover'
        : 'bg-dp-bg-card border border-dp-border-primary'"
      @mouseover="(e: Event) => active !== 'reports' && setHoverBg(e)"
      @mouseleave="(e: Event) => active !== 'reports' && clearHoverBg(e)"
    >
      <div class="mb-2 flex items-center gap-1">
        <Flag class="admin-top-tile-icon mb-0" :class="active === 'reports' ? 'text-dp-text-on-dark' : 'text-dp-text-secondary'" />
        <span
          v-if="displayOpenReportCount"
          class="admin-top-tile-badge"
          :aria-label="t('admin.nav.openCountAria', { count: displayOpenReportCount })"
        >{{ displayOpenReportCount }}</span>
      </div>
      <span class="admin-top-tile-label" :class="active === 'reports' ? 'text-dp-text-on-dark' : 'text-dp-text-primary'">
        {{ t('admin.nav.reports') }}
      </span>
    </router-link>

    <router-link
      to="/admin/inquiries"
      class="admin-top-tile"
      :class="active === 'inquiries'
        ? 'admin-top-tile-active hover:bg-dp-surface-strong-hover'
        : 'bg-dp-bg-card border border-dp-border-primary'"
      @mouseover="(e: Event) => active !== 'inquiries' && setHoverBg(e)"
      @mouseleave="(e: Event) => active !== 'inquiries' && clearHoverBg(e)"
    >
      <div class="mb-2 flex items-center gap-1">
        <MessageSquare class="admin-top-tile-icon mb-0" :class="active === 'inquiries' ? 'text-dp-text-on-dark' : 'text-dp-text-secondary'" />
        <span
          v-if="displayOpenInquiryCount"
          class="admin-top-tile-badge"
          :aria-label="t('admin.nav.openCountAria', { count: displayOpenInquiryCount })"
        >{{ displayOpenInquiryCount }}</span>
      </div>
      <span class="admin-top-tile-label" :class="active === 'inquiries' ? 'text-dp-text-on-dark' : 'text-dp-text-primary'">
        {{ t('admin.nav.inquiries') }}
      </span>
    </router-link>

    <router-link
      to="/admin/dev"
      class="admin-top-tile"
      :class="active === 'dev'
        ? 'admin-top-tile-active hover:bg-dp-surface-strong-hover'
        : 'bg-dp-bg-card border border-dp-border-primary'"
      @mouseover="(e: Event) => active !== 'dev' && setHoverBg(e)"
      @mouseleave="(e: Event) => active !== 'dev' && clearHoverBg(e)"
    >
      <Code2 class="admin-top-tile-icon" :class="active === 'dev' ? 'text-dp-text-on-dark' : 'text-dp-text-secondary'" />
      <span class="admin-top-tile-label" :class="active === 'dev' ? 'text-dp-text-on-dark' : 'text-dp-text-primary'">
        {{ t('admin.nav.dev') }}
      </span>
    </router-link>

    <a
      href="/docs/index.html"
      target="_blank"
      class="admin-top-tile bg-dp-bg-card border border-dp-border-primary"
      @mouseover="(e: Event) => setHoverBg(e)"
      @mouseleave="(e: Event) => clearHoverBg(e)"
    >
      <div class="mb-2 flex items-center gap-1">
        <FileText class="admin-top-tile-icon mb-0 text-dp-text-secondary" />
        <ExternalLink class="hidden sm:block w-3 h-3 text-dp-text-muted" />
      </div>
      <span class="admin-top-tile-label text-dp-text-primary">{{ t('admin.nav.apiDocs') }}</span>
    </a>
  </div>
</template>

<style scoped>
.admin-top-tile {
  display: flex;
  min-width: 0;
  min-height: 5.3rem;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border-radius: 1rem;
  padding: 0.75rem 0.4rem;
  text-align: center;
  transition:
    background-color 160ms ease,
    box-shadow 180ms ease,
    transform 180ms ease;
}

.admin-top-tile-active {
  background-color: var(--dp-modal-header-bg);
}

.admin-top-tile-icon {
  width: 1.15rem;
  height: 1.15rem;
  margin-bottom: 0.5rem;
  flex-shrink: 0;
}

.admin-top-tile-label {
  font-size: 0.72rem;
  line-height: 1.1rem;
  font-weight: 700;
  word-break: keep-all;
}

.admin-top-tile-badge {
  display: inline-flex;
  min-width: 1.15rem;
  align-items: center;
  justify-content: center;
  border-radius: 9999px;
  background-color: var(--dp-danger);
  color: var(--dp-text-on-dark);
  font-size: 0.65rem;
  font-weight: 700;
  line-height: 1;
  padding: 0.2rem 0.35rem;
}

@media (hover: hover) {
  .admin-top-tile:hover {
    transform: translateY(-1px);
  }
}

@media (min-width: 640px) {
  .admin-top-tile {
    min-height: auto;
    align-items: flex-start;
    padding: 1rem;
    text-align: left;
  }

  .admin-top-tile-icon {
    width: 1.5rem;
    height: 1.5rem;
  }

  .admin-top-tile-label {
    font-size: 1rem;
    line-height: 1.4rem;
  }
}
</style>
