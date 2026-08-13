<script setup lang="ts">
import { computed, nextTick, onUnmounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import {
  AlertTriangle,
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
  getAccountDeletionErrorKey,
  isAccountDeletionAlreadyPending,
  type AccountDeletionPreview,
} from '@/api/accountDeletion'
import type { SocialAccountProvider } from '@/api/member'
import {
  ACCOUNT_DELETION_STEPS,
  accountDeletionNameMatches,
  canLeaveAccountDeletionTeamStep,
  createMemoryOnlyReauthProof,
  readValidReauthProof,
  type AccountDeletionCompletion,
  type AccountDeletionStep,
  type MemoryOnlyReauthProof,
} from '@/utils/accountDeletionFlow'

const props = defineProps<{
  isOpen: boolean
  memberName: string
}>()

const emit = defineEmits<{
  close: []
  completed: [completion: AccountDeletionCompletion]
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
  loading.value = false
  working.value = false
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
  return provider === 'KAKAO'
    ? t('member.sso.providers.kakao')
    : t('member.sso.providers.naver')
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

  working.value = true
  errorKey.value = null
  let completion: AccountDeletionCompletion | null = null
  try {
    await accountDeletionApi.requestDeletion(reauthProof, selectedTransferMemberId.value)
    completion = 'accepted'
  } catch (error) {
    if (isAccountDeletionAlreadyPending(error)) {
      completion = 'alreadyPending'
    } else {
      errorKey.value = getAccountDeletionErrorKey(error)
      step.value = 'reauthentication'
    }
  } finally {
    // Proofs are one-use and every final request consumes or invalidates them.
    clearProof()
    password.value = ''
    working.value = false
  }

  if (completion) emit('completed', completion)
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
            <div v-if="preview.socialProviders.length" class="space-y-2">
              <p class="text-sm font-medium text-dp-text-primary">{{ t('member.accountDeletion.reauth.socialTitle') }}</p>
              <button
                v-for="provider in preview.socialProviders"
                :key="provider"
                type="button"
                class="min-h-11 w-full rounded-lg border border-dp-border-primary bg-dp-bg-secondary px-4 font-medium text-dp-text-primary transition hover:bg-dp-bg-hover disabled:cursor-not-allowed disabled:opacity-50"
                :disabled="working"
                @click="reauthenticateWithSocial(provider)"
              >
                {{ t('member.accountDeletion.reauth.socialAction', { provider: providerLabel(provider) }) }}
              </button>
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
          </template>

          <p v-if="errorKey" class="flex items-start gap-2 rounded-xl bg-dp-danger-soft p-3 text-sm leading-6 text-dp-danger" role="alert">
            <AlertTriangle class="mt-1 h-4 w-4 shrink-0" aria-hidden="true" />
            {{ t(errorKey) }}
          </p>
        </div>
      </div>

      <div v-if="preview" class="modal-actions modal-footer-safe flex-col-reverse sm:flex-row">
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
