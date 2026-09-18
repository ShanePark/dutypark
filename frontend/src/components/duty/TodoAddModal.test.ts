import { describe, expect, it } from 'vitest'
import todoAddModal from './TodoAddModal.vue?raw'

describe('TodoAddModal two-column layout', () => {
  it('uses a wide desktop modal with a main and options column', () => {
    expect(todoAddModal).toContain('size="3xl"')
    expect(todoAddModal).toContain('todo-add-modal-columns')
    expect(todoAddModal).toContain('todo-add-modal-main-column')
    expect(todoAddModal).toContain('todo-add-modal-side-column')
    expect(todoAddModal).toContain('grid-template-columns: minmax(0, 1.3fr) minmax(19rem, 0.9fr)')
    expect(todoAddModal).toContain('@media (min-width: 640px)')
    expect(todoAddModal).not.toContain('activeMetadata')
    expect(todoAddModal).toContain(':always-expanded="isDesktop"')
    expect(todoAddModal).toContain('appearance="flat"')
  })

  it('fills the shared desktop height and separates the columns without affecting mobile', () => {
    expect(todoAddModal).toMatch(/\.todo-add-modal-columns \{[\s\S]*?align-items: stretch;/)
    expect(todoAddModal).toMatch(/\.todo-add-modal-main-column,[\s\S]*?height: 100%;/)
    expect(todoAddModal).toMatch(/\.todo-add-modal-side-column \{[\s\S]*?height: 100%;/)
    expect(todoAddModal).toMatch(/\.todo-add-modal-content-field \{[\s\S]*?flex: 1;[\s\S]*?min-height: 0;/)
    expect(todoAddModal).toMatch(/\.todo-add-modal-content-input \{[\s\S]*?flex: 1;/)
    expect(todoAddModal).toContain('border-left: 1px solid var(--dp-border-primary)')
    expect(todoAddModal).toContain('padding-left: 1.25rem')
    expect(todoAddModal).toContain('padding-right: 1.25rem')
    expect(todoAddModal).toMatch(/@media \(max-width: 639px\) \{[\s\S]*?border-left: none;/)
  })

  it('keeps the main fields visible and places status between title and content', () => {
    const mainColumnIndex = todoAddModal.indexOf('todo-add-modal-main-column')
    const sideColumnIndex = todoAddModal.indexOf('todo-add-modal-side-column')
    const footerIndex = todoAddModal.indexOf('todo-add-modal-footer')

    expect(mainColumnIndex).toBeGreaterThan(-1)
    expect(sideColumnIndex).toBeGreaterThan(mainColumnIndex)
    expect(footerIndex).toBeGreaterThan(sideColumnIndex)
    expect(todoAddModal).toContain('id="todo-add-title"')
    expect(todoAddModal).toContain('id="todo-add-content"')
    expect(todoAddModal).toContain('rows="8"')
    expect(todoAddModal).toContain('todo-add-modal-status-grid')
    expect(todoAddModal).toContain('todo-add-modal-status-section')
    expect(todoAddModal).toContain('todo-add-modal-mobile-status')
    expect(todoAddModal).toContain('id="todo-add-mobile-status-trigger"')
    expect(todoAddModal).toContain('<DatePickerField')
    expect(todoAddModal).toContain('<FriendTagSelector')
    expect(todoAddModal).toContain('<FileUploader')

    const titleIndex = todoAddModal.indexOf('id="todo-add-title"')
    const statusIndex = todoAddModal.indexOf('todo-add-modal-status-section')
    const contentIndex = todoAddModal.indexOf('id="todo-add-content"')
    expect(titleIndex).toBeLessThan(statusIndex)
    expect(statusIndex).toBeLessThan(contentIndex)

    const sideColumn = todoAddModal.slice(sideColumnIndex, footerIndex)
    expect(sideColumn).not.toContain('status-card')
  })

  it('keeps desktop inline friend expansion inside a scrollable side column', () => {
    expect(todoAddModal).not.toContain('presentation="popover"')
    expect(todoAddModal).toMatch(/@media \(min-width: 640px\) \{[\s\S]*?\.todo-add-modal-body \{[\s\S]*?overflow: hidden;/)
    expect(todoAddModal).toMatch(/@media \(min-width: 640px\) \{[\s\S]*?\.todo-add-modal-columns \{[\s\S]*?flex: 1;[\s\S]*?min-height: 0;/)
    expect(todoAddModal).toMatch(/@media \(min-width: 640px\) \{[\s\S]*?\.todo-add-modal-side-column \{[\s\S]*?overflow-y: auto;[\s\S]*?scrollbar-width: thin;/)
    expect(todoAddModal).toContain('.todo-add-modal-side-column::-webkit-scrollbar')
  })

  it('keeps desktop geometry stable and constrains the inline selector to the side rail', () => {
    const desktopMedia = todoAddModal.slice(todoAddModal.indexOf('@media (min-width: 640px)'))

    expect(desktopMedia).toMatch(/\.todo-add-modal-body \{[\s\S]*?height: min\(32\.875rem, calc\(var\(--dp-viewport-height, 100dvh\) - 10rem\)\);[\s\S]*?flex: 1 1 auto;/)
    expect(todoAddModal).toMatch(/\.todo-add-modal-side-section > \.friend-tag-selector \{[\s\S]*?width: 100%;[\s\S]*?min-width: 0;[\s\S]*?max-width: 100%;/)
  })

  it('keeps the expanded options rail compact enough for ordinary desktop entry', () => {
    expect(todoAddModal).toMatch(/\.todo-add-modal-side-column \{[\s\S]*?gap: 0\.5rem;/)
    expect(todoAddModal).toMatch(/\.todo-add-modal-side-section \{[\s\S]*?gap: 0\.25rem;/)
    expect(todoAddModal).toContain('.todo-add-modal-side-section > .form-label')
    expect(todoAddModal).not.toContain(':deep(.friend-tag-selector)')
    expect(todoAddModal).not.toContain(':deep(.friend-tag-selector__selected)')
    expect(todoAddModal).toMatch(/:deep\(\.file-uploader\) \{[\s\S]*?gap: 0\.5rem;/)
    expect(todoAddModal).toMatch(/:deep\(\.drop-zone\) \{[\s\S]*?grid-template-columns: auto minmax\(0, 1fr\);[\s\S]*?padding: 0\.375rem 0\.5rem;/)
  })

  it('compresses the initial mobile layout while preserving touch-sized controls', () => {
    expect(todoAddModal).toMatch(/@media \(max-width: 639px\) \{[\s\S]*?\.todo-add-modal-body \{[\s\S]*?padding: 0\.625rem;/)
    expect(todoAddModal).toMatch(/@media \(max-width: 639px\) \{[\s\S]*?\.todo-add-modal-columns \{[\s\S]*?gap: 0\.625rem;/)
    expect(todoAddModal).toMatch(/@media \(max-width: 639px\) \{[\s\S]*?\.todo-add-modal-content-input \{[\s\S]*?min-height: 7rem;/)
    expect(todoAddModal).toMatch(/@media \(max-width: 639px\) \{[\s\S]*?\.status-card \{[\s\S]*?min-height: 2\.75rem;/)
  })

  it('places the compact mobile status override after the base rule so it wins the cascade', () => {
    const baseStatusRuleIndex = todoAddModal.indexOf('.status-card {\n  display: flex')
    const compactMediaIndex = todoAddModal.lastIndexOf('@media (max-width: 639px) {')
    const compactMedia = todoAddModal.slice(compactMediaIndex)

    expect(baseStatusRuleIndex).toBeGreaterThan(-1)
    expect(compactMediaIndex).toBeGreaterThan(baseStatusRuleIndex)
    expect(compactMedia).toMatch(/\.status-card \{[\s\S]*?min-height: 2\.75rem;[\s\S]*?gap: 0\.25rem;[\s\S]*?padding: 0\.5rem 0\.25rem;/)
  })

  it('fixes the initial mobile textarea block size instead of letting rows expand the modal', () => {
    const compactMediaIndex = todoAddModal.lastIndexOf('@media (max-width: 639px) {')
    const compactMedia = todoAddModal.slice(compactMediaIndex)

    expect(compactMedia).toMatch(/\.todo-add-modal-content-input \{[\s\S]*?height: 7rem;[\s\S]*?block-size: 7rem;[\s\S]*?flex: none;/)
  })

  it('keeps the mobile shell height stable while allowing the body to scroll after expansion', () => {
    const mobileBodyRule = todoAddModal.match(/@media \(max-width: 639px\) \{\n  \.todo-add-modal-body \{[\s\S]*?\n  \}/)?.[0] ?? ''

    expect(mobileBodyRule).toMatch(/height: min\(35rem, calc\(var\(--dp-viewport-height, 100dvh\) - 9\.5rem\)\);/)
    expect(mobileBodyRule).toContain('flex: 1 1 auto;')
    expect(mobileBodyRule).toContain('overflow-y: auto;')
  })

  it('keeps status and modal actions keyboard-accessible', () => {
    expect(todoAddModal).toContain('aria-labelledby="todo-add-modal-title"')
    expect(todoAddModal).toContain('id="todo-add-modal-title"')
    expect(todoAddModal).toContain(':aria-label="t(\'common.actions.close\')"')
    expect(todoAddModal).toContain(':title="t(\'common.actions.close\')"')
    expect(todoAddModal).toContain(':aria-pressed="status === option.value"')
    expect(todoAddModal).toContain('class="todo-add-modal-footer modal-actions-compact')
  })

  it('uses an anchored custom status menu on mobile instead of the native select popup', () => {
    expect(todoAddModal).not.toContain('<select id="todo-add-mobile-status"')
    expect(todoAddModal).toContain('todo-add-modal-status-picker')
    expect(todoAddModal).toContain('aria-haspopup="listbox"')
    expect(todoAddModal).toContain(':aria-expanded="isStatusMenuOpen"')
    expect(todoAddModal).toContain('role="listbox"')
    expect(todoAddModal).toContain('role="option"')
    expect(todoAddModal).toContain('@keydown.esc.stop.prevent="closeStatusMenu({ restoreFocus: true })"')
    expect(todoAddModal).toContain('@click.stop="selectStatus(option.value)"')
    expect(todoAddModal).toContain('useEscapeKey(isStatusMenuOpen')
    expect(todoAddModal).toContain('status-option--todo')
    expect(todoAddModal).toContain('status-option--in-progress')
    expect(todoAddModal).toContain('status-option--done')
  })

  it('keeps the existing save and upload guards intact', () => {
    expect(todoAddModal).toContain('if (isUploading.value)')
    expect(todoAddModal).toContain("showWarning(t('duty.todo.warnings.uploadInProgress'))")
    expect(todoAddModal).toContain(':disabled="isTitleMissing || isUploading"')
    expect(todoAddModal).toContain('orderedAttachmentIds')
  })
})
