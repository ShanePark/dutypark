<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { useThemeStore, type ThemeMode } from '@/stores/theme'
import { memberApi, refreshTokenApi } from '@/api/member'
import { authApi } from '@/api/auth'
import { useSwal } from '@/composables/useSwal'
import { useKakao } from '@/composables/useKakao'
import { useNaver } from '@/composables/useNaver'
import { usePushNotification } from '@/composables/usePushNotification'
import type { MemberPreviewDto, MemberDto, RefreshTokenDto, CalendarVisibility } from '@/types'
import { VISIBILITY_COLORS } from '@/utils/visibility'
import BaseModal from '@/components/common/BaseModal.vue'
import SessionTokenList from '@/components/common/SessionTokenList.vue'
import ProfilePhotoUploader from '@/components/common/ProfilePhotoUploader.vue'
import ProfileAvatar from '@/components/common/ProfileAvatar.vue'
import { resolveApiErrorMessage } from '@/utils/resolveApiError'
import {
  User,
  Building2,
  Mail,
  Eye,
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
  ChevronRight,
  Loader2,
  Sun,
  Moon,
  Users,
  LogIn,
  Plus,
  Bell,
  BellOff,
} from 'lucide-vue-next'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const themeStore = useThemeStore()
const { t } = useI18n()
const { showSuccess, showError, showInfo, confirm, toastSuccess } = useSwal()

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

// Push notification settings
const pushNotification = usePushNotification()
const togglingPush = ref(false)

const isIOSPWA = computed(() => {
  const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !(window as any).MSStream
  const isStandalone = window.matchMedia('(display-mode: standalone)').matches ||
    (window.navigator as any).standalone === true
  return isIOS && isStandalone
})

const showPushSettings = computed(() => {
  return pushNotification.isSupported.value && pushNotification.isEnabled.value
})

const pushStatusText = computed(() => {
  if (!pushNotification.isSupported.value) return t('member.push.status.unsupported')
  if (!pushNotification.isEnabled.value) return t('member.push.status.serverDisabled')
  if (pushNotification.permission.value === 'denied') return t('member.push.status.denied')
  if (pushNotification.permission.value === 'granted' && pushNotification.isSubscribed.value) {
    return t('member.push.status.enabled')
  }
  return t('member.push.status.disabled')
})

async function togglePushNotification() {
  if (togglingPush.value) return
  togglingPush.value = true

  try {
    if (pushNotification.permission.value === 'granted' && pushNotification.isSubscribed.value) {
      await pushNotification.unsubscribe()
      toastSuccess(t('member.push.messages.disabled'))
    } else {
      const success = await pushNotification.subscribe()
      if (success) {
        toastSuccess(t('member.push.messages.enabled'))
      } else if (pushNotification.permission.value === 'denied') {
        showError(t('member.push.messages.deniedHelp'))
      }
    }
  } catch (error) {
    console.error('Failed to toggle push notification:', error)
    showError(t('member.push.messages.updateFailed'))
  } finally {
    togglingPush.value = false
  }
}

async function initPushNotification() {
  pushNotification.checkSupport()
  if (pushNotification.isSupported.value) {
    await pushNotification.checkEnabled()
  }
}

// Theme settings
const themeOptions = computed<{ value: ThemeMode; label: string; icon: typeof Sun }[]>(() => [
  { value: 'light', label: t('member.theme.options.light'), icon: Sun },
  { value: 'dark', label: t('member.theme.options.dark'), icon: Moon },
])

const currentThemeLabel = computed(() => {
  return themeStore.mode === 'dark'
    ? t('member.theme.options.dark')
    : t('member.theme.options.light')
})

function setTheme(mode: ThemeMode) {
  themeStore.setTheme(mode)
}

// Loading states
const loading = ref(false)
const tokensLoading = ref(false)
const savingVisibility = ref(false)
const savingManager = ref(false)
type SsoProvider = 'Kakao' | 'Naver'

const connectingSso = ref<SsoProvider | null>(null)

// Visibility settings
const calendarVisibility = ref<CalendarVisibility>('FRIENDS')
const showVisibilityModal = ref(false)

