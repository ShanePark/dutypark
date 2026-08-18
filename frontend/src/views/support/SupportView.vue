<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { AxiosError } from 'axios'
import { CircleCheck, Clock, FileText, Flag, LifeBuoy, Send, UserX } from 'lucide-vue-next'
import PageHeader from '@/components/common/PageHeader.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import MyInquiryList from './MyInquiryList.vue'
import { inquiryApi } from '@/api/inquiry'
import { useAuthStore } from '@/stores/auth'

const SUBJECT_MAX_LENGTH = 100
const CONTENT_MAX_LENGTH = 2000
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

type SupportTab = 'form' | 'history'

const TABS: { value: SupportTab; labelKey: string }[] = [
  { value: 'form', labelKey: 'support.tabs.form' },
  { value: 'history', labelKey: 'support.tabs.history' },
]

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

/** Guests keep the published contact layout: no tabs, no history, e-mail reply copy. */
const isSignedIn = computed(() => authStore.isLoggedIn)

function resolveTab(value: unknown): SupportTab {
  return value === 'history' ? 'history' : 'form'
}

const activeTab = ref<SupportTab>(resolveTab(route.query.tab))
const showHistory = computed(() => isSignedIn.value && activeTab.value === 'history')

// A notification opened while already on /support only swaps the query, so follow it.
watch(() => route.query.tab, (value) => {
  activeTab.value = resolveTab(value)
})

function selectTab(tab: SupportTab) {
  if (activeTab.value === tab) return
  activeTab.value = tab

  const query = { ...route.query }
  if (tab === 'history') query.tab = 'history'
  else delete query.tab
  router.replace({ query })
}

const formDescription = computed(() => isSignedIn.value
  ? t('support.form.descriptionSignedIn')
  : t('support.form.description'))
const successDescription = computed(() => isSignedIn.value
  ? t('support.success.descriptionSignedIn')
  : t('support.success.description'))

/** Signed-in members get their account address, but it stays editable for a different reply inbox. */
const email = ref(authStore.user?.email ?? '')
const subject = ref('')
const content = ref('')
const isSubmitting = ref(false)
const isSubmitted = ref(false)
const error = ref('')

const isEmailValid = computed(() => EMAIL_PATTERN.test(email.value.trim()))
const hasContent = computed(() => content.value.trim().length > 0)
const canSubmit = computed(() => isEmailValid.value && hasContent.value && !isSubmitting.value)

async function handleSubmit() {
  if (isSubmitting.value) return
  error.value = ''

  if (!isEmailValid.value) {
    error.value = t('support.form.error.email')
    return
  }

  if (!hasContent.value) {
    error.value = t('support.form.error.content')
    return
  }

  isSubmitting.value = true
  try {
    await inquiryApi.create({
      email: email.value.trim(),
      subject: subject.value.trim() || undefined,
      content: content.value.trim(),
    })
    isSubmitted.value = true
  } catch (exception) {
    const status = exception instanceof AxiosError ? exception.response?.status : undefined
    error.value = status === 429
      ? t('support.form.error.rateLimit')
      : t('support.form.error.generic')
  } finally {
    isSubmitting.value = false
  }
}

function startAnotherInquiry() {
  subject.value = ''
  content.value = ''
  error.value = ''
  isSubmitted.value = false
}
</script>

