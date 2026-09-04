/**
 * Read image files exposed by the clipboard without touching text clipboard items.
 *
 * A clipboard can contain both text and a rendered image (for example, a screenshot copied
 * from an editor). Only the image item belongs to the attachment uploader; leaving string items
 * alone also lets normal text paste continue through the focused form control.
 */
export function extractClipboardImageFiles(
  dataTransfer: Pick<DataTransfer, 'files' | 'items'> | null | undefined,
): File[] {
  const itemFiles = Array.from(dataTransfer?.items ?? [])
    .filter((item) => item.kind === 'file' && item.type.toLowerCase().startsWith('image/'))
    .flatMap((item) => {
      try {
        const file = item.getAsFile()
        return file ? [file] : []
      } catch {
        return []
      }
    })

  const images = itemFiles.length > 0
    ? itemFiles
    : Array.from(dataTransfer?.files ?? []).filter((file) => file.type.startsWith('image/'))
  const timestamp = Date.now()

  return images.map((file, index) => ensureClipboardImageName(file, timestamp, index))
}

function ensureClipboardImageName(file: File, timestamp: number, index: number): File {
  if (file.name.trim()) return file

  const mimeSubtype = file.type.split('/')[1]?.split('+')[0]?.toLowerCase() ?? ''
  const extension = /^[a-z0-9]+$/.test(mimeSubtype)
    ? (mimeSubtype === 'jpeg' ? 'jpg' : mimeSubtype)
    : 'png'

  return new File([file], `pasted-image-${timestamp}-${index + 1}.${extension}`, {
    type: file.type,
    lastModified: file.lastModified,
  })
}

/**
 * Tell drag handlers whether taking ownership of the event is appropriate. This keeps ordinary
 * text and link dragging inside form controls working while still accepting browsers that expose
 * a file item before they populate `dataTransfer.files`.
 */
export function hasDroppedFiles(
  dataTransfer: Pick<DataTransfer, 'files' | 'items' | 'types'> | null | undefined,
): boolean {
  if (!dataTransfer) return false
  if (dataTransfer.files.length > 0) return true
  if (Array.from(dataTransfer.items).some((item) => item.kind === 'file')) return true
  return Array.from(dataTransfer.types).includes('Files')
}

/**
 * Read files from a drop. Some browsers expose a FileList directly, while an image dragged from
 * another browser window may only expose file DataTransferItems. Prefer the FileList so items are
 * not queried twice, then use getAsFile as the browser-compatible fallback.
 */
export function extractDroppedFiles(
  dataTransfer: Pick<DataTransfer, 'files' | 'items'> | null | undefined,
): File[] {
  const files = Array.from(dataTransfer?.files ?? [])
  if (files.length > 0) return files

  return Array.from(dataTransfer?.items ?? [])
    .filter((item) => item.kind === 'file')
    .flatMap((item) => {
      try {
        const file = item.getAsFile()
        return file ? [file] : []
      } catch {
        return []
      }
    })
}
