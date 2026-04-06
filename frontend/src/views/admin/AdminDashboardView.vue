<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { adminApi } from '@/api/admin'
import { authApi } from '@/api/auth'
import { refreshTokenApi } from '@/api/member'
import { useSwal } from '@/composables/useSwal'
import type { AdminMemberDetailDto, AdminMemberDto, RefreshTokenDto } from '@/types'
import { resolveApiErrorMessage } from '@/utils/resolveApiError'
import SessionTokenList from '@/components/common/SessionTokenList.vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import BaseModal from '@/components/common/BaseModal.vue'
import AdminMemberDetailModal from '@/components/admin/AdminMemberDetailModal.vue'
import { countTodayLogins } from './adminDashboardStats'
import {
  Users,
  Building2,
  ChevronLeft,
  ChevronRight,
  Search,
  Code2,
  Loader2,
  FileText,
  ExternalLink,
  X,
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const { t } = useI18n()
const { showSuccess, showError, confirm, toastSuccess } = useSwal()

const loading = ref(true)
const members = ref<AdminMemberDto[]>([])
const allTokens = ref<RefreshTokenDto[]>([])

// Pagination state
const currentPage = ref(0)
const totalPages = ref(0)
const totalElements = ref(0)
const pageSize = 10

const stats = computed(() => {
  return {
    totalMembers: totalElements.value,
    totalTeams: new Set(members.value.map(m => m.teamId).filter(Boolean)).size,
    activeTokens: allTokens.value.length,
    todayLogins: countTodayLogins(allTokens.value),
  }
})

const searchKeyword = ref('')
const isLoading = ref(false)

// Debounce search
let searchTimeout: ReturnType<typeof setTimeout> | null = null
watch(searchKeyword, () => {
  if (searchTimeout) clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    currentPage.value = 0
    fetchMembers()
  }, 300)
})


const showPasswordModal = ref(false)
const passwordTargetMember = ref<{ id: number; name: string } | null>(null)
const newPassword = ref('')
const confirmPassword = ref('')
const passwordError = ref('')
const showMemberDetailModal = ref(false)
const selectedMemberId = ref<number | null>(null)
const selectedMemberDetail = ref<AdminMemberDetailDto | null>(null)
const isMemberDetailLoading = ref(false)
const memberDetailError = ref<string | null>(null)
let memberDetailRequestId = 0

const selectedMemberForDetail = computed(() => {
  if (selectedMemberId.value == null) return null
  return members.value.find(member => member.id === selectedMemberId.value) ?? null
})

function openPasswordModal(member: { id: number; name: string }) {
  passwordTargetMember.value = member
  newPassword.value = ''
  confirmPassword.value = ''
  passwordError.value = ''
  showPasswordModal.value = true
}

function closePasswordModal() {
  showPasswordModal.value = false
  passwordTargetMember.value = null
}

const changingPassword = ref(false)

async function handleChangePassword() {
  if (!newPassword.value || !confirmPassword.value) {
    passwordError.value = t('admin.dashboard.password.validation.required')
    return
  }
  if (newPassword.value.length < 8) {
    passwordError.value = t('admin.dashboard.password.validation.min')
    return
  }
  if (newPassword.value !== confirmPassword.value) {
    passwordError.value = t('admin.dashboard.password.validation.mismatch')
    return
  }

  changingPassword.value = true
  try {
    await authApi.changePassword({
      memberId: passwordTargetMember.value!.id,
      newPassword: newPassword.value,
    })
    showSuccess(t('admin.dashboard.messages.changePasswordSuccess', { name: passwordTargetMember.value?.name ?? '' }))
    closePasswordModal()
  } catch (error: any) {
    const message = resolveApiErrorMessage(error, { fallbackKey: 'admin.dashboard.messages.changePasswordFailed' }, t)
    passwordError.value = message
  } finally {
    changingPassword.value = false
  }
}

