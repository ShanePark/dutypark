import { beforeEach, describe, expect, it, vi } from 'vitest'
import { resolveFileUploaderErrorMessage } from './fileUploaderError'

const mocks = vi.hoisted(() => ({
  tooLargeMessage: vi.fn(),
  blockedExtensionMessage: vi.fn(),
  resolveApiCodeMessage: vi.fn(),
}))

vi.mock('@/api/attachment', () => ({
  attachmentValidation: {
    tooLargeMessage: mocks.tooLargeMessage,
    blockedExtensionMessage: mocks.blockedExtensionMessage,
  },
}))

vi.mock('@/utils/resolveApiError', () => ({
  resolveApiCodeMessage: mocks.resolveApiCodeMessage,
}))

describe('resolveFileUploaderErrorMessage', () => {
  const t = vi.fn((key: string) => key)

  beforeEach(() => {
    mocks.tooLargeMessage.mockReset()
    mocks.blockedExtensionMessage.mockReset()
    mocks.resolveApiCodeMessage.mockReset()
    t.mockClear()
  })

  it('returns too-large copy for HTTP 413 responses', () => {
    mocks.tooLargeMessage.mockReturnValue('report.xlsx exceeds 50MB')

    const message = resolveFileUploaderErrorMessage('report.xlsx', { status: 413 }, t)

    expect(message).toBe('report.xlsx exceeds 50MB')
    expect(mocks.tooLargeMessage).toHaveBeenCalledWith('report.xlsx')
    expect(mocks.blockedExtensionMessage).not.toHaveBeenCalled()
    expect(mocks.resolveApiCodeMessage).not.toHaveBeenCalled()
  })

  it('returns blocked-extension copy for blocked extension responses', () => {
    mocks.blockedExtensionMessage.mockReturnValue('report.exe is blocked')

    const message = resolveFileUploaderErrorMessage('report.exe', {
      status: 400,
      body: {
        code: 'attachment.extension.blocked',
      },
    }, t)

    expect(message).toBe('report.exe is blocked')
    expect(mocks.blockedExtensionMessage).toHaveBeenCalledWith('report.exe')
    expect(mocks.tooLargeMessage).not.toHaveBeenCalled()
    expect(mocks.resolveApiCodeMessage).not.toHaveBeenCalled()
  })

  it('falls back to API code resolution for other structured errors', () => {
    mocks.resolveApiCodeMessage.mockReturnValue('Upload failed from code')

    const response = {
      status: 400,
      body: {
        errorCode: 'attachment.upload.failed',
        errorDetails: {
          filename: 'report.txt',
        },
      },
    }

    const message = resolveFileUploaderErrorMessage('report.txt', response, t)

    expect(message).toBe('Upload failed from code')
    expect(mocks.resolveApiCodeMessage).toHaveBeenCalledWith(
      response.body,
      { fallbackKey: 'fileUploader.uploadFailed' },
      t,
    )
  })

  it('uses the generic fallback when no response body is available', () => {
    mocks.resolveApiCodeMessage.mockReturnValue('fileUploader.uploadFailed')

    const message = resolveFileUploaderErrorMessage('report.txt', undefined, t)

    expect(message).toBe('fileUploader.uploadFailed')
    expect(mocks.resolveApiCodeMessage).toHaveBeenCalledWith(
      undefined,
      { fallbackKey: 'fileUploader.uploadFailed' },
      t,
    )
  })
})
