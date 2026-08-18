import { AxiosError } from 'axios'
import { describe, expect, it } from 'vitest'
import { resolveLoginErrorMessage } from './loginError'

const translations: Record<string, string> = {
  'apiErrors.auth.login.failed': '이메일 또는 비밀번호가 올바르지 않습니다.',
  'apiErrors.auth.login.rateLimited': '로그인 시도 횟수를 초과했습니다. 잠시 후 다시 시도해 주세요.',
  'apiErrors.auth.account.suspended': '계정이 이용 정지되었습니다.',
  'auth.login.error.generic': '로그인에 실패했습니다.',
  'auth.login.error.network': '서버에 연결할 수 없습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.',
  'auth.login.error.server': '서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요. (오류 {status})',
  'auth.login.error.unknown': '로그인에 실패했습니다. 잠시 후 다시 시도해주세요. (오류 {status})',
  'auth.login.apple.generic': 'Apple 로그인에 실패했습니다.',
}

function t(key: string, params?: Record<string, unknown>): string {
  const template = translations[key] ?? key
  return Object.entries(params ?? {}).reduce((message, [paramKey, value]) => {
    return message.split(`{${paramKey}}`).join(String(value))
  }, template)
}

function axiosError(status: number, data: unknown): AxiosError {
  return new AxiosError(
    'Request failed',
    'ERR_BAD_RESPONSE',
    undefined,
    undefined,
    { status, data } as never,
  )
}

describe('resolveLoginErrorMessage', () => {
  it('reports a connection problem when the request never reached the server', () => {
    const message = resolveLoginErrorMessage(
      new AxiosError('Network Error', 'ERR_NETWORK'),
      t,
    )

    expect(message).toBe('서버에 연결할 수 없습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.')
  })

  it('reports a connection problem when the request times out', () => {
    const message = resolveLoginErrorMessage(
      new AxiosError('timeout of 30000ms exceeded', 'ECONNABORTED'),
      t,
    )

    expect(message).toBe('서버에 연결할 수 없습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요.')
  })

  it('reports a server outage with the status code for gateway errors', () => {
    const message = resolveLoginErrorMessage(
      axiosError(502, '<html><body>502 Bad Gateway</body></html>'),
      t,
    )

    expect(message).toBe('서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요. (오류 502)')
  })

  it('reports a server outage even when the payload carries an error code', () => {
    const message = resolveLoginErrorMessage(
      axiosError(500, { status: 500, code: 'common.internal.error' }),
      t,
    )

    expect(message).toBe('서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요. (오류 500)')
  })

  it('keeps the credential message for rejected logins', () => {
    const message = resolveLoginErrorMessage(
      axiosError(401, { status: 401, code: 'auth.login.failed', details: { remainingAttempts: 2 } }),
      t,
    )

    expect(message).toBe('이메일 또는 비밀번호가 올바르지 않습니다.')
  })

  it('keeps the rate limit message for throttled logins', () => {
    const message = resolveLoginErrorMessage(
      axiosError(429, { status: 429, code: 'auth.login.rateLimited' }),
      t,
    )

    expect(message).toBe('로그인 시도 횟수를 초과했습니다. 잠시 후 다시 시도해 주세요.')
  })

  it('appends the status code when a client error carries no translatable code', () => {
    const message = resolveLoginErrorMessage(axiosError(400, 'Bad Request'), t)

    expect(message).toBe('로그인에 실패했습니다. 잠시 후 다시 시도해주세요. (오류 400)')
  })

  it('falls back to the generic message when the failure has no http status', () => {
    const message = resolveLoginErrorMessage(new Error('boom'), t)

    expect(message).toBe('로그인에 실패했습니다.')
  })

  it('uses the provided generic key for provider specific failures', () => {
    const message = resolveLoginErrorMessage(new Error('boom'), t, {
      genericKey: 'auth.login.apple.generic',
    })

    expect(message).toBe('Apple 로그인에 실패했습니다.')
  })
})
