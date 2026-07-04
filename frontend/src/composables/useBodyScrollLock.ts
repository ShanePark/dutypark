import { watch, onUnmounted, type Ref } from 'vue'

const bodyScrollLockTokens = new Set<symbol>()
let originalBodyOverflow = ''

function lockBodyScroll(token: symbol) {
  if (bodyScrollLockTokens.size === 0) {
    originalBodyOverflow = document.body.style.overflow
  }

  bodyScrollLockTokens.add(token)
  document.body.style.overflow = 'hidden'
}

function unlockBodyScroll(token: symbol) {
  bodyScrollLockTokens.delete(token)

  if (bodyScrollLockTokens.size === 0) {
    document.body.style.overflow = originalBodyOverflow
    return
  }

  document.body.style.overflow = 'hidden'
}

export function useBodyScrollLock(isOpen: Ref<boolean> | (() => boolean)) {
  const token = Symbol('body-scroll-lock')

  watch(
    typeof isOpen === 'function' ? isOpen : () => isOpen.value,
    (open) => {
      if (open) {
        lockBodyScroll(token)
      } else {
        unlockBodyScroll(token)
      }
    },
    { immediate: true }
  )

  onUnmounted(() => {
    unlockBodyScroll(token)
  })
}
