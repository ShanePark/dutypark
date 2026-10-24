import { describe, expect, it } from 'vitest'
import saveShortcutHint from '@/components/common/SaveShortcutHint.vue?raw'
import dayDetailModal from './DayDetailModal.vue?raw'
import todoAddModal from './TodoAddModal.vue?raw'
import todoDetailModal from './TodoDetailModal.vue?raw'

const saveForms = [
  { name: 'schedule create/edit (DayDetailModal)', source: dayDetailModal, handler: 'saveSchedule' },
  { name: 'todo create (TodoAddModal)', source: todoAddModal, handler: 'handleSave' },
  { name: 'todo edit (TodoDetailModal)', source: todoDetailModal, handler: 'saveEdit' },
]

describe('Ctrl/Cmd+Enter save shortcut', () => {
  it.each(saveForms)('routes the shortcut through the save button of the $name form', ({ source, handler }) => {
    expect(source).toContain("import { useSaveShortcut } from '@/composables/useSaveShortcut'")
    expect(source).toContain('const saveButtonRef = ref<HTMLButtonElement | null>(null)')
    expect(source).toContain('useSaveShortcut(saveButtonRef)')

    const saveButton = source.match(new RegExp(`<button[^>]*?ref="saveButtonRef"[^>]*?>`))?.[0] ?? ''
    expect(saveButton).toContain(`@click="${handler}"`)
    expect(saveButton).toContain('aria-keyshortcuts="Control+Enter Meta+Enter"')
    expect(saveButton).toContain('whitespace-nowrap')
  })

  it.each(saveForms)('shows the shortcut hint inside the save button of the $name form', ({ source }) => {
    expect(source).toContain("import SaveShortcutHint from '@/components/common/SaveShortcutHint.vue'")
    expect(source).toMatch(/ref="saveButtonRef"[\s\S]*?<SaveShortcutHint \/>\s*<\/button>/)
  })
})

describe('SaveShortcutHint', () => {
  it('is hidden by default and only shown for a fine hovering pointer', () => {
    expect(saveShortcutHint).toMatch(/\.save-shortcut-hint \{\s*display: none;/)
    expect(saveShortcutHint).toMatch(
      /@media \(hover: hover\) and \(pointer: fine\) \{\s*\.save-shortcut-hint \{[\s\S]*?display: inline-flex;/,
    )
  })

  it('is decorative so screen readers rely on aria-keyshortcuts instead', () => {
    expect(saveShortcutHint).toContain('aria-hidden="true"')
    expect(saveShortcutHint).toContain('<kbd')
  })

  it('takes its colour from the button so it works on any theme', () => {
    expect(saveShortcutHint).toContain('currentColor')
    expect(saveShortcutHint).toContain('white-space: nowrap')
  })
})
