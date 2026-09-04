import { describe, expect, it } from 'vitest'
import fileUploader from './FileUploader.vue?raw'

describe('FileUploader interaction contract', () => {
  it('handles clipboard and drop input through the common Uppy path', () => {
    expect(fileUploader).toContain('extractClipboardImageFiles')
    expect(fileUploader).toContain('extractDroppedFiles')
    expect(fileUploader).toContain('hasDroppedFiles')
    expect(fileUploader).toContain('function addFilesToUppy(files: File[])')
    expect(fileUploader).toContain('event.preventDefault()')
    expect(fileUploader).toContain('function handleDialogPaste(event: ClipboardEvent)')
    expect(fileUploader).toContain('if (files.length === 0) return')
  })

  it('binds and removes listeners on the nearest modal dialog', () => {
    expect(fileUploader).toContain("closest<HTMLElement>('[role=\"dialog\"]')")
    expect(fileUploader).toContain("dialogElement.addEventListener('dragover'")
    expect(fileUploader).toContain("dialogElement.addEventListener('drop'")
    expect(fileUploader).toContain("dialogElement.addEventListener('paste'")
    expect(fileUploader).toContain("window.addEventListener('dragend'")
    expect(fileUploader).toContain("window.addEventListener('drop'")
    expect(fileUploader).toContain("dialogElement.removeEventListener('dragover'")
    expect(fileUploader).toContain("dialogElement.removeEventListener('drop'")
    expect(fileUploader).toContain("dialogElement.removeEventListener('paste'")
    expect(fileUploader).toContain("window.removeEventListener('dragend'")
    expect(fileUploader).toContain("window.removeEventListener('drop'")
    expect(fileUploader).toContain('detachDialogListeners()')
  })

  it('scrolls to newly added files and highlights completed uploads', () => {
    expect(fileUploader).toContain('nextTick')
    expect(fileUploader).toContain("block: 'nearest'")
    expect(fileUploader).toContain("behavior: prefersReducedMotion() ? 'auto' : 'smooth'")
    expect(fileUploader).toContain('highlightAttachment(normalized.id)')
    expect(fileUploader).toContain('highlightTimers')
    expect(fileUploader).toContain('attachment-item--highlighted')
    expect(fileUploader).toContain('@media (prefers-reduced-motion: reduce)')
  })

  it('shows a modal-wide drop affordance while dragging files', () => {
    expect(fileUploader).toContain('const dialogTarget = shallowRef<HTMLElement | null>(null)')
    expect(fileUploader).toContain("dialogElement.classList.add('file-uploader-dialog')")
    expect(fileUploader).toContain("dialogElement.classList.remove('file-uploader-dialog')")
    expect(fileUploader).toContain('<Teleport v-if="isDragging && dialogTarget" :to="dialogTarget">')
    expect(fileUploader).toContain('class="file-uploader-drop-overlay"')
    expect(fileUploader).toContain('pointer-events: none')
    expect(fileUploader).toContain("t('fileUploader.dropOverlay')")
  })
})
