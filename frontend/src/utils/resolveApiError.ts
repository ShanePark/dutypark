import { AxiosError } from 'axios'
import type { ApiError } from '@/types'
import { translateGlobal } from '@/i18n'

type ApiErrorTranslate = (key: string, params?: Record<string, unknown>) => string

type ResolveApiErrorOptions = {
  fallbackKey?: string
  fallbackMessage?: string
}

type ApiErrorCarrier = {
  code?: unknown
  errorCode?: unknown
  details?: unknown
  errorDetails?: unknown
  fieldErrors?: unknown
}

const CODE_PATTERN = /^[a-z][a-zA-Z0-9]*(\.[a-zA-Z0-9]+)+$/

function isApiError(value: unknown): value is ApiError {
  return typeof value === 'object' && value !== null && 'status' in value
}

function isApiErrorCode(value: unknown): value is string {
  return typeof value === 'string' && CODE_PATTERN.test(value.trim())
}

function translateCode(code: string, t: ApiErrorTranslate): string | null {
  const key = `apiErrors.${code}`
  const translated = String(t(key))
  return translated == key ? null : translated
}

function findCode(source: ApiErrorCarrier | null | undefined): string | null {
  if (!source) {
    return null
  }

  const values = [
    source.code,
    source.errorCode,
  ]

  return values.find(isApiErrorCode) ?? null
}

export function extractApiError(error: unknown): ApiError | null {
  if (error instanceof AxiosError) {
    const data = error.response?.data
    return isApiError(data) ? data : null
  }

  return isApiError(error) ? error : null
}

export function getApiErrorDetail<T>(
  error: unknown,
  key: string,
): T | null {
  const apiError = extractApiError(error)
  if (!apiError?.details || typeof apiError.details !== 'object') {
    return null
  }

  const value = (apiError.details as Record<string, unknown>)[key]
  return (value as T | undefined) ?? null
}

export function resolveApiCodeMessage(
  source: ApiErrorCarrier | null | undefined,
  options: ResolveApiErrorOptions = {},
  t: ApiErrorTranslate = translateGlobal,
): string {
  const code = findCode(source)
  if (code) {
    const details = source?.details ?? source?.errorDetails
    const translated = translateCode(
      code,
      (key, params) => t(
        key,
        params ?? (typeof details === 'object' && details !== null ? details as Record<string, unknown> : undefined),
      ),
    )
    if (translated) {
      return translated
    }
  }

  if (options.fallbackKey) {
    return String(t(options.fallbackKey))
  }

  return options.fallbackMessage ?? String(t('common.swal.error'))
}

export function resolveApiErrorMessage(
  error: unknown,
  options: ResolveApiErrorOptions = {},
  t: ApiErrorTranslate = translateGlobal,
): string {
  return resolveApiCodeMessage(extractApiError(error), options, t)
}
