import { AxiosError } from 'axios'
import { describe, expect, it } from 'vitest'
import { getApiErrorDetail, resolveApiCodeMessage, resolveApiErrorMessage } from './resolveApiError'

const translations: Record<string, string> = {
  'apiErrors.auth.login.failed': '로그인에 실패했습니다.',
  'apiErrors.dutyBatch.template.required': '먼저 일괄 업로드 템플릿을 선택해주세요.',
  'apiErrors.dutyBatch.notSupportedFile': '지원 형식: {supportedFile}',
  'apiErrors.dutyBatch.yearMonthNotMatch': '업로드한 파일의 연월이 {year}년 {month}월과 일치하지 않습니다.',
  'common.swal.error': '오류',
  'fallback.key': '기본 오류 메시지',
}

function t(key: string, params?: Record<string, unknown>): string {
  const template = translations[key] ?? key
  return Object.entries(params ?? {}).reduce((message, [paramKey, value]) => {
    return message.split(`{${paramKey}}`).join(String(value))
  }, template)
}

describe('resolveApiError', () => {
  it('prefers translatable code values from api error payloads', () => {
    const message = resolveApiErrorMessage(
      {
        status: 401,
        code: 'auth.login.failed',
      },
      {},
      t,
    )

    expect(message).toBe('로그인에 실패했습니다.')
  })

  it('falls back to the provided fallback key when code translation is unavailable', () => {
    const message = resolveApiCodeMessage(
      {
        code: 'unknown.code',
      },
      { fallbackKey: 'fallback.key' },
      t,
    )

    expect(message).toBe('기본 오류 메시지')
  })

  it('reads nested details values from api error responses', () => {
    const detail = getApiErrorDetail<number>(
      {
        status: 401,
        code: 'auth.login.failed',
        details: {
          remainingAttempts: 2,
        },
      },
      'remainingAttempts',
    )

    expect(detail).toBe(2)
  })

  it('uses errorDetails when resolving batch result error messages', () => {
    const message = resolveApiCodeMessage(
      {
        errorCode: 'dutyBatch.notSupportedFile',
        errorDetails: {
          supportedFile: '.xls, .xlsx',
        },
      },
      {},
      t,
    )

    expect(message).toBe('지원 형식: .xls, .xlsx')
  })

  it('translates camelCase codes from AxiosError responses', () => {
    const message = resolveApiErrorMessage(
      new AxiosError(
        'Bad Request',
        'ERR_BAD_REQUEST',
        undefined,
        undefined,
        {
          data: {
            status: 400,
            code: 'dutyBatch.template.required',
          },
        } as never,
      ),
      {},
      t,
    )

    expect(message).toBe('먼저 일괄 업로드 템플릿을 선택해주세요.')
  })

  it('injects details into translated api error messages', () => {
    const message = resolveApiCodeMessage(
      {
        code: 'dutyBatch.yearMonthNotMatch',
        details: {
          year: 2026,
          month: 3,
        },
      },
      {},
      t,
    )

    expect(message).toBe('업로드한 파일의 연월이 2026년 3월과 일치하지 않습니다.')
  })

  it('falls back when code is present but does not match the supported pattern', () => {
    const message = resolveApiCodeMessage(
      {
        code: 'BAD_REQUEST',
      },
      { fallbackKey: 'fallback.key' },
      t,
    )

    expect(message).toBe('기본 오류 메시지')
  })
})