async function handleRevokeToken(tokenId: number, member: AdminMemberDto) {
  if (!await confirm(
    t('admin.dashboard.messages.revokeSessionConfirm', { name: member.name }),
    t('admin.dashboard.messages.revokeSessionTitle'),
  )) return

  try {
    await refreshTokenApi.deleteRefreshToken(tokenId)
    toastSuccess(t('admin.dashboard.messages.revokeSessionSuccess', { name: member.name }))
    member.tokens = member.tokens.filter(t => t.id !== tokenId)
    allTokens.value = allTokens.value.filter(t => t.id !== tokenId)
    if (showMemberDetailModal.value && selectedMemberId.value === member.id) {
      fetchSelectedMemberDetail(member.id)
    }
  } catch (error) {
    console.error('Failed to revoke token:', error)
    showError(t('admin.dashboard.messages.revokeSessionFailed'))
  }
}

async function fetchSelectedMemberDetail(memberId: number = selectedMemberId.value ?? -1) {
  if (!memberId || memberId < 0) return

  const requestId = ++memberDetailRequestId
  isMemberDetailLoading.value = true
  memberDetailError.value = null

  try {
    const res = await adminApi.getMemberDetail(memberId)
    if (requestId !== memberDetailRequestId) return
    selectedMemberDetail.value = res.data
  } catch (error) {
    console.error('Failed to fetch member detail:', error)
    if (requestId !== memberDetailRequestId) return
    selectedMemberDetail.value = null
    memberDetailError.value = t('admin.dashboard.messages.loadMemberDetailFailed')
  } finally {
    if (requestId === memberDetailRequestId) {
      isMemberDetailLoading.value = false
    }
  }
}

function openMemberDetail(member: AdminMemberDto) {
  selectedMemberId.value = member.id
  selectedMemberDetail.value = null
  memberDetailError.value = null
  showMemberDetailModal.value = true
  fetchSelectedMemberDetail(member.id)
}

function closeMemberDetailModal() {
  showMemberDetailModal.value = false
  selectedMemberId.value = null
  selectedMemberDetail.value = null
  memberDetailError.value = null
  memberDetailRequestId += 1
  isMemberDetailLoading.value = false
}

function openPasswordModalFromDetail(member: AdminMemberDto) {
  closeMemberDetailModal()
  openPasswordModal(member)
}

async function goToMemberSchedule(memberId: number) {
  closeMemberDetailModal()
  await router.push({ name: 'duty', params: { id: String(memberId) } })
}

async function fetchMembers() {
  isLoading.value = true
  try {
    const res = await adminApi.getMembers(searchKeyword.value, currentPage.value, pageSize)
    members.value = res.data.content
    totalPages.value = res.data.totalPages
    totalElements.value = res.data.totalElements
  } catch (error) {
    console.error('Failed to fetch members:', error)
    showError(t('admin.dashboard.messages.loadMembersFailed'))
  } finally {
    isLoading.value = false
  }
}

async function fetchTokens() {
  try {
    const res = await adminApi.getAllRefreshTokens()
    allTokens.value = res.data
  } catch (error) {
    console.error('Failed to fetch tokens:', error)
  }
}

async function fetchData() {
  loading.value = true
  try {
    await Promise.all([fetchMembers(), fetchTokens()])
  } catch (error) {
    console.error('Failed to fetch admin data:', error)
    showError(t('admin.dashboard.messages.loadDataFailed'))
  } finally {
    loading.value = false
  }
}

async function refreshData() {
  await fetchData()
}

function goToPage(page: number) {
  if (page >= 0 && page < totalPages.value) {
    currentPage.value = page
    fetchMembers()
  }
}

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

