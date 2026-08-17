<script setup lang="ts">
import { ref, computed, nextTick, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import {
  canUnlinkSocialAccount,
  getSocialAccountUnlinkErrorKey,
  getVisibleSocialAccountProviders,
  memberApi,
  refreshAppleLinkMemberState,
  refreshTokenApi,
  type SocialAccountProvider,
} from '@/api/member'
import { authApi } from '@/api/auth'
import { useSwal } from '@/composables/useSwal'
import { useLogout } from '@/composables/useLogout'
import { useKakao } from '@/composables/useKakao'
import { useNaver } from '@/composables/useNaver'
import { AppleSignInError, isAppleSignInCancellation, useApple } from '@/composables/useApple'
import type { MemberPreviewDto, MemberDto, RefreshTokenDto } from '@/types'
import BaseModal from '@/components/common/BaseModal.vue'
import PageHeader from '@/components/common/PageHeader.vue'
import SessionTokenList from '@/components/common/SessionTokenList.vue'
import { sessionClientName } from '@/components/common/sessionClient'
import ProfilePhotoUploader from '@/components/common/ProfilePhotoUploader.vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import DutyPatternCard from '@/components/member/DutyPatternCard.vue'
import SocialAccountConnectionModal from '@/components/member/SocialAccountConnectionModal.vue'
import AccountDeletionModal from '@/components/member/AccountDeletionModal.vue'
import type { AccountDeletionCompletion } from '@/utils/accountDeletionFlow'
import {
  clearPendingSocialLinkProvider,
  consumeConnectedPendingSocialLinkProvider,
  consumeSocialLinkCallback,
  storePendingSocialLinkProvider,
  type SocialLinkProvider,
} from '@/utils/socialLinkCallback'
import { resolveApiErrorMessage } from '@/utils/resolveApiError'
import {
  User,
  Building2,
  Mail,
  Shield,
  Smartphone,
  Link,
  Lock,
  UserX,
  LogOut,
  Trash2,
  Info,
  Check,
  X,
  Loader2,
  Users,
  LogIn,
  Plus,
  Settings,
  Apple,
} from 'lucide-vue-next'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const { t } = useI18n()
const { showSuccess, showError, showWarning, showInfo, confirm, confirmDelete, toastSuccess } = useSwal()
const { logoutAndRedirect } = useLogout()

// Managed members (accounts I manage)
const managedMembers = ref<MemberDto[]>([])
const managedMembersLoading = ref(false)
const impersonating = ref<number | null>(null)

// Auxiliary account creation
const showAuxiliaryModal = ref(false)
const auxiliaryName = ref('')
const creatingAuxiliary = ref(false)

async function fetchManagedMembers() {
  managedMembersLoading.value = true
  try {
    const response = await memberApi.getManagedMembers()
    managedMembers.value = response.data
  } catch (error) {
    console.error('Failed to fetch managed members:', error)
  } finally {
    managedMembersLoading.value = false
  }
}

function openAuxiliaryModal() {
  auxiliaryName.value = ''
  showAuxiliaryModal.value = true
}

async function createAuxiliaryAccount() {
  const name = auxiliaryName.value.trim()
  if (!name) {
    showError(t('member.auxiliary.validation.required'))
    return
  }
  if (name.length > 10) {
    showError(t('member.auxiliary.validation.max'))
    return
  }

  creatingAuxiliary.value = true
  try {
    await memberApi.createAuxiliaryAccount(name)
    await fetchManagedMembers()
    showAuxiliaryModal.value = false
    toastSuccess(t('member.auxiliary.success'))
  } catch (error: any) {
    console.error('Failed to create auxiliary account:', error)
    const errorMessage = resolveApiErrorMessage(error, { fallbackKey: 'member.auxiliary.createFailed' }, t)
    showError(errorMessage)
  } finally {
    creatingAuxiliary.value = false
  }
}

async function handleImpersonate(member: MemberDto) {
  if (!member.id) return

  const confirmed = await confirm(
    t('member.manager.impersonateMessage', { name: member.name }),
    t('member.manager.impersonateTitle')
  )

  if (!confirmed) return

  impersonating.value = member.id
  try {
    await authStore.impersonate(member.id)
    router.push('/')
  } catch (error: any) {
    console.error('Failed to impersonate:', error)
    const errorMessage = resolveApiErrorMessage(error, { fallbackKey: 'member.manager.impersonateFailed' }, t)
    showError(errorMessage)
  } finally {
    impersonating.value = null
  }
}
const { kakaoLink } = useKakao()
const { isNaverEnabled, naverLink } = useNaver()
const {
  isAppleConfigured,
  isAppleReady,
  preloadAppleSdk,
  appleLink,
} = useApple()
const isApplePreparing = ref(false)
const applePreparationFailed = ref(false)

async function prepareAppleLink() {
  if (!isAppleConfigured || isApplePreparing.value) return
  isApplePreparing.value = true
  applePreparationFailed.value = false
  try {
    await preloadAppleSdk()
  } catch {
    applePreparationFailed.value = true
  } finally {
    isApplePreparing.value = false
  }
}

// Loading states
const loading = ref(false)
const tokensLoading = ref(false)
const savingManager = ref(false)
type SsoProvider = SocialAccountProvider
type RedirectConnectableSsoProvider = Exclude<SsoProvider, 'APPLE'>

const connectingSso = ref<SsoProvider | null>(null)
const unlinkingSso = ref<SsoProvider | null>(null)
const isSsoActionPending = computed(() => !!connectingSso.value || !!unlinkingSso.value)

// Manager delegation
const familyMembers = ref<MemberPreviewDto[]>([])
const managers = ref<MemberDto[]>([])
const selectedManagerToAdd = ref<string>('')

const availableFamilyMembers = computed(() => {
  return familyMembers.value.filter(
    (member) => !managers.value.some((m) => m.id === member.id)
  )
})

async function fetchFamilyAndManagers() {
  try {
    const [familyResponse, managersResponse] = await Promise.all([
      memberApi.getFamilyMembers(),
      memberApi.getManagers(),
    ])
    familyMembers.value = familyResponse.data
    managers.value = managersResponse.data
  } catch (error) {
    console.error('Failed to fetch family/managers:', error)
  }
}

async function assignManager() {
  if (!selectedManagerToAdd.value) return

  const memberId = parseInt(selectedManagerToAdd.value)
  savingManager.value = true
  try {
    await memberApi.assignManager(memberId)
    await fetchFamilyAndManagers()
    selectedManagerToAdd.value = ''
    toastSuccess(t('member.manager.assignSuccess'))
  } catch (error) {
    console.error('Failed to assign manager:', error)
    showError(t('member.manager.assignFailed'))
  } finally {
    savingManager.value = false
  }
}

async function unAssignManager(manager: MemberDto) {
  if (!await confirm(t('member.manager.unassignConfirm', { name: manager.name }))) return

  try {
    await memberApi.unassignManager(manager.id!)
    await fetchFamilyAndManagers()
    toastSuccess(t('member.manager.unassignSuccess'))
  } catch (error) {
    console.error('Failed to unassign manager:', error)
    showError(t('member.manager.unassignFailed'))
  }
}

// Session management
const tokens = ref<RefreshTokenDto[]>([])

async function fetchTokens() {
  tokensLoading.value = true
  try {
    const response = await refreshTokenApi.getRefreshTokens()
    tokens.value = response.data
  } catch (error) {
    console.error('Failed to fetch tokens:', error)
  } finally {
    tokensLoading.value = false
  }
}

async function deleteToken(token: RefreshTokenDto) {
  const confirmed = await confirm(
    t('member.sessions.signOutCurrentConfirm', {
      device: token.userAgent?.device ?? '-',
      browser: sessionClientName(token, t),
      ip: token.remoteAddr ?? '-',
    }),
    t('member.sessions.signOutCurrentTitle')
  )
  if (!confirmed) return

  try {
    await refreshTokenApi.deleteRefreshToken(token.id)
    await fetchTokens()
    toastSuccess(t('member.sessions.signOutCurrentSuccess'))
  } catch (error) {
    console.error('Failed to delete token:', error)
    showError(t('member.sessions.signOutFailed'))
  }
}

const deletingOtherTokens = ref(false)

async function deleteOtherTokens() {
  const otherTokensCount = tokens.value.filter(t => !t.isCurrentLogin).length
  if (otherTokensCount === 0) {
    showInfo(t('member.sessions.noOtherSessions'))
    return
  }

  const confirmed = await confirm(
    t('member.sessions.signOutOthersConfirm', { count: otherTokensCount }),
    t('member.sessions.signOutOthersTitle')
  )
  if (!confirmed) return

  deletingOtherTokens.value = true
  try {
    const response = await refreshTokenApi.deleteOtherRefreshTokens()
    await fetchTokens()
    toastSuccess(t('member.sessions.signOutOthersSuccess', { count: response.data.deletedCount }))
  } catch (error) {
    console.error('Failed to delete other tokens:', error)
    showError(t('member.sessions.signOutFailed'))
  } finally {
    deletingOtherTokens.value = false
  }
}

// SSO connections
interface SsoConnection {
  provider: SsoProvider
  label: string
  icon?: string
  connected: boolean
  accountName?: string
}

const ssoConnections = ref<SsoConnection[]>([])
const selectedSsoConnection = ref<SsoConnection | null>(null)
let ssoSettingsTrigger: HTMLElement | null = null

function buildSsoConnections(member: MemberDto | null): SsoConnection[] {
  const connections: SsoConnection[] = [
    {
      provider: 'KAKAO',
      label: t('member.sso.providers.kakao'),
      icon: '/img/kakao.png',
      connected: !!member?.kakaoId,
    },
    {
      provider: 'NAVER',
      label: t('member.sso.providers.naver'),
      icon: '/img/naver.svg',
      connected: !!member?.naverId,
    },
    {
      provider: 'APPLE',
      label: t('member.sso.providers.apple'),
      connected: !!member?.appleId,
    },
  ]

  const visibleProviders = getVisibleSocialAccountProviders(member, isNaverEnabled, true)
  return connections.filter((connection) => visibleProviders.includes(connection.provider))
}

function canUnlinkSso(provider: SsoProvider): boolean {
  return canUnlinkSocialAccount(memberInfo.value, provider)
}

function isWebConnectableSsoProvider(provider: SsoProvider): boolean {
  return provider === 'KAKAO' || provider === 'NAVER' || provider === 'APPLE'
}

function toSocialLinkProvider(provider: RedirectConnectableSsoProvider): SocialLinkProvider {
  return provider === 'KAKAO' ? 'kakao' : 'naver'
}

function appleLinkStatusMessage(): string {
  if (isApplePreparing.value) return t('member.sso.apple.retrying')
  if (applePreparationFailed.value) return t('member.sso.apple.providerUnavailable')
  return ''
}

function getAppleLinkErrorMessage(error: unknown): string {
  if (error instanceof AppleSignInError) {
    switch (error.code) {
      case 'CONFIGURATION_UNAVAILABLE':
        return t('member.sso.apple.providerUnavailable')
      case 'SDK_UNAVAILABLE':
        return t('member.sso.apple.providerUnavailable')
      case 'INVALID_CREDENTIAL':
      case 'STATE_MISMATCH':
        return t('member.sso.apple.invalidCredential')
      case 'CANCELLED':
        return ''
    }
  }
  return resolveApiErrorMessage(error, { fallbackKey: 'member.sso.apple.linkFailed' }, t)
}

function openSsoSettings(connection: SsoConnection, event: Event) {
  if (isSsoActionPending.value || !connection.connected) return
  ssoSettingsTrigger = event.currentTarget instanceof HTMLElement ? event.currentTarget : null
  selectedSsoConnection.value = connection
}

async function closeSsoSettings() {
  if (isSsoActionPending.value) return
  selectedSsoConnection.value = null
  await nextTick()
  ssoSettingsTrigger?.focus()
  ssoSettingsTrigger = null
}

async function connectSso(provider: SsoProvider) {
  if (isSsoActionPending.value || !isWebConnectableSsoProvider(provider)) return
  if (provider === 'APPLE' && (!isAppleConfigured || !isAppleReady.value)) return

  const prompts: Record<SsoProvider, { message: string; title: string; connect: () => Promise<unknown> }> = {
    KAKAO: {
      message: t('member.sso.prompts.kakaoMessage'),
      title: t('member.sso.prompts.kakaoTitle'),
      connect: () => kakaoLink(),
    },
    NAVER: {
      message: t('member.sso.prompts.naverMessage'),
      title: t('member.sso.prompts.naverTitle'),
      connect: () => naverLink(),
    },
    APPLE: {
      message: t('member.sso.prompts.appleMessage'),
      title: t('member.sso.prompts.appleTitle'),
      connect: () => appleLink(),
    },
  }

  const prompt = prompts[provider]
  const confirmed = await confirm(prompt.message, prompt.title)
  if (!confirmed || isSsoActionPending.value) return

  connectingSso.value = provider
  try {
    if (provider === 'APPLE') {
      await prompt.connect()
      const successMessage = t('member.sso.linkSuccess', {
        provider: t('member.sso.providers.apple'),
      })
      toastSuccess(successMessage)

      const refreshResult = await refreshAppleLinkMemberState(async () => (
        await memberApi.getMyInfo()
      ).data)
      if (refreshResult.member) {
        memberInfo.value = refreshResult.member
        ssoConnections.value = buildSsoConnections(memberInfo.value)
      } else {
        console.error('Apple account linked, but failed to refresh member info:', refreshResult.error)
        ssoConnections.value = ssoConnections.value.map((connection) => (
          connection.provider === 'APPLE'
            ? { ...connection, connected: true }
            : connection
        ))
        await showWarning(
          t('member.sso.apple.refreshFailed'),
          t('member.sso.apple.refreshFailedTitle'),
        )
      }
      return
    }

    storePendingSocialLinkProvider(toSocialLinkProvider(provider))
    await prompt.connect()
  } catch (error) {
    if (provider === 'APPLE' && isAppleSignInCancellation(error)) return
    console.error('Failed to connect sso:', error)
    if (provider === 'APPLE') {
      if (error instanceof AppleSignInError && error.code === 'SDK_UNAVAILABLE') {
        applePreparationFailed.value = true
      }
      showError(getAppleLinkErrorMessage(error))
    } else {
      clearPendingSocialLinkProvider()
      showError(t('member.sso.startFailed'))
    }
  } finally {
    connectingSso.value = null
  }
}

async function unlinkSso(connection: SsoConnection) {
  if (isSsoActionPending.value || !canUnlinkSso(connection.provider)) return

  const confirmed = await confirmDelete(
    t(
      connection.provider === 'APPLE'
        ? 'member.sso.unlink.appleConfirmMessage'
        : 'member.sso.unlink.confirmMessage',
      { provider: connection.label },
    ),
    t('member.sso.unlink.confirmTitle', { provider: connection.label }),
    t('member.sso.unlink.action'),
  )
  if (!confirmed || isSsoActionPending.value) return

  let shouldCloseSettings = false
  unlinkingSso.value = connection.provider
  try {
    await memberApi.unlinkSocialAccount(connection.provider)
    await fetchMemberInfo()
    ssoConnections.value = buildSsoConnections(memberInfo.value)
    toastSuccess(t(
      connection.provider === 'APPLE'
        ? 'member.sso.unlink.appleSuccess'
        : 'member.sso.unlink.success',
      { provider: connection.label },
    ))
    shouldCloseSettings = true
  } catch (error) {
    console.error('Failed to unlink social account:', error)
    showError(t(getSocialAccountUnlinkErrorKey(error)))
  } finally {
    unlinkingSso.value = null
    if (shouldCloseSettings) await closeSsoSettings()
  }
}

async function handleSocialLinkQuery() {
  const result = await consumeSocialLinkCallback(
    route.query,
    (query) => router.replace({ query }),
  )
  if (result) {
    clearPendingSocialLinkProvider()
  }

  const fallbackProvider = !result && memberInfo.value
    ? consumeConnectedPendingSocialLinkProvider(memberInfo.value)
    : null
  const provider = result?.provider ?? fallbackProvider

  if (!provider) return

  const providerLabel = provider === 'kakao'
    ? t('member.sso.providers.kakao')
    : t('member.sso.providers.naver')

  if (!result || result.type === 'success') {
    toastSuccess(t('member.sso.linkSuccess', { provider: providerLabel }))
    return
  }

  await showError(
    t('member.sso.alreadyLinkedMessage', { provider: providerLabel }),
    t('member.sso.alreadyLinkedTitle')
  )
}

// Password change
const showPasswordModal = ref(false)
const passwordForm = ref({
  currentPassword: '',
  newPassword: '',
  confirmPassword: '',
})
const memberModalPanelStyle = { backgroundColor: 'var(--dp-bg-card)' }
const passwordErrors = ref({
  currentPassword: '',
  newPassword: '',
  confirmPassword: '',
})
const changingPassword = ref(false)
const passwordSubmitHint = computed(() => {
  if (!passwordForm.value.currentPassword) return t('member.password.validation.currentRequired')
  if (!passwordForm.value.newPassword) return t('member.password.validation.newRequired')
  if (passwordForm.value.newPassword.length < 8 || passwordForm.value.newPassword.length > 20) {
    return t('member.password.validation.length')
  }
  if (passwordForm.value.currentPassword === passwordForm.value.newPassword) {
    return t('member.password.validation.sameAsCurrent')
  }
  if (!passwordForm.value.confirmPassword) return t('member.password.validation.confirmRequired')
  if (passwordForm.value.newPassword !== passwordForm.value.confirmPassword) {
    return t('member.password.validation.mismatch')
  }
  return ''
})
const isPasswordSubmitDisabled = computed(() => changingPassword.value || !!passwordSubmitHint.value)

function openPasswordModal() {
  passwordForm.value = { currentPassword: '', newPassword: '', confirmPassword: '' }
  passwordErrors.value = { currentPassword: '', newPassword: '', confirmPassword: '' }
  showPasswordModal.value = true
}

function validatePasswordForm(): boolean {
  passwordErrors.value = { currentPassword: '', newPassword: '', confirmPassword: '' }
  let isValid = true

  if (!passwordForm.value.currentPassword) {
    passwordErrors.value.currentPassword = t('member.password.validation.currentRequired')
    isValid = false
  }

  if (!passwordForm.value.newPassword) {
    passwordErrors.value.newPassword = t('member.password.validation.newRequired')
    isValid = false
  } else if (passwordForm.value.newPassword.length < 8 || passwordForm.value.newPassword.length > 20) {
    passwordErrors.value.newPassword = t('member.password.validation.length')
    isValid = false
  } else if (passwordForm.value.currentPassword === passwordForm.value.newPassword) {
    passwordErrors.value.newPassword = t('member.password.validation.sameAsCurrent')
    isValid = false
  }

  if (!passwordForm.value.confirmPassword) {
    passwordErrors.value.confirmPassword = t('member.password.validation.confirmRequired')
    isValid = false
  } else if (passwordForm.value.newPassword !== passwordForm.value.confirmPassword) {
    passwordErrors.value.confirmPassword = t('member.password.validation.mismatch')
    isValid = false
  }

  return isValid
}

async function changePassword() {
  if (!validatePasswordForm()) return
  if (!authStore.user) return

  changingPassword.value = true
  try {
    await authApi.changePassword({
      memberId: authStore.user.id,
      currentPassword: passwordForm.value.currentPassword,
      newPassword: passwordForm.value.newPassword,
    })
    await showSuccess(t('member.password.changedReLogin'))
    showPasswordModal.value = false
    await logoutAndRedirect()
  } catch (error: any) {
    const message = resolveApiErrorMessage(error, { fallbackKey: 'member.password.changeFailed' }, t)
    showError(message)
  } finally {
    changingPassword.value = false
  }
}

// Account deletion
const showAccountDeletionModal = ref(false)
const accountDeletionCompletion = ref<AccountDeletionCompletion | null>(null)

function deleteAccount() {
  if (authStore.isImpersonating) {
    showError(t('member.accountDeletion.errors.impersonation'))
    return
  }
  showAccountDeletionModal.value = true
}

function completeAccountDeletion(completion: AccountDeletionCompletion) {
  showAccountDeletionModal.value = false
  accountDeletionCompletion.value = completion
  authStore.completeAccountDeletion()
}

async function finishAccountDeletionCompletion() {
  await router.push('/')
}

// Member info (fetched from API)
const memberInfo = ref<MemberDto | null>(null)

async function fetchMemberInfo() {
  try {
    const response = await memberApi.getMyInfo()
    memberInfo.value = response.data
  } catch (error) {
    console.error('Failed to fetch member info:', error)
    showError(t('member.errors.loadFailed'))
  }
}

// Initialize data
onMounted(async () => {
  loading.value = true
  void prepareAppleLink()
  try {
    // Fetch all data in parallel
    await Promise.all([
      fetchMemberInfo(),
      fetchFamilyAndManagers(),
      fetchManagedMembers(),
      fetchTokens(),
    ])

    // Set SSO connections based on user data
    ssoConnections.value = buildSsoConnections(memberInfo.value)
  } catch (error) {
    console.error('Failed to initialize:', error)
  } finally {
    loading.value = false
  }

  try {
    await handleSocialLinkQuery()
  } catch (error) {
    console.error('Failed to handle social account linking callback:', error)
  }
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <section
      v-if="accountDeletionCompletion"
      class="mx-auto mt-8 max-w-lg rounded-2xl border border-dp-border-primary bg-dp-bg-card p-5 text-center shadow-sm sm:p-8"
      aria-live="polite"
    >
      <div class="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-dp-success-soft text-dp-success">
        <Check class="h-7 w-7" aria-hidden="true" />
      </div>
      <h1 class="mt-4 text-xl font-bold text-dp-text-primary">
        {{ accountDeletionCompletion === 'alreadyPending'
          ? t('member.accountDeletion.completion.alreadyPendingTitle')
          : t('member.accountDeletion.completion.acceptedTitle') }}
      </h1>
      <p class="mt-3 text-sm leading-6 text-dp-text-secondary">
        {{ t('member.accountDeletion.completion.signedOut') }}
      </p>
      <p class="mt-2 text-sm leading-6 text-dp-text-secondary">
        {{ t('member.accountDeletion.completion.asyncCleanup') }}
      </p>
      <button
        type="button"
        class="mt-6 min-h-11 w-full rounded-lg bg-dp-accent px-4 font-medium text-dp-text-on-dark transition hover:bg-dp-accent-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
        @click="finishAccountDeletionCompletion"
      >
        {{ t('member.accountDeletion.completion.confirm') }}
      </button>
    </section>

    <template v-else>
    <PageHeader :title="t('member.pageTitle')" :icon="User" show-back back-fallback="/more" />

    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center py-20">
      <Loader2 class="w-8 h-8 animate-spin text-dp-accent" />
    </div>

    <template v-else>
      <!-- Profile Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4 bg-dp-bg-card border border-dp-border-primary">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2 text-dp-text-primary">
          <User class="w-5 h-5 text-dp-text-secondary" />
          {{ t('member.profile.sectionTitle') }}
        </h2>

        <div class="flex items-center gap-4 sm:gap-6">
          <!-- Profile Photo (Left) -->
          <div class="flex-shrink-0">
            <div class="sm:hidden">
              <ProfilePhotoUploader
                v-if="memberInfo?.id"
                :member-id="memberInfo.id"
                :profile-photo-version="memberInfo.profilePhotoVersion"
                size="sm"
                @upload-complete="fetchMemberInfo"
              />
            </div>
            <div class="hidden sm:block">
              <ProfilePhotoUploader
                v-if="memberInfo?.id"
                :member-id="memberInfo.id"
                :profile-photo-version="memberInfo.profilePhotoVersion"
                size="lg"
                @upload-complete="fetchMemberInfo"
              />
            </div>
          </div>

          <!-- Member Info (Right) -->
          <div class="flex flex-col justify-center space-y-2 sm:space-y-3 min-w-0">
            <div class="flex items-center gap-2 sm:gap-3">
              <User class="w-4 h-4 flex-shrink-0 text-dp-text-secondary" />
              <span class="text-sm w-12 sm:w-14 flex-shrink-0 text-dp-text-secondary">{{ t('member.profile.name') }}</span>
              <span class="font-medium truncate text-dp-text-primary">{{ memberInfo?.name }}</span>
            </div>
            <div class="flex items-center gap-2 sm:gap-3">
              <Building2 class="w-4 h-4 flex-shrink-0 text-dp-text-secondary" />
              <span class="text-sm w-12 sm:w-14 flex-shrink-0 text-dp-text-secondary">{{ t('member.profile.team') }}</span>
              <span class="font-medium truncate text-dp-text-primary">{{ memberInfo?.team || '-' }}</span>
            </div>
            <div v-if="memberInfo?.email" class="flex items-center gap-2 sm:gap-3">
              <Mail class="w-4 h-4 flex-shrink-0 text-dp-text-secondary" />
              <span class="text-sm w-12 sm:w-14 flex-shrink-0 text-dp-text-secondary">{{ t('member.profile.email') }}</span>
              <span class="font-medium truncate text-sm sm:text-base text-dp-text-primary">{{ memberInfo?.email }}</span>
            </div>
          </div>
        </div>
      </section>

      <DutyPatternCard />

      <!-- Manager Delegation Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4 bg-dp-bg-card border border-dp-border-primary">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2 text-dp-text-primary">
          <Shield class="w-5 h-5 text-dp-text-secondary" />
          {{ t('member.manager.sectionTitle') }}
        </h2>
        <div class="space-y-4">
          <div class="flex items-center gap-2 text-sm text-dp-text-secondary">
            <Info class="w-4 h-4" />
            <span>{{ t('member.manager.info') }}</span>
          </div>

          <!-- Add Manager -->
          <div class="flex items-center gap-3">
            <select
              v-model="selectedManagerToAdd"
              @change="assignManager"
              :disabled="savingManager || availableFamilyMembers.length === 0"
              class="flex-1 px-3 py-3 sm:py-2 min-h-11 rounded-lg focus:outline-none focus:ring-2 focus:ring-dp-accent focus:border-transparent disabled:opacity-50"
              :style="{ borderWidth: '1px', borderColor: 'var(--dp-border-primary)', backgroundColor: 'var(--dp-bg-secondary)', color: 'var(--dp-text-primary)' }"
            >
              <option value="">{{ t('member.manager.addPlaceholder') }}</option>
              <option v-for="member in availableFamilyMembers" :key="member.id ?? 'none'" :value="member.id">
                {{ member.name }}
              </option>
            </select>
            <Loader2 v-if="savingManager" class="w-5 h-5 animate-spin text-dp-accent" />
          </div>

          <!-- Current Managers -->
          <div v-if="managers.length > 0" class="flex flex-wrap gap-2">
            <div
              v-for="manager in managers"
              :key="manager.id ?? 'none'"
              class="inline-flex items-center gap-2 px-3 py-2 rounded-lg bg-dp-bg-hover"
            >
              <span class="text-dp-text-primary">{{ manager.name }}</span>
              <button
                @click="unAssignManager(manager)"
                class="p-1 rounded-full hover-danger cursor-pointer text-dp-text-muted"
              >
                <Trash2 class="w-4 h-4" />
              </button>
            </div>
          </div>
          <p v-else class="text-sm text-dp-text-muted">{{ t('member.manager.empty') }}</p>

          <!-- Managed Members (accounts I manage) -->
          <div class="mt-6 pt-4 border-t border-dp-border-primary">
            <div class="flex items-center gap-2 mb-3">
              <Users class="w-4 h-4 text-dp-text-secondary" />
              <h3 class="text-sm font-medium text-dp-text-primary">{{ t('member.manager.managedAccountsTitle') }}</h3>
            </div>
            <div class="space-y-2">
              <div
                v-for="member in managedMembers"
                :key="member.id ?? 'unknown'"
                class="flex items-center justify-between p-3 rounded-lg bg-dp-bg-secondary"
              >
                <div class="flex items-center gap-3">
                  <ProfileAvatar :member-id="member.id" :has-profile-photo="member.hasProfilePhoto" :profile-photo-version="member.profilePhotoVersion" size="md" :name="member.name" />
                  <div>
                    <p class="font-medium text-dp-text-primary">{{ member.name }}</p>
                    <p v-if="member.team" class="text-xs text-dp-text-muted">{{ member.team }}</p>
                  </div>
                </div>
                <button
                  @click="handleImpersonate(member)"
                  :disabled="impersonating === member.id"
                  class="flex items-center gap-1.5 px-3 py-2 min-h-10 text-sm font-medium text-dp-accent bg-dp-accent-soft hover:bg-dp-accent-soft-hover rounded-lg transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
                >
                  <Loader2 v-if="impersonating === member.id" class="w-4 h-4 animate-spin" />
                  <LogIn v-else class="w-4 h-4" />
                  <span class="hidden sm:inline">{{ t('member.manager.login') }}</span>
                </button>
              </div>
              <!-- Add auxiliary account card -->
              <button
                @click="openAuxiliaryModal"
                class="w-full flex items-center justify-center gap-2 p-3 rounded-lg border-2 border-dashed transition cursor-pointer hover:border-solid border-dp-border-primary hover:border-dp-border-hover hover:bg-dp-bg-hover hover:text-dp-text-secondary text-dp-text-muted"
              >
                <Plus class="w-5 h-5" />
                <span class="text-sm font-medium">{{ t('member.manager.addAuxiliary') }}</span>
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- Session Management Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4 bg-dp-bg-card border border-dp-border-primary">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold flex items-center gap-2 text-dp-text-primary">
            <Smartphone class="w-5 h-5 text-dp-text-secondary" />
            {{ t('member.sessions.sectionTitle') }}
          </h2>
          <button
            v-if="tokens.filter(t => !t.isCurrentLogin).length > 0"
            @click="deleteOtherTokens"
            :disabled="deletingOtherTokens"
            class="px-3 py-2 min-h-10 text-xs font-medium text-dp-danger bg-dp-danger-soft hover:bg-dp-danger-soft-hover rounded-lg transition flex items-center gap-1.5 disabled:opacity-50 cursor-pointer"
          >
            <Loader2 v-if="deletingOtherTokens" class="w-4 h-4 animate-spin" />
            <LogOut v-else class="w-4 h-4" />
            {{ t('member.sessions.signOutOthersButton') }}
          </button>
        </div>
        <SessionTokenList
          :tokens="tokens"
          :loading="tokensLoading"
          :show-delete-button="true"
          @delete="deleteToken"
        />
      </section>

      <!-- SSO Connections Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4 bg-dp-bg-card border border-dp-border-primary">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2 text-dp-text-primary">
          <Link class="w-5 h-5 text-dp-text-secondary" />
          {{ t('member.sso.sectionTitle') }}
        </h2>
        <div class="space-y-3">
          <div
            v-for="sso in ssoConnections"
            :key="sso.provider"
            class="flex min-h-16 items-center justify-between gap-3 rounded-lg bg-dp-bg-secondary p-3"
          >
            <div class="flex min-w-0 items-center gap-3">
              <span
                v-if="sso.provider === 'APPLE'"
                class="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-dp-bg-card text-dp-text-primary"
                aria-hidden="true"
              >
                <Apple class="h-5 w-5" />
              </span>
              <img v-else :src="sso.icon" :alt="sso.label" class="w-8 h-8 rounded" />
              <div class="min-w-0">
                <p class="truncate font-medium text-dp-text-primary">{{ sso.label }}</p>
                <p v-if="sso.connected && sso.accountName" class="text-sm text-dp-text-secondary">
                  {{ sso.accountName }}
                </p>
                <p
                  v-else-if="sso.provider === 'APPLE' && appleLinkStatusMessage()"
                  class="mt-0.5 max-w-md text-xs text-dp-text-muted"
                  aria-live="polite"
                >
                  {{ appleLinkStatusMessage() }}
                </p>
              </div>
            </div>
            <div class="flex shrink-0 items-center gap-2">
              <span v-if="sso.connected" class="flex min-h-6 items-center gap-1 whitespace-nowrap rounded-full bg-dp-success-soft px-2 py-0.5 text-xs font-medium text-dp-success">
                <Check class="w-4 h-4" />
                {{ t('member.sso.connected') }}
              </span>
              <button
                v-if="sso.connected"
                type="button"
                class="flex min-h-11 min-w-11 items-center justify-center rounded-lg text-dp-text-muted transition hover:bg-dp-bg-hover hover:text-dp-text-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring disabled:cursor-not-allowed disabled:opacity-50"
                :disabled="isSsoActionPending"
                :aria-label="t('member.sso.unlink.manageAction', { provider: sso.label })"
                :aria-describedby="`social-account-settings-hint-${sso.provider.toLowerCase()}`"
                aria-haspopup="dialog"
                :aria-expanded="selectedSsoConnection?.provider === sso.provider"
                @click="openSsoSettings(sso, $event)"
              >
                <Settings class="h-5 w-5" aria-hidden="true" />
              </button>
              <span
                v-if="sso.connected"
                :id="`social-account-settings-hint-${sso.provider.toLowerCase()}`"
                class="sr-only"
              >
                {{ t('member.sso.unlink.manageHint') }}
              </span>
              <button
                v-else-if="isWebConnectableSsoProvider(sso.provider) && !(sso.provider === 'APPLE' && applePreparationFailed)"
                type="button"
                @click="connectSso(sso.provider)"
                :disabled="isSsoActionPending || (sso.provider === 'APPLE' && (!isAppleConfigured || !isAppleReady))"
                class="min-h-11 w-full rounded-lg bg-dp-accent-soft px-4 py-2.5 text-sm font-medium text-dp-accent transition hover:bg-dp-accent-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent disabled:cursor-not-allowed disabled:opacity-50 sm:w-auto"
              >
                {{ connectingSso === sso.provider ? t('member.sso.connecting') : t('member.sso.connect') }}
              </button>
              <button
                v-else-if="sso.provider === 'APPLE' && applePreparationFailed"
                type="button"
                @click="prepareAppleLink"
                :disabled="isSsoActionPending || isApplePreparing"
                class="min-h-11 w-full rounded-lg bg-dp-accent-soft px-4 py-2.5 text-sm font-medium text-dp-accent transition hover:bg-dp-accent-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent disabled:cursor-not-allowed disabled:opacity-50 sm:w-auto"
              >
                {{ isApplePreparing ? t('member.sso.apple.retrying') : t('member.sso.apple.retry') }}
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- Account Management Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4 bg-dp-bg-card border border-dp-border-primary">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2 text-dp-text-primary">
          <Lock class="w-5 h-5 text-dp-text-secondary" />
          {{ t('member.account.sectionTitle') }}
        </h2>
        <div class="flex flex-wrap gap-3">
          <button
            v-if="memberInfo?.hasPassword"
            @click="openPasswordModal"
            class="px-4 py-3 sm:py-2 min-h-11 text-sm font-medium text-dp-accent bg-dp-accent-soft hover:bg-dp-accent-soft-hover rounded-lg transition flex items-center gap-2 cursor-pointer"
          >
            <Lock class="w-4 h-4" />
            {{ t('member.account.changePassword') }}
          </button>
          <button
            @click="deleteAccount"
            class="px-4 py-3 sm:py-2 min-h-11 text-sm font-medium text-dp-danger bg-dp-danger-soft hover:bg-dp-danger-soft-hover rounded-lg transition flex items-center gap-2 cursor-pointer"
          >
            <UserX class="w-4 h-4" />
            {{ t('member.account.deleteAccount') }}
          </button>
        </div>
      </section>

    </template>

    <AccountDeletionModal
      v-if="memberInfo"
      :is-open="showAccountDeletionModal"
      :member-name="memberInfo.name"
      @close="showAccountDeletionModal = false"
      @completed="completeAccountDeletion"
    />

    <SocialAccountConnectionModal
      v-if="selectedSsoConnection"
      :is-open="true"
      :provider="selectedSsoConnection.provider"
      :provider-label="selectedSsoConnection.label"
      :provider-icon="selectedSsoConnection.icon"
      :can-unlink="canUnlinkSso(selectedSsoConnection.provider)"
      :busy="unlinkingSso === selectedSsoConnection.provider"
      @close="closeSsoSettings"
      @unlink="unlinkSso(selectedSsoConnection)"
    />

    <!-- Password Change Modal -->
    <BaseModal
      :is-open="showPasswordModal"
      size="md"
      height="fit"
      rounded
      :panel-style="memberModalPanelStyle"
      @close="showPasswordModal = false"
    >
      <div class="modal-header">
        <h2>{{ t('member.password.modalTitle') }}</h2>
        <button @click="showPasswordModal = false" class="p-1.5 rounded-full hover-close-btn cursor-pointer text-dp-text-muted">
          <X class="w-5 h-5" />
        </button>
      </div>
      <div class="modal-body-form-lg">
        <div>
          <label class="form-label text-dp-text-primary">{{ t('member.password.currentLabel') }}</label>
          <input
            v-model="passwordForm.currentPassword"
            type="password"
            maxlength="20"
            class="form-control-card"
            :style="{
              borderColor: passwordErrors.currentPassword ? 'var(--dp-danger)' : 'var(--dp-border-primary)'
            }"
            :placeholder="t('member.password.currentPlaceholder')"
          />
          <p v-if="passwordErrors.currentPassword" class="text-sm text-dp-danger mt-1">
            {{ passwordErrors.currentPassword }}
          </p>
        </div>
        <div>
          <label class="form-label text-dp-text-primary">{{ t('member.password.newLabel') }}</label>
          <input
            v-model="passwordForm.newPassword"
            type="password"
            maxlength="20"
            class="form-control-card"
            :style="{
              borderColor: passwordErrors.newPassword ? 'var(--dp-danger)' : 'var(--dp-border-primary)'
            }"
            :placeholder="t('member.password.newPlaceholder')"
          />
          <p v-if="passwordErrors.newPassword" class="text-sm text-dp-danger mt-1">
            {{ passwordErrors.newPassword }}
          </p>
        </div>
        <div>
          <label class="form-label text-dp-text-primary">{{ t('member.password.confirmLabel') }}</label>
          <input
            v-model="passwordForm.confirmPassword"
            type="password"
            maxlength="20"
            class="form-control-card"
            :style="{
              borderColor: passwordErrors.confirmPassword ? 'var(--dp-danger)' : 'var(--dp-border-primary)'
            }"
            :placeholder="t('member.password.confirmPlaceholder')"
          />
          <p v-if="passwordErrors.confirmPassword" class="text-sm text-dp-danger mt-1">
            {{ passwordErrors.confirmPassword }}
          </p>
        </div>
      </div>
      <div class="modal-actions modal-footer-safe sm:px-6 sm:py-6">
        <button
          @click="changePassword"
          :disabled="isPasswordSubmitDisabled"
          class="flex-1 px-4 py-3 sm:py-2 min-h-11 bg-dp-accent hover:bg-dp-accent-hover rounded-lg text-dp-text-on-dark font-medium transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
        >
          <Loader2 v-if="changingPassword" class="w-4 h-4 animate-spin" />
          {{ changingPassword ? t('member.password.submitting') : t('member.password.submit') }}
        </button>
        <button
          @click="showPasswordModal = false"
          :disabled="changingPassword"
          class="flex-1 px-4 py-3 sm:py-2 min-h-11 rounded-lg font-medium hover-interactive cursor-pointer disabled:opacity-50"
          :style="{ backgroundColor: 'var(--dp-bg-hover)', color: 'var(--dp-text-primary)' }"
        >
          {{ t('common.actions.cancel') }}
        </button>
      </div>
    </BaseModal>

    <!-- Auxiliary Account Modal -->
    <BaseModal
      :is-open="showAuxiliaryModal"
      size="md"
      height="fit"
      rounded
      :panel-style="memberModalPanelStyle"
      @close="showAuxiliaryModal = false"
    >
      <div class="modal-header">
        <h2>{{ t('member.auxiliary.modalTitle') }}</h2>
        <button @click="showAuxiliaryModal = false" class="p-1.5 rounded-full hover-close-btn cursor-pointer text-dp-text-muted">
          <X class="w-5 h-5" />
        </button>
      </div>
      <div class="modal-body-form-lg">
        <p class="text-sm text-dp-text-secondary whitespace-pre-line">
          {{ t('member.auxiliary.description') }}
        </p>
        <div>
          <label class="form-label text-dp-text-primary">{{ t('member.auxiliary.nameLabel') }}</label>
          <input
            v-model="auxiliaryName"
            type="text"
            maxlength="10"
            class="form-control-card"
            :placeholder="t('member.auxiliary.namePlaceholder')"
            @keyup.enter="createAuxiliaryAccount"
          />
          <p class="text-xs mt-1 text-dp-text-muted">{{ t('member.auxiliary.maxLength') }}</p>
        </div>
      </div>
      <div class="modal-actions modal-footer-safe sm:px-6 sm:py-6">
        <button
          @click="createAuxiliaryAccount"
          :disabled="creatingAuxiliary || !auxiliaryName.trim()"
          class="flex-1 px-4 py-3 sm:py-2 min-h-11 bg-dp-accent hover:bg-dp-accent-hover rounded-lg text-dp-text-on-dark font-medium transition disabled:opacity-50 flex items-center justify-center gap-2 cursor-pointer"
        >
          <Loader2 v-if="creatingAuxiliary" class="w-4 h-4 animate-spin" />
          {{ creatingAuxiliary ? t('member.auxiliary.submitting') : t('member.auxiliary.submit') }}
        </button>
        <button
          @click="showAuxiliaryModal = false"
          :disabled="creatingAuxiliary"
          class="flex-1 px-4 py-3 sm:py-2 min-h-11 rounded-lg font-medium hover-interactive cursor-pointer disabled:opacity-50"
          :style="{ backgroundColor: 'var(--dp-bg-hover)', color: 'var(--dp-text-primary)' }"
        >
          {{ t('common.actions.cancel') }}
        </button>
      </div>
    </BaseModal>
    </template>
  </div>
</template>