<template>
  <div class="max-w-4xl mx-auto px-4 py-6">
    <PageHeader :title="t('support.title')" :icon="LifeBuoy" show-back back-fallback="/more" />

    <p class="mb-4 text-sm leading-relaxed text-dp-text-muted">{{ t('support.subtitle') }}</p>

    <div
      v-if="isSignedIn"
      role="tablist"
      class="mb-4 grid grid-cols-2 gap-1 rounded-xl bg-dp-bg-tertiary p-1"
    >
      <button
        v-for="tab in TABS"
        :key="tab.value"
        type="button"
        role="tab"
        :aria-selected="activeTab === tab.value"
        class="min-h-11 rounded-lg px-3 py-2 text-sm font-medium transition-colors"
        :class="activeTab === tab.value
          ? 'bg-dp-surface-strong text-dp-text-on-dark'
          : 'text-dp-text-secondary hover:bg-dp-bg-hover'"
        @click="selectTab(tab.value)"
      >
        {{ t(tab.labelKey) }}
      </button>
    </div>

    <section v-if="showHistory" class="card card-body">
      <MyInquiryList @go-to-form="selectTab('form')" />
    </section>

    <template v-else>
      <section class="card card-body mb-4">
        <h2 class="mb-4 text-lg font-semibold text-dp-text-primary">{{ t('support.guide.title') }}</h2>

        <div class="space-y-4 text-sm text-dp-text-secondary">
          <div class="flex gap-3">
            <Flag class="mt-0.5 h-4 w-4 shrink-0 text-dp-text-muted" />
            <div>
              <h3 class="font-medium text-dp-text-primary">{{ t('support.guide.reportTitle') }}</h3>
              <p class="mt-1 leading-relaxed">{{ t('support.guide.reportDescription') }}</p>
            </div>
          </div>

          <div class="flex gap-3">
            <UserX class="mt-0.5 h-4 w-4 shrink-0 text-dp-text-muted" />
            <div>
              <h3 class="font-medium text-dp-text-primary">{{ t('support.guide.blockTitle') }}</h3>
              <p class="mt-1 leading-relaxed">{{ t('support.guide.blockDescription') }}</p>
            </div>
          </div>

          <div class="flex gap-3">
            <Clock class="mt-0.5 h-4 w-4 shrink-0 text-dp-text-muted" />
            <div>
              <h3 class="font-medium text-dp-text-primary">{{ t('support.guide.handlingTitle') }}</h3>
              <p class="mt-1 leading-relaxed">{{ t('support.guide.handlingDescription') }}</p>
              <p class="mt-1 leading-relaxed">{{ t('support.guide.appealDescription') }}</p>
            </div>
          </div>
        </div>

        <router-link
          to="/terms"
          class="mt-4 inline-flex min-h-11 items-center gap-1.5 rounded-lg px-3 py-2 text-sm font-medium text-dp-accent transition-colors hover:bg-dp-bg-hover"
        >
          <FileText class="h-4 w-4" />
          {{ t('support.guide.termsLink') }}
        </router-link>
      </section>

      <section class="card card-body">
        <div v-if="isSubmitted" class="py-6 text-center">
          <CircleCheck class="mx-auto h-10 w-10 text-dp-success" />
          <h2 class="mt-3 text-lg font-semibold text-dp-text-primary">{{ t('support.success.title') }}</h2>
          <p class="mt-2 text-sm leading-relaxed text-dp-text-secondary">{{ successDescription }}</p>
          <button
            type="button"
            class="mt-4 inline-flex min-h-11 items-center rounded-lg border border-dp-border-primary px-4 py-2 text-sm font-medium text-dp-text-secondary transition-colors hover:bg-dp-bg-hover"
            @click="startAnotherInquiry"
          >
            {{ t('support.success.another') }}
          </button>
        </div>

        <form v-else class="space-y-4" @submit.prevent="handleSubmit">
          <div>
            <h2 class="text-lg font-semibold text-dp-text-primary">{{ t('support.form.title') }}</h2>
            <p class="mt-1 text-sm leading-relaxed text-dp-text-muted">{{ formDescription }}</p>
          </div>

          <div>
            <label for="support-email" class="form-label">
              {{ t('support.form.emailLabel') }} <span class="text-dp-danger">*</span>
            </label>
            <input
              id="support-email"
              v-model="email"
              type="email"
              required
              maxlength="255"
              autocomplete="email"
              class="form-control"
              :placeholder="t('support.form.emailPlaceholder')"
            />
          </div>

          <div>
            <label for="support-subject" class="form-label">
              {{ t('support.form.subjectLabel') }}
              <CharacterCounter :current="subject.length" :max="SUBJECT_MAX_LENGTH" />
            </label>
            <input
              id="support-subject"
              v-model="subject"
              type="text"
              :maxlength="SUBJECT_MAX_LENGTH"
              class="form-control"
              :placeholder="t('support.form.subjectPlaceholder')"
            />
          </div>

          <div>
            <label for="support-content" class="form-label">
              {{ t('support.form.contentLabel') }} <span class="text-dp-danger">*</span>
              <CharacterCounter :current="content.length" :max="CONTENT_MAX_LENGTH" />
            </label>
            <textarea
              id="support-content"
              v-model="content"
              rows="7"
              required
              :maxlength="CONTENT_MAX_LENGTH"
              class="form-control"
              :placeholder="t('support.form.contentPlaceholder')"
            ></textarea>
          </div>

          <p
            v-if="error"
            role="alert"
            class="rounded-xl border border-dp-danger-border bg-dp-danger-soft p-3 text-sm text-dp-danger"
          >
            {{ error }}
          </p>

          <button
            type="submit"
            :disabled="!canSubmit"
            class="inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-xl bg-dp-surface-strong px-4 py-3 font-semibold text-dp-text-on-dark transition-colors hover:bg-dp-surface-strong-hover disabled:cursor-not-allowed disabled:opacity-50"
          >
            <Send class="h-4 w-4" />
            {{ isSubmitting ? t('support.form.submitting') : t('support.form.submit') }}
          </button>

          <p v-if="!isSignedIn" class="text-sm leading-relaxed text-dp-text-muted">{{ t('support.form.guestHint') }}</p>
        </form>
      </section>
    </template>
  </div>
</template>
