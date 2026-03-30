import { attachmentValidation } from '@/api/attachment'
import { resolveApiCodeMessage } from '@/utils/resolveApiError'

type FileUploaderTranslate = (key: string, params?: Record<string, unknown>) => string

type FileUploaderErrorBody = {
  code?: unknown
  errorCode?: unknown
  details?: unknown
  errorDetails?: unknown
}

type FileUploaderErrorResponse = {
  status?: number
  body?: FileUploaderErrorBody
}

export function resolveFileUploaderErrorMessage(
  fileName: string | undefined,
  response: FileUploaderErrorResponse | null | undefined,
  t: FileUploaderTranslate,
): string {
  if (response?.status === 413) {
    return attachmentValidation.tooLargeMessage(fileName)
  }

  if (response?.status === 400 && response.body?.code === 'attachment.extension.blocked') {
    return attachmentValidation.blockedExtensionMessage(fileName)
  }

  return resolveApiCodeMessage(
    response?.body,
    { fallbackKey: 'fileUploader.uploadFailed' },
    t,
  )
}
