import { describe, expect, it, vi } from 'vitest'
import {
  handleSaveShortcut,
  isApplePlatform,
  isSaveShortcut,
  saveShortcutModifierLabel,
  type SaveShortcutEvent,
} from './useSaveShortcut'

function keyEvent(overrides: Partial<SaveShortcutEvent> = {}): SaveShortcutEvent {
  return {
    key: 'Enter',
    ctrlKey: true,
    metaKey: false,
    altKey: false,
    shiftKey: false,
    isComposing: false,
    keyCode: 13,
    repeat: false,
    defaultPrevented: false,
    target: null,
    preventDefault: vi.fn(),
    ...overrides,
  }
}

function fakeButton({ disabled = false, inside = true } = {}) {
  const scope = { contains: vi.fn(() => inside) }
  const button = {
    disabled,
    click: vi.fn(),
    closest: vi.fn(() => scope),
  }
  return { button: button as unknown as HTMLButtonElement, scope }
}

describe('isSaveShortcut', () => {
  it('accepts Ctrl+Enter and Cmd+Enter', () => {
    expect(isSaveShortcut(keyEvent({ ctrlKey: true }))).toBe(true)
    expect(isSaveShortcut(keyEvent({ ctrlKey: false, metaKey: true }))).toBe(true)
  })

  it('leaves plain Enter and other modifier combinations alone', () => {
    expect(isSaveShortcut(keyEvent({ ctrlKey: false }))).toBe(false)
    expect(isSaveShortcut(keyEvent({ shiftKey: true }))).toBe(false)
    expect(isSaveShortcut(keyEvent({ altKey: true }))).toBe(false)
    expect(isSaveShortcut(keyEvent({ key: 's' }))).toBe(false)
  })

  it('ignores keys pressed while an IME composition is in progress', () => {
    expect(isSaveShortcut(keyEvent({ isComposing: true }))).toBe(false)
    expect(isSaveShortcut(keyEvent({ keyCode: 229 }))).toBe(false)
  })

  it('ignores auto-repeated keydowns so holding the keys cannot submit twice', () => {
    expect(isSaveShortcut(keyEvent({ repeat: true }))).toBe(false)
  })
})

describe('handleSaveShortcut', () => {
  it('clicks the save button when the shortcut is pressed inside its dialog', () => {
    const { button, scope } = fakeButton()
    const target = {} as EventTarget
    const event = keyEvent({ target })

    expect(handleSaveShortcut(event, button)).toBe(true)
    expect(button.closest).toHaveBeenCalledWith('[role="dialog"]')
    expect(scope.contains).toHaveBeenCalledWith(target)
    expect(event.preventDefault).toHaveBeenCalledOnce()
    expect(button.click).toHaveBeenCalledOnce()
  })

  it('does nothing while the save button is disabled', () => {
    const { button } = fakeButton({ disabled: true })
    const event = keyEvent()

    handleSaveShortcut(event, button)
    expect(button.click).not.toHaveBeenCalled()
  })

  it('does nothing when no save button is rendered', () => {
    const event = keyEvent()

    expect(handleSaveShortcut(event, null)).toBe(false)
    expect(event.preventDefault).not.toHaveBeenCalled()
  })

  it('ignores the shortcut when focus is outside the save button dialog', () => {
    const { button } = fakeButton({ inside: false })
    const event = keyEvent()

    expect(handleSaveShortcut(event, button)).toBe(false)
    expect(event.preventDefault).not.toHaveBeenCalled()
    expect(button.click).not.toHaveBeenCalled()
  })

  it('ignores composition and already handled events', () => {
    const { button } = fakeButton()

    handleSaveShortcut(keyEvent({ isComposing: true }), button)
    handleSaveShortcut(keyEvent({ defaultPrevented: true }), button)
    handleSaveShortcut(keyEvent({ ctrlKey: false }), button)
    expect(button.click).not.toHaveBeenCalled()
  })
})

describe('platform label', () => {
  it('detects Apple platforms from userAgentData, platform, or user agent', () => {
    expect(isApplePlatform({ userAgentData: { platform: 'macOS' }, platform: '', userAgent: '' })).toBe(true)
    expect(isApplePlatform({ platform: 'MacIntel', userAgent: '' })).toBe(true)
    expect(isApplePlatform({ platform: '', userAgent: 'Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X)' })).toBe(true)
    expect(isApplePlatform({ userAgentData: { platform: 'Windows' }, platform: 'Win32', userAgent: '' })).toBe(false)
    expect(isApplePlatform({ platform: 'Linux x86_64', userAgent: 'X11; Linux x86_64' })).toBe(false)
    expect(isApplePlatform({})).toBe(false)
  })

  it('names the platform modifier', () => {
    expect(saveShortcutModifierLabel(true)).toBe('⌘')
    expect(saveShortcutModifierLabel(false)).toBe('Ctrl')
  })
})
