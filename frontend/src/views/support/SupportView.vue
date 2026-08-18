<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { AxiosError } from 'axios'
import { CircleCheck, Clock, FileText, Flag, LifeBuoy, Send, UserX } from 'lucide-vue-next'
import PageHeader from '@/components/common/PageHeader.vue'
import CharacterCounter from '@/components/common/CharacterCounter.vue'
import { inquiryApi } from '@/api/inquiry'
import { useAuthStore } from '@/stores/auth'

const SUBJECT_MAX_LENGTH = 100
const CONTENT_MAX_LENGTH = 2000
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

const { t } = useI18n()
const authStore = useAuthStore()

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
        <p class="mt-2 text-sm leading-relaxed text-dp-text-secondary">{{ t('support.success.description') }}</p>
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
          <p class="mt-1 text-sm leading-relaxed text-dp-text-muted">{{ t('support.form.description') }}</p>
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
      </form>
    </section>
  </div>
</template>
