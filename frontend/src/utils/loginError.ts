import { AxiosError } from 'axios'
import { extractApiError, resolveApiErrorMessage } from './resolveApiError'

type LoginErrorTranslate = (key: string, params?: Record<string, unknown>) => string

type ResolveLoginErrorOptions = {
  genericKey?: string
}

/** Distinguishes "the server never answered" from "the server rejected the login". */
function isUnreachable(error: unknown): boolean {
  return error instanceof AxiosError && !error.response
}

function httpStatus(error: unknown): number | null {
  if (error instanceof AxiosError && error.response) {
    return error.response.status
  }

  const apiError = extractApiError(error)
  return typeof apiError?.status === 'number' ? apiError.status : null
}

/**
 * Login failures reach the user as one of four cases: the server was unreachable,
 * the server is broken (5xx), the login itself was rejected with a known error code,
 * or an unclassified response the user can only report by its status code.
 */
export function resolveLoginErrorMessage(
  error: unknown,
  t: LoginErrorTranslate,
  options: ResolveLoginErrorOptions = {},
): string {
  if (isUnreachable(error)) {
    return String(t('auth.login.error.network'))
  }

  const status = httpStatus(error)
  if (status !== null && status >= 500) {
    return String(t('auth.login.error.server', { status }))
  }

  const fallbackMessage = status === null
    ? String(t(options.genericKey ?? 'auth.login.error.generic'))
    : String(t('auth.login.error.unknown', { status }))

  return resolveApiErrorMessage(error, { fallbackMessage }, t)
}