onMounted(async () => {
  if (!authStore.isAdmin) {
    router.push('/')
    return
  }
  await fetchData()
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
      <div v-if="loading" class="flex items-center justify-center py-20">
        <Loader2 class="w-8 h-8 animate-spin text-dp-text-muted" />
      </div>

      <template v-else>
        <!-- Admin Navigation -->
        <div class="grid grid-cols-4 gap-2 sm:gap-4 mb-4 sm:mb-6">
          <router-link
            to="/admin"
            class="admin-top-tile admin-top-tile-active hover:bg-dp-surface-strong-hover"
          >
            <Users class="admin-top-tile-icon text-dp-text-on-dark" />
            <span class="admin-top-tile-label text-dp-text-on-dark">{{ t('admin.nav.members') }}</span>
          </router-link>
          <router-link
            to="/admin/teams"
            class="admin-top-tile bg-dp-bg-card border border-dp-border-primary"
            @mouseover="(e: Event) => setHoverBg(e)"
            @mouseleave="(e: Event) => clearHoverBg(e)"
          >
            <Building2 class="admin-top-tile-icon text-dp-text-secondary" />
            <span class="admin-top-tile-label text-dp-text-primary">{{ t('admin.nav.teams') }}</span>
          </router-link>
          <router-link
            to="/admin/dev"
            class="admin-top-tile bg-dp-bg-card border border-dp-border-primary"
            @mouseover="(e: Event) => setHoverBg(e)"
            @mouseleave="(e: Event) => clearHoverBg(e)"
          >
            <Code2 class="admin-top-tile-icon text-dp-text-secondary" />
            <span class="admin-top-tile-label text-dp-text-primary">{{ t('admin.nav.dev') }}</span>
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

        <!-- Stats Cards -->
        <div class="admin-stats-band mb-4 sm:mb-6" :aria-label="t('admin.dashboard.statsAriaLabel')">
          <div class="admin-stats-grid">
            <div class="admin-stat-tile">
              <p class="admin-stat-kicker text-dp-text-muted">{{ t('admin.dashboard.stats.totalMembersLabel') }}</p>
              <p class="admin-stat-tile-value text-dp-text-primary">{{ stats.totalMembers }}</p>
              <p class="admin-stat-tile-note text-dp-text-secondary">{{ t('admin.dashboard.stats.totalMembersNote') }}</p>
            </div>
            <div class="admin-stat-tile">
              <p class="admin-stat-kicker text-dp-text-muted">{{ t('admin.dashboard.stats.totalTeamsLabel') }}</p>
              <p class="admin-stat-tile-value text-dp-text-primary">{{ stats.totalTeams }}</p>
              <p class="admin-stat-tile-note text-dp-text-secondary">{{ t('admin.dashboard.stats.totalTeamsNote') }}</p>
            </div>
            <div class="admin-stat-tile">
              <p class="admin-stat-kicker text-dp-text-muted">{{ t('admin.dashboard.stats.activeTokensLabel') }}</p>
              <p class="admin-stat-tile-value text-dp-text-primary">{{ stats.activeTokens }}</p>
              <p class="admin-stat-tile-note text-dp-text-secondary">{{ t('admin.dashboard.stats.activeTokensNote') }}</p>
            </div>
            <div class="admin-stat-tile">
              <p class="admin-stat-kicker text-dp-text-muted">{{ t('admin.dashboard.stats.todayLoginsLabel') }}</p>
              <p class="admin-stat-tile-value text-dp-text-primary">{{ stats.todayLogins }}</p>
              <p class="admin-stat-tile-note text-dp-text-secondary">{{ t('admin.dashboard.stats.todayLoginsNote') }}</p>
            </div>
          </div>
        </div>

        <!-- Member Management Section -->
        <div class="rounded-xl bg-dp-bg-card border border-dp-border-primary">
          <div class="p-4 border-b border-dp-border-primary">
            <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <h2 class="text-lg font-semibold text-dp-text-primary">{{ t('admin.dashboard.title') }}</h2>
              <div class="relative w-full sm:w-auto">
                <Search class="w-4 h-4 absolute left-3 top-1/2 transform -translate-y-1/2 text-dp-text-muted" />
                <input
                  v-model="searchKeyword"
                  type="text"
                  :placeholder="t('admin.dashboard.searchPlaceholder')"
                  class="w-full sm:w-auto pl-9 pr-4 py-2 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-dp-text-primary focus:border-transparent bg-dp-bg-input border border-dp-border-input text-dp-text-primary"
                />
              </div>
            </div>
          </div>

          <div class="border-t border-dp-border-secondary">
            <div v-if="isLoading" class="flex items-center justify-center py-12">
              <Loader2 class="w-6 h-6 animate-spin text-dp-text-muted" />
            </div>

            <template v-else>
              <div
                v-for="member in members"
                :key="member.id"
                class="admin-member-row group/admin-member p-4 border-b border-dp-border-secondary cursor-pointer focus-visible:outline-none"
                role="button"
                tabindex="0"
                @click="openMemberDetail(member)"
                @keydown.enter.prevent="openMemberDetail(member)"
                @keydown.space.prevent="openMemberDetail(member)"
              >
                <div class="flex items-start justify-between gap-3 mb-3">
                  <div class="flex min-w-0 items-center gap-3">
                    <div class="admin-member-avatar-ring">
                      <ProfileAvatar :member-id="member.id" :has-profile-photo="member.hasProfilePhoto" :profile-photo-version="member.profilePhotoVersion" size="md" :name="member.name" />
                    </div>
                    <div class="min-w-0">
                      <p class="admin-member-name font-medium truncate text-dp-text-primary">{{ member.name }}</p>
                      <p class="admin-member-meta text-sm text-dp-text-secondary">
                        {{ member.tokens.length > 0
                          ? t('admin.dashboard.memberRow.activeSessions', { count: member.tokens.length })
                          : t('admin.dashboard.memberRow.noActiveSessions') }}
                      </p>
                    </div>
                  </div>
                  <div class="admin-member-aside flex flex-col items-end gap-1 text-dp-text-muted">
                    <span class="text-xs whitespace-nowrap">{{ member.teamName || t('admin.dashboard.memberRow.noTeam') }}</span>
                    <ChevronRight class="admin-member-chevron w-4 h-4" />
                  </div>
                </div>

                <div v-if="member.tokens.length > 0" class="ml-0 sm:ml-13 mt-2" @click.stop>
                  <SessionTokenList
                    :tokens="member.tokens"
                    :loading="false"
                    :show-delete-button="true"
                    :compact="true"
                    :collapsible="true"
                    @delete="(tokenId: number) => handleRevokeToken(tokenId, member)"
                  />
                </div>
              </div>

              <div v-if="members.length === 0" class="p-8 text-center text-dp-text-muted">
                {{ t('admin.dashboard.empty') }}
              </div>
            </template>
          </div>

          <!-- Pagination -->
          <div v-if="totalPages > 1" class="p-4 flex items-center justify-between" :style="{ borderTop: '1px solid var(--dp-border-primary)' }">
            <p class="text-sm text-dp-text-secondary">
              {{ t('admin.dashboard.pagination', {
                total: totalElements,
                start: currentPage * pageSize + 1,
                end: Math.min((currentPage + 1) * pageSize, totalElements),
              }) }}
            </p>
            <div class="flex items-center gap-2">
              <button
                @click="goToPage(currentPage - 1)"
                :disabled="currentPage === 0"
                class="p-2 rounded-lg transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed bg-dp-bg-tertiary"
              >
                <ChevronLeft class="w-4 h-4 text-dp-text-secondary" />
              </button>
              <span class="text-sm px-2 text-dp-text-primary">
                {{ currentPage + 1 }} / {{ totalPages }}
              </span>
              <button
                @click="goToPage(currentPage + 1)"
                :disabled="currentPage >= totalPages - 1"
                class="p-2 rounded-lg transition cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                :style="{ backgroundColor: 'var(--dp-bg-tertiary)' }"
              >
                <ChevronRight class="w-4 h-4 text-dp-text-secondary" />
              </button>
            </div>
          </div>
        </div>
      </template>

    <AdminMemberDetailModal
      :open="showMemberDetailModal"
      :member="selectedMemberForDetail"
      :member-detail="selectedMemberDetail"
      :loading="isMemberDetailLoading"
      :load-error="memberDetailError"
      @close="closeMemberDetailModal"
      @retry="fetchSelectedMemberDetail()"
      @go-to-schedule="goToMemberSchedule"
      @change-password="openPasswordModalFromDetail"
    />

    <!-- Password Change Modal -->
    <BaseModal
      :is-open="showPasswordModal"
      size="md"
      height="fit"
      rounded
      z-index="admin"
      @close="closePasswordModal"
    >
      <div class="modal-header">
        <div>
          <h2>{{ t('admin.dashboard.password.modalTitle') }}</h2>
          <p class="mt-1 text-sm text-dp-text-secondary">
            {{ t('admin.dashboard.password.modalDescription', { name: passwordTargetMember?.name ?? '' }) }}
          </p>
        </div>
        <button
          @click="closePasswordModal"
          class="p-1.5 rounded-full hover-close-btn cursor-pointer"
        >
          <X class="w-5 h-5 text-dp-text-primary" />
        </button>
      </div>
      <div class="modal-body-form">
        <div>
          <label class="form-label">{{ t('admin.dashboard.password.newLabel') }}</label>
          <input
            v-model="newPassword"
            type="password"
            class="form-control-neutral"
            :placeholder="t('admin.dashboard.password.newPlaceholder')"
          />
        </div>
        <div>
          <label class="form-label">{{ t('admin.dashboard.password.confirmLabel') }}</label>
          <input
            v-model="confirmPassword"
            type="password"
            class="form-control-neutral"
            :placeholder="t('admin.dashboard.password.confirmPlaceholder')"
          />
        </div>
        <p v-if="passwordError" class="text-sm text-dp-danger">{{ passwordError }}</p>
      </div>
      <div class="modal-actions modal-actions-end modal-footer-safe">
        <button
          @click="closePasswordModal"
          :disabled="changingPassword"
          class="px-4 py-2 text-sm font-medium rounded-lg transition disabled:opacity-50 cursor-pointer bg-dp-bg-tertiary text-dp-text-primary hover-interactive"
        >
          {{ t('common.actions.cancel') }}
        </button>
        <button
          @click="handleChangePassword"
          :disabled="changingPassword"
          class="px-4 py-2 text-sm font-medium text-dp-text-on-dark bg-dp-surface-strong hover:bg-dp-surface-strong-hover rounded-lg transition disabled:opacity-50 flex items-center gap-2 cursor-pointer"
        >
          <Loader2 v-if="changingPassword" class="w-4 h-4 animate-spin" />
          {{ changingPassword ? t('admin.dashboard.password.changing') : t('admin.dashboard.password.change') }}
        </button>
      </div>
    </BaseModal>
  </div>
</template>

<style scoped>
.admin-top-tile {
  min-width: 0;
  transition:
    background-color 160ms ease,
    box-shadow 180ms ease,
    transform 180ms ease;
}

.admin-top-tile {
  display: flex;
  min-height: 5.3rem;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border-radius: 1rem;
  padding: 0.75rem 0.4rem;
  text-align: center;
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

.admin-stats-band {
  overflow: hidden;
  border: 1px solid var(--dp-border-primary);
  border-radius: 1.15rem;
  background:
    linear-gradient(
      180deg,
      color-mix(in srgb, var(--dp-bg-card) 92%, var(--dp-bg-secondary)) 0%,
      color-mix(in srgb, var(--dp-bg-card) 80%, var(--dp-bg-tertiary)) 100%
    );
  box-shadow:
    inset 0 1px 0 color-mix(in srgb, var(--dp-bg-card) 72%, white 28%),
    inset 0 -1px 0 color-mix(in srgb, var(--dp-border-secondary) 35%, transparent);
}

.admin-stats-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.admin-stat-tile {
  min-width: 0;
  min-height: 5.15rem;
  padding: 0.68rem 0.3rem 0.62rem;
  text-align: center;
  user-select: none;
}

.admin-stat-tile + .admin-stat-tile {
  border-left: 1px solid color-mix(in srgb, var(--dp-border-primary) 78%, transparent);
}

.admin-stat-kicker {
  font-size: 0.68rem;
  line-height: 0.95rem;
  font-weight: 600;
  letter-spacing: -0.01em;
  word-break: keep-all;
}

.admin-stat-tile-value {
  margin-top: 0.2rem;
  font-size: 1.55rem;
  line-height: 1.15;
  font-weight: 700;
}

.admin-stat-tile-note {
  margin-top: 0.16rem;
  font-size: 0.68rem;
  line-height: 0.95rem;
  word-break: keep-all;
}

.admin-member-row {
  position: relative;
  transition:
    background-color 160ms ease,
    box-shadow 180ms ease,
    transform 180ms ease;
}

.admin-member-avatar-ring,
.admin-member-name,
.admin-member-meta,
.admin-member-aside,
.admin-member-chevron {
  transition:
    transform 180ms ease,
    color 180ms ease,
    opacity 180ms ease,
    box-shadow 180ms ease,
    background-color 180ms ease;
}

.admin-member-avatar-ring {
  border-radius: 9999px;
}

.admin-member-row:focus-visible {
  background-color: color-mix(in srgb, var(--dp-bg-hover) 74%, var(--dp-accent-bg));
  box-shadow:
    inset 3px 0 0 color-mix(in srgb, var(--dp-accent) 72%, transparent),
    0 0 0 2px color-mix(in srgb, var(--dp-accent) 18%, transparent);
}

@media (hover: hover) {
  .admin-top-tile:hover {
    transform: translateY(-1px);
  }

  .admin-member-row:hover {
    background-color: color-mix(in srgb, var(--dp-bg-hover) 74%, var(--dp-accent-bg));
    box-shadow: inset 3px 0 0 color-mix(in srgb, var(--dp-accent) 72%, transparent);
    transform: translateY(-1px);
  }

  .admin-member-row:hover .admin-member-avatar-ring,
  .admin-member-row:focus-visible .admin-member-avatar-ring {
    box-shadow:
      0 0 0 5px color-mix(in srgb, var(--dp-accent) 12%, transparent),
      0 10px 24px color-mix(in srgb, var(--dp-overlay-scrim) 14%, transparent);
  }

  .admin-member-row:hover .admin-member-name,
  .admin-member-row:focus-visible .admin-member-name {
    color: color-mix(in srgb, var(--dp-text-primary) 58%, var(--dp-accent));
  }

  .admin-member-row:hover .admin-member-meta,
  .admin-member-row:focus-visible .admin-member-meta,
  .admin-member-row:hover .admin-member-aside,
  .admin-member-row:focus-visible .admin-member-aside {
    color: var(--dp-text-primary);
  }

  .admin-member-row:hover .admin-member-chevron,
  .admin-member-row:focus-visible .admin-member-chevron {
    color: var(--dp-accent);
    transform: translateX(4px);
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

  .admin-stats-band {
    border-radius: 1.35rem;
  }

  .admin-stat-tile {
    min-height: 6rem;
    padding: 1rem 1.1rem 0.95rem;
    text-align: left;
  }

  .admin-stat-kicker {
    font-size: 0.82rem;
    line-height: 1.1rem;
  }

  .admin-stat-tile-value {
    margin-top: 0.3rem;
    font-size: 1.85rem;
  }

  .admin-stat-tile-note {
    margin-top: 0.2rem;
    font-size: 0.8rem;
    line-height: 1.1rem;
  }
}
</style>
