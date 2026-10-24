import { onMounted, onUnmounted, type Ref } from 'vue'

export type SaveShortcutEvent = Pick<
  KeyboardEvent,
  | 'key'
  | 'ctrlKey'
  | 'metaKey'
  | 'altKey'
  | 'shiftKey'
  | 'isComposing'
  | 'keyCode'
  | 'repeat'
  | 'defaultPrevented'
  | 'target'
  | 'preventDefault'
>

type PlatformNavigator = {
  platform?: string
  userAgent?: string
  userAgentData?: { platform?: string }
}

/** Ctrl+Enter or Cmd+Enter, never while an IME (Korean) composition is still open. */
export function isSaveShortcut(event: SaveShortcutEvent): boolean {
  if (event.key !== 'Enter' || event.repeat) return false
  if (event.isComposing || event.keyCode === 229) return false
  if (event.altKey || event.shiftKey) return false
  return event.ctrlKey || event.metaKey
}

/**
 * Presses the save button itself, so the shortcut shares the click's handler and the button's
 * disabled guard instead of duplicating either. Only keys typed inside the button's own dialog
 * count, which keeps an open confirm dialog or another modal from submitting this form.
 */
export function handleSaveShortcut(event: SaveShortcutEvent, button: HTMLButtonElement | null): boolean {
  if (!button || event.defaultPrevented || !isSaveShortcut(event)) return false
  const scope = button.closest('[role="dialog"]')
  if (!scope?.contains(event.target as Node | null)) return false

  event.preventDefault()
  if (!button.disabled) button.click()
  return true
}

export function isApplePlatform(
  nav: PlatformNavigator | undefined = typeof navigator === 'undefined' ? undefined : navigator,
): boolean {
  const platform = nav?.userAgentData?.platform || nav?.platform || nav?.userAgent || ''
  return /mac|iphone|ipad|ipod/i.test(platform)
}

export function saveShortcutModifierLabel(apple: boolean): string {
  return apple ? '⌘' : 'Ctrl'
}

export function useSaveShortcut(saveButtonRef: Ref<HTMLButtonElement | null>) {
  function onKeydown(event: KeyboardEvent) {
    handleSaveShortcut(event, saveButtonRef.value)
  }

  onMounted(() => document.addEventListener('keydown', onKeydown))
  onUnmounted(() => document.removeEventListener('keydown', onKeydown))
}