const visibilityLabel = computed(() => {
  const labels: Record<CalendarVisibility, string> = {
    PUBLIC: t('member.visibility.options.public.label'),
    FRIENDS: t('member.visibility.options.friends.label'),
    FAMILY: t('member.visibility.options.family.label'),
    PRIVATE: t('member.visibility.options.private.label'),
  }
  return labels[calendarVisibility.value]
})

const visibilityOptions = computed<
  { value: CalendarVisibility; label: string; color: string; description: string }[]
>(() => [
  {
    value: 'PUBLIC',
    label: t('member.visibility.options.public.label'),
    color: VISIBILITY_COLORS.PUBLIC,
    description: t('member.visibility.options.public.description'),
  },
  {
    value: 'FRIENDS',
    label: t('member.visibility.options.friends.label'),
    color: VISIBILITY_COLORS.FRIENDS,
    description: t('member.visibility.options.friends.description'),
  },
  {
    value: 'FAMILY',
    label: t('member.visibility.options.family.label'),
    color: VISIBILITY_COLORS.FAMILY,
    description: t('member.visibility.options.family.description'),
  },
  {
    value: 'PRIVATE',
    label: t('member.visibility.options.private.label'),
    color: VISIBILITY_COLORS.PRIVATE,
    description: t('member.visibility.options.private.description'),
  },
])

const visibilityColorClass = computed(() => VISIBILITY_COLORS[calendarVisibility.value] ?? 'bg-dp-accent')

async function setVisibility(value: CalendarVisibility) {
  if (!authStore.user) return

  savingVisibility.value = true
  try {
    await memberApi.updateVisibility(authStore.user.id, value)
    calendarVisibility.value = value
    showVisibilityModal.value = false
  } catch (error) {
    console.error('Failed to update visibility:', error)
    showError(t('member.visibility.updateFailed'))
  } finally {
    savingVisibility.value = false
  }
}

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

async function deleteToken(tokenId: number) {
  const confirmed = await confirm(
    t('member.sessions.signOutCurrentConfirm'),
    t('member.sessions.signOutCurrentTitle')
  )
  if (!confirmed) return

  try {
    await refreshTokenApi.deleteRefreshToken(tokenId)
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
  icon: string
  connected: boolean
  accountName?: string
}

const ssoConnections = ref<SsoConnection[]>([])

function buildSsoConnections(member: MemberDto | null): SsoConnection[] {
  const connections: SsoConnection[] = [
    {
      provider: 'Kakao',
      label: t('member.sso.providers.kakao'),
      icon: '/img/kakao.png',
      connected: !!member?.kakaoId,
    },
    {
      provider: 'Naver',
      label: t('member.sso.providers.naver'),
      icon: '/img/naver.svg',
      connected: !!member?.naverId,
    },
  ]

  return connections.filter((connection) => connection.connected || connection.provider !== 'Naver' || isNaverEnabled)
}

async function connectSso(provider: SsoProvider) {
  if (connectingSso.value) return

  const prompts: Record<SsoProvider, { message: string; title: string; connect: () => void }> = {
    Kakao: {
      message: t('member.sso.prompts.kakaoMessage'),
      title: t('member.sso.prompts.kakaoTitle'),
      connect: () => kakaoLink(),
    },
    Naver: {
      message: t('member.sso.prompts.naverMessage'),
      title: t('member.sso.prompts.naverTitle'),
      connect: () => naverLink(),
    },
  }

  const prompt = prompts[provider]
  const confirmed = await confirm(prompt.message, prompt.title)
  if (!confirmed) return

  connectingSso.value = provider
  try {
    prompt.connect()
  } catch (error) {
    console.error('Failed to connect sso:', error)
    connectingSso.value = null
    showError(t('member.sso.startFailed'))
    return
  }
}

type SocialLinkProvider = 'kakao' | 'naver'
type SocialLinkErrorCode = 'already_linked'

function getSingleQueryValue(value: unknown): string | null {
  if (Array.isArray(value)) {
    return typeof value[0] === 'string' ? value[0] : null
  }
  return typeof value === 'string' ? value : null
}

async function clearSocialLinkQuery() {
  if (!route.query.socialLinkError && !route.query.socialProvider) return

  const nextQuery = { ...route.query }
  delete nextQuery.socialLinkError
  delete nextQuery.socialProvider
  await router.replace({ query: nextQuery })
}

async function handleSocialLinkQuery() {
  const socialLinkError = getSingleQueryValue(route.query.socialLinkError) as SocialLinkErrorCode | null
  const socialProvider = getSingleQueryValue(route.query.socialProvider) as SocialLinkProvider | null

  if (!socialLinkError || !socialProvider) return

  await clearSocialLinkQuery()

  if (socialLinkError !== 'already_linked') return

  const providerLabel = socialProvider === 'kakao'
    ? t('member.sso.providers.kakao')
    : t('member.sso.providers.naver')
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
    authStore.logout()
    router.push('/auth/login')
  } catch (error: any) {
    const message = resolveApiErrorMessage(error, { fallbackKey: 'member.password.changeFailed' }, t)
    showError(message)
  } finally {
    changingPassword.value = false
  }
}

