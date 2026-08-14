<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { parseAccountDeletionOAuthCallback } from '@/utils/accountDeletionFlow'

const { t } = useI18n()
const errorMessage = ref('')
const sent = ref(false)

function closeWindow() {
  window.close()
}

onMounted(() => {
  const opener = window.opener
  if (!opener || opener === window || opener.closed) {
    errorMessage.value = t('member.accountDeletion.oauth.callbackNoOpener')
    return
  }
  try {
    if (opener.location.origin !== window.location.origin) {
      errorMessage.value = t('member.accountDeletion.oauth.callbackNoOpener')
      return
    }
  } catch {
    errorMessage.value = t('member.accountDeletion.oauth.callbackNoOpener')
    return
  }

  const message = parseAccountDeletionOAuthCallback(window.location.search)
  if (!message) {
    errorMessage.value = t('member.accountDeletion.oauth.callbackInvalid')
    return
  }

  opener.postMessage(message, window.location.origin)
  sent.value = true
  window.close()
})
</script>

<template>
  <main class="flex min-h-screen items-center justify-center bg-dp-bg-secondary p-4">
    <section class="w-full max-w-md rounded-xl border border-dp-border-primary bg-dp-bg-card p-6 text-center shadow-sm">
      <h1 class="text-lg font-bold text-dp-text-primary">
        {{ t('member.accountDeletion.oauth.callbackTitle') }}
      </h1>
      <p v-if="errorMessage" class="mt-3 text-sm leading-6 text-dp-danger" role="alert">
        {{ errorMessage }}
      </p>
      <p v-else class="mt-3 text-sm leading-6 text-dp-text-secondary">
        {{ sent
          ? t('member.accountDeletion.oauth.callbackComplete')
          : t('member.accountDeletion.oauth.callbackWorking') }}
      </p>
      <button
        v-if="sent || errorMessage"
        type="button"
        class="mt-5 min-h-11 w-full rounded-lg bg-dp-bg-tertiary px-4 font-medium text-dp-text-primary transition hover:bg-dp-bg-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-dp-accent-ring"
        @click="closeWindow"
      >
        {{ t('common.actions.close') }}
      </button>
    </section>
  </main>
</template>
