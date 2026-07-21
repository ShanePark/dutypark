<script setup lang="ts">
import { ref, computed, onUnmounted } from 'vue'
import { Copy, Check } from 'lucide-vue-next'
import { useI18n } from 'vue-i18n'
import { useSwal } from '@/composables/useSwal'

const props = defineProps<{
  text: string
  label?: string
}>()

const { t } = useI18n()
const { toastError } = useSwal()

const copied = ref(false)
let revertTimer: ReturnType<typeof setTimeout> | null = null

const buttonLabel = computed(() =>
  copied.value ? t('common.actions.copied') : (props.label ?? t('common.actions.copy'))
)

// Fallback for non-secure contexts where navigator.clipboard is unavailable/rejected.
function copyViaTextarea(value: string): boolean {
  const textarea = document.createElement('textarea')
  textarea.value = value
  textarea.setAttribute('readonly', '')
  textarea.style.position = 'fixed'
  textarea.style.top = '-9999px'
  textarea.style.left = '-9999px'
  document.body.appendChild(textarea)
  textarea.select()
  let success = false
  try {
    success = document.execCommand('copy')
  } catch {
    success = false
  }
  document.body.removeChild(textarea)
  return success
}

function markCopied() {
  copied.value = true
  if (revertTimer) clearTimeout(revertTimer)
  revertTimer = setTimeout(() => {
    copied.value = false
    revertTimer = null
  }, 2000)
}

async function handleCopy() {
  if (revertTimer) clearTimeout(revertTimer)

  if (navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(props.text)
      markCopied()
      return
    } catch {
      // Fall through to the textarea fallback.
    }
  }

  if (copyViaTextarea(props.text)) {
    markCopied()
  } else {
    toastError(t('common.messages.copyFailed'))
  }
}

onUnmounted(() => {
  if (revertTimer) clearTimeout(revertTimer)
})
</script>

<template>
  <button
    type="button"
    class="copy-text-btn p-1.5 rounded-lg hover-icon-btn cursor-pointer"
    :class="copied ? 'text-dp-success' : 'text-dp-text-muted'"
    :title="buttonLabel"
    :aria-label="buttonLabel"
    @click.stop="handleCopy"
  >
    <Check v-if="copied" class="w-4 h-4" />
    <Copy v-else class="w-4 h-4" />
  </button>
</template>

<style scoped>
.copy-text-btn {
  position: relative;
}

/* Keep the button visually compact but expand the touch target to >=44px. */
.copy-text-btn::after {
  content: '';
  position: absolute;
  inset: -8px;
}
</style>