// Account deletion
function deleteAccount() {
  showInfo(t('member.account.deleteInfo'))
}

// Logout
async function logout() {
  const confirmed = await confirm(
    t('member.logoutDialog.message'),
    t('member.logoutDialog.title')
  )
  if (confirmed) {
    authStore.logout()
    router.push('/auth/login')
  }
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
  try {
    // Fetch all data in parallel
    await Promise.all([
      fetchMemberInfo(),
      fetchFamilyAndManagers(),
      fetchManagedMembers(),
      fetchTokens(),
      initPushNotification(),
    ])

    // Set initial visibility from user data
    if (memberInfo.value) {
      calendarVisibility.value = memberInfo.value.calendarVisibility
    }

    // Set SSO connections based on user data
    ssoConnections.value = buildSsoConnections(memberInfo.value)
    await handleSocialLinkQuery()
  } catch (error) {
    console.error('Failed to initialize:', error)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <h1 class="text-2xl font-bold mb-6 text-dp-text-primary">{{ t('member.title') }}</h1>

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

      <!-- Privacy Settings Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4 bg-dp-bg-card border border-dp-border-primary">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2 text-dp-text-primary">
          <Eye class="w-5 h-5 text-dp-text-secondary" />
          {{ t('member.visibility.sectionTitle') }}
        </h2>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div>
            <p class="text-dp-text-primary">{{ t('member.visibility.currentLabel') }}</p>
            <p class="text-sm mt-1 text-dp-text-secondary">{{ t('member.visibility.description') }}</p>
          </div>
          <button
            @click="showVisibilityModal = true"
            class="px-4 py-3 sm:py-2 min-h-11 rounded-lg font-medium transition flex items-center justify-center gap-2 hover:brightness-95 cursor-pointer bg-dp-bg-tertiary text-dp-text-primary"
          >
            <span
              class="w-2 h-2 rounded-full"
              :class="visibilityColorClass"
            ></span>
            {{ visibilityLabel }}
            <ChevronRight class="w-4 h-4" />
          </button>
        </div>
      </section>

      <!-- Theme Settings Section -->
      <section class="rounded-xl shadow-sm p-6 mb-4 bg-dp-bg-card border border-dp-border-primary">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2 text-dp-text-primary">
          <Sun class="w-5 h-5 text-dp-text-secondary" />
          {{ t('member.theme.sectionTitle') }}
        </h2>
        <div class="flex flex-col sm:flex-row gap-3">
          <button
            v-for="option in themeOptions"
            :key="option.value"
            @click="setTheme(option.value)"
            class="flex-1 px-4 py-3 rounded-lg font-medium transition flex items-center justify-center gap-2 hover:brightness-95 cursor-pointer"
            :class="{ 'hover:scale-[1.02]': themeStore.mode !== option.value }"
            :style="{
              borderWidth: '2px',
              borderColor: themeStore.mode === option.value ? 'var(--dp-accent)' : 'var(--dp-border-primary)',
              backgroundColor: themeStore.mode === option.value ? 'var(--dp-accent-bg)' : 'var(--dp-bg-secondary)',
              color: themeStore.mode === option.value ? 'var(--dp-accent)' : 'var(--dp-text-primary)'
            }"
          >
            <component :is="option.icon" class="w-5 h-5" />
            {{ option.label }}
          </button>
        </div>
        <p class="text-sm mt-3 text-dp-text-muted">
          {{ t('member.theme.current', { theme: currentThemeLabel }) }}
        </p>
      </section>

      <!-- Push Notification Settings Section -->
      <section v-if="showPushSettings" class="rounded-xl shadow-sm p-6 mb-4 bg-dp-bg-card border border-dp-border-primary">
        <h2 class="text-lg font-semibold mb-4 flex items-center gap-2 text-dp-text-primary">
          <Bell class="w-5 h-5 text-dp-text-secondary" />
          {{ t('member.push.sectionTitle') }}
        </h2>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div>
            <p class="text-dp-text-primary">{{ t('member.push.statusLabel') }}</p>
            <p class="text-sm mt-1 text-dp-text-secondary">{{ pushStatusText }}</p>
          </div>
          <button
            @click="togglePushNotification"
            :disabled="togglingPush || pushNotification.permission.value === 'denied'"
            class="px-4 py-3 sm:py-2 min-h-11 rounded-lg font-medium transition flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
            :style="{
              backgroundColor: pushNotification.permission.value === 'granted' && pushNotification.isSubscribed.value
                ? 'var(--dp-bg-tertiary)'
                : 'var(--dp-accent)',
              color: pushNotification.permission.value === 'granted' && pushNotification.isSubscribed.value
                ? 'var(--dp-text-primary)'
                : 'var(--dp-text-on-dark)'
            }"
          >
            <Loader2 v-if="togglingPush" class="w-4 h-4 animate-spin" />
            <template v-else>
              <BellOff v-if="pushNotification.permission.value === 'granted' && pushNotification.isSubscribed.value" class="w-4 h-4" />
              <Bell v-else class="w-4 h-4" />
            </template>
            {{ pushNotification.permission.value === 'granted' && pushNotification.isSubscribed.value
              ? t('member.push.buttonDisable')
              : t('member.push.buttonEnable') }}
          </button>
        </div>
        <p v-if="isIOSPWA && pushNotification.permission.value === 'denied'" class="text-sm mt-3 text-dp-text-muted">
          {{ t('member.push.iosHint') }}
        </p>
      </section>

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
                  class="flex items-center gap-1.5 px-3 py-2 min-h-10 text-sm font-medium text-dp-accent bg-dp-accent-soft hover:bg-dp-accent-soft rounded-lg transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
                >
                  <Loader2 v-if="impersonating === member.id" class="w-4 h-4 animate-spin" />
                  <LogIn v-else class="w-4 h-4" />
                  <span class="hidden sm:inline">{{ t('member.manager.login') }}</span>
                </button>
              </div>
              <!-- Add auxiliary account card -->
              <button
                @click="openAuxiliaryModal"
                class="w-full flex items-center justify-center gap-2 p-3 rounded-lg border-2 border-dashed transition cursor-pointer hover:border-solid border-dp-border-primary text-dp-text-muted"
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
            class="px-3 py-2 min-h-10 text-xs font-medium text-dp-danger bg-dp-danger-soft hover:bg-dp-danger-soft rounded-lg transition flex items-center gap-1.5 disabled:opacity-50 cursor-pointer"
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
            class="flex items-center justify-between p-3 rounded-lg bg-dp-bg-secondary"
          >
            <div class="flex items-center gap-3">
              <img :src="sso.icon" :alt="sso.label" class="w-8 h-8 rounded" />
              <div>
                <p class="font-medium text-dp-text-primary">{{ sso.label }}</p>
                <p v-if="sso.connected && sso.accountName" class="text-sm text-dp-text-secondary">
                  {{ sso.accountName }}
                </p>
              </div>
            </div>
            <div>
              <span v-if="sso.connected" class="flex items-center gap-1 text-dp-success text-sm">
                <Check class="w-4 h-4" />
                {{ t('member.sso.connected') }}
              </span>
              <button
                v-else
                @click="connectSso(sso.provider)"
                :disabled="!!connectingSso"
                class="px-4 py-2.5 sm:py-1.5 min-h-11 sm:min-h-0 text-sm font-medium text-dp-accent bg-dp-accent-soft hover:bg-dp-accent-soft rounded-lg transition disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
              >
                {{ connectingSso === sso.provider ? t('member.sso.connecting') : t('member.sso.connect') }}
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
            class="px-4 py-3 sm:py-2 min-h-11 text-sm font-medium text-dp-accent bg-dp-accent-soft hover:bg-dp-accent-soft rounded-lg transition flex items-center gap-2 cursor-pointer"
          >
            <Lock class="w-4 h-4" />
            {{ t('member.account.changePassword') }}
          </button>
          <button
            @click="deleteAccount"
            class="px-4 py-3 sm:py-2 min-h-11 text-sm font-medium text-dp-danger bg-dp-danger-soft hover:bg-dp-danger-soft rounded-lg transition flex items-center gap-2 cursor-pointer"
          >
            <UserX class="w-4 h-4" />
            {{ t('member.account.deleteAccount') }}
          </button>
        </div>
      </section>

      <!-- Logout Section -->
      <section class="rounded-xl shadow-sm p-4 sm:p-6 bg-dp-bg-card border border-dp-border-primary">
        <button
          @click="logout"
          class="w-full px-4 py-3 min-h-12 text-dp-warning bg-dp-warning-soft hover:bg-dp-warning-soft rounded-lg font-medium transition flex items-center justify-center gap-2 cursor-pointer"
        >
          <LogOut class="w-5 h-5" />
          {{ t('member.logout') }}
        </button>
      </section>
    </template>

    <!-- Visibility Modal -->
    <BaseModal
      :is-open="showVisibilityModal"
      size="md"
      height="fit"
      rounded
      :panel-style="memberModalPanelStyle"
      @close="showVisibilityModal = false"
    >
      <div class="modal-header">
        <h2>{{ t('member.visibility.modalTitle') }}</h2>
        <button @click="showVisibilityModal = false" class="p-1.5 rounded-full hover-close-btn cursor-pointer text-dp-text-muted">
          <X class="w-5 h-5" />
        </button>
      </div>
      <div class="modal-body-form-lg">
        <p class="text-dp-text-secondary">{{ t('member.visibility.modalDescription') }}</p>
        <p class="text-sm text-dp-text-muted">{{ t('member.visibility.modalHint') }}</p>
        <div class="space-y-2">
          <button
            v-for="option in visibilityOptions"
            :key="option.value"
            @click="setVisibility(option.value)"
            :disabled="savingVisibility"
            class="w-full p-4 min-h-16 rounded-lg transition text-left disabled:opacity-50 hover:scale-[1.01] cursor-pointer"
            :class="{ 'hover:bg-opacity-80': calendarVisibility !== option.value }"
            :style="{
              borderWidth: '2px',
              borderColor: calendarVisibility === option.value ? 'var(--dp-accent)' : 'var(--dp-border-primary)',
              backgroundColor: calendarVisibility === option.value ? 'var(--dp-accent-bg)' : 'var(--dp-bg-secondary)'
            }"
          >
            <div class="flex items-center gap-3">
              <span class="w-3 h-3 rounded-full" :class="option.color"></span>
              <span class="font-medium text-dp-text-primary">{{ option.label }}</span>
              <Check
                v-if="calendarVisibility === option.value"
                class="w-5 h-5 text-dp-accent ml-auto"
              />
              <Loader2
                v-if="savingVisibility && calendarVisibility !== option.value"
                class="w-5 h-5 animate-spin ml-auto text-dp-text-muted"
              />
            </div>
            <p class="text-sm mt-1 ml-6 text-dp-text-secondary">{{ option.description }}</p>
          </button>
        </div>
      </div>
      <div class="modal-actions modal-footer-safe sm:px-6 sm:py-6">
        <button
          @click="showVisibilityModal = false"
          class="w-full px-4 py-3 sm:py-2 min-h-11 rounded-lg font-medium hover-interactive cursor-pointer bg-dp-bg-tertiary text-dp-text-primary"
        >
          {{ t('member.visibility.closeButton') }}
        </button>
      </div>
    </BaseModal>

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
  </div>
</template>
