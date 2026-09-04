import { describe, expect, it, vi } from 'vitest'
import {
  extractClipboardImageFiles,
  extractDroppedFiles,
  hasDroppedFiles,
} from './fileUploaderInput'

function makeItem(
  kind: DataTransferItem['kind'],
  type: string,
  file: File | null,
) {
  return {
    kind,
    type,
    getAsFile: vi.fn(() => file),
  } as unknown as DataTransferItem
}

function makeDataTransfer({
  files = [],
  items = [],
  types = [],
}: {
  files?: File[]
  items?: DataTransferItem[]
  types?: string[]
} = {}) {
  return { files, items, types } as unknown as DataTransfer
}

describe('extractClipboardImageFiles', () => {
  it('extracts image files while leaving text clipboard items alone', () => {
    const image = new File(['image'], 'screenshot.png', { type: 'image/png' })
    const textItem = makeItem('string', 'text/plain', null)
    const imageItem = makeItem('file', 'image/png', image)

    const files = extractClipboardImageFiles(
      makeDataTransfer({ items: [textItem, imageItem] }),
    )

    expect(files).toEqual([image])
    expect(textItem.getAsFile).not.toHaveBeenCalled()
    expect(imageItem.getAsFile).toHaveBeenCalledOnce()
  })

  it('does not treat non-image files as clipboard attachments', () => {
    const document = new File(['text'], 'notes.txt', { type: 'text/plain' })
    const item = makeItem('file', 'text/plain', document)

    expect(extractClipboardImageFiles(makeDataTransfer({ items: [item] }))).toEqual([])
    expect(item.getAsFile).not.toHaveBeenCalled()
  })

  it('falls back to clipboard files and gives unnamed images a visible filename', () => {
    const unnamedImage = new File(['image'], '', { type: 'image/jpeg' })
    const text = new File(['text'], 'notes.txt', { type: 'text/plain' })

    const files = extractClipboardImageFiles(
      makeDataTransfer({ files: [unnamedImage, text] }),
    )

    expect(files).toHaveLength(1)
    expect(files[0]?.name).toMatch(/^pasted-image-\d+-1\.jpg$/)
    expect(files[0]?.type).toBe('image/jpeg')
  })
})

describe('extractDroppedFiles', () => {
  it('uses dataTransfer.files when the browser exposes files directly', () => {
    const image = new File(['image'], 'image.png', { type: 'image/png' })
    const item = makeItem('file', 'image/png', image)

    expect(extractDroppedFiles(makeDataTransfer({ files: [image], items: [item] }))).toEqual([image])
    expect(item.getAsFile).not.toHaveBeenCalled()
  })

  it('falls back to file data-transfer items when files is empty', () => {
    const image = new File(['image'], 'image.png', { type: 'image/png' })
    const document = new File(['document'], 'document.pdf', { type: 'application/pdf' })
    const imageItem = makeItem('file', 'image/png', image)
    const textItem = makeItem('string', 'text/uri-list', null)
    const documentItem = makeItem('file', 'application/pdf', document)
    const emptyFileItem = makeItem('file', 'image/jpeg', null)

    expect(
      extractDroppedFiles(
        makeDataTransfer({ items: [imageItem, textItem, documentItem, emptyFileItem] }),
      ),
    ).toEqual([image, document])
    expect(imageItem.getAsFile).toHaveBeenCalledOnce()
    expect(documentItem.getAsFile).toHaveBeenCalledOnce()
    expect(emptyFileItem.getAsFile).toHaveBeenCalledOnce()
    expect(textItem.getAsFile).not.toHaveBeenCalled()
  })
})

describe('hasDroppedFiles', () => {
  it('recognises direct files, file items, and the browser Files marker', () => {
    const image = new File(['image'], 'image.png', { type: 'image/png' })

    expect(hasDroppedFiles(makeDataTransfer({ files: [image] }))).toBe(true)
    expect(hasDroppedFiles(makeDataTransfer({ items: [makeItem('file', 'image/png', image)] }))).toBe(true)
    expect(hasDroppedFiles(makeDataTransfer({ types: ['Files'] }))).toBe(true)
  })

  it('leaves text and link dragging to the form control', () => {
    expect(
      hasDroppedFiles(makeDataTransfer({
        items: [makeItem('string', 'text/uri-list', null)],
        types: ['text/uri-list'],
      })),
    ).toBe(false)
  })
})
