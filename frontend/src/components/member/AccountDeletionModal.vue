<script setup lang="ts">
import { computed, nextTick, onUnmounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import {
  AlertTriangle,
  Apple,
  KeyRound,
  Loader2,
  ShieldCheck,
  UserX,
  Users,
  X,
} from 'lucide-vue-next'
import BaseModal from '@/components/common/BaseModal.vue'
import {
  AccountDeletionOAuthError,
  accountDeletionApi,
  createAccountDeletionReceiptToken,
  getWebSocialReauthenticationProviders,
  getAccountDeletionErrorKey,
  isAccountDeletionAlreadyPending,
  requiresIosAppleReauthentication,
  type AccountDeletionAcceptedResponse,
  type AccountDeletionPreview,
} from '@/api/accountDeletion'
import type { SocialAccountProvider } from '@/api/member'
import {
  ACCOUNT_DELETION_STEPS,
  accountDeletionNameMatches,
  canLeaveAccountDeletionTeamStep,
  createMemoryOnlyReauthProof,
  isAmbiguousAccountDeletionRequestError,
  readValidReauthProof,
  type AccountDeletionCompletionResult,
  type AccountDeletionStep,
  type MemoryOnlyReauthProof,
} from '@/utils/accountDeletionFlow'
import {
  ACCOUNT_DELETION_EXPECTED_COMPLETION_MS,
  clearAccountDeletionReceipt,
  hasStoredAccountDeletionReceiptEntry,
  isAccountDeletionReceipt,
  readAccountDeletionReceipt,
  saveAccountDeletionReceipt,
  type AccountDeletionReceipt,
} from '@/utils/accountDeletionReceipt'

const props = defineProps<{
  isOpen: boolean
  memberId: number
  memberName: string
}>()

const emit = defineEmits<{
  close: []
  completed: [result: AccountDeletionCompletionResult]
}>()

const { t } = useI18n()
const closeButton = ref<HTMLButtonElement | null>(null)
const preview = ref<AccountDeletionPreview | null>(null)
const step = ref<AccountDeletionStep>('scope')
const selectedTransferMemberId = ref<number | null>(null)
const password = ref('')
const typedName = ref('')
const proof = ref<MemoryOnlyReauthProof | null>(null)
const loading = ref(false)
const working = ref(false)
const errorKey = ref<string | null>(null)
const requestBlocked = ref(false)
const pendingReceiptToken = ref<string | null>(null)
const pendingReceipt = ref<AccountDeletionReceipt | null>(null)
let proofExpiryTimer: number | null = null

const titleId = 'account-deletion-modal-title'
const progressId = 'account-deletion-modal-progress'
const stepIndex = computed(() => ACCOUNT_DELETION_STEPS.indexOf(step.value))
const stepNumber = computed(() => stepIndex.value + 1)
const requiresAdminTransfer = computed(() => {
  const team = preview.value?.teamImpact
  return !!team?.isAdmin && team.activeMemberCount > 1
})
const hasValidProof = computed(() => readValidReauthProof(proof.value) !== null)
const webSocialProviders = computed(() => preview.value
  ? getWebSocialReauthenticationProviders(preview.value)
  : [])
const hasAppleProvider = computed(() => preview.value?.socialProviders.includes('APPLE') ?? false)
const canCheckDeletionStatus = computed(() => pendingReceiptToken.value !== null
  || readAccountDeletionReceipt() !== null
  || hasStoredAccountDeletionReceiptEntry())
const shouldShowReceiptRecovery = computed(() => errorKey.value === 'member.accountDeletion.errors.receiptMismatch'
  || errorKey.value === 'member.accountDeletion.errors.receiptStorage'
  || canCheckDeletionStatus.value)
const appleIsOnlyReauthenticationMethod = computed(() => preview.value
  ? requiresIosAppleReauthentication(preview.value)
  : false)
const canContinue = computed(() => {
  if (!preview.value) return false
  switch (step.value) {
    case 'scope':
      return true
    case 'team':
      return canLeaveAccountDeletionTeamStep(preview.value, selectedTransferMemberId.value)
    case 'reauthentication':
      return hasValidProof.value
    case 'nameConfirmation':
      return accountDeletionNameMatches(typedName.value, props.memberName)
    case 'finalConfirmation':
      return false
  }
})

watch(
  () => props.isOpen,
  async (isOpen) => {
    if (!isOpen) return
    resetFlow()
    await nextTick()
    closeButton.value?.focus()
    await loadPreview()
  },
  { immediate: true },
)

function resetFlow() {
  clearProof()
  preview.value = null
  step.value = 'scope'
  selectedTransferMemberId.value = null
  password.value = ''
  typedName.value = ''
  errorKey.value = null
  requestBlocked.value = false
  loading.value = false
  working.value = false
  pendingReceiptToken.value = null
  pendingReceipt.value = null
}

function clearProof() {
  proof.value = null
  if (proofExpiryTimer !== null) {
    window.clearTimeout(proofExpiryTimer)
    proofExpiryTimer = null
  }
}

onUnmounted(clearProof)

async function loadPreview() {
  if (loading.value) return
  loading.value = true
  errorKey.value = null
  try {
    preview.value = (await accountDeletionApi.getPreview()).data
  } catch (error) {
    const mapped = getAccountDeletionErrorKey(error)
    errorKey.value = mapped === 'member.accountDeletion.errors.impersonation'
      ? mapped
      : 'member.accountDeletion.errors.load'
  } finally {
    loading.value = false
  }
}

function close() {
  if (working.value) return
  clearProof()
  password.value = ''
  emit('close')
}

function next() {
  errorKey.value = null
  if (!preview.value) return

  switch (step.value) {
    case 'scope':
      step.value = 'team'
      break
    case 'team':
      if (!canLeaveAccountDeletionTeamStep(preview.value, selectedTransferMemberId.value)) {
        errorKey.value = preview.value.teamImpact?.transferCandidates.length
          ? 'member.accountDeletion.errors.transferRequired'
          : 'member.accountDeletion.errors.noTransferCandidate'
        return
      }
      step.value = 'reauthentication'
      break
    case 'reauthentication':
      if (!readValidReauthProof(proof.value)) {
        clearProof()
        errorKey.value = 'member.accountDeletion.errors.proofExpired'
        return
      }
      step.value = 'nameConfirmation'
      break
    case 'nameConfirmation':
      if (!accountDeletionNameMatches(typedName.value, props.memberName)) {
        errorKey.value = 'member.accountDeletion.errors.nameMismatch'
        return
      }
      step.value = 'finalConfirmation'
      break
    case 'finalConfirmation':
      break
  }
}

function back() {
  if (working.value) return
  errorKey.value = null
  switch (step.value) {
    case 'scope':
      break
    case 'team':
      step.value = 'scope'
      break
    case 'reauthentication':
      clearProof()
      password.value = ''
      step.value = 'team'
      break
    case 'nameConfirmation':
      step.value = 'reauthentication'
      break
    case 'finalConfirmation':
      step.value = 'nameConfirmation'
      break
  }
}

function storeProof(reauthProof: string, expiresIn: number) {
  clearProof()
  proof.value = createMemoryOnlyReauthProof(reauthProof, expiresIn)
  proofExpiryTimer = window.setTimeout(() => {
    clearProof()
    if (step.value === 'reauthentication') {
      errorKey.value = 'member.accountDeletion.errors.proofExpired'
    }
  }, Math.max(0, expiresIn * 1000))
}

async function reauthenticateWithPassword() {
  if (!password.value || working.value) return
  working.value = true
  errorKey.value = null
  try {
    const response = await accountDeletionApi.reauthenticateWithPassword(password.value)
    storeProof(response.data.reauthProof, response.data.expiresIn)
  } catch (error) {
    clearProof()
    errorKey.value = getAccountDeletionErrorKey(error)
  } finally {
    password.value = ''
    working.value = false
  }
}

function oauthErrorKey(error: AccountDeletionOAuthError): string {
  switch (error.reason) {
    case 'popup_blocked':
      return 'member.accountDeletion.errors.oauthPopupBlocked'
    case 'popup_closed':
      return 'member.accountDeletion.errors.oauthPopupClosed'
    case 'popup_timeout':
      return 'member.accountDeletion.errors.oauthPopupTimeout'
    case 'oauth_cancelled':
      return 'member.accountDeletion.errors.oauthCancelled'
    case 'reauth_account_mismatch':
      return 'member.accountDeletion.errors.oauthAccountMismatch'
    case 'provider_failed':
    case 'invalid_response':
      return 'member.accountDeletion.errors.oauthProviderFailed'
    case 'unsupported_provider':
      return 'member.accountDeletion.errors.appleRequiresIos'
  }
}

async function reauthenticateWithSocial(provider: SocialAccountProvider) {
  if (working.value) return
  working.value = true
  errorKey.value = null
  try {
    const response = await accountDeletionApi.reauthenticateWithSocial(provider)
    storeProof(response.reauthProof, response.expiresIn)
  } catch (error) {
    clearProof()
    errorKey.value = error instanceof AccountDeletionOAuthError
      ? oauthErrorKey(error)
      : getAccountDeletionErrorKey(error)
  } finally {
    working.value = false
  }
}

function providerLabel(provider: SocialAccountProvider): string {
  switch (provider) {
    case 'KAKAO':
      return t('member.sso.providers.kakao')
    case 'NAVER':
      return t('member.sso.providers.naver')
    case 'APPLE':
      return t('member.sso.providers.apple')
  }
}

async function submit() {
  if (working.value) return
  const reauthProof = readValidReauthProof(proof.value)
  if (!reauthProof) {
    clearProof()
    step.value = 'reauthentication'
    errorKey.value = 'member.accountDeletion.errors.proofExpired'
    return
  }

  const receiptToken = ensurePendingReceiptToken()
  if (!receiptToken) return

  working.value = true
  errorKey.value = null
  let completionResult: AccountDeletionCompletionResult | null = null
  try {
    const response = await accountDeletionApi.requestDeletion(
      reauthProof,
      selectedTransferMemberId.value,
      receiptToken,
    )
    const responseData: unknown = response?.data
    if (!isTrustedAcceptedResponse(responseData, receiptToken)) {
      // A successful response with a different token is a protocol violation. The
      // request may still have been accepted, so preserve the provisional receipt
      // and let the caller sign out into the status flow instead of resubmitting.
      completionResult = uncertainCompletionResult()
    } else {
      const receipt = accountDeletionReceiptFromAcceptedResponse(responseData)
      completionResult = {
        completion: 'accepted',
        // Keep the pre-request receipt as a safe fallback if the response is incomplete.
        receipt: receipt ?? currentMemberReceipt(pendingReceipt.value ?? readAccountDeletionReceipt()),
      }
    }
  } catch (error) {
    if (isAccountDeletionAlreadyPending(error)) {
      const serverReceipt = accountDeletionReceiptFromUnknown(error)
      completionResult = {
        completion: 'alreadyPending',
        // Do not replace the pre-request credential if an error payload carries
        // a different token; that is another protocol ambiguity.
        receipt: serverReceipt?.receiptToken === receiptToken
          ? serverReceipt
          : currentMemberReceipt(pendingReceipt.value ?? readAccountDeletionReceipt()),
      }
    } else if (isAmbiguousAccountDeletionRequestError(error)) {
      completionResult = uncertainCompletionResult()
    } else {
      const mappedErrorKey = getAccountDeletionErrorKey(error)
      clearProvisionalReceipt()
      errorKey.value = mappedErrorKey
      requestBlocked.value = mappedErrorKey === 'member.accountDeletion.errors.receiptMismatch'
      if (!requestBlocked.value) step.value = 'reauthentication'
    }
  } finally {
    // Proofs are one-use and every final request consumes or invalidates them.
    clearProof()
    password.value = ''
    working.value = false
  }

  if (completionResult) emit('completed', completionResult)
}

function ensurePendingReceiptToken(): string | null {
  if (pendingReceiptToken.value) {
    if (pendingReceipt.value?.ownerMemberId === props.memberId) {
      return pendingReceiptToken.value
    }
    errorKey.value = 'member.accountDeletion.errors.receiptOwnedByAnotherAccount'
    return null
  }

  const stored = readAccountDeletionReceipt()
  if (stored && stored.ownerMemberId !== props.memberId) {
    errorKey.value = 'member.accountDeletion.errors.receiptOwnedByAnotherAccount'
    return null
  }
  if (stored?.jobId === null) {
    pendingReceiptToken.value = stored.receiptToken
    pendingReceipt.value = stored
    return stored.receiptToken
  }
  if (stored) {
    errorKey.value = 'member.accountDeletion.errors.receiptAlreadyPending'
    return null
  }

  const receiptToken = createAccountDeletionReceiptToken()
  const newReceipt: AccountDeletionReceipt = {
    ownerMemberId: props.memberId,
    jobId: null,
    receiptToken,
    estimatedCompletionAt: new Date(Date.now() + ACCOUNT_DELETION_EXPECTED_COMPLETION_MS).toISOString(),
  }
  if (!saveAccountDeletionReceipt(newReceipt)) {
    errorKey.value = 'member.accountDeletion.errors.receiptStorage'
    return null
  }
  pendingReceiptToken.value = receiptToken
  pendingReceipt.value = newReceipt
  return receiptToken
}

function uncertainCompletionResult(): AccountDeletionCompletionResult | null {
  const receipt = currentMemberReceipt(pendingReceipt.value ?? readAccountDeletionReceipt())
  return receipt ? { completion: 'accepted', receipt } : null
}

function currentMemberReceipt(receipt: AccountDeletionReceipt | null): AccountDeletionReceipt | null {
  return receipt?.ownerMemberId === props.memberId ? receipt : null
}

function clearProvisionalReceipt() {
  const receipt = currentMemberReceipt(pendingReceipt.value ?? readAccountDeletionReceipt())
  if (receipt?.jobId === null) clearAccountDeletionReceipt()
  pendingReceiptToken.value = null
  pendingReceipt.value = null
}

function isTrustedAcceptedResponse(
  value: unknown,
  receiptToken: string,
): value is AccountDeletionAcceptedResponse {
  if (!value || typeof value !== 'object') return false
  const response = value as Record<string, unknown>
  return Number.isInteger(response.jobId)
    && (response.jobId as number) > 0
    && typeof response.status === 'string'
    && response.status.trim().length > 0
    && response.receiptToken === receiptToken
    && typeof response.estimatedCompletionAt === 'string'
    && Number.isFinite(Date.parse(response.estimatedCompletionAt))
}

function accountDeletionReceiptFromAcceptedResponse(
  response: AccountDeletionAcceptedResponse,
): AccountDeletionReceipt | null {
  const receipt = {
    ownerMemberId: props.memberId,
    jobId: response.jobId,
    receiptToken: response.receiptToken,
    estimatedCompletionAt: response.estimatedCompletionAt,
  }
  return isAccountDeletionReceipt(receipt) ? receipt : null
}

function accountDeletionReceiptFromUnknown(error: unknown): AccountDeletionReceipt | null {
  const data = (error as { response?: { data?: unknown } }).response?.data
  if (!data || typeof data !== 'object') return null
  const value = data as Record<string, unknown>
  const receipt = {
    ownerMemberId: props.memberId,
    jobId: value.jobId,
    receiptToken: value.receiptToken,
    estimatedCompletionAt: value.estimatedCompletionAt,
  }
  return isAccountDeletionReceipt(receipt) ? receipt : null
}

function receiptRecoveryPath(): string {
  return hasStoredAccountDeletionReceiptEntry() ? '/account-deletion-status' : '/support'
}

function receiptRecoveryLabel(): string {
  return hasStoredAccountDeletionReceiptEntry()
    ? t('member.accountDeletion.status.recoverStoredReceipt')
    : t('member.accountDeletion.completion.contactSupport')
}
</script>

<template>
  <BaseModal
    :is-open="isOpen"
    size="md"
    height="viewport"
    overlay-padding="none"
    overlay-class="!items-end sm:!items-center"
    panel-class="w-full !rounded-t-2xl !rounded-b-none border border-dp-border-primary sm:!rounded-2xl"
    :aria-labelledby="titleId"
    :aria-describedby="progressId"
    :close-on-backdrop="!working"
    :close-on-escape="!working"
    @close="close"
  >
    <section class="flex min-h-0 flex-1 flex-col overflow-hidden">
      <div class="modal-header gap-3">
        <div class="min-w-0">
          <h2 :id="titleId" class="truncate">{{ t('member.accountDeletion.title') }}</h2>
          <p :id="progressId" class="mt-1 text-xs text-dp-text-muted">
            {{ t('member.accountDeletion.progress', { current: stepNumber, total: ACCOUNT_DELETION_STEPS.length }) }}
          </p>
        </div>
        <button
          ref="closeButton"
          type="button"
          class="flex min-h-11 min-w-11 shrink-0 items-center justify-center rounded-full text-dp-text-muted transition hover:bg-dp-bg-hover hover:text-dp-text-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="working"
          :aria-label="t('common.actions.close')"
          @click="close"
        >
          <X class="h-5 w-5" aria-hidden="true" />
        </button>
      </div>

      <div class="h-1 shrink-0 bg-dp-bg-tertiary" aria-hidden="true">
        <div
          class="h-full bg-dp-danger transition-[width] duration-200"
          :style="{ width: `${(stepNumber / ACCOUNT_DELETION_STEPS.length) * 100}%` }"
        ></div>
      </div>

      <div class="min-h-0 flex-1 overflow-x-hidden overflow-y-auto p-4 sm:p-5">
        <div v-if="loading" class="flex min-h-56 items-center justify-center gap-2 text-dp-text-secondary">
          <Loader2 class="h-5 w-5 animate-spin text-dp-accent" aria-hidden="true" />
          {{ t('member.accountDeletion.loading') }}
        </div>

        <div v-else-if="requestBlocked" class="flex min-h-56 flex-col items-center justify-center text-center">
          <AlertTriangle class="h-8 w-8 text-dp-warning" aria-hidden="true" />
          <p class="mt-3 text-sm leading-6 text-dp-text-secondary" role="alert">
            {{ t(errorKey || 'member.accountDeletion.errors.generic') }}
          </p>
          <RouterLink
            to="/support"
            class="mt-4 inline-flex min-h-11 items-center rounded-lg bg-dp-accent-soft px-4 font-medium text-dp-accent hover:bg-dp-accent-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
          >
            {{ t('member.accountDeletion.completion.contactSupport') }}
          </RouterLink>
        </div>

        <div v-else-if="!preview" class="flex min-h-56 flex-col items-center justify-center text-center">
          <AlertTriangle class="h-8 w-8 text-dp-warning" aria-hidden="true" />
          <p class="mt-3 text-sm leading-6 text-dp-text-secondary">
            {{ t(errorKey || 'member.accountDeletion.errors.load') }}
          </p>
          <button
            type="button"
            class="mt-4 min-h-11 rounded-lg bg-dp-accent-soft px-4 font-medium text-dp-accent hover:bg-dp-accent-soft-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
            @click="loadPreview"
          >
            {{ t('common.actions.retry') }}
          </button>
        </div>

        <div v-else class="space-y-4">
          <template v-if="step === 'scope'">
            <div>
              <h3 class="text-lg font-semibold text-dp-text-primary">{{ t('member.accountDeletion.scope.title') }}</h3>
              <p class="mt-2 text-sm leading-6 text-dp-text-secondary">{{ t('member.accountDeletion.scope.message') }}</p>
            </div>
            <div class="space-y-2">
              <div class="flex items-start gap-2 rounded-xl bg-dp-danger-soft p-3 text-sm leading-6 text-dp-danger">
                <AlertTriangle class="mt-1 h-4 w-4 shrink-0" aria-hidden="true" />
                {{ t('member.accountDeletion.scope.access') }}
              </div>
              <div class="flex items-start gap-2 rounded-xl bg-dp-warning-soft p-3 text-sm leading-6 text-dp-warning">
                <AlertTriangle class="mt-1 h-4 w-4 shrink-0" aria-hidden="true" />
                {{ t('member.accountDeletion.scope.async') }}
              </div>
            </div>
            <div class="rounded-xl border border-dp-border-primary bg-dp-bg-secondary p-4">
              <p class="text-sm leading-6 text-dp-text-secondary">
                {{ t('member.accountDeletion.retentionNotice') }}
              </p>
              <RouterLink
                to="/privacy"
                class="mt-2 inline-flex text-sm font-semibold text-dp-accent hover:underline"
              >
                {{ t('policy.privacy.title') }}
              </RouterLink>
            </div>
            <div v-if="preview.auxiliaryImpacts.length" class="rounded-xl border border-dp-border-primary bg-dp-bg-secondary p-4">
              <h4 class="font-semibold text-dp-text-primary">{{ t('member.accountDeletion.scope.auxiliary') }}</h4>
              <ul class="mt-2 space-y-2 text-sm text-dp-text-secondary">
                <li v-for="account in preview.auxiliaryImpacts" :key="account.memberId" class="flex items-center gap-2">
                  <UserX class="h-4 w-4 shrink-0" aria-hidden="true" />
                  <span class="min-w-0 truncate">{{ account.name }}</span>
                </li>
              </ul>
            </div>
          </template>

          <template v-else-if="step === 'team'">
            <div>
              <h3 class="text-lg font-semibold text-dp-text-primary">{{ t('member.accountDeletion.team.title') }}</h3>
              <p class="mt-2 text-sm leading-6 text-dp-text-secondary">{{ t('member.accountDeletion.team.message') }}</p>
            </div>
            <div v-if="preview.teamImpact" class="rounded-xl border border-dp-border-primary bg-dp-bg-secondary p-4">
              <p class="flex items-center gap-2 font-semibold text-dp-text-primary">
                <Users class="h-5 w-5 text-dp-text-muted" aria-hidden="true" />
                {{ preview.teamImpact.teamName }}
              </p>
              <p v-if="preview.teamImpact.willDeleteTeam" class="mt-3 text-sm leading-6 text-dp-danger">
                {{ t('member.accountDeletion.team.soloDelete') }}
              </p>
              <template v-else-if="requiresAdminTransfer">
                <p class="mt-3 text-sm leading-6 text-dp-text-secondary">
                  {{ t('member.accountDeletion.team.transferRequired') }}
                </p>
                <label class="mt-4 block text-sm font-medium text-dp-text-primary" for="account-deletion-successor">
                  {{ t('member.accountDeletion.team.successor') }}
                </label>
                <select
                  id="account-deletion-successor"
                  v-model="selectedTransferMemberId"
                  class="mt-2 min-h-11 w-full rounded-lg border border-dp-border-input bg-dp-bg-input px-3 text-dp-text-primary focus:outline-none focus:ring-2 focus:ring-dp-accent-ring"
                  :disabled="working || preview.teamImpact.transferCandidates.length === 0"
                >
                  <option :value="null">{{ t('member.accountDeletion.team.select') }}</option>
                  <option
                    v-for="candidate in preview.teamImpact.transferCandidates"
                    :key="candidate.memberId"
                    :value="candidate.memberId"
                  >
                    {{ candidate.name }}
                  </option>
                </select>
                <p v-if="preview.teamImpact.transferCandidates.length === 0" class="mt-2 text-sm text-dp-danger">
                  {{ t('member.accountDeletion.errors.noTransferCandidate') }}
                </p>
              </template>
              <p v-else class="mt-3 text-sm leading-6 text-dp-text-secondary">
                {{ t('member.accountDeletion.team.memberOnly') }}
              </p>
            </div>
            <p v-else class="rounded-xl bg-dp-bg-secondary p-4 text-sm text-dp-text-secondary">
              {{ t('member.accountDeletion.team.none') }}
            </p>
          </template>

          <template v-else-if="step === 'reauthentication'">
            <div>
              <h3 class="text-lg font-semibold text-dp-text-primary">{{ t('member.accountDeletion.reauth.title') }}</h3>
              <p class="mt-2 text-sm leading-6 text-dp-text-secondary">{{ t('member.accountDeletion.reauth.message') }}</p>
            </div>
            <form v-if="preview.hasPassword" class="space-y-2" @submit.prevent="reauthenticateWithPassword">
              <label for="account-deletion-password" class="block text-sm font-medium text-dp-text-primary">
                {{ t('member.accountDeletion.reauth.password') }}
              </label>
              <input
                id="account-deletion-password"
                v-model="password"
                type="password"
                autocomplete="current-password"
                maxlength="100"
                class="min-h-11 w-full rounded-lg border border-dp-border-input bg-dp-bg-input px-3 text-dp-text-primary focus:outline-none focus:ring-2 focus:ring-dp-accent-ring"
                :disabled="working"
              />
              <button
                type="submit"
                class="flex min-h-11 w-full items-center justify-center gap-2 rounded-lg bg-dp-accent px-4 font-medium text-dp-text-on-dark transition hover:bg-dp-accent-hover disabled:cursor-not-allowed disabled:opacity-50"
                :disabled="working || !password"
              >
                <Loader2 v-if="working" class="h-4 w-4 animate-spin" aria-hidden="true" />
                <KeyRound v-else class="h-4 w-4" aria-hidden="true" />
                {{ t('member.accountDeletion.reauth.passwordAction') }}
              </button>
            </form>
            <div v-if="webSocialProviders.length" class="space-y-2">
              <p class="text-sm font-medium text-dp-text-primary">{{ t('member.accountDeletion.reauth.socialTitle') }}</p>
              <button
                v-for="provider in webSocialProviders"
                :key="provider"
                type="button"
                class="min-h-11 w-full rounded-lg border border-dp-border-primary bg-dp-bg-secondary px-4 font-medium text-dp-text-primary transition hover:bg-dp-bg-hover disabled:cursor-not-allowed disabled:opacity-50"
                :disabled="working"
                @click="reauthenticateWithSocial(provider)"
              >
                {{ t('member.accountDeletion.reauth.socialAction', { provider: providerLabel(provider) }) }}
              </button>
            </div>
            <div
              v-if="hasAppleProvider"
              class="flex items-start gap-3 rounded-xl border border-dp-border-primary bg-dp-bg-secondary p-4"
            >
              <Apple class="mt-0.5 h-5 w-5 shrink-0 text-dp-text-primary" aria-hidden="true" />
              <div class="min-w-0">
                <p class="font-medium text-dp-text-primary">
                  {{ t('member.accountDeletion.reauth.appleTitle') }}
                </p>
                <p class="mt-1 text-sm leading-6 text-dp-text-secondary">
                  {{ t(
                    appleIsOnlyReauthenticationMethod
                      ? 'member.accountDeletion.reauth.appleOnlyMessage'
                      : 'member.accountDeletion.reauth.appleAlternativeMessage',
                  ) }}
                </p>
              </div>
            </div>
            <div v-if="hasValidProof" class="flex items-center gap-2 rounded-xl bg-dp-success-soft p-3 text-sm text-dp-success">
              <ShieldCheck class="h-5 w-5 shrink-0" aria-hidden="true" />
              {{ t('member.accountDeletion.reauth.complete') }}
            </div>
          </template>

          <template v-else-if="step === 'nameConfirmation'">
            <div>
              <h3 class="text-lg font-semibold text-dp-text-primary">{{ t('member.accountDeletion.name.title') }}</h3>
              <p class="mt-2 text-sm leading-6 text-dp-text-secondary">{{ t('member.accountDeletion.name.message') }}</p>
            </div>
            <p class="rounded-lg bg-dp-bg-secondary p-3 font-semibold text-dp-text-primary select-all">{{ memberName }}</p>
            <label for="account-deletion-name" class="block text-sm font-medium text-dp-text-primary">
              {{ t('member.accountDeletion.name.label') }}
            </label>
            <input
              id="account-deletion-name"
              v-model="typedName"
              type="text"
              autocomplete="off"
              class="min-h-11 w-full rounded-lg border border-dp-border-input bg-dp-bg-input px-3 text-dp-text-primary focus:outline-none focus:ring-2 focus:ring-dp-accent-ring"
              :placeholder="t('member.accountDeletion.name.placeholder')"
              :disabled="working"
            />
          </template>

          <template v-else>
            <div>
              <h3 class="text-lg font-semibold text-dp-text-primary">{{ t('member.accountDeletion.final.title') }}</h3>
              <p class="mt-2 text-sm leading-6 text-dp-text-secondary">{{ t('member.accountDeletion.final.message') }}</p>
            </div>
            <div class="rounded-xl border border-dp-danger-border bg-dp-danger-soft p-4 text-sm leading-6 text-dp-danger">
              <p class="flex items-start gap-2 font-semibold">
                <AlertTriangle class="mt-1 h-4 w-4 shrink-0" aria-hidden="true" />
                {{ t('member.accountDeletion.final.irreversible') }}
              </p>
            </div>
            <div class="rounded-xl border border-dp-border-primary bg-dp-bg-secondary p-4">
              <p class="text-sm leading-6 text-dp-text-secondary">
                {{ t('member.accountDeletion.retentionNotice') }}
              </p>
              <RouterLink
                to="/privacy"
                class="mt-2 inline-flex text-sm font-semibold text-dp-accent hover:underline"
              >
                {{ t('policy.privacy.title') }}
              </RouterLink>
            </div>
          </template>

          <p v-if="errorKey" class="flex items-start gap-2 rounded-xl bg-dp-danger-soft p-3 text-sm leading-6 text-dp-danger" role="alert">
            <AlertTriangle class="mt-1 h-4 w-4 shrink-0" aria-hidden="true" />
            {{ t(errorKey) }}
          </p>
          <RouterLink
            v-if="errorKey && shouldShowReceiptRecovery"
            :to="receiptRecoveryPath()"
            class="block text-center text-sm font-semibold text-dp-accent hover:underline"
          >
            {{ receiptRecoveryLabel() }}
          </RouterLink>
        </div>
      </div>

      <div v-if="preview && !requestBlocked" class="modal-actions modal-footer-safe flex-col-reverse sm:flex-row">
        <button
          v-if="step !== 'scope'"
          type="button"
          class="min-h-11 flex-1 rounded-lg bg-dp-bg-tertiary px-4 font-medium text-dp-text-primary transition hover:bg-dp-bg-hover disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="working"
          @click="back"
        >
          {{ t('member.accountDeletion.back') }}
        </button>
        <button
          v-if="step === 'finalConfirmation'"
          type="button"
          class="flex min-h-11 flex-1 items-center justify-center gap-2 rounded-lg bg-dp-danger px-4 font-medium text-dp-text-on-dark transition hover:bg-dp-danger-hover disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="working"
          @click="submit"
        >
          <Loader2 v-if="working" class="h-4 w-4 animate-spin" aria-hidden="true" />
          <UserX v-else class="h-4 w-4" aria-hidden="true" />
          {{ t('member.accountDeletion.final.action') }}
        </button>
        <button
          v-else
          type="button"
          class="min-h-11 flex-1 rounded-lg bg-dp-accent px-4 font-medium text-dp-text-on-dark transition hover:bg-dp-accent-hover disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="working || !canContinue"
          @click="next"
        >
          {{ t('member.accountDeletion.continue') }}
        </button>
      </div>
    </section>
  </BaseModal>
</template>
