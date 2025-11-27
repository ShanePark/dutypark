import { watch, onUnmounted, type Ref } from 'vue'

export function useBodyScrollLock(isOpen: Ref<boolean> | (() => boolean)) {
  const lockScroll = () => {
    document.body.style.overflow = 'hidden'
  }

  const unlockScroll = () => {
    document.body.style.overflow = ''
  }

  watch(
    typeof isOpen === 'function' ? isOpen : () => isOpen.value,
    (open) => {
      if (open) {
        lockScroll()
      } else {
        unlockScroll()
      }
    },
    { immediate: true }
  )

  onUnmounted(() => {
    unlockScroll()
  })
}
